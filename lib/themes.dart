import 'package:flutter/material.dart';

// 3 offline themes, system fonts only (no Google Fonts download = fast + 100% offline).
// Sunlight: white high-contrast. Pavilion: zinc dark. Solar: yellow high-vis.

class AppThemes {
  static ThemeData sunlight() {
    const seed = Color(0xFF0F172A);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardTheme: const CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamilyFallback: ['monospace'], fontWeight: FontWeight.w900),
        bodyLarge: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  static ThemeData pavilion() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE4E4E7),
        secondary: Color(0xFFA1A1AA),
        surface: Color(0xFF18181B),
      ),
      scaffoldBackgroundColor: const Color(0xFF09090B),
      cardTheme: const CardThemeData(
        color: Color(0xFF18181B),
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
    );
  }

  static ThemeData solar() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Colors.black,
        secondary: Colors.black87,
        surface: Color(0xFFFDE047),
      ),
      scaffoldBackgroundColor: const Color(0xFFFDE047),
      cardTheme: const CardThemeData(
        color: Colors.black,
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
    );
  }

  static ThemeData byId(String id) {
    switch (id) {
      case 'night':
        return pavilion();
      case 'solar':
        return solar();
      default:
        return sunlight();
    }
  }
}
