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

/// Softer-rule aliases: saturated glare-proof fills stay the source of truth
/// in `StylePreset`; widgets read them via `context.tokens` instead of
/// hardcoding a new hex value per screen.
@immutable
class DesignTokens {
  /// Primary CTA fill (scoreboard-style near-black in both themes).
  final Color primaryFill;
  final Color onPrimaryFill;
  final Color surfaceOutline;

  const DesignTokens({
    this.primaryFill = const Color(0xFF131316),
    this.onPrimaryFill = Colors.white,
    this.surfaceOutline = const Color(0xFFE2E2E2),
  });
}

extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textStyles => Theme.of(this).textTheme;
  AppSpacing get spacing =>
      Theme.of(this).extension<AppSpacing>() ?? const AppSpacing();
  DesignTokens get tokens => const DesignTokens();
}
