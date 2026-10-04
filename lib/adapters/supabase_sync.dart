import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/room_code.dart';
import '../domain/room_snapshot.dart';
import '../ports/sync_port.dart';

/// Supabase-backed rooms.
///
/// Design notes that matter:
///
/// * The scoring phone signs in **anonymously**. Its uid becomes the row's
///   `owner_id`, and row level security is what stops anyone else writing —
///   not any check in this file. A leaked join code therefore grants read and
///   nothing else, even if someone rewrites the client.
/// * Every write carries the whole match. A viewer that drops a packet just
///   reads the next full snapshot; there are no deltas to reconcile.
/// * Nothing here can break scoring. Scoring calls [publish] without awaiting
///   it, and every call is internally guarded, so a dead backend degrades to
///   "no live room", never to a failed ball.
class SupabaseSync implements SyncPort {
  final String url;
  final String publishableKey;

  SupabaseSync({required this.url, required this.publishableKey});

  /// Postgres unique_violation: that code is already taken, draw another.
  static const _duplicateCode = '23505';

  SupabaseClient? _db;
  RealtimeChannel? _channel;
  String? _watching;
  final _updates = StreamController<RoomSnapshot>.broadcast();

  SyncState _state = SyncState.unconfigured;
  String? _lastError;

  @override
  SyncState get state => _state;

  @override
  String? get lastError => _lastError;

  @override
  Stream<RoomSnapshot> get roomUpdates => _updates.stream;

  @override
  int get viewerCount {
    try {
      final state = _channel?.presence.state;
      if (state == null) return 0;
      var n = 0;
      for (final list in state.values) {
        n += list.length;
      }
      return n;
    } catch (_) {
      return 0;
    }
  }

  void _set(SyncState s, [String? error]) {
    _state = s;
    _lastError = error;
  }

  @override
  Future<void> init() async {
    if (url.isEmpty || publishableKey.isEmpty) {
      _set(SyncState.unconfigured, 'No Supabase URL/key configured');
      return;
    }
    _set(SyncState.connecting);
    try {
      final supabase = await Supabase.initialize(
        url: url,
        publishableKey: publishableKey,
        // Supabase's realtime client logs handshake details at debug level.
        debug: false,
      );
      _db = supabase.client;
      // Anonymous sign-in is what gives the scorer an owner identity. The
      // dashboard must have "Anonymous sign-ins" enabled under
      // Authentication -> Sign In / Providers.
      if (_db!.auth.currentSession == null) {
        await _db!.auth.signInAnonymously();
      }
      _set(SyncState.ready);
    } catch (e) {
      _db = null;
      _set(SyncState.error, 'Backend unreachable: $e');
    }
  }

  @override
  Future<String?> createRoom() async {
    if (_db == null) {
      if (_state != SyncState.ready) await init();
    }
    final db = _db;
    if (db == null || _state != SyncState.ready) return null;

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = RoomCode.generate();
      final expires = DateTime.now().add(const Duration(hours: 12));
      try {
        await db.from('rooms').insert({
          'code': code,
          'owner_id': db.auth.currentUser!.id,
          'seq': 0,
          // Placeholder until the first ball: an empty, versioned payload that
          // a viewer decodes but ignores (seq 0 means "nothing scored yet").
          'payload': {
            'v': RoomSnapshot.version,
            'seq': 0,
            'match': <String, dynamic>{},
            'at': expires.toIso8601String(),
          },
          'expires_at': expires.toIso8601String(),
        });
        return code;
      } on PostgrestException catch (e) {
        if (e.code == _duplicateCode) continue; // astronomically unlikely
        _set(SyncState.error, 'Could not open room: ${e.message}');
        return null;
      } catch (e) {
        _set(SyncState.error, 'Could not open room: $e');
        return null;
      }
    }
    _set(SyncState.error, 'Could not find a free room code');
    return null;
  }

  @override
  Future<void> publish(String code, RoomSnapshot snapshot) async {
    final db = _db;
    if (db == null || _state != SyncState.ready) return;
    try {
      await db.from('rooms').update({
        'seq': snapshot.seq,
        'payload': snapshot.toPayload(),
        'updated_at': snapshot.updatedAt.toIso8601String(),
        // Refresh the TTL on every publish so a long match stays readable for
        // its full length instead of expiring mid-over.
        'expires_at': DateTime.now().add(snapshot.ttl).toIso8601String(),
      }).eq('code', code);
    } catch (e) {
      // Never surfaced to scoring: the match is already recorded locally.
      _set(SyncState.error, 'Publish failed: $e');
    }
  }

  @override
  Future<void> watchRoom(String code) async {
    final db = _db;
    if (db == null) {
      if (_state != SyncState.ready) await init();
    }
    final client = _db;
    if (client == null || _state != SyncState.ready) return;
    await _stopChannel();

    _watching = RoomCode.normalize(code) ?? code;
    final name = 'room:${_watching!}';
    // Catch up first: the current snapshot may be older than our last event.
    try {
      final row = await client
          .from('rooms')
          .select('payload, seq, updated_at')
          .eq('code', _watching!)
          .maybeSingle();
      if (row != null) {
        final snap = RoomSnapshot.fromRow(row);
        if (snap != null && snap.seq > 0) _updates.add(snap);
      }
    } catch (e) {
      _set(SyncState.error, 'Could not read room: $e');
    }

    final channel = client.channel(name)
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'rooms',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'code',
          value: _watching!,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          if (row.isEmpty) return;
          final snap = RoomSnapshot.fromRow(row);
          if (snap != null) _updates.add(snap);
        },
      );
    // subscribe() is synchronous; it kicks off the socket connect in the
    // background, so a watcher never blocks the UI on a handshake.
    channel.subscribe();
    // Best effort presence so a scorer can see how many people are watching.
    try {
      await channel.track({'at': DateTime.now().toIso8601String()});
    } catch (_) {}
    _channel = channel;
  }

  @override
  Future<void> endRoom(String code) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.from('rooms').delete().eq('code', code);
    } catch (_) {
      // Even if this fails the row expires on its own.
    }
    if (_watching == code) {
      await _stopChannel();
      _watching = null;
    }
  }

  Future<void> _stopChannel() async {
    final ch = _channel;
    _channel = null;
    if (ch == null) return;
    try {
      await _db?.removeChannel(ch);
    } catch (_) {}
  }

  @override
  Future<void> shutdown() async {
    await _stopChannel();
    await _updates.close();
    _db = null;
    _set(SyncState.offline);
  }
}
