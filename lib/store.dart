import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'math.dart';
import 'models.dart';
import 'sound.dart';

/// Offline store: SharedPreferences only. No network - 100% offline.
class MatchStore extends ChangeNotifier {
  static const kActive = 'cricket_active_match_v4';
  static const kHistory = 'cricket_history_vault_v4';
  static const kUndo = 'cricket_undo_stack_v4';
  static const kTheme = 'cricket_app_theme';
  static const kSound = 'cricket_sound_on';
  static const kAdvExtras = 'cricket_adv_extras';
  static const kStyle = 'cricket_style';
  static const kFont = 'cricket_score_font';
  static const kCeleb = 'cricket_celebration';
  static const kComplexWkts = 'cricket_complex_wkts';

  /// Team colors: fixed dots for differentiation (blue = Team A, red = Team B).
  static const teamAColor = 0xFF2563EB; // blue-600
  static const teamBColor = 0xFFDC2626; // red-600

  Match? match;
  MatchConfig draft = MatchConfig();
  bool nbArmed = false;
  String themeId = 'light'; // 'light' | 'dark'
  bool soundOn = true; // master arcade SFX toggle
  bool advancedExtras = true; // master extra-detail buttons toggle
  String styleId = 'umpire'; // keypad/strip/hero style preset
  String fontId = 'stadium'; // score numeral font
  String celebId = 'pulse'; // hero celebration: off + 10 styles
  bool complexWickets = true; // full wicket-type grid vs Wicket/RunOut
  List<String> _undo = [];
  List<String> _redo = [];
  bool loaded = false;

  Innings? get innings => match == null
      ? null
      : (match!.currentInnings == 1 ? match!.innings1 : match!.innings2);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    themeId = _migrateTheme(p.getString(kTheme));
    soundOn = p.getBool(kSound) ?? true;
    advancedExtras = p.getBool(kAdvExtras) ?? true;
    styleId = p.getString(kStyle) ?? 'umpire';
    fontId = p.getString(kFont) ?? 'stadium';
    celebId = MatchStore.migrateCeleb(p.getString(kCeleb));
    complexWickets = p.getBool(kComplexWkts) ?? true;
    SoundService.instance.init(enabled: soundOn);
    final raw = p.getString(kActive);
    if (raw != null) {
      try {
        final m = Match.decode(raw);
        if (m.config.commonPlayers > 1) m.config.commonPlayers = 1;
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

  /// Old 3-theme ids -> light/dark.
  String _migrateTheme(String? v) {
    switch (v) {
      case 'dark':
      case 'night':
        return 'dark';
      default:
        return 'light'; // sunlight, solar, null
    }
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
      if (inn.runs >= tgt ||
          inn.legalDeliveries >= maxBalls ||
          inn.wickets >= maxW) {
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
    await p.setBool(kSound, soundOn);
    await p.setBool(kAdvExtras, advancedExtras);
    await p.setString(kStyle, styleId);
    await p.setString(kFont, fontId);
    await p.setString(kCeleb, celebId);
    await p.setBool(kComplexWkts, complexWickets);
  }

  void setTheme(String id) {
    themeId = id == 'dark' ? 'dark' : 'light';
    _persist();
    notifyListeners();
  }

  void toggleTheme() => setTheme(themeId == 'dark' ? 'light' : 'dark');

  void setSound(bool v) {
    soundOn = v;
    SoundService.instance.setEnabled(v);
    _persist();
    notifyListeners();
  }

  void setAdvancedExtras(bool v) {
    advancedExtras = v;
    _persist();
    notifyListeners();
  }

  void setStyle(String id) {
    styleId = id;
    _persist();
    notifyListeners();
  }

  void setFont(String id) {
    fontId = id;
    _persist();
    notifyListeners();
  }

  static const celebIds = [
    'off',
    'rise',
    'pop',
    'flash',
    'glow',
    'roll',
    'shake',
    'sweep',
    'ring',
    'burst',
    'blink',
  ];
  static const celebNames = {
    'off': 'Off',
    'rise': 'Rise Tag',
    'pop': 'Pop',
    'flash': 'Flash Tint',
    'glow': 'Glow Bloom',
    'roll': 'Tick Roll',
    'shake': 'Shake',
    'sweep': 'Shimmer Sweep',
    'ring': 'Ring Ping',
    'burst': 'Chip Burst',
    'blink': 'Double Blink',
  };

  /// Legacy ids from earlier builds map forward silently.
  static String migrateCeleb(String? v) {
    switch (v) {
      case 'pulse':
        return 'pop';
      case 'shimmer':
        return 'sweep';
      case 'glow':
        return 'glow';
      default:
        return celebIds.contains(v) ? v! : 'rise';
    }
  }

  void setCeleb(String id) {
    celebId = MatchStore.migrateCeleb(id);
    _persist();
    notifyListeners();
  }

  void setComplexWickets(bool v) {
    complexWickets = v;
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
    SoundService.instance.undo();
    await _persist();
    notifyListeners();
  }

  bool get canUndo => _undo.isNotEmpty;

  void startMatch(MatchConfig cfg) {
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
    // Deferred over rollover: only start a fresh over when a new delivery
    // arrives after a completed one. The completed strip stays visible.
    if (inn.overs.last.balls.where((x) => x.isLegal).length >= 6) {
      inn.overs.add(Over(overNumber: inn.overs.length + 1));
      inn.currentOverNumber = inn.overs.length;
    }
    // Immutable append: the strip's old/new widgets must hold different
    // list objects, otherwise length comparison sees no change and the
    // glide animation never fires.
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

  String? score({
    required String action, // DOT,RUNS,FOUR,SIX,WIDE,NB_DIRECT,BYE,LEGBYE,WICKET
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
          b = Ball(
              runs: 0,
              extra: 'NB',
              extraRuns: rules.noBallPenalty,
              isLegal: false,
              badge: 'NB');
          nbArmed = false;
        } else {
          b = Ball(runs: 0, badge: '0');
        }
        break;
      case 'RUNS':
        if (nbArmed) {
          b = Ball(
              runs: runs,
              extra: 'NB',
              extraRuns: rules.noBallPenalty,
              isLegal: false,
              badge: 'N$runs');
          nbArmed = false;
        } else {
          b = Ball(runs: runs, badge: '$runs');
        }
        break;
      case 'FOUR':
        if (nbArmed) {
          b = Ball(
              runs: 4,
              extra: 'NB',
              extraRuns: rules.noBallPenalty,
              isLegal: false,
              badge: 'N4');
          nbArmed = false;
        } else {
          b = Ball(runs: 4, badge: '4');
        }
        break;
      case 'SIX':
        if (nbArmed) {
          b = Ball(
              runs: 6,
              extra: 'NB',
              extraRuns: rules.noBallPenalty,
              isLegal: false,
              badge: 'N6');
          nbArmed = false;
        } else {
          b = Ball(runs: 6, badge: '6');
        }
        break;
      case 'WIDE':
        // runs = overthrow runs on top of the wide penalty.
        final total = rules.widePenalty + runs;
        b = Ball(
            runs: 0,
            extra: 'WD',
            extraRuns: total,
            isLegal: false,
            badge: total <= 1 ? 'WD' : 'WD$total');
        break;
      case 'NB_DIRECT':
        b = Ball(
            runs: runs,
            extra: 'NB',
            extraRuns: rules.noBallPenalty,
            isLegal: false,
            badge: runs > 0 ? 'N$runs' : 'NB');
        break;
      case 'BYE':
        b = Ball(
            runs: 0,
            extra: 'B',
            extraRuns: runs,
            isLegal: true,
            badge: 'B$runs');
        break;
      case 'LEGBYE':
        b = Ball(
            runs: 0,
            extra: 'LB',
            extraRuns: runs,
            isLegal: true,
            badge: 'LB$runs');
        break;
      case 'WICKET':
        // Wickets are recorded as standalone legal balls (a run-out on a
        // wide is tapped as WD then W — totals match reality). Only the
        // free-hit rule can downgrade a wicket to runs-only here.
        if (inn.isFreeHitActive && wicketType != 'Run Out') {
          b = Ball(runs: runs, badge: runs == 0 ? '0' : '$runs');
        } else {
          // Run-outs with completed runs read W+1 / W+2 on the strip.
          b = Ball(
              runs: runs,
              isWicket: true,
              wicketType: wicketType,
              badge: runs > 0 ? 'W+$runs' : 'W');
        }
        inn.isFreeHitActive = false;
        break;
      default:
        _undo.removeLast();
        return 'Unknown action';
    }

    if (b.extra == 'NB' && rules.freeHit) inn.isFreeHitActive = true;
    // A completed legal non-NB delivery consumes the free hit.
    if (b.isLegal && b.extra != 'NB' && inn.isFreeHitActive) {
      inn.isFreeHitActive = false;
    }

    _addBall(inn, b);
    _feedback(b);
    _checkEnd();
    _persist();
    notifyListeners();
    return null;
  }

  /// Haptics + arcade SFX by impact tier. Decoration only — scoring
  /// never depends on it.
  void _feedback(Ball b) {
    final sfx = SoundService.instance;
    try {
      if (b.isWicket) {
        HapticFeedback.heavyImpact();
        sfx.wicket();
      } else if (b.badge == '4' ||
          b.badge == '6' ||
          b.badge.startsWith('N4') ||
          b.badge.startsWith('N6')) {
        HapticFeedback.mediumImpact();
        sfx.boundary();
      } else if (b.extra != 'none') {
        HapticFeedback.selectionClick();
        sfx.extra();
      } else {
        HapticFeedback.lightImpact();
        sfx.run();
      }
    } catch (_) {}
  }

  void toggleNb() {
    nbArmed = !nbArmed;
    HapticFeedback.selectionClick();
    SoundService.instance.extra();
    notifyListeners();
  }

  /// Mid-match config change (settings sheet). Validated + undoable.
  /// Returns error message or null on success.
  String? applyMidMatch({
    int? totalOvers,
    int? playersPerSide,
    int? commonPlayers,
    int? widePenalty,
    int? noBallPenalty,
    bool? freeHit,
    bool? lastManStanding,
  }) {
    final m = match;
    final inn = innings;
    if (m == null || inn == null) return 'No live match';
    final cfg = m.config;
    final newOvers = totalOvers ?? cfg.totalOvers;
    final newPlayers = playersPerSide ?? cfg.playersPerSide;
    if (newOvers * 6 < inn.legalDeliveries) {
      return 'Overs below balls already bowled';
    }
    final maxW = CricketMath.getMaxWickets(
        newPlayers, lastManStanding ?? cfg.rules.lastManStanding);
    if (inn.wickets >= maxW && !inn.completed) {
      return 'Players below wickets already fallen';
    }
    pushSnapshot();
    cfg.totalOvers = newOvers.clamp(1, 50);
    cfg.playersPerSide = newPlayers.clamp(2, 15);
    if (commonPlayers != null) {
      cfg.commonPlayers = commonPlayers.clamp(0, 1);
    }
    if (widePenalty != null) cfg.rules.widePenalty = widePenalty.clamp(0, 2);
    if (noBallPenalty != null) {
      cfg.rules.noBallPenalty = noBallPenalty.clamp(0, 2);
    }
    if (freeHit != null) {
      cfg.rules.freeHit = freeHit;
      if (!freeHit) inn.isFreeHitActive = false;
    }
    if (lastManStanding != null) cfg.rules.lastManStanding = lastManStanding;
    HapticFeedback.selectionClick();
    _checkEnd();
    _persist();
    notifyListeners();
    return null;
  }

  /// Umpire declares a winner mid-match.
  void declareWinner(String team, [String? margin]) {
    final m = match;
    if (m == null) return;
    pushSnapshot();
    final inn = innings;
    if (inn != null) inn.completed = true;
    m.completed = true;
    m.winner = team;
    m.winMargin = margin ?? 'Declared winner';
    HapticFeedback.heavyImpact();
    SoundService.instance.fanfare();
    _archive();
    _persist();
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
        SoundService.instance.confirm();
      }
    } else {
      final tgt = m.target ?? (m.innings1.runs + 1);
      if (inn.runs >= tgt) {
        inn.completed = true;
        m.completed = true;
        m.winner = inn.battingTeam;
        final wktsLeft = maxW - inn.wickets;
        m.winMargin = 'Won by $wktsLeft wicket${wktsLeft == 1 ? '' : 's'}';
        HapticFeedback.heavyImpact();
        SoundService.instance.fanfare();
        _archive();
      } else if (inn.legalDeliveries >= maxBalls || inn.wickets >= maxW) {
        inn.completed = true;
        m.completed = true;
        if (inn.runs == tgt - 1) {
          m.winner = 'TIE';
          m.winMargin = 'Scores level';
        } else {
          m.winner = inn.bowlingTeam;
          final diff = (tgt - 1) - inn.runs;
          m.winMargin = 'Won by $diff run${diff == 1 ? '' : 's'}';
        }
        _archive();
      }
    }
  }

  void startSecondInnings() {
    final m = match!;
    m.innings2 =
        Innings.create(m.innings1.bowlingTeam, m.innings1.battingTeam, m.target);
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
      return list
          .map((e) => Match.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteHistoryAt(int idx) async {
    final p = await SharedPreferences.getInstance();
    final h = await history();
    if (idx >= 0 && idx < h.length) {
      h.removeAt(idx);
      await p.setString(
          kHistory, jsonEncode(h.map((e) => e.toJson()).toList()));
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
