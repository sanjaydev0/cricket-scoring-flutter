import 'domain/players.dart';
import 'math.dart';
import 'models.dart';

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

  Innings? get innings => match == null
      ? null
      : (match!.currentInnings == 1 ? match!.innings1 : match!.innings2);

  InningsSheet? get currentSheet =>
      match == null ? null : sheetFor(match!.currentInnings);

  InningsSheet? sheetFor(int inningsNo) => sheets[inningsNo.toString()];

  void addBall(Innings inn, Ball b) {
    if (inn.overs.isEmpty) inn.overs.add(Over(overNumber: 1));
    if (inn.overs.last.balls.where((x) => x.isLegal).length >= 6) {
      inn.overs.add(Over(overNumber: inn.overs.length + 1));
      inn.currentOverNumber = inn.overs.length;
    }
    final last = inn.overs.last;
    last.balls = [...last.balls, b];
    inn.runs += b.totalRuns;
    if (b.isLegal) inn.legalDeliveries++;
    if (b.isWicket) inn.wickets++;
    if (b.extra == 'WD') inn.wides += b.extraRuns;
    if (b.extra == 'NB') inn.noBalls += b.extraRuns;
    if (b.extra == 'B') inn.byes += b.extraRuns;
    if (b.extra == 'LB') inn.legByes += b.extraRuns;
  }

  void moveDismissalToNonStriker(InningsSheet sheet, Ball b) {
    final outId = sheet.nonStrikerId;
    if (outId == null) return;
    final bat = sheet.striker;
    final nst = sheet.batting[outId];
    if (bat == null || nst == null) return;
    nst.dismissal = bat.dismissal;
    nst.isNotOut = false;
    nst.wicketNumber = bat.wicketNumber;
    nst.bowlerName = bat.bowlerName;
    nst.dismissedByName = bat.dismissedByName;
    bat.dismissal = null;
    bat.isNotOut = true;
    bat.wicketNumber = 0;
    bat.bowlerName = null;
    bat.dismissedByName = null;
    b.strikerId = outId;
  }

  void closeCompletedOvers(Innings inn, InningsSheet sheet) {
    final done = sheet.completedOverCount(inn);
    if (done <= sheet.closedOvers) return;
    for (var i = sheet.closedOvers; i < done; i++) {
      sheet.swapEnds();
      finishOverForSheet();
    }
    sheet.closedOvers = done;
    final m = match;
    final maxBalls = m == null
        ? 0
        : CricketMath.totalBalls(m.config.totalOvers);
    final maxW = m == null
        ? 0
        : CricketMath.getMaxWickets(
            m.config.playersPerSide,
            m.config.rules.lastManStanding,
          );
    final over = inn.legalDeliveries >= maxBalls || inn.wickets >= maxW;
    sheet.needsNewBowler = !inn.completed && !over;
  }

  void finishOverForSheet() {
    final sheet = currentSheet;
    final inn = innings;
    if (sheet == null || inn == null) return;
    final overs = inn.overs;
    final last = overs.isEmpty ? null : overs.last;
    var legal = 0;
    if (last != null) {
      for (final b in last.balls) {
        if (b.isLegal) legal++;
      }
    }
    sheet.closeOver(legalBalls: legal);
  }
}
