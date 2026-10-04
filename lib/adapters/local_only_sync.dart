import 'dart:async';

import '../domain/room_snapshot.dart';
import '../ports/sync_port.dart';

/// The default adapter: no backend, no network, no behaviour change.
///
/// This is what the app runs when no Supabase URL/key is supplied at build
/// time, and it is deliberately a real [SyncPort] rather than a null check
/// scattered through the store — sharing is simply unavailable, exactly as it
/// was before the feature existed.
class LocalOnlySync implements SyncPort {
  final _updates = StreamController<RoomSnapshot>.broadcast();

  @override
  SyncState get state => SyncState.unconfigured;

  @override
  String? get lastError => null;

  @override
  Stream<RoomSnapshot> get roomUpdates => _updates.stream;

  @override
  int get viewerCount => 0;

  @override
  Future<void> init() async {}

  @override
  Future<ShareAttempt> createRoom() async =>
      const ShareAttempt.failed(ShareFailure.noBackend, 'local-only build');

  @override
  Future<void> publish(String code, RoomSnapshot snapshot) async {}

  @override
  Future<void> watchRoom(String code) async {}

  @override
  Future<void> endRoom(String code) async {}

  @override
  Future<void> shutdown() async => _updates.close();
}

/// Records everything asked of it, for tests and for the "is sharing actually
/// publishing?" question that a real phone cannot answer.
class FakeSync implements SyncPort {
  final _updates = StreamController<RoomSnapshot>.broadcast();

  final List<String> publishedCodes = [];
  final List<RoomSnapshot> published = [];
  final List<String> created = [];
  final List<String> watched = [];
  final List<String> ended = [];

  /// Set to make [init] throw, exercising the store's failure path.
  Object? initError;

  /// Set to make [publish] throw, proving a dead backend cannot fail a ball.
  Object? publishError;

  /// Set to make [createRoom] fail.
  bool failCreate = false;

  SyncState _state = SyncState.ready;
  int _viewers = 0;

  @override
  SyncState get state => _state;

  @override
  String? get lastError => null;

  @override
  Stream<RoomSnapshot> get roomUpdates => _updates.stream;

  @override
  int get viewerCount => _viewers;

  set viewerCount(int v) => _viewers = v;

  @override
  Future<void> init() async {
    if (initError != null) throw initError!;
    _state = SyncState.ready;
  }

  @override
  Future<ShareAttempt> createRoom() async {
    if (failCreate) {
      return const ShareAttempt.failed(ShareFailure.failed, 'fake refused');
    }
    const code = 'TEST1';
    created.add(code);
    return const ShareAttempt.ok(code);
  }

  @override
  Future<void> publish(String code, RoomSnapshot snapshot) async {
    publishedCodes.add(code);
    published.add(snapshot);
    if (publishError != null) throw publishError!;
  }

  @override
  Future<void> watchRoom(String code) async => watched.add(code);

  @override
  Future<void> endRoom(String code) async => ended.add(code);

  @override
  Future<void> shutdown() async => _updates.close();

  /// Pushes a snapshot to whoever is watching (viewer-side tests).
  void emit(RoomSnapshot snapshot) => _updates.add(snapshot);
}
