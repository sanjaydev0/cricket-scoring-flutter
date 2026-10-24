import 'dart:async';

import 'domain/players.dart';
import 'math.dart';
import 'models.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sound.dart';
import 'store.dart';
import 'undo_log.dart';

/// Pure scoring state: the live match, its sheets, and the counters that drive
/// the UI. Extracted from [MatchStore] so the scoring rules can be reasoned
/// about and tested without SharedPreferences, backup, or live sync. The store
/// remains the persistence/notification adapter and keeps owning settings.
class ScoringEngine extends ChangeNotifier {
  /// Back-reference to the owning store for settings (sound/haptics/style) and
  /// side effects. Set by [MatchStore] after construction.
  MatchStore? store;

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

  Timer? breakTimer;

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

  void buzz(Future<void> Function() fn) {
    if (store?.hapticsOn != true) return;
    try {
      fn();
    } catch (_) {}
  }

  void feedback(Ball b) {
    final sfx = SoundService.instance;
    try {
      if (b.isWicket) {
        buzz(HapticFeedback.heavyImpact);
        sfx.wicket();
      } else if (b.badge == '4' || b.badge.startsWith('N4')) {
        buzz(HapticFeedback.heavyImpact);
        sfx.four();
      } else if (b.badge == '6' || b.badge.startsWith('N6')) {
        buzz(HapticFeedback.heavyImpact);
        sfx.six();
      } else if (b.extra == 'WD') {
        buzz(HapticFeedback.mediumImpact);
        sfx.wide();
      } else if (b.extra == 'NB') {
        buzz(HapticFeedback.mediumImpact);
        sfx.noball();
      } else if (b.extra != 'none') {
        buzz(HapticFeedback.selectionClick);
        sfx.extra();
      } else {
        buzz(HapticFeedback.lightImpact);
        sfx.run();
      }
    } catch (_) {}
  }

  void bumpAppearances() {
    final sheet = currentSheet;
    final m = match;
    if (sheet == null || m == null) return;
    final key = '${m.createdAt}_${m.currentInnings}';
    final store = this.store;
    if (store == null) return;
    if (store.appearanceKeys.contains(key)) return;
    store.appearanceKeys.add(key);
    for (final c in sheet.batting.values) {
      if (c.position > 0) {
        store.playerAppearances[c.playerId] =
            (store.playerAppearances[c.playerId] ?? 0) + 1;
      }
    }
    for (final c in sheet.bowling.values) {
      if ((c.balls > 0 || c.wickets > 0) &&
          (sheet.batting[c.playerId]?.position ?? 0) == 0) {
        store.playerAppearances[c.playerId] =
            (store.playerAppearances[c.playerId] ?? 0) + 1;
      }
    }
  }

  void withdrawAppearances() {
    final m = match;
    if (m == null) return;
    final key = '${m.createdAt}_${m.currentInnings}';
    final store = this.store;
    if (store == null) return;
    if (!store.appearanceKeys.remove(key)) return;
    final sheet = currentSheet;
    if (sheet == null) return;
    for (final c in sheet.batting.values) {
      if (c.position > 0) {
        store.playerAppearances[c.playerId] =
            ((store.playerAppearances[c.playerId] ?? 1) - 1).clamp(0, 1 << 30);
      }
    }
    for (final c in sheet.bowling.values) {
      if ((c.balls > 0 || c.wickets > 0) &&
          (sheet.batting[c.playerId]?.position ?? 0) == 0) {
        store.playerAppearances[c.playerId] =
            ((store.playerAppearances[c.playerId] ?? 1) - 1).clamp(0, 1 << 30);
      }
    }
  }

  void pushSnapshot() {
    if (match == null) return;
    store?.undoLog.add(UndoEnvelope.encode(match!, sheets));
    if ((store?.undoLog.length ?? 0) > 60) store?.undoLog.removeAt(0);
    store?.redoLog.clear();
  }

  void pushSnapshotSafe() {
    if (match != null) pushSnapshot();
  }

  void toggleNb() {
    nbArmed = !nbArmed;
    buzz(HapticFeedback.selectionClick);
    SoundService.instance.extra();
    notifyListeners();
  }

  void startBreakCountdown(String dest) {
    breakTimer?.cancel();
    breakDest = dest;
    breakWait = 10;
    notifyListeners();
    breakTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      breakWait--;
      if (breakWait <= 0) {
        t.cancel();
        breakTimer = null;
        breakDest = null;
        breakWait = 0;
      }
      notifyListeners();
    });
  }

  void skipBreakWait() {
    breakTimer?.cancel();
    breakTimer = null;
    breakDest = null;
    breakWait = 0;
    notifyListeners();
  }

  void cancelBreak() {
    breakTimer?.cancel();
    breakTimer = null;
    breakDest = null;
    breakWait = 0;
  }

  void abandon() {
    cancelBreak();
    match = null;
    sheets = {};
    store?.undoLog.clear();
    store?.redoLog.clear();
    if (store?.roomCode != null) {
      unawaited(store!.stopSharing());
    }
    store?.persistOnly();
  }

  void newMatch() {
    cancelBreak();
    match = null;
    sheets = {};
    store?.undoLog.clear();
    store?.redoLog.clear();
    if (store?.roomCode != null) {
      unawaited(store!.stopSharing());
    }
    store?.persistOnly();
  }
}
