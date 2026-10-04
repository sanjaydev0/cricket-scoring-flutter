import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Zero-latency arcade SFX (Kenney CC0, bundled) — fire-and-forget, never
/// blocks scoring. 100% offline: all files ship in assets/audio/.
///
/// One preloaded player per clip (`setSource` at startup, `resume()` to
/// play) — the lowest-latency pattern `audioplayers` offers. (`soundpool`
/// 2.4.1 was tried and dropped: it targets Android's removed v1 embedding
/// and no longer compiles.) Debounced so rapid keying never stacks audio,
/// and fully guarded: audio failure can never break the scorer, and the
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

  final Map<String, AudioPlayer> _players = {};
  bool enabled = true;
  bool _ready = false;
  int _lastMs = 0;

  Future<void> init({required bool enabled}) async {
    this.enabled = enabled;
    if (_ready) return;
    try {
      for (final name in _files) {
        final p = AudioPlayer();
        await p.setSource(AssetSource('audio/$name.ogg'));
        await p.setVolume(1);
        _players[name] = p;
      }
      _ready = true;
    } catch (_) {
      _players.clear(); // audio unavailable — scorer works without it
    }
  }

  Future<void> _play(String name) async {
    if (!enabled) return;
    // Debounce: rapid keying never stacks audio. One shot only.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < 150) return;
    _lastMs = now;
    // Only preloaded players ever play: constructing an AudioPlayer outside
    // init() throws uncatchable async errors on platforms without channels
    // (e.g. unit tests), so a missing player means stay silent.
    final p = _players[name];
    if (p == null) return;
    try {
      // Rewind first: resume() alone replays nothing once a clip finished.
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
