import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'adapters/local_only_sync.dart';
import 'domain/players.dart';
import 'domain/room_snapshot.dart';
import 'math.dart';
import 'models.dart';
import 'ports/sync_port.dart';
import 'sound.dart';

/// Offline store: SharedPreferences is the source of truth and always will be.
/// The optional [sync] adapter publishes snapshots for viewers; nothing in
/// scoring depends on it, so a missing or broken backend costs you the live
/// room and nothing else.
class MatchStore extends ChangeNotifier {
  /// Live-room adapter. Defaults to local-only, which is what every build
  /// without Supabase credentials uses.
  final SyncPort sync;

  MatchStore({SyncPort? sync}) : sync = sync ?? LocalOnlySync();

  /// Live join code while sharing, else null.
  String? roomCode;

  /// Monotonic snapshot counter for the open room.
  int _roomSeq = 0;

  /// Copies state out to viewers. Never awaited by scoring.
  void _publishRoom() {
    final code = roomCode;
    final m = match;
    if (code == null || m == null) return;
    _roomSeq++;
    final doc = m.toJson();
    if (sheets.isNotEmpty) {
      doc['sheets'] = sheets.map((k, v) => MapEntry(k, v.toJson()));
    }
    // Fire and forget, and the rejection is caught on the *future*: a `try`
    // around the call would not see it, which is how a failing backend used to
    // become an unhandled async error. A ball never waits on, or fails because
    // of, the network. Dropped publishes self-heal on the next ball.
    unawaited(sync
        .publish(
          code,
          RoomSnapshot(seq: _roomSeq, match: doc, updatedAt: DateTime.now()),
        )
        .catchError((Object _) {}));
  }

  /// Opens a live room for the current match. Returns the code, or the reason it
  /// could not — never a bare null, because a single "unavailable" message for
  /// four different failures is how a network error gets misreported as a
  /// missing build flag.
  Future<ShareAttempt> startSharing() async {
    if (match == null) {
      return const ShareAttempt.failed(ShareFailure.noMatch);
    }
    if (roomCode != null) return ShareAttempt.ok(roomCode!);
    final result = await sync.createRoom();
    if (!result.ok) return result;
    roomCode = result.code;
    _roomSeq = 0;
    _publishRoom();
    notifyListeners();
    return result;
  }

  /// Closes the room and deletes it server-side. The match stays untouched
  /// locally — sharing is additive, never destructive.
  Future<void> stopSharing() async {
    final code = roomCode;
    roomCode = null;
    _roomSeq = 0;
    if (code != null) await sync.endRoom(code);
    notifyListeners();
  }

  void _bumpAppearances() {
    final sheet = currentSheet;
    final m = match;
    if (sheet == null || m == null) return;
    final key = '${m.createdAt}_${m.currentInnings}';
    if (appearanceKeys.contains(key)) return;
    appearanceKeys.add(key);
    for (final c in sheet.batting.values) {
      if (c.position > 0) {
        playerAppearances[c.playerId] =
            (playerAppearances[c.playerId] ?? 0) + 1;
      }
    }
    for (final c in sheet.bowling.values) {
      if ((c.balls > 0 || c.wickets > 0) &&
          (sheet.batting[c.playerId]?.position ?? 0) == 0) {
        playerAppearances[c.playerId] =
            (playerAppearances[c.playerId] ?? 0) + 1;
      }
    }
  }

  /// Withdraws the appearance bump when undo reopens an innings, so the
  /// frequency ordering behind squad pickers cannot drift.
  void _withdrawAppearances() {
    final m = match;
    if (m == null) return;
    final key = '${m.createdAt}_${m.currentInnings}';
    if (!appearanceKeys.remove(key)) return;
    final sheet = currentSheet;
    if (sheet == null) return;
    for (final c in sheet.batting.values) {
      if (c.position > 0) {
        playerAppearances[c.playerId] =
            ((playerAppearances[c.playerId] ?? 1) - 1).clamp(0, 1 << 30);
      }
    }
    for (final c in sheet.bowling.values) {
      if ((c.balls > 0 || c.wickets > 0) &&
          (sheet.batting[c.playerId]?.position ?? 0) == 0) {
        playerAppearances[c.playerId] =
            ((playerAppearances[c.playerId] ?? 1) - 1).clamp(0, 1 << 30);
      }
    }
  }

  /// Best-effort viewer count for the share banner.
  int get viewerCount => sync.viewerCount;

  /// Live-backend status, surfaced verbatim in Settings so a failure on a gully
  /// ground is diagnosable without a laptop.
  SyncState get onlineState => sync.state;

  String? get onlineError => sync.lastError;
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
  static const kHaptics = 'cricket_haptics';
  static const kRoster = 'cricket_roster_v1';
  static const kClubs = 'cricket_clubs_v1';
  static const kProfiles = 'cricket_profiles_v1';
  static const kActiveProfile = 'cricket_active_profile';
  static const kSheets = 'cricket_sheets_v1';
  static const kAskFielder = 'cricket_ask_fielder';
  static const kAppearances = 'cricket_appearances_v1';
  static const kAppearanceKeys = 'cricket_appearance_keys_v1';

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
  bool hapticsOn = true; // master vibration toggle
  bool askFielder = false; // optional catcher/run-out picker on wickets
  List<Player> roster = [];
  List<Club> clubs = [];
  List<ClubProfile> profiles = [];
  String? activeProfileId;
  String? activeClubId;
  // Per-innings attribution sheets for the live match: '1' and '2'.
  Map<String, InningsSheet> sheets = {};

  /// Matches played per player id, across all matches on this device. Drives
  /// squad-picker ordering (most frequent first). Bumped when an innings
  /// completes, for everyone who batted or bowled.
  Map<String, int> playerAppearances = {};
  Set<String> appearanceKeys = {};
  int ballGen = 0; // advances on score() only — strip motion key
  int breakWait = 0; // countdown seconds before break/result handoff
  String? breakDest; // '/break' | '/result' while counting down
  Timer? _breakTimer;
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
    hapticsOn = p.getBool(kHaptics) ?? true;
    askFielder = p.getBool(kAskFielder) ?? false;
    try {
      playerAppearances = Map<String, int>.from(
          jsonDecode(p.getString(kAppearances) ?? '{}') as Map);
    } catch (_) {
      playerAppearances = {};
    }
    try {
      appearanceKeys =
          (jsonDecode(p.getString(kAppearanceKeys) ?? '[]') as List)
              .map((e) => e.toString())
              .toSet();
    } catch (_) {
      appearanceKeys = {};
    }
    try {
      roster = ((jsonDecode(p.getString(kRoster) ?? '[]')) as List)
          .map((e) => Player.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      roster = [];
    }
    try {
      clubs = ((jsonDecode(p.getString(kClubs) ?? '[]')) as List)
          .map((e) => Club.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      clubs = [];
    }
    try {
      profiles = ((jsonDecode(p.getString(kProfiles) ?? '[]')) as List)
          .map((e) => ClubProfile.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      profiles = [];
    }
    activeProfileId = p.getString(kActiveProfile);
    activeClubId = null;
    for (final pr in profiles) {
      if (pr.id == activeProfileId) {
        activeClubId = pr.clubId;
        break;
      }
    }
    try {
      sheets = {};
      final sj = jsonDecode(p.getString(kSheets) ?? '{}') as Map;
      for (final e in sj.entries) {
        sheets[e.key.toString()] =
            InningsSheet.fromJson(Map<String, dynamic>.from(e.value as Map));
      }
    } catch (_) {
      sheets = {};
    }
    // Awaited: when load() returns, every SFX clip is preloaded, so the first
    // ball of the match cannot outrun the audio pool.
    await SoundService.instance.init(enabled: soundOn);
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
    await p.setBool(kHaptics, hapticsOn);
    await p.setBool(kAskFielder, askFielder);
    await p.setString(kAppearances, jsonEncode(playerAppearances));
    await p.setString(kAppearanceKeys, jsonEncode(appearanceKeys.toList()));
    await p.setString(
        kRoster, jsonEncode(roster.map((e) => e.toJson()).toList()));
    await p.setString(
        kClubs, jsonEncode(clubs.map((e) => e.toJson()).toList()));
    await p.setString(
        kProfiles, jsonEncode(profiles.map((e) => e.toJson()).toList()));
    if (activeProfileId != null) {
      await p.setString(kActiveProfile, activeProfileId!);
    } else {
      await p.remove(kActiveProfile);
    }
    await p.setString(
        kSheets, jsonEncode(sheets.map((k, v) => MapEntry(k, v.toJson()))));
  }

  void setTheme(String id) {
    themeId = id == 'dark' ? 'dark' : 'light';
    _persist();
    notifyListeners();
  }

  void toggleTheme() => setTheme(themeId == 'dark' ? 'light' : 'dark');

  void setSound(bool v) {
    soundOn = v;
    // Un-muting after a failed/unfinished preload retries it, so the toggle is
    // never a dead end.
    if (v && !SoundService.instance.ready) {
      SoundService.instance.init(enabled: true);
    }
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
    'pop',
    'flash',
    'glow',
    'shake',
    'blink',
    'glitch',
    'crt',
    'slowmo',
  ];
  static const celebNames = {
    'off': 'Off',
    'pop': 'Pop',
    'flash': 'Flash Tint',
    'glow': 'Glow Bloom',
    'shake': 'Shake',
    'blink': 'Double Blink',
    'glitch': 'Pixel Glitch',
    'crt': 'CRT Flicker',
    'slowmo': 'Slow-Mo',
  };

  /// Legacy ids from earlier builds map forward silently.
  static String migrateCeleb(String? v) {
    switch (v) {
      case 'pulse':
      case 'roll':
      case 'rise':
        return 'pop';
      case 'shimmer':
      case 'sweep':
      case 'glow':
        return 'glow';
      case 'ring':
      case 'blink':
        return 'blink';
      case 'burst':
        return 'flash';
      default:
        return celebIds.contains(v) ? v! : 'pop';
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

  /// Save + refresh without any other side effects (used by the
  /// player-of-the-match override, which must not touch the match itself).
  void persistOnly() {
    _persist();
    notifyListeners();
  }

  void setHaptics(bool v) {
    hapticsOn = v;
    _persist();
    notifyListeners();
  }

  void setAskFielder(bool v) {
    askFielder = v;
    _persist();
    notifyListeners();
  }

  // --- club + roster (all local, all offline) ------------------------------

  ClubProfile createProfile({required String name, required String pin}) {
    final profile = ClubProfile.create(
        name: name.trim(), pinHash: hashPin(pin, name.trim()));
    profiles.add(profile);
    activeProfileId = profile.id;
    activeClubId = null;
    _persist();
    notifyListeners();
    return profile;
  }

  bool unlockProfile(String id, String pin) {
    for (final pr in profiles) {
      if (pr.id == id && pr.pinHash == hashPin(pin, pr.name)) {
        activeProfileId = id;
        activeClubId = pr.clubId;
        _persist();
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  void useWithoutProfile() {
    activeProfileId = null;
    activeClubId = profiles.isEmpty ? null : activeClubId;
    notifyListeners();
  }

  void lockProfile() {
    activeProfileId = null;
    notifyListeners();
  }

  Club createClub({required String name}) {
    final club = Club.create(name: name.trim());
    clubs.add(club);
    activeClubId = club.id;
    for (final pr in profiles) {
      if (pr.id == activeProfileId) pr.clubId = club.id;
    }
    _persist();
    notifyListeners();
    return club;
  }

  void selectClub(String id) {
    activeClubId = id;
    for (final pr in profiles) {
      if (pr.id == activeProfileId) pr.clubId = id;
    }
    _persist();
    notifyListeners();
  }

  /// Null when no club exists yet: the UI must create a club first instead
  /// of scattering players under a fake club.
  /// True when [name] already exists in the active club (case-insensitive).
  /// The UI warns "already exists" instead of creating a twin.
  bool duplicateName(String name) {
    final q = name.trim().toLowerCase();
    if (q.isEmpty) return false;
    return clubRoster.any((p) => p.name.trim().toLowerCase() == q);
  }

  Player? addPlayer(
      {required String name,
      PlayerRole role = PlayerRole.allRounder,
      BattingStyle battingStyle = BattingStyle.rightHand,
      BowlingStyle bowlingStyle = BowlingStyle.none,
      String? phone}) {
    final cid = activeClubId;
    if (cid == null) return null;
    if (duplicateName(name)) return null;
    final player = Player.create(
        clubId: cid,
        name: name.trim(),
        role: role,
        battingStyle: battingStyle,
        bowlingStyle: bowlingStyle);
    if (phone != null && phone.trim().isNotEmpty) {
      player.phone = phone.trim();
    }
    roster.add(player);
    // A newly added player joins any live tracked sheet immediately, so the
    // umpire never has to restart a match to use them.
    for (final sheet in sheets.values) {
      sheet.register(player);
    }
    _persist();
    notifyListeners();
    return player;
  }

  /// Paste-a-list bulk add: one name per line, optional "Name - role".
  BulkResult addPlayersBulk(String text) {
    if (activeClubId == null) return const BulkResult([], 0);
    final added = <Player>[];
    var skipped = 0;
    for (final line in text.split('\n')) {
      final t = line.trim().replaceAll(RegExp(r'^[\-\*\d.\)\s]+'), '');
      if (t.isEmpty) continue;
      var name = t;
      var role = PlayerRole.allRounder;
      final dash = t.lastIndexOf(' - ');
      if (dash > 0) {
        final r = t.substring(dash + 3).toLowerCase();
        name = t.substring(0, dash).trim();
        if (r.startsWith('bat')) role = PlayerRole.batter;
        if (r.startsWith('bowl')) role = PlayerRole.bowler;
        if (r.startsWith('keep')) role = PlayerRole.keeper;
        if (r.startsWith('all')) role = PlayerRole.allRounder;
      }
      if (name.isEmpty) continue;
      if (duplicateName(name)) {
        skipped++;
        continue;
      }
      final created = addPlayer(name: name, role: role);
      if (created != null) added.add(created);
    }
    return BulkResult(added, skipped);
  }

  void renamePlayer(String id, String name) {
    for (final p in roster) {
      if (p.id == id) p.name = name.trim();
    }
    for (final sheet in sheets.values) {
      final n = sheet.names[id];
      if (n != null) {
        sheet.names[id] = name.trim();
        sheet.batting[id]?.name = name.trim();
        sheet.bowling[id]?.name = name.trim();
        sheet.fielding[id]?.name = name.trim();
      }
    }
    _persist();
    notifyListeners();
  }

  void setPlayerActive(String id, bool active) {
    for (final p in roster) {
      if (p.id == id) p.active = active;
    }
    _persist();
    notifyListeners();
  }

  void setPlayerRole(String id, PlayerRole role) {
    for (final p in roster) {
      if (p.id == id) p.role = role;
    }
    _persist();
    notifyListeners();
  }

  String playerName(String id) {
    for (final p in roster) {
      if (p.id == id) return p.name;
    }
    return currentSheet?.nameOf(id) ?? '?';
  }

  CareerBatting careerBatting(String id) {
    final c = CareerBatting();
    for (final sheet in sheets.values) {
      final card = sheet.batting[id];
      if (card != null) c.add(card);
    }
    return c;
  }

  CareerBowling careerBowling(String id) {
    final c = CareerBowling();
    for (final sheet in sheets.values) {
      final card = sheet.bowling[id];
      if (card != null) c.add(card);
    }
    return c;
  }

  int careerMatches(String id) {
    var n = 0;
    for (final sheet in sheets.values) {
      final b = sheet.batting[id];
      final w = sheet.bowling[id];
      if ((b != null && b.position > 0) ||
          (w != null && (w.balls > 0 || w.wickets > 0))) {
        n++;
      }
    }
    return n;
  }

  // --- tracked scoring helpers ----------------------------------------------

  void setOpeners(String a, String b) {
    final sheet = currentSheet;
    if (sheet == null) return;
    pushSnapshot();
    sheet.setOpeners(a, b);
    _persist();
    notifyListeners();
  }

  /// Assigns the over's bowler. Returns an error when the Laws forbid it —
  /// the picker greys the just-bowled player, but the store is the enforcer.
  String? setBowler(String id) {
    final sheet = currentSheet;
    if (sheet == null) return 'Player tracking is off';
    if (!sheet.canBowl(id)) {
      return '${sheet.nameOf(id)} bowled the last over';
    }
    pushSnapshot();
    sheet.closeOver(legalBalls: 0); // reset without maiden: mid-over change
    sheet.setBowler(id);
    _persist();
    notifyListeners();
    return null;
  }

  /// Retires the striker (hurt or out): recorded on the card without a
  /// ball, and the next batter resolves through the same picker.
  void retireStriker(DismissalType type) {
    final sheet = currentSheet;
    if (sheet == null) return;
    if (type != DismissalType.retiredHurt && type != DismissalType.retiredOut) {
      return;
    }
    pushSnapshot();
    final bat = sheet.striker;
    if (bat != null) {
      bat.dismissal = type;
      bat.isNotOut = false;
    }
    // Retired-out is a dismissal in the Laws: it counts toward all-out.
    // Retired-hurt does not.
    if (type == DismissalType.retiredOut) {
      final inn = innings;
      if (inn != null) {
        inn.wickets++;
        _checkEnd();
      }
    }
    _persist();
    notifyListeners();
  }

  void swapStrike() {
    final sheet = currentSheet;
    if (sheet == null) return;
    pushSnapshot();
    sheet.swapEnds();
    _persist();
    notifyListeners();
  }

  /// The over just finished: maiden accounting happens here, where the legal
  /// count is known. Delegates to the sheet's single close path.
  void finishOverForSheet() {
    final sheet = currentSheet;
    final inn = innings;
    if (sheet == null || inn == null) return;
    // Legal balls in the over that just ended.
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

  void _buzz(Future<void> Function() fn) {
    if (!hapticsOn) return;
    try {
      fn();
    } catch (_) {}
  }

  void pushSnapshot() {
    if (match == null) return;
    _undo.add(jsonEncode({
      'm': match!.toJson(),
      's': sheets.map((k, v) => MapEntry(k, v.toJson())),
    }));
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  Map<String, dynamic>? _decodeEnvelope(String raw) {
    try {
      final d = jsonDecode(raw) as Map;
      if (d['m'] is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    return null;
  }

  Future<void> undo() async {
    nbArmed = false;
    if (_undo.isEmpty) return;
    if (match != null) {
      _redo.add(jsonEncode({
        'm': match!.toJson(),
        's': sheets.map((k, v) => MapEntry(k, v.toJson())),
      }));
    }
    final raw = _undo.removeLast();
    final env = _decodeEnvelope(raw);
    if (env != null) {
      match = Match.fromJson(Map<String, dynamic>.from(env['m'] as Map));
      try {
        sheets = {};
        final sj = Map<String, dynamic>.from((env['s'] ?? {}) as Map);
        for (final e in sj.entries) {
          sheets[e.key.toString()] =
              InningsSheet.fromJson(Map<String, dynamic>.from(e.value as Map));
        }
      } catch (_) {}
    } else {
      // Legacy plain-match entries from before player tracking.
      match = Match.decode(raw);
    }
    match!.completed = false;
    _withdrawAppearances();
    if (match!.currentInnings == 1) match!.innings1.completed = false;
    if (match!.innings2 != null && match!.currentInnings == 2) {
      match!.innings2!.completed = false;
    }
    _buzz(HapticFeedback.lightImpact);
    unawaited(SoundService.instance.undo());
    // Undo retracts too: a viewer must never be left showing a ball the scorer
    // has just taken back.
    _publishRoom();
    await _persist();
    notifyListeners();
  }

  bool get canUndo => _undo.isNotEmpty;

  void startMatch(MatchConfig cfg) {
    final batFirst = cfg.battingFirst == 'B';
    final inn = Innings.create(
        batFirst ? cfg.teamB : cfg.teamA, batFirst ? cfg.teamA : cfg.teamB);
    match = Match(config: cfg, innings1: inn);
    _undo.clear();
    _redo.clear();
    nbArmed = false;
    sheets = {};
    if (cfg.trackPlayers) _ensureSheet(1);
    _persist();
    notifyListeners();
  }

  /// Sheet for an innings, or null when player tracking is off.
  InningsSheet? sheetFor(int inningsNo) => sheets[inningsNo.toString()];

  InningsSheet? get currentSheet =>
      match == null ? null : sheetFor(match!.currentInnings);

  bool get tracking => match?.config.trackPlayers ?? false;

  InningsSheet _ensureSheet(int inningsNo) {
    final m = match!;
    final inn = inningsNo == 1 ? m.innings1 : m.innings2!;
    final key = inningsNo.toString();
    final existing = sheets[key];
    if (existing != null) return existing;
    final sheet = InningsSheet(
        battingTeam: inn.battingTeam, bowlingTeam: inn.bowlingTeam);
    final battingSquad = squadForTeam(inn.battingTeam);
    final bowlingSquad = squadForTeam(inn.bowlingTeam);
    sheet.registerSquad([...battingSquad, ...bowlingSquad]);
    sheets[key] = sheet;
    return sheet;
  }

  List<Player> squadForTeam(String team) {
    final m = match;
    if (m == null) return const [];
    final ids = team == m.config.teamA ? m.config.squadA : m.config.squadB;
    if (ids.isEmpty) return const [];
    final byId = {for (final p in roster) p.id: p};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!
    ];
  }

  List<Player> get clubRoster {
    final cid = activeClubId;
    if (cid == null) return List.unmodifiable(roster);
    return roster.where((p) => p.clubId == cid).toList();
  }

  List<Player> searchRoster(String q) {
    final query = q.toLowerCase().trim();
    final base = clubRoster.where((p) => p.active).toList();
    if (query.isEmpty) return base;
    return base.where((p) => p.searchKey.contains(query)).toList();
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
    required String
        action, // DOT,RUNS,FOUR,SIX,WIDE,NB_DIRECT,BYE,LEGBYE,WICKET
    int runs = 0,
    String wicketType = 'Bowled',
    String? dismissal, // DismissalType.name when tracking players
    String? fielderName,
    String? newBatterId,
    bool crossed = false,
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
        // wide is tapped as WD then W — totals match reality), except when
        // resolving an armed no-ball: Laws allow only a run-out there, and
        // the ball stays illegal.
        if (nbArmed) {
          nbArmed = false;
          if (wicketType != 'Run Out') {
            _undo.removeLast();
            return 'Only run-out possible on no-ball';
          }
          b = Ball(
              runs: runs,
              extra: 'NB',
              extraRuns: rules.noBallPenalty,
              isLegal: false,
              isWicket: true,
              wicketType: wicketType,
              badge: runs > 0 ? 'W+$runs' : 'W');
          if (rules.freeHit) inn.isFreeHitActive = true;
          break;
        }
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

    // Player attribution: stamp who faced and who bowled before the ball
    // lands, so the sheet and the strip never disagree.
    final sheet = tracking ? _ensureSheet(m.currentInnings) : null;
    if (sheet != null) {
      // An over that rolls here ends the previous bowler's figures first.
      if (inn.overs.isNotEmpty &&
          inn.overs.last.balls.where((x) => x.isLegal).length >= 6) {
        finishOverForSheet();
      }
      b.strikerId = sheet.strikerId;
      b.nonStrikerId = sheet.nonStrikerId;
      b.bowlerId = sheet.bowlerId;
      if (fielderName != null && fielderName.isNotEmpty) {
        b.fielderName = fielderName;
      }
    }
    _addBall(inn, b);
    if (sheet != null) {
      final type = dismissal != null
          ? DismissalType.fromId(dismissal)
          : DismissalType.fromId(b.wicketType);
      sheet.applyDelivery(b,
          dismissalType: b.isWicket ? type : null, fielderName: fielderName);
      if (b.isWicket && !inn.completed) {
        // Bring the new batter in at the striker's end in the same commit, so
        // a dismissal is always resolved: one sheet, one tap, no limbo.
        // Options exclude the out batter, the non-striker and the dismissed;
        // retired-hurt returnees stay eligible.
        final opts = sheet.nextBatterOptions(b.strikerId ?? '');
        final next = (newBatterId != null && newBatterId.isNotEmpty)
            ? newBatterId
            : (opts.isEmpty ? null : opts.first);
        if (next != null) {
          sheet.bringIn(next);
          if (crossed) sheet.crossedRunOutFix(next);
        }
      }
    }
    ballGen++; // strip animates on generation change only — undo is silent
    _feedback(b);
    _publishRoom(); // viewers see the ball; scoring never waits on this
    _checkEnd();
    _persist();
    notifyListeners();
    return null;
  }

  /// Haptics + arcade SFX by impact tier. Decoration only — scoring
  /// never depends on it.
  /// Haptics + arcade SFX by impact tier. Decoration only — scoring
  /// never depends on it.
  void _feedback(Ball b) {
    final sfx = SoundService.instance;
    try {
      if (b.isWicket) {
        _buzz(HapticFeedback.heavyImpact);
        sfx.wicket();
      } else if (b.badge == '4' || b.badge.startsWith('N4')) {
        _buzz(HapticFeedback.heavyImpact);
        sfx.four();
      } else if (b.badge == '6' || b.badge.startsWith('N6')) {
        _buzz(HapticFeedback.heavyImpact);
        sfx.six();
      } else if (b.extra == 'WD') {
        _buzz(HapticFeedback.mediumImpact);
        sfx.wide();
      } else if (b.extra == 'NB') {
        _buzz(HapticFeedback.mediumImpact);
        sfx.noball();
      } else if (b.extra != 'none') {
        _buzz(HapticFeedback.selectionClick);
        sfx.extra();
      } else {
        _buzz(HapticFeedback.lightImpact);
        sfx.run();
      }
    } catch (_) {}
  }

  void toggleNb() {
    nbArmed = !nbArmed;
    _buzz(HapticFeedback.selectionClick);
    SoundService.instance.extra();
    notifyListeners();
  }

  /// Adds a roster player to a mid-match XI. Enforces the same three rules as
  /// setup: the XI cap, cross-exclusion (waived for the shared pick when a
  /// common player is allowed), and tracking must be on.
  String? addToSquad(String team, String playerId) {
    final m = match;
    final sheet = currentSheet;
    if (m == null || sheet == null) return 'Player tracking is off';
    final mine = team == m.config.teamA ? m.config.squadA : m.config.squadB;
    final other = team == m.config.teamA ? m.config.squadB : m.config.squadA;
    if (mine.contains(playerId)) return null;
    if (mine.length >= m.config.playersPerSide) {
      return 'XI is full (${m.config.playersPerSide})';
    }
    if (other.contains(playerId) && m.config.commonPlayers == 0) {
      return 'Already in the other XI';
    }
    pushSnapshot();
    mine.add(playerId);
    final p = roster.where((e) => e.id == playerId);
    if (p.isNotEmpty) sheet.register(p.first);
    _persist();
    notifyListeners();
    return null;
  }

  /// Type-a-name mid-match add: roster hit joins the XI, a new name is created
  /// in the club (name-only; styles later) and joins. Duplicates warn.
  String? addSquadByName(String team, String name) {
    final t = name.trim();
    if (t.isEmpty) return 'Type a name';
    for (final p in clubRoster) {
      if (p.name.trim().toLowerCase() == t.toLowerCase()) {
        return addToSquad(team, p.id);
      }
    }
    final created = addPlayer(name: t);
    if (created == null) return 'Create a club first';
    return addToSquad(team, created.id);
  }

  /// Removes an uncapped pick mid-match. Anyone who batted or bowled stays:
  /// figures already reference them.
  String? removeFromSquad(String team, String playerId) {
    final m = match;
    final sheet = currentSheet;
    if (m == null || sheet == null) return 'Player tracking is off';
    final mine = team == m.config.teamA ? m.config.squadA : m.config.squadB;
    if (!mine.contains(playerId)) return null;
    final b = sheet.batting[playerId];
    final w = sheet.bowling[playerId];
    if ((b != null && b.position > 0) ||
        (w != null && (w.balls > 0 || w.wickets > 0))) {
      return 'Already played — cannot remove mid-match';
    }
    pushSnapshot();
    mine.remove(playerId);
    _persist();
    notifyListeners();
    return null;
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
    _buzz(HapticFeedback.selectionClick);
    SoundService.instance.confirm();
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
    _buzz(HapticFeedback.heavyImpact);
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
        _bumpAppearances();
        m.target = inn.runs + 1;
        SoundService.instance.confirm();
        _startBreakCountdown('/break');
      }
    } else {
      final tgt = m.target ?? (m.innings1.runs + 1);
      if (inn.runs >= tgt) {
        inn.completed = true;
        _bumpAppearances();
        m.completed = true;
        m.winner = inn.battingTeam;
        final wktsLeft = maxW - inn.wickets;
        m.winMargin = 'Won by $wktsLeft wicket${wktsLeft == 1 ? '' : 's'}';
        _buzz(HapticFeedback.heavyImpact);
        SoundService.instance.fanfare();
        _archive();
        _startBreakCountdown('/result');
      } else if (inn.legalDeliveries >= maxBalls || inn.wickets >= maxW) {
        inn.completed = true;
        _bumpAppearances();
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
        _startBreakCountdown('/result');
      }
    }
  }

  void startSecondInnings() {
    final m = match!;
    m.innings2 = Innings.create(
        m.innings1.bowlingTeam, m.innings1.battingTeam, m.target);
    m.currentInnings = 2;
    nbArmed = false;
    if (m.config.trackPlayers) _ensureSheet(2);
    _publishRoom();
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

  /// 10-second viewing pause before break/result handoffs, with NEXT.
  void _startBreakCountdown(String dest) {
    _breakTimer?.cancel();
    breakDest = dest;
    breakWait = 10;
    notifyListeners();
    _breakTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      breakWait--;
      if (breakWait <= 0) {
        t.cancel();
        _breakTimer = null;
        breakDest = null;
        breakWait = 0;
      }
      notifyListeners();
    });
  }

  /// NEXT button: skip the wait, handoff immediately.
  void skipBreakWait() {
    _breakTimer?.cancel();
    _breakTimer = null;
    breakDest = null;
    breakWait = 0;
    notifyListeners();
  }

  void _cancelBreak() {
    _breakTimer?.cancel();
    _breakTimer = null;
    breakDest = null;
    breakWait = 0;
  }

  void abandon() {
    _cancelBreak();
    match = null;
    sheets = {};
    _undo.clear();
    _redo.clear();
    // The match is gone, so the room has nothing to show: close it.
    if (roomCode != null) unawaited(stopSharing());
    _persist();
    notifyListeners();
  }

  void newMatch() {
    _cancelBreak();
    match = null;
    sheets = {};
    _undo.clear();
    _redo.clear();
    if (roomCode != null) unawaited(stopSharing());
    _persist();
    notifyListeners();
  }
}
