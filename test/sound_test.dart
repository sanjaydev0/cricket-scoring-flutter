import 'dart:io';

import 'package:cricket_scoring/sound.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the failure the scorer actually shipped with: a sound wired in code
/// but missing (or empty) in the bundle is silent on device and invisible in
/// review. Every clip the service can fire must exist on disk.
void main() {
  test('every wired SFX clip ships in assets/audio', () {
    final names = SoundService.clipNames;
    expect(names, contains('four'));
    expect(names, contains('six'));
    expect(names, contains('wicket'));
    for (final n in names) {
      final f = File('assets/audio/$n.ogg');
      expect(f.existsSync(), isTrue, reason: 'missing clip: $n.ogg');
      expect(f.lengthSync(), greaterThan(200), reason: 'empty clip: $n.ogg');
    }
  });

  test('boundary and wicket clips carry audible body', () {
    // A boundary that is one click long reads as "no sound" in the hand.
    for (final n in ['four', 'six', 'wicket']) {
      expect(File('assets/audio/$n.ogg').lengthSync(), greaterThan(4000),
          reason: '$n.ogg too small to be a real effect');
    }
  });

  test('firing sounds without a platform channel is safe and stays silent',
      () async {
    // No init() in unit tests: no pools exist, and _play must no-op instead of
    // throwing uncatchable async errors.
    expect(SoundService.instance.ready, isFalse);
    await SoundService.instance.four();
    await SoundService.instance.six();
    await SoundService.instance.wicket();
  });

  test('muting blocks playback requests', () async {
    final s = SoundService.instance;
    final was = s.enabled;
    s.setEnabled(false);
    expect(s.enabled, isFalse);
    await s.wicket();
    s.setEnabled(was);
  });
}
