import 'dart:convert';

import 'domain/players.dart';
import 'models.dart';

/// Owns the on-disk shape of an undo snapshot: a match plus its innings sheets.
/// Keeping the envelope in one place means `pushSnapshot` and `undo` cannot
/// drift apart on the JSON keys, and the format can be tested without a store.
class UndoEnvelope {
  static String encode(Match match, Map<String, InningsSheet> sheets) =>
      jsonEncode({
        'm': match.toJson(),
        's': sheets.map((k, v) => MapEntry(k, v.toJson())),
      });

  /// Returns null for legacy plain-match entries (pre player tracking) and for
  /// anything that is not one of our envelopes. Callers fall back to
  /// [Match.decode] in that case.
  static ({Match match, Map<String, InningsSheet> sheets})? decode(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is! Map || d['m'] is! Map) return null;
      final m = Match.fromJson(Map<String, dynamic>.from(d['m'] as Map));
      final sheets = <String, InningsSheet>{};
      final sj = Map<String, dynamic>.from((d['s'] ?? {}) as Map);
      for (final e in sj.entries) {
        sheets[e.key.toString()] = InningsSheet.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        );
      }
      return (match: m, sheets: sheets);
    } catch (_) {
      return null;
    }
  }
}
