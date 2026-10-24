import 'models.dart';
import 'domain/players.dart';

/// Pure scoring state: the live match, its sheets, and the counters that drive
/// the UI. Extracted from [MatchStore] so the scoring rules can be reasoned
/// about and tested without SharedPreferences, backup, or live sync. The store
/// remains the persistence/notification adapter and keeps owning settings.
class ScoringEngine {
  Match? match;
  MatchConfig draft = MatchConfig();
  bool nbArmed = false;

  /// Advances on score() only — strip motion key.
  int ballGen = 0;

  /// Countdown seconds before break/result handoff.
  int breakWait = 0;

  /// '/break' | '/result' while counting down.
  String? breakDest;

  Map<String, InningsSheet> sheets = {};

  /// Undo banner text for the change that was just applied.
  String? lastChange;
}
