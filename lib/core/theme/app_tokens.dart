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

  /// App canvas behind cards. Light is a bright neutral, not white: white
  /// everywhere halates in midday sun and erases the card edges, so the card
  /// has to earn its separation by luminance instead of by a heavy border.
  final Color scaffoldBg;

  /// Card, sheet and uncommitted-control fill. Always sits ON [scaffoldBg].
  final Color surface;

  /// Primary body ink: names, titles, values. Full contrast on [surface].
  final Color onSurface;

  /// Secondary ink: subtitles, reasons, captions, empty-state body. A real
  /// ink role, never `onSurface` multiplied by an alpha (Ink-Not-Tint Rule).
  final Color mutedInk;

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
    required this.scaffoldBg,
    required this.surface,
    required this.onSurface,
    required this.mutedInk,
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
    scaffoldBg: Color(0xFFF3F4F6),
    surface: Colors.white,
    onSurface: Color(0xFF0A0A0A),
    mutedInk: Color(0xFF475569),
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
    scaffoldBg: Color(0xFF09090B),
    surface: Color(0xFF141417),
    onSurface: Color(0xFFFAFAFA),
    mutedInk: Color(0xFFA1A1AA),
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
    Color? scaffoldBg,
    Color? surface,
    Color? onSurface,
    Color? mutedInk,
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
      scaffoldBg: scaffoldBg ?? this.scaffoldBg,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      mutedInk: mutedInk ?? this.mutedInk,
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
      scaffoldBg: Color.lerp(scaffoldBg, other.scaffoldBg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      mutedInk: Color.lerp(mutedInk, other.mutedInk, t)!,
    );
  }
}

/// One cricket-event colour and the ink that sits on it.
///
/// The pair travels together because the contrast is the point: bye cyan at
/// `#00B4D8` is 2.46:1 against white and 8.5:1 against black, so a badge that
/// borrowed the white ink would be unreadable outdoors.
@immutable
class EventRole {
  final Color fill;
  final Color ink;
  const EventRole(this.fill, this.ink);

  static EventRole lerp(EventRole a, EventRole b, double t) =>
      EventRole(Color.lerp(a.fill, b.fill, t)!, Color.lerp(a.ink, b.ink, t)!);
}

/// The six cricket-event colours, plus the dot and run tints.
///
/// These used to be inline `Color(0x…)` literals copied across four files —
/// crimson alone appeared six times — which made the Event Colour Rule
/// unenforceable: nothing stopped the same red becoming a settings accent.
/// A role makes "this colour means a wicket" a lookup instead of a convention.
@immutable
class EventTokens extends ThemeExtension<EventTokens> {
  final EventRole eventWicket;
  final EventRole eventSix;
  final EventRole eventFour;
  final EventRole eventWide;
  final EventRole eventNoBall;
  final EventRole eventBye;
  final EventRole eventDot;
  final EventRole eventRun1;
  final EventRole eventRun2;
  final EventRole eventRun3;
  final EventRole eventOther;

  const EventTokens({
    required this.eventWicket,
    required this.eventSix,
    required this.eventFour,
    required this.eventWide,
    required this.eventNoBall,
    required this.eventBye,
    required this.eventDot,
    required this.eventRun1,
    required this.eventRun2,
    required this.eventRun3,
    required this.eventOther,
  });

  /// Event colour carries meaning, not theme, so both themes share the fills.
  /// Only the ink is theme-blind too: it is chosen for contrast against the
  /// fill it sits on, never against the page.
  static const EventTokens light = EventTokens(
    eventWicket: EventRole(Color(0xFFDC143C), Colors.white),
    eventSix: EventRole(Color(0xFFEC008C), Colors.white),
    eventFour: EventRole(Color(0xFF15803D), Colors.white),
    eventWide: EventRole(Color(0xFFFFBA08), Colors.black),
    eventNoBall: EventRole(Color(0xFF7B2CBF), Colors.white),
    eventBye: EventRole(Color(0xFF00B4D8), Colors.black),
    eventDot: EventRole(Color(0xFF131316), Colors.white),
    eventRun1: EventRole(Color(0xFFA5F3FC), Colors.black),
    eventRun2: EventRole(Color(0xFF22D3EE), Colors.black),
    eventRun3: EventRole(Color(0xFF0E7490), Colors.white),
    eventOther: EventRole(Color(0xFF334155), Colors.white),
  );

  static const EventTokens dark = light;

  @override
  EventTokens copyWith({
    EventRole? eventWicket,
    EventRole? eventSix,
    EventRole? eventFour,
    EventRole? eventWide,
    EventRole? eventNoBall,
    EventRole? eventBye,
    EventRole? eventDot,
    EventRole? eventRun1,
    EventRole? eventRun2,
    EventRole? eventRun3,
    EventRole? eventOther,
  }) {
    return EventTokens(
      eventWicket: eventWicket ?? this.eventWicket,
      eventSix: eventSix ?? this.eventSix,
      eventFour: eventFour ?? this.eventFour,
      eventWide: eventWide ?? this.eventWide,
      eventNoBall: eventNoBall ?? this.eventNoBall,
      eventBye: eventBye ?? this.eventBye,
      eventDot: eventDot ?? this.eventDot,
      eventRun1: eventRun1 ?? this.eventRun1,
      eventRun2: eventRun2 ?? this.eventRun2,
      eventRun3: eventRun3 ?? this.eventRun3,
      eventOther: eventOther ?? this.eventOther,
    );
  }

  @override
  EventTokens lerp(ThemeExtension<EventTokens>? other, double t) {
    if (other is! EventTokens) return this;
    return EventTokens(
      eventWicket: EventRole.lerp(eventWicket, other.eventWicket, t),
      eventSix: EventRole.lerp(eventSix, other.eventSix, t),
      eventFour: EventRole.lerp(eventFour, other.eventFour, t),
      eventWide: EventRole.lerp(eventWide, other.eventWide, t),
      eventNoBall: EventRole.lerp(eventNoBall, other.eventNoBall, t),
      eventBye: EventRole.lerp(eventBye, other.eventBye, t),
      eventDot: EventRole.lerp(eventDot, other.eventDot, t),
      eventRun1: EventRole.lerp(eventRun1, other.eventRun1, t),
      eventRun2: EventRole.lerp(eventRun2, other.eventRun2, t),
      eventRun3: EventRole.lerp(eventRun3, other.eventRun3, t),
      eventOther: EventRole.lerp(eventOther, other.eventOther, t),
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
  EventTokens get events =>
      Theme.of(this).extension<EventTokens>() ?? EventTokens.light;
}
