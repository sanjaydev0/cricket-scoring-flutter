import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Zero-latency arcade SFX (bundled, offline) — fire-and-forget, never blocks
/// scoring. 100% offline: all clips ship in assets/audio/.
///
/// One [AudioPool] per clip. The pool is the deep module here: it preloads
/// players, recycles each one on completion (stop() rewinds it) and allocates
/// a fresh player when every one is still busy — so rapid `4-4-6-W-6` can
/// never silently drop a hit, which hand-rolled seek/resume did on Android.
///
/// Per-clip volumes level-match the assets (four/six/wicket are synthesised
/// with more body, so they run hotter than the UI blips), and every clip gets
/// its own debounce so a boundary followed by a wicket both sound.
class SoundService extends ChangeNotifier {
  static final SoundService instance = SoundService._();
  SoundService._();

  /// Clip file name -> playback gain. Measured mean level of each asset is
  /// normalised to ~-13 dBFS in the app so no clip is lost under another.
  static const _clips = <String, double>{
    'tap': 1.55, // 14ms click: dots and singles stay unobtrusive
    'four': 1.52, // bat crack + rising two-note
    'six': 1.26, // crack + rising chord stack
    'wicket': 1.78, // stump clack + low thud
    'wide': 1.21,
    'nb': 1.15,
    'extra': 1.21,
    'undo': 2.75,
    'confirm': 1.0,
    'error': 1.84,
    'fanfare': 1.0,
  };

  /// Players kept warm per clip; extras are created only under overlap.
  static const _minPlayers = 2;
  static const _maxPlayers = 6;

  /// Same-clip taps inside this window are dropped (no machine-gun stacking).
  static const _debounceMs = 150;

  /// System default output (speaker or a connected headset), but SFX take
  /// audio focus so nothing ducks them, and the ringer/silent switch is
  /// ignored: an umpire must hear a wicket even on silent.
  static final AudioContext _ctx =
      AudioContextConfig(focus: AudioContextConfigFocus.gain).build();

  final Map<String, AudioPool> _pools = {};
  final Map<String, int> _lastMs = {};
  bool enabled = true;
  bool _ready = false;

  /// True once every clip is preloaded — scoring screens can rely on SFX.
  bool get ready => _ready;

  /// Clip names the service expects in assets/audio/. Exposed so tests can
  /// prove no sound is silently missing from the bundle.
  static List<String> get clipNames => _clips.keys.toList(growable: false);

  Future<void> init({required bool enabled}) async {
    this.enabled = enabled;
    if (_ready) return;
    try {
      for (final name in _clips.keys) {
        _pools[name] = await AudioPool.create(
          source: AssetSource('audio/$name.ogg'),
          minPlayers: _minPlayers,
          maxPlayers: _maxPlayers,
          audioContext: _ctx,
        );
      }
      _ready = true;
    } catch (_) {
      // Audio unavailable (no platform channel, bad asset): the scorer must
      // still work, just silently.
      _pools.clear();
      _ready = false;
    }
  }

  Future<void> _play(String name) async {
    if (!enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastMs[name] ?? 0) < _debounceMs) return;
    _lastMs[name] = now;
    // Never construct an AudioPool/player here: outside init() that throws
    // uncatchable async errors on channels-less platforms (e.g. unit tests),
    // so a missing pool simply means silence.
    final pool = _pools[name];
    if (pool == null) return;
    try {
      await pool.start(volume: _clips[name] ?? 1.0);
    } catch (_) {}
  }

  Future<void> run() => _play('tap');
  Future<void> four() => _play('four');
  Future<void> six() => _play('six');
  Future<void> wicket() => _play('wicket');
  Future<void> wide() => _play('wide');
  Future<void> noball() => _play('nb');
  Future<void> extra() => _play('extra');
  Future<void> undo() => _play('undo');
  Future<void> confirm() => _play('confirm');
  Future<void> error() => _play('error');
  Future<void> fanfare() => _play('fanfare');

  void setEnabled(bool v) {
    enabled = v;
    notifyListeners();
  }
}
