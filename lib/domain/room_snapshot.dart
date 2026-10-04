import 'dart:convert';

/// One published state of a live room: the whole match, plus the ordering
/// metadata a viewer needs to stay consistent.
///
/// The match is carried verbatim as the JSON the app already persists, so there
/// is no room-specific score model to keep in sync — and a viewer that misses a
/// packet simply re-reads the next full snapshot instead of replaying deltas.
///
/// [version] is checked on decode. Bump it whenever the match JSON gains or
/// changes fields, so an old viewer can say "update me" instead of rendering
/// nonsense.
class RoomSnapshot {
  static const version = 1;

  /// Monotonic per room. Higher wins; equal means already applied.
  final int seq;

  /// The `Match.toJson()` document.
  final Map<String, dynamic> match;

  final DateTime updatedAt;

  /// How long the room stays readable.
  final Duration ttl;

  const RoomSnapshot({
    required this.seq,
    required this.match,
    required this.updatedAt,
    this.ttl = const Duration(hours: 12),
  });

  Map<String, dynamic> toPayload() => {
        'v': version,
        'seq': seq,
        'match': match,
        'at': updatedAt.toIso8601String(),
      };

  /// Decodes a payload written by [toPayload]. Returns null for a payload this
  /// build cannot read, so callers fall back to "waiting for a newer score"
  /// instead of crashing on a missing field.
  ///
  /// Accepts a JSON *string* as well as a map. An early build sent the payload
  /// pre-encoded, so Postgres stored it as a jsonb string scalar; rooms written
  /// that way must still decode rather than showing a viewer nothing.
  static RoomSnapshot? fromPayload(dynamic payload) {
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } catch (_) {
        return null;
      }
    }
    if (payload is! Map) return null;
    payload = Map<String, dynamic>.from(payload);
    final v = payload['v'];
    if (v is! int || v != version) return null;
    final seq = payload['seq'];
    final match = payload['match'];
    if (seq is! int || match is! Map) return null;
    final at = DateTime.tryParse('${payload['at']}') ?? DateTime.now();
    return RoomSnapshot(
      seq: seq,
      match: Map<String, dynamic>.from(match),
      updatedAt: at,
    );
  }

  /// Builds from a database row: picks the payload columns out of the row and
  /// falls back to `seq`/`updated_at` on the row itself.
  static RoomSnapshot? fromRow(Map<String, dynamic> row) {
    final payload = row['payload'];
    if (payload is Map || payload is String) {
      final decoded = fromPayload(payload);
      if (decoded != null) return decoded;
    }
    final seq = row['seq'];
    final match = row['match'];
    if (seq is! int || match is! Map) return null;
    return RoomSnapshot(
      seq: seq,
      match: Map<String, dynamic>.from(match),
      updatedAt: DateTime.tryParse('${row['updated_at']}') ?? DateTime.now(),
    );
  }

  /// True when this snapshot is newer than [other].
  bool supersedes(RoomSnapshot other) => seq > other.seq;
}
