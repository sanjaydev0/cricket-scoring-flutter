import 'package:flutter/material.dart';

import 'core/theme/app_tokens.dart';

export 'core/theme/app_tokens.dart';

/// Shared motion tokens: one timing language app-wide.
/// Press 150ms, overlays 300ms ease-out, celebrations 700ms,
/// strip glide scales with distance (200 + 80/ball, max 900ms).
class Motion {
  static const press = Duration(milliseconds: 150);
  static const overlay = Duration(milliseconds: 300);
  static const celebrate = Duration(milliseconds: 700);
  static const curve = Curves.easeOutCubic;
  static Duration glide(int ballsShifted) {
    final ms = 200 + 80 * ballsShifted.clamp(0, 8);
    return Duration(milliseconds: ms > 900 ? 900 : ms);
  }
}

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
    'nothing',
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
/// Instant page transition: no slide/fade fights in-flight scoreboard
/// motion. Calm handoffs for innings breaks and results.
class _NoTransition extends PageTransitionsBuilder {
  const _NoTransition();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class UmpireTheme {
  /// Chip: 8px rectangle, solid `primaryFill` slab when selected.
  static ChipThemeData _chips(DesignTokens t) => ChipThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    showCheckmark: false,
    // 44px+ touch targets per platform guidance.
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    backgroundColor: t.surface,
    selectedColor: t.primaryFill,
    labelStyle: TextStyle(fontWeight: FontWeight.w700, color: t.onSurface),
    secondaryLabelStyle: TextStyle(
      fontWeight: FontWeight.w800,
      color: t.onPrimaryFill,
    ),
    side: BorderSide(color: t.surfaceOutline, width: 1.5),
  );

  /// M3's icon button is a 40dp container. Every icon action in this app is
  /// pressed by a thumb in daylight, so the floor is lifted to 48dp here once
  /// instead of per-widget; a caller may still force a smaller box deliberately.
  static IconButtonThemeData _iconButtons(DesignTokens t) =>
      IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: WidgetStatePropertyAll(t.onSurface),
        ),
      );

  static SegmentedButtonThemeData _segmented(DesignTokens t) =>
      SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          // 44px+ touch targets per platform guidance.
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? t.primaryFill : t.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? t.onPrimaryFill
                : t.onSurface,
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: t.surfaceOutline, width: 1.5),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );

  /// One type voice for the chrome.
  ///
  /// `w900` is reserved for score numerals and tracked micro-labels. Every
  /// bundled family is a single file, so `w800`/`w900` on body copy is
  /// synthesised faux-bold — using it everywhere is what made the app read
  /// blobby. Titles sit at w700, body at w500, subtitles at w600.
  static TextTheme _text(DesignTokens t) {
    const tabular = [FontFeature.tabularFigures()];
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 68,
        height: 1.0,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
        fontFeatures: tabular,
        color: t.onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 48,
        height: 1.05,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
        fontFeatures: tabular,
        color: t.onSurface,
      ),
      displaySmall: TextStyle(
        fontSize: 34,
        height: 1.1,
        fontWeight: FontWeight.w900,
        fontFeatures: tabular,
        color: t.onSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: t.onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 17,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: t.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 16,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: t.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: t.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: t.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: t.onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: t.onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 13.5,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: t.onSurface,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: t.mutedInk,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: t.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: t.onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: t.mutedInk,
      ),
    );
  }

  static ThemeData light() =>
      _build(DesignTokens.light, EventTokens.light, Brightness.light);

  static ThemeData dark() =>
      _build(DesignTokens.dark, EventTokens.dark, Brightness.dark);

  /// Builds both themes from the same roles, so a role flips instead of a
  /// screen hardcoding a light-mode colour.
  static ThemeData _build(
    DesignTokens t,
    EventTokens events,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    // Seeded only for the members nothing reads directly (inverse colours,
    // disabled washes). Every tonal member a screen touches is overridden
    // below: the M3 pastel ladder is what made the app look dated.
    final scheme =
        ColorScheme.fromSeed(
          seedColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
          brightness: brightness,
        ).copyWith(
          primary: t.primaryFill,
          onPrimary: t.onPrimaryFill,
          primaryContainer: t.lockedFill,
          onPrimaryContainer: t.lockedInk,
          secondary: t.primaryFill,
          onSecondary: t.onPrimaryFill,
          secondaryContainer: t.lockedFill,
          onSecondaryContainer: t.lockedInk,
          tertiary: t.primaryFill,
          onTertiary: t.onPrimaryFill,
          tertiaryContainer: t.lockedFill,
          onTertiaryContainer: t.lockedInk,
          error: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
          onError: isDark ? const Color(0xFF0A0A0A) : Colors.white,
          errorContainer: t.lockedFill,
          onErrorContainer: t.lockedInk,
          surface: t.surface,
          onSurface: t.onSurface,
          onSurfaceVariant: t.mutedInk,
          surfaceTint: Colors.transparent,
          outline: t.surfaceOutline,
          outlineVariant: t.borderRow,
          surfaceContainerLowest: t.surface,
          surfaceContainerLow: t.surface,
          surfaceContainer: t.surface,
          surfaceContainerHigh: t.surface,
          surfaceContainerHighest: t.surface,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      extensions: [const AppSpacing(), t, events],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _NoTransition(),
          TargetPlatform.iOS: _NoTransition(),
          TargetPlatform.linux: _NoTransition(),
          TargetPlatform.macOS: _NoTransition(),
          TargetPlatform.windows: _NoTransition(),
        },
      ),
      colorScheme: scheme,
      scaffoldBackgroundColor: t.scaffoldBg,
      canvasColor: t.scaffoldBg,
      textTheme: _text(t),
      // Depth is border-led, not shadow-led: elevation 0 everywhere, and a
      // 1.5px structural border does the separating. A soft shadow vanishes
      // in sunlight and costs GPU overdraw for nothing.
      cardTheme: CardThemeData(
        elevation: 0,
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.surfaceOutline, width: 1.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.scaffoldBg,
        foregroundColor: t.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: t.onSurface,
        ),
        iconTheme: IconThemeData(color: t.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: t.onSurface, size: 22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        labelStyle: TextStyle(fontWeight: FontWeight.w600, color: t.mutedInk),
        hintStyle: TextStyle(fontWeight: FontWeight.w500, color: t.mutedInk),
        floatingLabelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: t.onSurface,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.surfaceOutline, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.surfaceOutline, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.primaryFill, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      // The M3 switch is the last pill-shaped silhouette in the chrome; its
      // track/thumb now read as a solid slab and a full-contrast knob.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? t.onPrimaryFill : t.lockedInk,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? t.primaryFill : t.lockedFill,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.surfaceOutline, width: 1.5),
        ),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: t.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 13.5,
          height: 1.4,
          fontWeight: FontWeight.w500,
          color: t.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: t.mutedInk,
        modalBarrierColor: Colors.black.withValues(alpha: 0.7),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: t.surfaceOutline, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.primaryFill,
        contentTextStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: t.onPrimaryFill,
        ),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: DividerThemeData(
        color: t.borderRow,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.onSurface,
        textColor: t.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: t.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: t.mutedInk,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        minVerticalPadding: 8,
      ),
      chipTheme: _chips(t),
      iconButtonTheme: _iconButtons(t),
      segmentedButtonTheme: _segmented(t),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.primaryFill,
          foregroundColor: t.onPrimaryFill,
          disabledBackgroundColor: t.lockedFill,
          disabledForegroundColor: t.lockedInk,
          elevation: 0,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.onSurface,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.onSurface,
          side: BorderSide(color: t.surfaceOutline, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: t.primaryFill),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.primaryFill,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: t.onPrimaryFill,
        ),
      ),
    );
  }
}
