import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'math.dart';
import 'models.dart';

/// Offline store: SharedPreferences only, undo capped at 60.
/// No network, no Firebase, no HTTP - 100% offline.
class MatchStore extends ChangeNotifier {
  static const kActive = 'cricket_active_match_v4';
  static const kHistory = 'cricket_history_vault_v4';
  static const kUndo = 'cricket_undo_stack_v4';
  static const kTheme = 'cricket_app_theme';

  Match? match;
  MatchConfig draft = MatchConfig();
  bool nbArmed = false;
  String themeId = 'sunlight';
  List<String> _undo = [];
  List<String> _redo = [];
  bool loaded = false;

  Innings? get innings =>
      match == null ? null : (match!.currentInnings == 1 ? match!.innings1 : match!.innings2);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    themeId = p.getString(kTheme) ?? 'sunlight';
    final raw = p.getString(kActive);
    if (raw != null) {
      try {
        final m = Match.decode(raw);
        if (_isActive(m)) match = m;
      } catch (_) {}
    }
    try {
      _undo = (jsonDecode(p.getString(kUndo) ?? '[]') as List).cast<String>();
    } catch (_) {
      _undo = [];
    }
    _redo = [];
    loaded = true;
    notifyListeners();
  }

  bool _isActive(Match m) {
    if (m.completed || m.winner != null) return false;
    if (m.currentInnings == 2 && m.innings2 != null) {
      final inn = m.innings2!;
      if (inn.completed) return false;
      final maxBalls = CricketMath.totalBalls(m.config.totalOvers);
      final maxW = CricketMath.getMaxWickets(
          m.config.playersPerSide, m.config.rules.lastManStanding);
      final tgt = m.target ?? (m.innings1.runs + 1);
      if (inn.runs >= tgt || inn.legalDeliveries >= maxBalls || inn.wickets >= maxW) {
        return false;
      }
    }
    return true;
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    if (match != null && _isActive(match!)) {
      await p.setString(kActive, match!.encode());
    } else {
      await p.remove(kActive);
    }
    await p.setString(kUndo, jsonEncode(_undo));
    await p.setString(kTheme, themeId);
  }

  void setTheme(String id) {
    themeId = id;
    _persist();
    notifyListeners();
  }

  void pushSnapshot() {
    if (match == null) return;
    _undo.add(match!.encode());
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  Future<void> undo() async {
    nbArmed = false;
    if (_undo.isEmpty) return;
    if (match != null) _redo.add(match!.encode());
    match = Match.decode(_undo.removeLast());
    match!.completed = false;
    if (match!.currentInnings == 1) match!.innings1.completed = false;
    if (match!.innings2 != null && match!.currentInnings == 2) {
      match!.innings2!.completed = false;
    }
    HapticFeedback.lightImpact();
    await _persist();
    notifyListeners();
  }

  bool get canUndo => _undo.isNotEmpty;

  void startMatch(MatchConfig cfg) {
    // Team A bats first by default (toss logic simplified, editable later)
    final inn = Innings.create(cfg.teamA, cfg.teamB);
    match = Match(config: cfg, innings1: inn);
    _undo.clear();
    _redo.clear();
    nbArmed = false;
    _persist();
    notifyListeners();
  }

  void _addBall(Innings inn, Ball b) {
    if (inn.overs.isEmpty) inn.overs.add(Over(overNumber: 1));
    inn.overs.last.balls.add(b);
    inn.runs += b.totalRuns;
    if (b.isLegal) inn.legalDeliveries++;
    if (b.isWicket) inn.wickets++;
    // extras counters
    if (b.extra == 'WD') inn.wides += b.extraRuns;
    if (b.extra == 'NB') inn.noBalls += b.extraRuns;
    if (b.extra == 'B') inn.byes += b.extraRuns == 0 ? b.runs : b.extraRuns;
    if (b.extra == 'LB') inn.legByes += b.extraRuns == 0 ? b.runs : b.extraRuns;
    // over roll
    final legalInOver =
        inn.overs.last.balls.where((x) => x.isLegal).length;
    if (legalInOver >= 6) {
      inn.overs.add(Over(overNumber: inn.overs.length + 1));
      inn.currentOverNumber = inn.overs.length;
    }
  }

  String? score({
    required String action, // DOT,RUNS,FOUR,SIX,WIDE,NB,WICKET,BYE,LEGBYE
    int runs = 0,
    String wicketType = 'Bowled',
  }) {
    final m = match;
    final inn = innings;
    if (m == null || inn == null || inn.completed) return 'Innings completed';
    pushSnapshot();
    final rules = m.config.rules;

    Ball b;
    switch (action) {
      case 'DOT':
        if (nbArmed) {
          b = Ball(runs: 0, extra: 'NB', extraRuns: rules.noBallPenalty, isLegal: false, badge: 'NB');
          if (rules.freeHit) inn.isFreeHitActive = true;
          nbArmed = false;
        } else {
          b = Ball(runs: 0, badge: '0');
        }
        break;
      case 'RUNS':
        if (nbArmed) {
          b = Ball(runs: runs, extra: 'NB', extraRuns: rules.noBallPenalty, isLegal: false, badge: 'N$runs');
          if (rules.freeHit) inn.isFreeHitActive = true;
          nbArmed = false;
        } else {
          b = Ball(runs: runs, badge: '$runs');
        }
        break;
      case 'FOUR':
        if (nbArmed) {
          b = Ball(runs: 4, extra: 'NB', extraRuns: rules.noBallPenalty, isLegal: false, badge: 'N4');
          nbArmed = false;
        } else {
          b = Ball(runs: 4, badge: '4');
        }
        break;
      case 'SIX':
        if (nbArmed) {
          b = Ball(runs: 6, extra: 'NB', extraRuns: rules.noBallPenalty, isLegal: false, badge: 'N6');
          nbArmed = false;
        } else {
          b = Ball(runs: 6, badge: '6');
        }
        break;
      case 'WIDE':
        b = Ball(runs: 0, extra: 'WD', extraRuns: rules.widePenalty, isLegal: false, badge: 'WD');
        break;
      case 'NB_DIRECT':
        b = Ball(runs: runs, extra: 'NB', extraRuns: rules.noBallPenalty, isLegal: false, badge: runs > 0 ? 'N$runs' : 'NB');
        if (rules.freeHit) inn.isFreeHitActive = true;
        break;
      case 'BYE':
        b = Ball(runs: 0, extra: 'B', extraRuns: runs, isLegal: true, badge: 'B$runs');
        break;
      case 'LEGBYE':
        b = Ball(runs: 0, extra: 'LB', extraRuns: runs, isLegal: true, badge: 'LB$runs');
        break;
      case 'WICKET':
        // Free-hit protects wickets (except run-out) - simplified: consume free hit
        if (inn.isFreeHitActive && wicketType != 'Run Out') {
          inn.isFreeHitActive = false;
          b = Ball(runs: runs, badge: runs == 0 ? '0' : '$runs');
        } else {
          inn.isFreeHitActive = false;
          b = Ball(runs: runs, isWicket: true, wicketType: wicketType, badge: 'W');
        }
        break;
      default:
        _undo.removeLast();
        return 'Unknown action';
    }

    // Free-hit trigger on no-ball
    if (b.extra == 'NB' && rules.freeHit) inn.isFreeHitActive = true;
    // Non-NB legal ball consumes free hit single-ball effect (keep active until next legal? simplified: clear after 1 legal ball)
    if (b.isLegal && inn.isFreeHitActive && b.extra != 'NB' && action != 'WICKET') {
      // keep active for this ball then clear
      inn.isFreeHitActive = false;
    }

    _addBall(inn, b);
    HapticFeedback.mediumImpact();
    _checkEnd();
    _persist();
    notifyListeners();
    return null;
  }

  void toggleNb() {
    nbArmed = !nbArmed;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  void _checkEnd() {
    final m = match!;
    final inn = innings!;
    final maxBalls = CricketMath.totalBalls(m.config.totalOvers);
    final maxW = CricketMath.getMaxWickets(
        m.config.playersPerSide, m.config.rules.lastManStanding);
    if (m.currentInnings == 1) {
      if (inn.legalDeliveries >= maxBalls || inn.wickets >= maxW) {
        inn.completed = true;
        m.target = inn.runs + 1;
      }
    } else {
      final tgt = m.target ?? (m.innings1.runs + 1);
      final ballsLeft = maxBalls - inn.legalDeliveries;
      if (inn.runs >= tgt) {
        inn.completed = true;
        m.completed = true;
        m.winner = inn.battingTeam;
        final wktsLeft = maxW - inn.wickets;
        m.winMargin = 'Won by $wktsLeft wicket${wktsLeft == 1 ? '' : 's'}';
        _archive();
      } else if (inn.legalDeliveries >= maxBalls || inn.wickets >= maxW) {
        inn.completed = true;
        m.completed = true;
        if (inn.runs == tgt - 1) {
          m.winner = 'TIE';
          m.winMargin = 'Scores level';
        } else if (inn.runs < tgt - 1) {
          m.winner = inn.bowlingTeam;
          final diff = (tgt - 1) - inn.runs;
          m.winMargin = 'Won by $diff run${diff == 1 ? '' : 's'}';
        }
        _archive();
      } else if (ballsLeft <= 0) {
        // safety
        _checkEnd();
      }
    }
  }

  void startSecondInnings() {
    final m = match!;
    final firstBowl = m.innings1.bowlingTeam;
    final firstBat = m.innings1.battingTeam;
    m.innings2 = Innings.create(firstBowl, firstBat, m.target);
    m.currentInnings = 2;
    nbArmed = false;
    _persist();
    notifyListeners();
  }

  Future<void> _archive() async {
    final p = await SharedPreferences.getInstance();
    List hist = [];
    try {
      hist = jsonDecode(p.getString(kHistory) ?? '[]') as List;
    } catch (_) {}
    final rec = match!.toJson();
    rec['savedAt'] = DateTime.now().toIso8601String();
    hist.insert(0, rec);
    if (hist.length > 50) hist = hist.sublist(0, 50);
    await p.setString(kHistory, jsonEncode(hist));
  }

  Future<List<Match>> history() async {
    final p = await SharedPreferences.getInstance();
    try {
      final list = jsonDecode(p.getString(kHistory) ?? '[]') as List;
      return list.map((e) => Match.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteHistoryAt(int idx) async {
    final p = await SharedPreferences.getInstance();
    final h = await history();
    if (idx >= 0 && idx < h.length) {
      h.removeAt(idx);
      await p.setString(kHistory, jsonEncode(h.map((e) => e.toJson()).toList()));
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(kHistory);
    notifyListeners();
  }

  void abandon() {
    match = null;
    _undo.clear();
    _redo.clear();
    _persist();
    notifyListeners();
  }

  void newMatch() {
    match = null;
    _undo.clear();
    _redo.clear();
    _persist();
    notifyListeners();
  }
}
