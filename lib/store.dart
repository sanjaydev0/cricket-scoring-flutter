import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';
import 'dart:convert';

import 'adapters/local_only_sync.dart';
import 'backup.dart';
import 'undo_log.dart';
import 'domain/players.dart';
import 'domain/room_snapshot.dart';
import 'math.dart';
import 'models.dart';
import 'ports/sync_port.dart';
import 'scoring_engine.dart';
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
    unawaited(
      sync
          .publish(
            code,
            RoomSnapshot(seq: _roomSeq, match: doc, updatedAt: DateTime.now()),
          )
          .catchError((Object _) {}),
    );
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

  /// The part of the preference store a scorer would actually miss. Settings
  /// alone never justify restoring a snapshot over a newer store.
  static const userDataKeys = [kActive, kHistory, kRoster, kClubs, kProfiles];

  /// Team colors: fixed dots for differentiation (blue = Team A, red = Team B).
  static const teamAColor = 0xFF2563EB; // blue-600
  static const teamBColor = 0xFFDC2626; // red-600

  final ScoringEngine engine = ScoringEngine();

  Match? get match => engine.match;
  set match(Match? v) => engine.match = v;
  MatchConfig get draft => engine.draft;
  set draft(MatchConfig v) => engine.draft = v;
  bool get nbArmed => engine.nbArmed;
  set nbArmed(bool v) => engine.nbArmed = v;
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
  Map<String, InningsSheet> get sheets => engine.sheets;
  set sheets(Map<String, InningsSheet> v) => engine.sheets = v;

  /// Matches played per player id, across all matches on this device. Drives
  /// squad-picker ordering (most frequent first). Bumped when an innings
  /// completes, for everyone who batted or bowled.
  Map<String, int> playerAppearances = {};
  Set<String> appearanceKeys = {};
  int get ballGen => engine.ballGen;
  set ballGen(int v) => engine.ballGen = v;
  int get breakWait => engine.breakWait;
  set breakWait(int v) => engine.breakWait = v;
  String? get breakDest => engine.breakDest;
  set breakDest(String? v) => engine.breakDest = v;
  Timer? _breakTimer;
  List<String> _undo = [];
  List<String> _redo = [];
  bool loaded = false;

  /// False only when [load] actually tried and failed to read the platform
  /// store (R8-renamed `kotlin.coroutines.Continuation` in
  /// shared_preferences_android 2.5.x did exactly that). The app still boots
  /// with defaults, but writes are then skipped: persisting empty lists would
  /// overwrite the real roster, clubs and archives that are safely on disk.
  bool _prefsReadable = true;

  /// Whether [load] has run at all. A store that never loaded (tests, a fresh
  /// preview) is still writable; only a *failed read* blocks persistence.
  bool _prefsLoadAttempted = false;

  /// True when a fresh install brought data back from the Downloads snapshot.
  /// HomeScreen shows a dismissible banner so the umpire knows why the old
  /// roster is suddenly there.
  bool restoredFromBackup = false;

  /// True when this was a fresh install with no readable automatic backup.
  /// HomeScreen offers the SAF picker so a JSON copied off the phone can
  /// still be recovered (scoped storage blocks a plain Downloads read on
  /// some Android versions).
  bool needsRestorePrompt = false;
  DateTime? lastBackupAt;
  String? lastBackupPath;
  String? lastBackupDownloadsPath;
  String? lastBackupError;
  bool _backupEnabled = false;
  bool _backingUp = false;
  bool _backupQueued = false;
  DateTime? _lastBackupAttempt;

  bool get _persistBlocked => _prefsLoadAttempted && !_prefsReadable;

  Innings? get innings => match == null
      ? null
      : (match!.currentInnings == 1 ? match!.innings1 : match!.innings2);

  /// Warms the SFX pools without ever blocking the first frame: a hung
  /// platform channel leaves the pools empty, not the app on a splash screen.
  void _warmAudio(bool enabled) {
    unawaited(
      SoundService.instance
          .init(enabled: enabled)
          .timeout(const Duration(seconds: 5))
          .catchError((Object _) {
            SoundService.instance.setEnabled(false);
          }),
    );
  }

  Future<void> load() async {
    debugPrint('STORE: load() start');
    _prefsLoadAttempted = true;
    restoredFromBackup = false;
    needsRestorePrompt = false;
    // A manual restore can replace or remove the live match. Clear the old
    // one first so a backup with no active match cannot leave a stale match
    // in memory after load().
    match = null;
    final SharedPreferences p;
    try {
      p = await SharedPreferences.getInstance();
      _prefsReadable = true;
    } catch (e) {
      // Fault-tolerant boot: never strand the umpire on a splash screen, and
      // never let the empty defaults that follow be written back over the
      // real saved data (see [_prefsReadable]).
      debugPrint('STORE: prefs unavailable, read-only boot: $e');
      loaded = true;
      notifyListeners();
      _warmAudio(soundOn);
      return;
    }
    // Separate from the read above: a backup failure must never turn a
    // successful prefs read into a read-only boot.
    await _restoreBackupIfEmpty(p);
    debugPrint('STORE: prefs loaded');
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
        jsonDecode(p.getString(kAppearances) ?? '{}') as Map,
      );
    } catch (_) {
      playerAppearances = {};
    }
    try {
      appearanceKeys = (jsonDecode(
        p.getString(kAppearanceKeys) ?? '[]',
      ) as List).map((e) => e.toString()).toSet();
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
        sheets[e.key.toString()] = InningsSheet.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        );
      }
    } catch (_) {
      sheets = {};
    }
    // Audio is preloaded, but it must NEVER be allowed to stop the app from
    // booting: a hung platform channel (audioplayers_android 5.3.0 did this
    // on a handful of devices) left the umpire staring at a splash screen.
    // The scorer still works without sound; it just stays silent.
    _warmAudio(soundOn);
    debugPrint('STORE: reading active match');
    final raw = p.getString(kActive);
    if (raw != null) {
      try {
        final m = Match.decode(raw);
        if (m.config.commonPlayers > 1) m.config.commonPlayers = 1;
        if (_isActive(m)) match = m;
      } catch (e) {
        debugPrint('STORE: match decode failed: $e');
      }
    }
    debugPrint('STORE: reading undo');
    try {
      _undo = (jsonDecode(p.getString(kUndo) ?? '[]') as List).cast<String>();
    } catch (e) {
      debugPrint('STORE: undo decode failed: $e');
      _undo = [];
    }
    _redo = [];
    _backupEnabled = true;
    loaded = true;
    notifyListeners();
    debugPrint(
      'STORE: load() complete — roster=${roster.length} '
      'clubs=${clubs.length} profiles=${profiles.length} '
      'match=${match != null} restored=$restoredFromBackup',
    );
  }

  /// First launch after an uninstall/reinstall has no `cricket_*` keys at all,
  /// so a leftover snapshot in Downloads is safe to bring back. Any existing
  /// key means this is not a fresh install — never overwrite it.
  Future<void> _restoreBackupIfEmpty(SharedPreferences p) async {
    try {
      if (p.getKeys().any((k) => k.startsWith('cricket_'))) return;
      final raw = await BackupService.read().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      if (raw == null || raw.isEmpty) {
        // Fresh install, no backup the app can read by itself. Offer the
        // system file picker once; it can read a manual copy in Downloads
        // where scoped storage stops a plain read.
        needsRestorePrompt = true;
        return;
      }
      final snap = BackupSnapshot.decode(raw);
      if (snap == null || !snap.hasAny(userDataKeys)) {
        debugPrint('STORE: backup found but unusable — keeping empty store');
        needsRestorePrompt = true;
        return;
      }
      await snap.writeTo(p);
      restoredFromBackup = true;
      needsRestorePrompt = false;
      lastBackupAt = snap.savedAt;
      debugPrint(
        'STORE: restored backup from ${snap.savedAt.toIso8601String()} '
        '(${snap.values.length} keys)',
      );
    } catch (e) {
      debugPrint('STORE: backup restore skipped: $e');
    }
  }

  /// Writes the current store to both backup locations. Returns false when
  /// there is nothing worth saving or storage refuses the write; the caller
  /// can show [lastBackupError].
  ///
  /// A store with no club/player/match/archive is never written, even
  /// manually: a settings-only snapshot must never clobber the real backup
  /// left by a previous install that auto-restore has not read yet.
  Future<bool> backupNow() async {
    if (_persistBlocked) return false;
    if (_backingUp) {
      _backupQueued = true;
      return false;
    }
    _backingUp = true;
    try {
      final p = await SharedPreferences.getInstance();
      final values = <String, Object?>{};
      for (final key in p.getKeys()) {
        if (!key.startsWith('cricket_')) continue;
        final value = p.get(key);
        if (value is String ||
            value is bool ||
            value is int ||
            value is double) {
          values[key] = value;
        } else if (value is List) {
          values[key] = value.map((e) => e.toString()).toList();
        }
      }
      final snap = BackupSnapshot(savedAt: DateTime.now(), values: values);
      if (!snap.hasAny(userDataKeys)) {
        debugPrint('STORE: backup skipped — no user data yet');
        return false;
      }
      final res = await BackupService.write(snap);
      if (res.ok) {
        lastBackupAt = snap.savedAt;
        lastBackupPath = res.path;
        lastBackupDownloadsPath = res.downloadsPath;
        lastBackupError = null;
        debugPrint(
          'STORE: backup written — app=${res.path} '
          'downloads=${res.downloadsPath}',
        );
      } else {
        lastBackupError = res.error ?? 'storage unavailable';
        debugPrint('STORE: backup FAILED — $lastBackupError');
      }
      notifyListeners();
      return res.ok;
    } catch (e) {
      lastBackupError = e.toString();
      debugPrint('STORE: backup FAILED — $e');
      notifyListeners();
      return false;
    } finally {
      _backingUp = false;
      if (_backupQueued) {
        _backupQueued = false;
        unawaited(backupNow());
      }
    }
  }

  /// Called after every persist. No timers: the 10-second floor is enough to
  /// keep a ball-by-ball match from hammering storage and cannot leak a
  /// pending timer into tests.
  void _maybeBackup() {
    if (!_backupEnabled || _persistBlocked) return;
    if (_backingUp) {
      // A save landed while the snapshot was being written; take one more
      // snapshot as soon as the current write finishes.
      _backupQueued = true;
      return;
    }
    final now = DateTime.now();
    final last = _lastBackupAttempt;
    if (last != null && now.difference(last) < const Duration(seconds: 10)) {
      return;
    }
    _lastBackupAttempt = now;
    unawaited(backupNow());
  }

  void acknowledgeRestore() {
    if (!restoredFromBackup) return;
    restoredFromBackup = false;
    notifyListeners();
  }

  void dismissRestorePrompt() {
    if (!needsRestorePrompt) return;
    needsRestorePrompt = false;
    notifyListeners();
  }

  /// Where the last backup landed, in words the umpire can find with a file
  /// manager. The public copy is the one that survives a reinstall.
  String get backupLocationLabel => lastBackupDownloadsPath != null
      ? 'Downloads/CricScore/${BackupService.fileName}'
      : lastBackupPath != null
      ? 'App storage (pull with adb)'
      : 'Not saved yet';

  /// Safe fallback for a backup copied off the phone (or from Drive).
  Future<BackupRestore> restoreLatestBackup() async {
    final raw = await BackupService.read();
    if (raw == null || raw.isEmpty) {
      return const BackupRestore(false, 'No backup found on this device');
    }
    return _applyBackup(raw);
  }

  /// Applies a raw snapshot the picker returned after the UI has shown the
  /// user which backup it is and asked for confirmation. Validation happens
  /// again here; the UI check is not trusted for a destructive replace.
  Future<BackupRestore> restorePickedBackup(String raw) => _applyBackup(raw);

  Future<BackupRestore> _applyBackup(String raw) async {
    final snap = BackupSnapshot.decode(raw);
    if (snap == null || !snap.hasAny(userDataKeys)) {
      return const BackupRestore(false, 'That file is not a CricScore backup');
    }
    try {
      final p = await SharedPreferences.getInstance();
      // Replacement, not merge: drop keys the backup predates so an old live
      // match cannot survive alongside the restored one. The backup module owns
      // the preference shape; the store only orchestrates load/notify.
      await snap.writeTo(p);
      await load();
      lastBackupAt = snap.savedAt;
      notifyListeners();
      debugPrint('STORE: restored user backup (${snap.values.length} keys)');
      return BackupRestore(
        true,
        'Restored backup from ${_stamp(snap.savedAt)}',
        savedAt: snap.savedAt,
      );
    } catch (e) {
      debugPrint('STORE: restore failed: $e');
      return BackupRestore(false, 'Restore failed: $e');
    }
  }

  static String _stamp(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.day}/${l.month}/${l.year} ${two(l.hour)}:${two(l.minute)}';
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
        m.config.playersPerSide,
        m.config.rules.lastManStanding,
      );
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
    if (_persistBlocked) {
      // The store was read and the read failed, so everything in memory is
      // defaults. Writing now would destroy the real saved data on disk.
      debugPrint('STORE: persist skipped — prefs read failed');
      return;
    }
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
      kRoster,
      jsonEncode(roster.map((e) => e.toJson()).toList()),
    );
    await p.setString(
      kClubs,
      jsonEncode(clubs.map((e) => e.toJson()).toList()),
    );
    await p.setString(
      kProfiles,
      jsonEncode(profiles.map((e) => e.toJson()).toList()),
    );
    if (activeProfileId != null) {
      await p.setString(kActiveProfile, activeProfileId!);
    } else {
      await p.remove(kActiveProfile);
    }
    await p.setString(
      kSheets,
      jsonEncode(sheets.map((k, v) => MapEntry(k, v.toJson()))),
    );
    _maybeBackup();
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
      name: name.trim(),
      pinHash: hashPin(pin, name.trim()),
    );
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

  Player? addPlayer({
    required String name,
    PlayerRole role = PlayerRole.allRounder,
    BattingStyle battingStyle = BattingStyle.rightHand,
    BowlingStyle bowlingStyle = BowlingStyle.none,
    String? phone,
  }) {
    final cid = activeClubId;
    if (cid == null) return null;
    if (duplicateName(name)) return null;
    final player = Player.create(
      clubId: cid,
      name: name.trim(),
      role: role,
      battingStyle: battingStyle,
      bowlingStyle: bowlingStyle,
    );
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

  /// Deletes a club player from the roster AND the stats lists. Refused
  /// when the player is in a live XI, has batted/bowled, or sits in either
  /// live sheet — figures already reference them and must not dangle.
  /// Archived matches keep their name snapshots regardless.
  String? deletePlayer(String id) {
    for (final sheet in sheets.values) {
      final b = sheet.batting[id];
      final w = sheet.bowling[id];
      if ((b != null && b.position > 0) ||
          (w != null && (w.balls > 0 || w.wickets > 0))) {
        return 'Already played — cannot delete mid-match';
      }
    }
    final m = match;
    if (m != null &&
        (m.config.squadA.contains(id) || m.config.squadB.contains(id))) {
      return 'In a live squad — remove from the XI first';
    }
    pushSnapshotSafe();
    roster.removeWhere((p) => p.id == id);
    playerAppearances.remove(id);
    _persist();
    notifyListeners();
    return null;
  }

  /// Snapshot only when a match is live (delete works without one).
  void pushSnapshotSafe() {
    if (match != null) pushSnapshot();
  }

  /// Renames a club and regenerates its handle, which is derived from the
  /// name. Null when the id is unknown or the name is blank.
  String? renameClub(String id, String name) {
    final t = name.trim();
    if (t.isEmpty) return 'Enter a club name';
    Club? target;
    for (final c in clubs) {
      if (c.id == id) target = c;
    }
    if (target == null) return 'Club not found';
    pushSnapshotSafe();
    target.name = t;
    target.handle = Club.create(name: t).handle;
    _persist();
    notifyListeners();
    return null;
  }

  /// Deletes a club and every player registered to it.
  ///
  /// Refused while a live match uses one of its players in an XI, or while any
  /// of them has recorded figures in a live sheet: those rows are referenced by
  /// balls already on the strip and by the current striker/bowler, and
  /// orphaning them corrupts the scorecard. Archived matches are unaffected —
  /// they carry their own name snapshots.
  String? deleteClub(String id) {
    final members = roster.where((p) => p.clubId == id).toList();
    final ids = members.map((p) => p.id).toSet();
    final m = match;
    if (m != null) {
      final inSquad = ids.any(
        (pid) => m.config.squadA.contains(pid) || m.config.squadB.contains(pid),
      );
      if (inSquad) return 'Players are in the live XI — remove them first';
      for (final sheet in sheets.values) {
        final played = ids.any((pid) {
          final b = sheet.batting[pid];
          final w = sheet.bowling[pid];
          if (sheet.strikerId == pid || sheet.bowlerId == pid) return true;
          return (b != null && b.position > 0) ||
              (w != null && (w.balls > 0 || w.wickets > 0));
        });
        if (played) return 'A player has already batted or bowled this match';
      }
    }
    pushSnapshotSafe();
    roster.removeWhere((p) => p.clubId == id);
    for (final pid in ids) {
      playerAppearances.remove(pid);
    }
    clubs.removeWhere((c) => c.id == id);
    if (activeClubId == id) {
      activeClubId = clubs.isEmpty ? null : clubs.first.id;
    }
    _persist();
    notifyListeners();
    return null;
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
  /// the picker greys the just-bowled player, but the store is the enforcer
  /// (Law 17.4: no two consecutive overs).
  String? setBowler(String id) {
    final sheet = currentSheet;
    if (sheet == null) return 'Player tracking is off';
    final block = sheet.bowlBlockReason(id);
    if (block != null) return '${sheet.nameOf(id)} $block';
    pushSnapshot();
    // Mid-over change: reset the live over counters without crediting a
    // maiden. The over that already completed was closed when it completed.
    final live = sheet.currentBowler;
    if (live != null && (live.overLegal > 0 || live.overBalls > 0)) {
      sheet.closeOver(legalBalls: 0);
    }
    sheet.setBowler(id);
    // Disarms the latch: the very next delivery is the first of the new over
    // and must never be refused.
    sheet.needsNewBowler = false;
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

  /// Replaces the batter at one end, mid-over.
  ///
  /// One commit: the departing player is recorded as retired and the newcomer
  /// takes that exact end. A single snapshot means ONE undo puts both men
  /// back, which is what the umpire wants after a mistap — not a half state.
  ///
  /// [atStrikerEnd] decides the consequence, and it is the whole point:
  ///   - striker retired -> the newcomer faces the next ball;
  ///   - non-striker retired -> the striker keeps his strike.
  ///
  /// [retireAs] is how the departing man is recorded: retired hurt (he may
  /// come back later, no wicket falls) or retired out (a wicket falls).
  String? substituteBatter({
    required bool atStrikerEnd,
    required String newcomerId,
    DismissalType retireAs = DismissalType.retiredHurt,
  }) {
    final sheet = currentSheet;
    if (sheet == null) return 'Player tracking is off';
    if (retireAs != DismissalType.retiredHurt &&
        retireAs != DismissalType.retiredOut) {
      return 'Not a retirement';
    }
    // The bowler must be settled first: a substitution in the middle of a
    // refused delivery would leave the over half-scored.
    if (sheet.needsNewBowler) return 'Pick the next bowler first';
    final outgoingId = atStrikerEnd ? sheet.strikerId : sheet.nonStrikerId;
    if (outgoingId == null) return 'No batter at that end';
    // An empty newcomer means "retire, nobody comes in" — the innings is over
    // and there is no one left to bat.
    if (newcomerId.isNotEmpty) {
      if (newcomerId == outgoingId) return 'Same player';
      final otherEnd = atStrikerEnd ? sheet.nonStrikerId : sheet.strikerId;
      if (!sheet
          .replacementOptions(outgoingId, otherEnd)
          .contains(newcomerId)) {
        return 'That player cannot come in';
      }
    }
    pushSnapshot();
    final outgoingName = sheet.nameOf(outgoingId);
    final newcomerName = newcomerId.isEmpty
        ? 'nobody'
        : sheet.nameOf(newcomerId);
    sheet.substituteBatter(
      atStrikerEnd: atStrikerEnd,
      newcomerId: newcomerId,
      retireAs: retireAs,
    );
    // Retired-out is a dismissal in the Laws: it counts toward all-out.
    // Retired-hurt does not.
    if (retireAs == DismissalType.retiredOut) {
      final inn = innings;
      if (inn != null) {
        inn.wickets++;
        _checkEnd();
      }
    }
    // The players sheet shows this with an UNDO button: a substitution the
    // umpire does not like must be one tap from being undone.
    lastChange = '$outgoingName → $newcomerName';
    _persist();
    notifyListeners();
    return null;
  }

  /// One-line description of the last batter change, for the undo banner.
  /// Cleared by undo and by the next delivery.
  String? get lastChange => engine.lastChange;
  set lastChange(String? v) => engine.lastChange = v;

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
  /// Closes every over that has completed since the last call: credits the
  /// maiden, records who bowled it, and arms the single bowler latch.
  ///
  /// Called from `score` immediately after the delivery lands, so the latch is
  /// armed by the sixth ball. The old code armed it lazily on the *next* tap,
  /// which refused that delivery and then re-prompted for an over the umpire
  /// had already answered — the stuck loop.
  ///
  /// The strip keeps the finished over visible (deferred rollover); the new one
  /// appears when the first ball of it is recorded.
  void _closeCompletedOvers(Innings inn, InningsSheet sheet) {
    final done = sheet.completedOverCount(inn);
    if (done <= sheet.closedOvers) return;

    // Law 41.6: the ends change at the end of EVERY over, unconditionally.
    //
    // This used to carry a parity guard that skipped the swap when the over
    // contained an odd run, on the theory that the batters had "already"
    // changed ends. That conflated two different things: odd runs swap the
    // ends because the batters physically crossed, while the over ending
    // swaps them because a new over starts from the other end. Both happen.
    //
    // So a single on the last ball sends the batter to the non-striker's end
    // AND the over ending brings him straight back on strike. Six dots have no
    // odd run, and the single boundary swap gives the partner the strike.
    for (var i = sheet.closedOvers; i < done; i++) {
      sheet.swapEnds();
      finishOverForSheet();
    }
    sheet.closedOvers = done;

    // Only ask for a change when play actually continues. `inn.completed` is
    // read defensively as well as relied on, because the ordering fix in
    // score() is what makes it trustworthy and this must not silently regress
    // into prompting for a bowler who will never bowl again.
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
    _undo.add(UndoEnvelope.encode(match!, sheets));
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  Future<void> undo() async {
    nbArmed = false;
    // The undo banner describes the change that was just undone, so it goes
    // with it.
    lastChange = null;
    if (_undo.isEmpty) return;
    if (match != null) {
      _redo.add(UndoEnvelope.encode(match!, sheets));
    }
    final raw = _undo.removeLast();
    final env = UndoEnvelope.decode(raw);
    if (env != null) {
      match = env.match;
      sheets = env.sheets;
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
      batFirst ? cfg.teamB : cfg.teamA,
      batFirst ? cfg.teamA : cfg.teamB,
    );
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
      battingTeam: inn.battingTeam,
      bowlingTeam: inn.bowlingTeam,
    );
    final battingSquad = squadForTeam(inn.battingTeam);
    final bowlingSquad = squadForTeam(inn.bowlingTeam);
    sheet.registerSquad([...battingSquad, ...bowlingSquad]);
    // Only the batting side may be brought on to bat. Both squads are
    // registered above because figures need the fielders, but without this
    // the next-batter list offered the whole fielding side.
    sheet.setBattingXI(battingSquad);
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
        if (byId[id] != null) byId[id]!,
    ];
  }

  List<Player> get clubRoster {
    final cid = activeClubId;
    if (cid == null) return List.unmodifiable(roster);
    return roster.where((p) => p.clubId == cid).toList();
  }

  /// Roster search. INCLUDES inactive players.
  ///
  /// It used to filter them out, while [duplicateName] (correctly) checked the
  /// whole roster. So an inactive player blocked their own name with "already
  /// exists" and was impossible to find, edit or delete — visible only in
  /// STATS, which read the unfiltered list. Callers order active first and
  /// mark the rest; hiding a name that still blocks that name is the bug.
  List<Player> searchRoster(String q) {
    final query = q.toLowerCase().trim();
    final all = clubRoster.toList()
      ..sort((a, b) {
        if (a.active != b.active) return a.active ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    if (query.isEmpty) return all;
    return all.where((p) => p.searchKey.contains(query)).toList();
  }

  /// The currently selected club, or null before one is created.
  Club? get activeClub {
    final id = activeClubId;
    if (id == null) return null;
    for (final c in clubs) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The roster player with [id], or null. Needed when the XI holds ids that
  /// predate the roster entry (mid-match adds, imported squads).
  Player? playerById(String id) {
    for (final p in roster) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The roster player already using [name], active or not — so the UI can
  /// offer "open that player" instead of a dead-end warning.
  Player? playerByName(String name) {
    final q = name.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final p in clubRoster) {
      if (p.name.trim().toLowerCase() == q) return p;
    }
    return null;
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

  /// Scoring refuses while set: pick the new bowler first. Compared by _tap
  /// to reopen the picker instead of only showing a snackbar.
  static const needBowlerMsg = 'Select the new bowler to continue';
  static const needSetupMsg = 'Set batters + bowler first';

  String? score({
    required String
    action, // DOT,RUNS,FOUR,SIX,WIDE,NB_DIRECT,BYE,LEGBYE,WICKET
    int runs = 0,
    String wicketType = 'Bowled',
    String? dismissal, // DismissalType.name when tracking players
    String? fielderName,
    String? newBatterId,

    /// Run-out dismissed the batter at the NON-STRIKER's end. A short ball
    /// run, a direct hit at the other end. Replaces the old free-floating
    /// `crossed` flag: choosing the end determines crossedness, so the umpire
    /// can no longer mistap it and silently seat the new batter at the wrong
    /// end.
    /// Run-out dismissed the batter at the NON-STRIKER's end.
    ///
    /// Crossing is not a parameter. It only changes the outcome for a run-out,
    /// where choosing the end already determines it: a batter out at the
    /// non-striker's end got there by crossing. For every other dismissal the
    /// batters are taken to have stayed in their creases, and the one rare
    /// exception - batters crossing on a catch - is corrected with the manual
    /// swap ends control.
    bool outAtNonStrikerEnd = false,

    /// WHICH END the dismissal happened at, stated directly by the umpire.
    ///
    /// This was previously inferred from [outAtNonStrikerEnd] and run parity,
    /// which quietly forced the two facts to agree. They do not always: a
    /// non-striker is commonly out at the STRIKER's end (he backed up or
    /// crossed), and a striker can be out at the bowler's end. Stating the end
    /// separately lets all four combinations be scored the way they happened.
    ///
    /// True = the batter was out at the striker's end (where he was facing).
    /// False = out at the bowler's end (where his partner was).
    bool outAtStrikerEnd = true,
  }) {
    final m = match;
    final inn = innings;
    if (m == null || inn == null || inn.completed) return 'Innings completed';
    final gate = tracking ? _ensureSheet(m.currentInnings) : null;
    if (gate != null) {
      if (gate.strikerId == null || gate.bowlerId == null) {
        return needSetupMsg;
      }
      // The only bowler latch. Armed by the delivery that COMPLETES an over
      // (see _closeCompletedOvers below), disarmed by picking a bowler — so
      // the first delivery of the new over is never refused.
      if (gate.needsNewBowler) return needBowlerMsg;
    }
    pushSnapshot();
    // A new delivery supersedes the undo banner: the change it described is
    // now part of the match, not a pending edit.
    lastChange = null;
    final rules = m.config.rules;

    // The dismissal type is settled ONCE, from the enum id when the UI sent
    // one and from the display string otherwise. Nothing further down compares
    // the strings: `'Run Out' != 'Run out'` is what let a non-run-out slip past
    // the no-ball and free-hit guards, and what made a run-out print as
    // `b <bowler>` on the card.
    final type =
        DismissalType.tryFromId(dismissal ?? wicketType) ??
        DismissalType.bowled;

    Ball b;
    switch (action) {
      case 'DOT':
        if (nbArmed) {
          b = Ball(
            runs: 0,
            extra: 'NB',
            extraRuns: rules.noBallPenalty,
            isLegal: false,
            badge: 'NB',
          );
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
            badge: 'N$runs',
          );
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
            badge: 'N4',
          );
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
            badge: 'N6',
          );
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
          badge: total <= 1 ? 'WD' : 'WD$total',
        );
        break;
      case 'NB_DIRECT':
        b = Ball(
          runs: runs,
          extra: 'NB',
          extraRuns: rules.noBallPenalty,
          isLegal: false,
          badge: runs > 0 ? 'N$runs' : 'NB',
        );
        break;
      case 'BYE':
        b = Ball(
          runs: 0,
          extra: 'B',
          extraRuns: runs,
          isLegal: true,
          badge: 'B$runs',
        );
        break;
      case 'LEGBYE':
        b = Ball(
          runs: 0,
          extra: 'LB',
          extraRuns: runs,
          isLegal: true,
          badge: 'LB$runs',
        );
        break;
      case 'WICKET':
        // Wickets are recorded as standalone legal balls (a run-out on a
        // wide is tapped as WD then W — totals match reality), except when
        // resolving an armed no-ball: Laws allow only a run-out there, and
        // the ball stays illegal.
        if (nbArmed) {
          nbArmed = false;
          if (type != DismissalType.runOut) {
            _undo.removeLast();
            return 'Only run-out possible on no-ball';
          }
          b = Ball(
            runs: runs,
            extra: 'NB',
            extraRuns: rules.noBallPenalty,
            isLegal: false,
            isWicket: true,
            wicketType: type.label,
            badge: wicketBadge(runs),
          );
          if (rules.freeHit) inn.isFreeHitActive = true;
          break;
        }
        if (inn.isFreeHitActive && type != DismissalType.runOut) {
          b = Ball(runs: runs, badge: runs == 0 ? '0' : '$runs');
        } else {
          // Run-outs with completed runs read W+1 / W+2 on the strip.
          b = Ball(
            runs: runs,
            isWicket: true,
            wicketType: type.label,
            badge: wicketBadge(runs),
          );
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
      b.strikerId = sheet.strikerId;
      b.nonStrikerId = sheet.nonStrikerId;
      b.bowlerId = sheet.bowlerId;
      if (fielderName != null && fielderName.isNotEmpty) {
        b.fielderName = fielderName;
      }
    }
    _addBall(inn, b);
    if (sheet != null) {
      sheet.applyDelivery(
        b,
        dismissalType: b.isWicket ? type : null,
        fielderName: fielderName,
      );
    }

    // Settle the innings BEFORE deciding whether anything is owed. The old
    // order asked the two questions while `inn.completed` was still false, so
    // the final delivery of an innings armed the bowler prompt and the last
    // wicket tried to seat a batter who no longer existed (8 players, 7
    // wickets: all out, yet it still asked for the next man).
    _checkEnd();

    if (sheet != null) {
      if (b.isWicket && !inn.completed) {
        // Run-out can dismiss either end. Which one decides whether the ends
        // changed, so it also decides who faces the next ball.
        final outIsNonStriker =
            outAtNonStrikerEnd && type == DismissalType.runOut;
        final outId = outIsNonStriker
            ? (sheet.nonStrikerId ?? '')
            : (b.strikerId ?? '');
        // Crossing is DERIVED, never a manual toggle: dismissing the
        // non-striker means the batters must have crossed for him to be out
        // at that end, and an odd number of completed runs always changes
        // the ends. A missed toggle used to seat the new batter at the wrong
        // end silently, corrupting every later ball.
        // Dismissal is attributed by applyDelivery to the striker, so a
        // non-striker run-out is moved across here.
        if (outIsNonStriker) _moveDismissalToNonStriker(sheet, b);

        // Bring the new batter in at the striker's end in the same commit, so
        // a dismissal is always resolved: one sheet, one tap, no limbo.
        // Options exclude the OUT batter and the man at the other end;
        // retired-hurt returnees stay eligible.
        final opts = sheet.nextBatterOptions(outId);
        final next = (newBatterId != null && newBatterId.isNotEmpty)
            ? newBatterId
            : (opts.isEmpty ? null : opts.first);
        if (type == DismissalType.runOut) {
          // Seat from WHERE the dismissal happened, not who was out. The end
          // tells us which man must move across and where the newcomer lands,
          // so both of the umpire's answers are honoured instead of one being
          // inferred from the other.
          //
          //   out at the striker's end -> newcomer there, he is next in line
          //   out at the bowler's end  -> newcomer fills that gap, the batter
          //                               already on strike keeps his end
          //
          // This runs even with nobody left to bat, so the vacated end is
          // emptied rather than left holding the man who is already out.
          sheet.seatAfterDismissal(
            dismissedId: outId,
            newcomerId: next,
            atStrikerEnd: outAtStrikerEnd,
          );
        } else if (next != null) {
          if (b.runs % 2 == 1) {
            // Every other dismissal: the batters crossed, so the newcomer takes
            // the striker's vacated end and the man who crossed is on strike.
            sheet.crossedRunOutFix(next);
          } else {
            sheet.bringIn(next);
          }
        }
      }

      // The over has now ended (if this was its sixth legal ball): credit the
      // maiden, change the ends per Law 41.6, name the previous bowler, and
      // ask for a change — only if play continues.
      _closeCompletedOvers(inn, sheet);
    }

    ballGen++; // strip animates on generation change only — undo is silent
    _feedback(b);
    _publishRoom(); // viewers see the ball; scoring never waits on this
    _persist();
    notifyListeners();
    return null;
  }

  /// Moves a run-out recorded against the striker onto the non-striker.
  /// `applyDelivery` credits the wicket to whoever is on strike; a run-out at
  /// the non-striker's end must credit the non-striker instead.
  void _moveDismissalToNonStriker(InningsSheet sheet, Ball b) {
    final outId = sheet.nonStrikerId;
    if (outId == null) return;
    final bat = sheet.striker;
    final nst = sheet.batting[outId];
    if (bat == null || nst == null) return;
    // Hand the dismissal across: number, dismissed flag and credit.
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
    // Register on the live sheet AND every other innings sheet, so a player
    // added during innings 1 is still selectable in innings 2 (whose sheet is
    // built lazily from the squads and would otherwise miss them).
    final p = playerById(playerId);
    if (p != null) {
      for (final sh in sheets.values) {
        sh.register(p);
        // Added to THIS side's XI, so they are a legitimate batter for the
        // sheets whose batting team matches, and must stay out of the other.
        if (sh.battingTeam == team) sh.addToBattingXI(playerId);
      }
    }
    _persist();
    notifyListeners();
    return null;
  }

  /// Type-a-name mid-match add: roster hit joins the XI, a new name is created
  /// in the club (name-only; styles later) and joins. Duplicates warn.
  /// Adds a mid-match player by typed name: an existing roster player (inactive
  /// or not) is added as-is; an unknown name is created in the club first.
  String? addSquadByName(String team, String name) {
    final t = name.trim();
    if (t.isEmpty) return 'Type a name';
    final existing = playerByName(t);
    if (existing != null) return addToSquad(team, existing.id);
    if (activeClubId == null) return 'Create a club first';
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
      newPlayers,
      lastManStanding ?? cfg.rules.lastManStanding,
    );
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
      m.config.playersPerSide,
      m.config.rules.lastManStanding,
    );
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
      m.innings1.bowlingTeam,
      m.innings1.battingTeam,
      m.target,
    );
    m.currentInnings = 2;
    nbArmed = false;
    if (m.config.trackPlayers) _ensureSheet(2);
    _publishRoom();
    _persist();
    notifyListeners();
  }

  Future<void> _archive() async {
    if (_persistBlocked) return;
    final SharedPreferences p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('STORE: archive skipped — prefs unavailable: $e');
      return;
    }
    List hist = [];
    try {
      hist = jsonDecode(p.getString(kHistory) ?? '[]') as List;
    } catch (_) {}
    final rec = match!.toJson();
    rec['savedAt'] = DateTime.now().toIso8601String();
    if (sheets.isNotEmpty) {
      rec['sheets'] = sheets.map((k, v) => MapEntry(k, v.toJson()));
    }
    hist.insert(0, rec);
    if (hist.length > 50) hist = hist.sublist(0, 50);
    await p.setString(kHistory, jsonEncode(hist));
    // Archiving does not go through _persist, so take the snapshot here.
    // A fresh install must never lose the match that just finished.
    if (_backupEnabled) unawaited(backupNow());
  }

  /// Raw archive records (match + optional sheets), newest first.
  Future<List<Map<String, dynamic>>> historyRecords() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = jsonDecode(p.getString(kHistory) ?? '[]') as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Sheets stored with an archive record, or empty when the match predates
  /// player tracking. Never throws: old archives render totals-only.
  static Map<String, InningsSheet> sheetsFromRecord(Map<String, dynamic> rec) {
    final out = <String, InningsSheet>{};
    try {
      final sj = Map<String, dynamic>.from((rec['sheets'] ?? {}) as Map);
      for (final e in sj.entries) {
        out[e.key.toString()] = InningsSheet.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        );
      }
    } catch (_) {}
    return out;
  }

  Future<List<Match>> history() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = jsonDecode(p.getString(kHistory) ?? '[]') as List;
      return list
          .map((e) => Match.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteHistoryAt(int idx) async {
    final SharedPreferences p;
    try {
      p = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    final h = await history();
    if (idx >= 0 && idx < h.length) {
      h.removeAt(idx);
      await p.setString(
        kHistory,
        jsonEncode(h.map((e) => e.toJson()).toList()),
      );
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(kHistory);
    } catch (_) {}
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
