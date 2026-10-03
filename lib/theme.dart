import 'package:flutter/material.dart';

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
