import 'package:flutter/material.dart';

/// Score numeral fonts (bundled OFL, 100% offline). '' = system default.
class ScoreFonts {
  static const ids = [
    'stadium',
    'condensed',
    'block',
    'ledger',
    'tech',
    'tall',
    'slab',
    'wide',
    'broadcast',
    'ticket',
  ];
  static const names = {
    'stadium': 'Stadium Sans',
    'condensed': 'Condensed Punch',
    'block': 'Block Heavy',
    'ledger': 'Mono Ledger',
    'tech': 'Tech Board',
    'tall': 'Tall Ticket',
    'slab': 'Ultra Slab',
    'wide': 'Wide Circuit',
    'broadcast': 'Broadcast',
    'ticket': 'Narrow Board',
  };
  static String? family(String id) {
    switch (id) {
      case 'condensed':
        return 'AntonCond';
      case 'block':
        return 'ArchivoBlack';
      case 'ledger':
        return 'PlexMono';
      case 'tech':
        return 'ChakraPetch';
      case 'tall':
        return 'BebasTall';
      case 'slab':
        return 'AlfaSlab';
      case 'wide':
        return 'Audiowide';
      case 'broadcast':
        return 'BarlowCond';
      case 'ticket':
        return 'Fjalla';
      default:
        return null;
    }
  }
}

/// Visual style preset for keypad + over strip + score hero.
/// Every preset is glare-proof: solid saturated fills, bold dark/light
/// text, strong borders — no pastels.
class StylePreset {
  final String id;
  final String name;
  final Color heroBg;
  final Color heroFg;
  final Color? keyDefault;
  final Color? keyFg;
  final double keyRadius;
  final Color stripBg;
  const StylePreset({
    required this.id,
    required this.name,
    required this.heroBg,
    required this.heroFg,
    this.keyDefault,
    this.keyFg,
    required this.keyRadius,
    required this.stripBg,
  });

  static const ids = [
    'umpire',
    'night',
    'solar',
    'pitch',
    'led',
    'pureblack',
    'purewhite',
    'ocean',
    'crimson',
    'slate',
  ];

  static const presets = {
    'umpire': StylePreset(
      id: 'umpire',
      name: 'Umpire Pro',
      heroBg: Color(0xFF1D4ED8),
      heroFg: Colors.white,
      keyRadius: 14,
      stripBg: Color(0xFFFFFFFF),
    ),
    'night': StylePreset(
      id: 'night',
      name: 'Stadium Night',
      heroBg: Color(0xFF000000),
      heroFg: Color(0xFF00E676),
      keyDefault: Color(0xFF1B1B1F),
      keyFg: Colors.white,
      keyRadius: 14,
      stripBg: Color(0xFF101014),
    ),
    'solar': StylePreset(
      id: 'solar',
      name: 'Solar Flare',
      heroBg: Color(0xFFFFBA08),
      heroFg: Colors.black,
      keyDefault: Colors.black,
      keyFg: Color(0xFFFFBA08),
      keyRadius: 10,
      stripBg: Color(0xFFFFF3C4),
    ),
    'pitch': StylePreset(
      id: 'pitch',
      name: 'Pitch Green',
      heroBg: Color(0xFF0B5D2E),
      heroFg: Colors.white,
      keyRadius: 18,
      stripBg: Color(0xFFEAF7EE),
    ),
    'led': StylePreset(
      id: 'led',
      name: 'Scoreboard LED',
      heroBg: Color(0xFF1A0505),
      heroFg: Color(0xFFFFB300),
      keyDefault: Color(0xFF241A08),
      keyFg: Color(0xFFFFD54F),
      keyRadius: 6,
      stripBg: Color(0xFF140B02),
    ),
    'pureblack': StylePreset(
      id: 'pureblack',
      name: 'Pure Black',
      heroBg: Color(0xFF000000),
      heroFg: Colors.white,
      keyDefault: Color(0xFF111111),
      keyFg: Colors.white,
      keyRadius: 14,
      stripBg: Color(0xFF000000),
    ),
    'purewhite': StylePreset(
      id: 'purewhite',
      name: 'Pure White',
      heroBg: Colors.white,
      heroFg: Colors.black,
      keyDefault: Colors.white,
      keyFg: Colors.black,
      keyRadius: 14,
      stripBg: Colors.white,
    ),
    'ocean': StylePreset(
      id: 'ocean',
      name: 'Deep Ocean',
      heroBg: Color(0xFF062A5E),
      heroFg: Color(0xFF7DD3FC),
      keyDefault: Color(0xFF0B3B7A),
      keyFg: Colors.white,
      keyRadius: 16,
      stripBg: Color(0xFFE8F4FF),
    ),
    'crimson': StylePreset(
      id: 'crimson',
      name: 'Crimson Court',
      heroBg: Color(0xFF7F1D1D),
      heroFg: Colors.white,
      keyRadius: 12,
      stripBg: Color(0xFFFDECEC),
    ),
    'slate': StylePreset(
      id: 'slate',
      name: 'Slate Storm',
      heroBg: Color(0xFF1E293B),
      heroFg: Color(0xFFBEF264),
      keyDefault: Color(0xFF0F172A),
      keyFg: Color(0xFFE2E8F0),
      keyRadius: 8,
      stripBg: Color(0xFFF1F5F9),
    ),
  };

  static StylePreset of(String id) => presets[id] ?? presets['umpire']!;
}

/// Material 3 umpire theme: maximum contrast for extreme sunlight glare.
/// Solid saturated fills, near-black on bright / white on deep, no pastels.
class UmpireTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1D4ED8),
      brightness: Brightness.light,
    ).copyWith(
      surface: Colors.white,
      onSurface: const Color(0xFF0A0A0A),
      surfaceContainerHighest: const Color(0xFFF1F1F1),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      cardTheme: const CardThemeData(
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFFE2E2E2)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle:
              const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF60A5FA),
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF131316),
      onSurface: Colors.white,
      surfaceContainerHighest: const Color(0xFF232327),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0B0B0D),
      cardTheme: const CardThemeData(
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFF2E2E33)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle:
              const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
