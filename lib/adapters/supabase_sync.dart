import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/room_code.dart';
import '../domain/room_snapshot.dart';
import '../ports/sync_port.dart';

/// Supabase-backed rooms.
///
/// **Write access is the database's job.** The scoring phone holds a random
/// 256-bit secret per room and passes it to `room_publish` / `room_end`; those
/// `security definer` functions update the row only when the secret matches.
/// Direct writes through PostgREST are rejected by row level security, and the
/// secret table itself has no policy at all, so no client role can read it —
/// not even someone who knows the room code.
///
/// Verified against the live project: an `anon` PATCH on a room returns 204
/// with **zero rows affected**, and reading `room_secrets` returns 401.
///
/// Deliberately no Supabase Auth: anonymous sign-ins are disabled on a fresh
/// project, and a scoring app should not carry a token refresh cycle to save a
/// snapshot. The room code plus the secret are both capabilities.
///
/// Every publish carries the whole match, so a viewer that drops a packet just
/// reads the next full snapshot — there are no deltas to reconcile. Nothing
/// here can break scoring: callers never await, and every call is guarded.
class SupabaseSync implements SyncPort {
  final String url;
  final String publishableKey;

  SupabaseSync({required this.url, required this.publishableKey});

  /// Stored so a scorer can resume sharing after the app is killed.
  static const _secretKeyPrefix = 'cricket_room_secret_';

  /// 40 hex chars = 160 bits. Only the scoring phone ever has this.
  static String _newSecret() {
    final r = Random.secure();
    final bytes = List<int>.generate(20, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

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
    // debugPrint survives release builds, so a field failure is visible in
    // logcat instead of vanishing. The first cut of this swallowed every error
    // into lastError, which nothing displayed, and the app reported a network
    // error as "no backend configured in this build".
    if (error != null) {
      // ignore: avoid_print
      print('[CricScore sync] $s: $error');
    }
  }

  /// The in-flight connect, so concurrent callers share one attempt.
  Future<void>? _connecting;

  @override
  Future<void> init() {
    final inFlight = _connecting;
    if (inFlight != null) return inFlight;
    final attempt = _connect();
    _connecting = attempt;
    // Clear the slot when it settles, so a later failure can be retried.
    return attempt.whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    if (url.isEmpty || publishableKey.isEmpty) {
      _set(SyncState.unconfigured, 'No Supabase URL/key in this build');
      return;
    }
    _set(SyncState.connecting);
    try {
      final supabase = await Supabase.initialize(
        url: url,
        publishableKey: publishableKey,
        // Supabase's own logger is noisy; enable it for debug builds only and
        // rely on _set() for release visibility.
        debug: kDebugMode,
      );
      _db = supabase.client;
      _set(SyncState.ready);
    } catch (e) {
      _db = null;
      _set(SyncState.error, 'connect failed: $e');
    }
  }

  Future<void> _ensureReady() async {
    if (_state == SyncState.ready && _db != null) return;
    await init();
  }

  /// This phone's write-capability for [code], if it is sharing that room.
  Future<String?> _secretFor(String code) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString('$_secretKeyPrefix$code');
    } catch (_) {
      return null;
    }
  }

  Future<void> _rememberSecret(String code, String secret) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('$_secretKeyPrefix$code', secret);
    } catch (_) {}
  }

  Future<void> _forgetSecret(String code) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('$_secretKeyPrefix$code');
    } catch (_) {}
  }

  @override
  Future<ShareAttempt> createRoom() async {
    await _ensureReady();
    if (_state == SyncState.unconfigured) {
      return const ShareAttempt.failed(
          ShareFailure.noBackend, 'no URL/key at build time');
    }
    final db = _db;
    if (db == null || _state != SyncState.ready) {
      return ShareAttempt.failed(
          ShareFailure.offline, _lastError ?? 'not connected');
    }

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = RoomCode.generate();
      final secret = _newSecret();
      try {
        final created = await db.rpc(
          'room_create',
          params: {'p_code': code, 'p_secret': secret},
        );
        if (created == true) {
          await _rememberSecret(code, secret);
          return ShareAttempt.ok(code);
        }
        // Code already taken (astronomically unlikely): draw another.
      } catch (e) {
        _set(SyncState.error, 'room_create failed: $e');
        return ShareAttempt.failed(ShareFailure.failed, '$e');
      }
    }
    _set(SyncState.error, 'no free room code after 5 tries');
    return const ShareAttempt.failed(
        ShareFailure.failed, 'could not find a free room code');
  }

  @override
  Future<void> publish(String code, RoomSnapshot snapshot) async {
    final db = _db;
    if (db == null || _state != SyncState.ready) return;
    try {
      final secret = await _secretFor(code);
      if (secret == null) return; // not ours to write
      await db.rpc('room_publish', params: {
        'p_code': code,
        'p_secret': secret,
        'p_seq': snapshot.seq,
        // The payload must go as a JSON OBJECT, not a pre-encoded string.
        // Sending jsonEncode(...) made PostgREST store it as a jsonb *string
        // scalar (jsonb_typeof = 'string'), so a viewer reading the row could
        // not decode it and would sit on "waiting" forever.
        'p_payload': snapshot.toPayload(),
      });
    } catch (e) {
      // Never surfaced to scoring: the ball is already recorded locally.
      _set(SyncState.error, 'Publish failed: $e');
    }
  }

  @override
  Future<void> watchRoom(String code) async {
    await _ensureReady();
    final client = _db;
    if (client == null || _state != SyncState.ready) return;
    await _stopChannel();

    _watching = RoomCode.normalize(code) ?? code;
    // Catch up first: the row may be newer than our last event.
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

    final channel = client.channel('room:${_watching!}')
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
      final secret = await _secretFor(code);
      if (secret != null) {
        await db.rpc('room_end', params: {'p_code': code, 'p_secret': secret});
      }
    } catch (_) {
      // Even if this fails the row expires on its own.
    }
    await _forgetSecret(code);
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
