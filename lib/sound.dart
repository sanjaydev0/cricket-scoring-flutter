import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// Zero-latency arcade SFX (bundled, offline) — fire-and-forget, never blocks
/// scoring. 100% offline: all clips ship in assets/audio/.
///
/// SoLoud is a real mixer: every clip is preloaded once and `play()` starts a
/// new voice that the engine mixes with the others. That removes the old
/// per-clip pool bookkeeping (and its "all players busy" drop) while keeping
/// the same guarantee: rapid `4-4-6-W-6` never silently loses a hit.
///
/// Per-clip volumes level-match the assets (four/six/wicket are synthesised
/// with more body, so they run hotter than the UI blips). Gains above 1.0 are
/// safe: every asset is normalised to ~-13 dBFS, so 2.75x (+8.8 dB) still
/// peaks below full scale. Each clip gets its own debounce so a boundary
/// followed by a wicket both sound.
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

  /// Same-clip taps inside this window are dropped (no machine-gun stacking).
  static const _debounceMs = 150;

  /// Small mix buffer: ~23ms at 44.1kHz, low enough that a wicket lands with
  /// the visual, large enough to avoid underruns on a busy scoring screen.
  static const _bufferSize = 1024;

  final Map<String, AudioSource> _sources = {};
  final Map<String, int> _lastMs = {};
  bool enabled = true;
  bool _ready = false;
  Future<void>? _initializing;

  /// True once every clip is preloaded — scoring screens can rely on SFX.
  bool get ready => _ready;

  /// Clip names the service expects in assets/audio/. Exposed so tests can
  /// prove no sound is silently missing from the bundle.
  static List<String> get clipNames => _clips.keys.toList(growable: false);

  /// Boots the engine and preloads every clip. Concurrent calls (boot plus a
  /// user toggling sound back on) share one initialisation.
  Future<void> init({required bool enabled}) {
    this.enabled = enabled;
    if (_ready) return Future.value();
    return _initializing ??= _init().whenComplete(() => _initializing = null);
  }

  Future<void> _init() async {
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) {
        await soloud.init(
          lowLatency: true,
          bufferSize: _bufferSize,
          // Media usage: audible even when the ringer is on silent, which an
          // umpire needs, on the same stream as the rest of the app's audio.
          androidAAudioAttributes: AndroidAAudioAttributes.mediaMusic,
        );
      }
      for (final name in _clips.keys) {
        _sources[name] = await soloud.loadAsset('assets/audio/$name.ogg');
      }
      _ready = true;
    } catch (_) {
      // Audio unavailable (no platform channel, bad asset, no output device):
      // the scorer must still work, just silently.
      _sources.clear();
      _ready = false;
    }
  }

  void _play(String name) {
    if (!enabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastMs[name] ?? 0) < _debounceMs) return;
    _lastMs[name] = now;
    // No source outside init() means audio never came up (unit tests, no
    // output device): stay silent instead of touching the engine.
    final source = _sources[name];
    if (source == null) return;
    try {
      SoLoud.instance.play(source, volume: _clips[name] ?? 1.0);
    } catch (_) {}
  }

  Future<void> run() async => _play('tap');
  Future<void> four() async => _play('four');
  Future<void> six() async => _play('six');
  Future<void> wicket() async => _play('wicket');
  Future<void> wide() async => _play('wide');
  Future<void> noball() async => _play('nb');
  Future<void> extra() async => _play('extra');
  Future<void> undo() async => _play('undo');
  Future<void> confirm() async => _play('confirm');
  Future<void> error() async => _play('error');
  Future<void> fanfare() async => _play('fanfare');

  void setEnabled(bool v) {
    enabled = v;
    notifyListeners();
  }
}
