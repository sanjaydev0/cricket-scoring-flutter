import 'package:flutter/material.dart';

/// Spacing + radii contract. Widgets read `context.spacing.xs` etc. instead
/// of raw numbers, so a screen rebuild stays on the 4/8/16/24/32 grid.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;

  const AppSpacing({
    this.xs = 4.0,
    this.sm = 8.0,
    this.md = 16.0,
    this.lg = 24.0,
    this.xl = 32.0,
    this.radiusSm = 8.0,
    this.radiusMd = 12.0,
    this.radiusLg = 16.0,
  });

  @override
  AppSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
  }) {
    return AppSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
    );
  }

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    return AppSpacing(
      xs: xs + (other.xs - xs) * t,
      sm: sm + (other.sm - sm) * t,
      md: md + (other.md - md) * t,
      lg: lg + (other.lg - lg) * t,
      xl: xl + (other.xl - xl) * t,
      radiusSm: radiusSm + (other.radiusSm - radiusSm) * t,
      radiusMd: radiusMd + (other.radiusMd - radiusMd) * t,
      radiusLg: radiusLg + (other.radiusLg - radiusLg) * t,
    );
  }
}

/// Semantic colour roles for the rules in `DESIGN.md`. A widget asks for a
/// role ("the fill behind a locked row") and never for a hex value, so the same
/// widget is legible on the paper theme and on the night theme.
///
/// This is a [ThemeExtension] on purpose: the old `const DesignTokens()` was
/// theme-blind, which is how a light-mode `#E2E8F0` slab ends up on near-black.
@immutable
class DesignTokens extends ThemeExtension<DesignTokens> {
  /// Primary CTA fill (scoreboard-style near-black in both themes).
  final Color primaryFill;
  final Color onPrimaryFill;

  /// Structural border: 1.5px around a card, sheet section or tile. Strong
  /// enough to read in direct sun, where a 1px 50%-alpha hairline vanishes.
  final Color surfaceOutline;

  /// Inner divider between rows of the same table/list. Solid, 1px, never
  /// alpha-blended — the row rule is a rule, not a suggestion.
  final Color borderRow;

  /// Solid fill behind a locked or disabled row. A fill, not an opacity, so
  /// the name stays readable at 10,000 lux.
  final Color lockedFill;

  /// Ink on [lockedFill]. Full contrast against its own fill.
  final Color lockedInk;

  /// Positive derived figure (wickets taken, a completed XI slot) as text.
  final Color statGoodInk;

  /// Pill fill when a positive figure needs to sit on a surface.
  final Color statGoodFill;

  /// Economy / strike-rate style advisory figure as text. Never bare amber.
  final Color statWarnInk;

  const DesignTokens({
    required this.primaryFill,
    required this.onPrimaryFill,
    required this.surfaceOutline,
    required this.borderRow,
    required this.lockedFill,
    required this.lockedInk,
    required this.statGoodInk,
    required this.statGoodFill,
    required this.statWarnInk,
  });

  /// Paper theme: near-black structure, slate-filled locked rows, deep inks.
  static const DesignTokens light = DesignTokens(
    primaryFill: Color(0xFF131316),
    onPrimaryFill: Colors.white,
    surfaceOutline: Color(0xFF0F172A),
    borderRow: Color(0xFFCBD5E1),
    lockedFill: Color(0xFFE2E8F0),
    lockedInk: Color(0xFF0F172A),
    statGoodInk: Color(0xFF14532D),
    statGoodFill: Color(0xFFDCFCE7),
    statWarnInk: Color(0xFF92400E),
  );

  /// Night theme: the same roles, flipped so nothing turns into a light slab.
  static const DesignTokens dark = DesignTokens(
    primaryFill: Color(0xFFF2F2F2),
    onPrimaryFill: Color(0xFF0A0A0A),
    surfaceOutline: Color(0xFFE2E8F0),
    borderRow: Color(0xFF3F3F46),
    lockedFill: Color(0xFF24242A),
    lockedInk: Color(0xFFE8E8EC),
    statGoodInk: Color(0xFF6EE7A0),
    statGoodFill: Color(0xFF0B2A18),
    statWarnInk: Color(0xFFFCD34D),
  );

  @override
  DesignTokens copyWith({
    Color? primaryFill,
    Color? onPrimaryFill,
    Color? surfaceOutline,
    Color? borderRow,
    Color? lockedFill,
    Color? lockedInk,
    Color? statGoodInk,
    Color? statGoodFill,
    Color? statWarnInk,
  }) {
    return DesignTokens(
      primaryFill: primaryFill ?? this.primaryFill,
      onPrimaryFill: onPrimaryFill ?? this.onPrimaryFill,
      surfaceOutline: surfaceOutline ?? this.surfaceOutline,
      borderRow: borderRow ?? this.borderRow,
      lockedFill: lockedFill ?? this.lockedFill,
      lockedInk: lockedInk ?? this.lockedInk,
      statGoodInk: statGoodInk ?? this.statGoodInk,
      statGoodFill: statGoodFill ?? this.statGoodFill,
      statWarnInk: statWarnInk ?? this.statWarnInk,
    );
  }

  @override
  DesignTokens lerp(ThemeExtension<DesignTokens>? other, double t) {
    if (other is! DesignTokens) return this;
    return DesignTokens(
      primaryFill: Color.lerp(primaryFill, other.primaryFill, t)!,
      onPrimaryFill: Color.lerp(onPrimaryFill, other.onPrimaryFill, t)!,
      surfaceOutline: Color.lerp(surfaceOutline, other.surfaceOutline, t)!,
      borderRow: Color.lerp(borderRow, other.borderRow, t)!,
      lockedFill: Color.lerp(lockedFill, other.lockedFill, t)!,
      lockedInk: Color.lerp(lockedInk, other.lockedInk, t)!,
      statGoodInk: Color.lerp(statGoodInk, other.statGoodInk, t)!,
      statGoodFill: Color.lerp(statGoodFill, other.statGoodFill, t)!,
      statWarnInk: Color.lerp(statWarnInk, other.statWarnInk, t)!,
    );
  }
}

extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textStyles => Theme.of(this).textTheme;
  AppSpacing get spacing =>
      Theme.of(this).extension<AppSpacing>() ?? const AppSpacing();
  DesignTokens get tokens =>
      Theme.of(this).extension<DesignTokens>() ?? DesignTokens.light;
}
