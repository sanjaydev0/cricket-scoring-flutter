import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:soundpool/soundpool.dart';

/// Zero-latency arcade SFX (Kenney CC0, bundled) — fire-and-forget, never
/// blocks scoring. 100% offline: all files ship in assets/audio/.
///
/// Android/low-level targets use `soundpool` with all Sound IDs preloaded at
/// startup. Web has no soundpool backend, so it keeps `audioplayers`.
/// Everything is guarded: audio failure can never break the scorer, and the
/// service constructs safely in unit tests (no platform channels there).
class SoundService extends ChangeNotifier {
  static final SoundService instance = SoundService._();
  SoundService._();

  static const _files = [
    'tap',
    'boundary',
    'wicket',
    'extra',
    'undo',
    'confirm',
    'error',
    'fanfare',
  ];

  Soundpool? _pool;
  final Map<String, int> _ids = {};
  AudioPlayer? _webPlayer; // web fallback only
  bool enabled = true;
  bool _ready = false;
  int _lastMs = 0;

  Future<void> init({required bool enabled}) async {
    this.enabled = enabled;
    if (_ready) return;
    try {
      if (kIsWeb) {
        _webPlayer ??= AudioPlayer();
        await _webPlayer!.setVolume(1);
      } else {
        _pool ??= Soundpool.fromOptions(
          options: const SoundpoolOptions(maxStreams: 8),
        );
        for (final name in _files) {
          final data = await rootBundle.load('assets/audio/$name.ogg');
          final id = await _pool!.load(data);
          if (id > 0) _ids[name] = id;
        }
      }
      _ready = true;
    } catch (_) {
      _pool = null; // audio unavailable — scorer works without it
    }
  }

  Future<void> _play(String name) async {
    if (!enabled) return;
    // Debounce: rapid keying never stacks audio. One shot only.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < 150) return;
    _lastMs = now;
    try {
      if (kIsWeb) {
        _webPlayer ??= AudioPlayer();
        await _webPlayer!.play(AssetSource('audio/$name.ogg'));
      } else {
        final id = _ids[name];
        if (id == null) return;
        _pool ??= Soundpool.fromOptions(
          options: const SoundpoolOptions(maxStreams: 8),
        );
        await _pool!.play(id);
      }
    } catch (_) {}
  }

  Future<void> run() => _play('tap');
  Future<void> boundary() => _play('boundary');
  Future<void> wicket() => _play('wicket');
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
