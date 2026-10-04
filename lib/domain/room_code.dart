import 'dart:math';

/// Room join codes: 5 characters from a 32-symbol alphabet.
///
/// Digits-only would be 100,000 combinations — seconds to brute-force, so the
/// code would not be a real capability. 32^5 is 33,554,432, and the alphabet
/// drops the symbols people misread when reading a code aloud (0/O, 1/I), which
/// matters when someone shouts a code across a gully ground.
class RoomCode {
  static const length = 5;

  /// A-Z minus I and O, plus 2-9. Exactly 32 symbols.
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Membership test for the alphabet. Built once; a map beats a scan because
  /// [normalize] runs on every keystroke of a typed code.
  static final _allowed = <String>{...alphabet.split('')};

  static final Random _random = Random.secure();

  /// A fresh random code.
  static String generate() {
    final b = StringBuffer();
    for (var i = 0; i < length; i++) {
      b.write(alphabet[_random.nextInt(alphabet.length)]);
    }
    return b.toString();
  }

  /// Upper-cases and validates a typed/pasted code. Returns null when it is not
  /// a well-formed code, so the UI can refuse without a network round trip.
  static String? normalize(String raw) {
    final v = raw.trim().toUpperCase();
    if (v.length != length) return null;
    for (var i = 0; i < v.length; i++) {
      if (!_allowed.contains(v[i])) return null;
    }
    return v;
  }

  static bool isValid(String raw) => normalize(raw) != null;
}
