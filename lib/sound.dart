import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Arcade SFX (Kenney CC0, bundled) — fire-and-forget, never blocks scoring.
/// 100% offline: all files ship in assets/audio/.
/// Lazily creates players so unit tests (no platform channels) stay green.
class SoundService extends ChangeNotifier {
  static final SoundService instance = SoundService._();
  SoundService._();

  AudioPlayer? _fx;
  bool enabled = true;
  int _lastMs = 0;

  Future<void> init({required bool enabled}) async {
    this.enabled = enabled;
    try {
      _fx ??= AudioPlayer();
      await _fx!.setVolume(1);
    } catch (_) {
      _fx = null; // audio unavailable — scorer works without it
    }
  }

  Future<void> _play(String file, {double volume = 1}) async {
    if (!enabled) return;
    // Debounce: rapid keying never stacks audio. One shot only.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < 150) return;
    _lastMs = now;
    try {
      _fx ??= AudioPlayer();
      await _fx!.play(AssetSource(file), volume: volume);
    } catch (_) {}
  }

  Future<void> run() => _play('audio/tap.ogg');
  Future<void> boundary() => _play('audio/boundary.ogg');
  Future<void> wicket() => _play('audio/wicket.ogg');
  Future<void> extra() => _play('audio/extra.ogg', volume: 0.8);
  Future<void> undo() => _play('audio/undo.ogg', volume: 0.8);
  Future<void> confirm() => _play('audio/confirm.ogg');
  Future<void> error() => _play('audio/error.ogg', volume: 0.8);
  Future<void> fanfare() => _play('audio/fanfare.ogg');

  void setEnabled(bool v) {
    enabled = v;
    notifyListeners();
  }
}
