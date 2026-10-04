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
    'solar',
    'purewhite',
    'crimson',
    'ios',
    'nothing',
    'vercel',
    'openrouter',
    'linear',
    'crt',
    'neon',
    'gameboy',
    'prored',
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
    'crimson': StylePreset(
      id: 'crimson',
      name: 'Crimson Court',
      heroBg: Color(0xFF7F1D1D),
      heroFg: Colors.white,
      keyRadius: 12,
      stripBg: Color(0xFFFDECEC),
    ),
    'ios': StylePreset(
      id: 'ios',
      name: 'iOS Frost',
      heroBg: Color(0xFF007AFF),
      heroFg: Colors.white,
      keyRadius: 16,
      stripBg: Color(0xFFEAF2FF),
    ),
    'nothing': StylePreset(
      id: 'nothing',
      name: 'Nothing Mono',
      heroBg: Color(0xFF111111),
      heroFg: Colors.white,
      keyDefault: Color(0xFF1C1C1E),
      keyFg: Colors.white,
      keyRadius: 12,
      stripBg: Color(0xFFF5F5F5),
    ),
    'vercel': StylePreset(
      id: 'vercel',
      name: 'Vercel Ink',
      heroBg: Colors.white,
      heroFg: Colors.black,
      keyDefault: Colors.black,
      keyFg: Colors.white,
      keyRadius: 8,
      stripBg: Color(0xFFF5F5F5),
    ),
    'openrouter': StylePreset(
      id: 'openrouter',
      name: 'Router Paper',
      heroBg: Color(0xFFF5F0E8),
      heroFg: Color(0xFF3E2F25),
      keyRadius: 10,
      stripBg: Color(0xFFEFE7D8),
    ),
    'linear': StylePreset(
      id: 'linear',
      name: 'Linear Dusk',
      heroBg: Color(0xFF08090A),
      heroFg: Color(0xFF8A9CFF),
      keyDefault: Color(0xFF1B1E2E),
      keyFg: Color(0xFFC7D2FE),
      keyRadius: 10,
      stripBg: Color(0xFF101223),
    ),
    'crt': StylePreset(
      id: 'crt',
      name: 'CRT Phosphor',
      heroBg: Color(0xFF000000),
      heroFg: Color(0xFF33FF66),
      keyDefault: Color(0xFF0A0F0A),
      keyFg: Color(0xFF33FF66),
      keyRadius: 8,
      stripBg: Color(0xFF0A0F0A),
    ),
    'neon': StylePreset(
      id: 'neon',
      name: 'Neon Cabinet',
      heroBg: Color(0xFF0D0221),
      heroFg: Color(0xFFFF2EA6),
      keyDefault: Color(0xFF1A0533),
      keyFg: Color(0xFF00F0FF),
      keyRadius: 12,
      stripBg: Color(0xFF150826),
    ),
    'gameboy': StylePreset(
      id: 'gameboy',
      name: 'Game Boy',
      heroBg: Color(0xFF9BBC0F),
      heroFg: Color(0xFF0F380F),
      keyDefault: Color(0xFF0F380F),
      keyFg: Color(0xFF9BBC0F),
      keyRadius: 6,
      stripBg: Color(0xFF9BBC0F),
    ),
    'prored': StylePreset(
      id: 'prored',
      name: 'Pro Red',
      heroBg: Color(0xFFDC2626),
      heroFg: Colors.white,
      keyRadius: 12,
      stripBg: Color(0xFFFEF2F2),
    ),
  };

  static StylePreset of(String id) => presets[id] ?? presets['umpire']!;
}

/// Material 3 umpire theme: maximum contrast for extreme sunlight glare.
/// Solid saturated fills, near-black on bright / white on deep, no pastels.
/// Chips + segmented controls are 8px rectangles, carbon when selected.
class UmpireTheme {
  static ChipThemeData _chips(ColorScheme scheme) => ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        showCheckmark: false,
        // 44px+ touch targets per platform guidance.
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        selectedColor: const Color(0xFF131316),
        labelStyle: TextStyle(
            fontWeight: FontWeight.w800, color: scheme.onSurface),
        secondaryLabelStyle: const TextStyle(
            fontWeight: FontWeight.w800, color: Colors.white),
        side: BorderSide(color: scheme.outline),
      );

  static SegmentedButtonThemeData _segmented() =>
      SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          // 44px+ touch targets per platform guidance.
          minimumSize: const WidgetStatePropertyAll(
              Size(48, 44)),
          backgroundColor:
              WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected)
                      ? const Color(0xFF131316)
                      : null),
          foregroundColor:
              WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected)
                      ? Colors.white
                      : null),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
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
      chipTheme: _chips(scheme),
      segmentedButtonTheme: _segmented(),
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
      chipTheme: _chips(scheme),
      segmentedButtonTheme: _segmented(),
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
