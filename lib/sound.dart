import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Zero-latency arcade SFX (Kenney CC0, bundled) — fire-and-forget, never
/// blocks scoring. 100% offline: all files ship in assets/audio/.
///
/// Each clip owns a 3-player round-robin pool, all preloaded at startup.
/// Replaying a finished clip on the same player goes silent (playhead sits
/// at the end), so every fire takes the next player: stop + seek(0) +
/// resume. Debounce is per-sound, so different buttons never block each
/// other. Fully guarded: audio failure can never break the scorer, and the
/// service constructs safely in unit tests.
class SoundService extends ChangeNotifier {
  static final SoundService instance = SoundService._();
  SoundService._();

  static const _files = [
    'tap',
    'four',
    'six',
    'wicket',
    'wide',
    'nb',
    'extra',
    'undo',
    'confirm',
    'error',
    'fanfare',
  ];

  static const _poolSize = 3;
  final Map<String, List<AudioPlayer>> _pools = {};
  final Map<String, int> _next = {};
  final Map<String, int> _lastMs = {};
  bool enabled = true;
  bool _ready = false;

  Future<void> init({required bool enabled}) async {
    this.enabled = enabled;
    if (_ready) return;
    try {
      for (final name in _files) {
        final players = <AudioPlayer>[];
        for (var i = 0; i < _poolSize; i++) {
          final p = AudioPlayer();
          await p.setSource(AssetSource('audio/$name.ogg'));
          await p.setVolume(1);
          players.add(p);
        }
        _pools[name] = players;
        _next[name] = 0;
      }
      _ready = true;
    } catch (_) {
      _pools.clear(); // audio unavailable — scorer works without it
    }
  }

  Future<void> _play(String name) async {
    if (!enabled) return;
    // Per-sound debounce: rapid same-key taps never stack audio, but a
    // boundary followed instantly by a wicket still plays both.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastMs[name] ?? 0) < 150) return;
    _lastMs[name] = now;
    // Only preloaded players ever play: constructing an AudioPlayer outside
    // init() throws uncatchable async errors on platforms without channels
    // (e.g. unit tests), so a missing pool means stay silent.
    final pool = _pools[name];
    if (pool == null || pool.isEmpty) return;
    try {
      final p = pool[_next[name]! % pool.length];
      _next[name] = _next[name]! + 1;
      await p.stop();
      await p.seek(Duration.zero);
      await p.resume();
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
