import '../domain/room_snapshot.dart';

/// Where a sync adapter is in its lifecycle. The UI shows this verbatim so a
/// scorer can tell "no backend configured" apart from "backend is down" — the
/// two failures used to look identical because there was no UI at all.
enum SyncState {
  /// No backend configured: the app runs exactly as before, offline.
  unconfigured,

  /// Adapter present, idle, ready to open a room.
  offline,

  /// Signing in / opening the first connection.
  connecting,

  /// Signed in and reachable.
  ready,

  /// Configured but failing; [SyncPort.lastError] says why.
  error,
}

/// The seam between scoring and the internet.
///
/// Everything online lives behind this: the scorer publishes snapshots, a
/// viewer receives them, and the implementation can be the Supabase backend, a
/// local-only no-op, or a fake in tests. Scoring itself never awaits this — a
/// dead backend must never be able to block or fail a ball.
///
/// Two adapters (online + local-only) make this a real seam rather than a
/// hypothetical one.
abstract interface class SyncPort {
  SyncState get state;

  /// Human-readable reason for the last failure, or null.
  String? get lastError;

  /// Snapshots received from a watched room, newest last.
  Stream<RoomSnapshot> get roomUpdates;

  /// Number of viewers currently connected to the watched room, best effort.
  int get viewerCount;

  /// Signs in and opens connections. Must be safe to call when unconfigured.
  Future<void> init();

  /// Opens a room and returns its join code, or null when unavailable.
  Future<String?> createRoom();

  /// Publishes the newest state of [code]. Fire-and-forget from scoring.
  Future<void> publish(String code, RoomSnapshot snapshot);

  /// Subscribes to a room and streams its snapshots. Viewer side.
  Future<void> watchRoom(String code);

  /// Deletes the room. Viewer-side locks keep failing after this.
  Future<void> endRoom(String code);

  Future<void> shutdown();
}
