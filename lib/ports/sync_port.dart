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

/// Why sharing could not start.
///
/// These are kept distinct on purpose. The first cut of this returned a bare
/// `String?` code, and the UI reported every failure as "no backend configured
/// in this build" — so a network failure or a rejected RPC was indistinguishable
/// from a missing build flag, and a real bug shipped with a message that pointed
/// at the wrong thing entirely.
enum ShareFailure {
  /// This build has no Supabase URL/key: sharing is off by design.
  noBackend,

  /// Tried to share with no live match.
  noMatch,

  /// Configured, but the backend could not be reached.
  offline,

  /// Reached the backend, which refused. [ShareAttempt.detail] says why.
  failed,
}

/// The outcome of trying to open a room: a code, or a reason.
class ShareAttempt {
  final String? code;
  final ShareFailure? failure;

  /// The backend's own message, when there is one.
  final String? detail;

  const ShareAttempt.ok(this.code)
      : failure = null,
        detail = null;

  const ShareAttempt.failed(this.failure, [this.detail]) : code = null;

  bool get ok => code != null;

  /// One sentence for the scorer. Names the actual cause instead of guessing.
  String get message => switch (failure) {
        null => 'Live — code $code',
        ShareFailure.noBackend =>
          'Live sharing is off in this build (no backend configured)',
        ShareFailure.noMatch => 'Start a match before sharing',
        ShareFailure.offline => 'Cannot reach the live server — $detail',
        ShareFailure.failed => 'Could not open a room — $detail',
      };
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

  /// Connects and opens the client. Must be safe to call when unconfigured,
  /// and safe to call concurrently — implementations single-flight it, because
  /// two overlapping connects left the client half-built and permanently
  /// unavailable.
  Future<void> init();

  /// Opens a room and returns its join code, or why it could not.
  Future<ShareAttempt> createRoom();

  /// Publishes the newest state of [code]. Fire-and-forget from scoring.
  Future<void> publish(String code, RoomSnapshot snapshot);

  /// Subscribes to a room and streams its snapshots. Viewer side.
  Future<void> watchRoom(String code);

  /// Deletes the room. Viewer-side locks keep failing after this.
  Future<void> endRoom(String code);

  Future<void> shutdown();
}
