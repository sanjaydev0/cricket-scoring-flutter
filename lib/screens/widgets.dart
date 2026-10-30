import 'package:flutter/material.dart';

import 'dart:math' show sin;

import '../domain/players.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Apple-design sheet primitive: one drag handle, one motion language,
/// reduced-motion aware. The settle follows the design spec (280ms ease-out
/// with a slight overshoot) instead of Material's fixed 250ms curve, and
/// collapses to a short fade when reduced motion is requested.
Future showAppSheet(
  BuildContext context, {
  bool showDragHandle = true,
  bool isScrollControlled = true,
  required WidgetBuilder builder,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  final dur = reduced
      ? const Duration(milliseconds: 120)
      : const Duration(milliseconds: 280);
  return showModalBottomSheet(
    context: context,
    showDragHandle: showDragHandle,
    isScrollControlled: isScrollControlled,
    sheetAnimationStyle: AnimationStyle(
      duration: dur,
      reverseDuration: dur,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    ),
    builder: builder,
  );
}

/// Carbon-black rectangular buttons (8px corners, white text) for all
/// dialogs, sheets and primary actions. Secondary = surface fill with
/// black border. No pills anywhere.
class RectBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;
  const RectBtn({
    required this.child,
    required this.onTap,
    this.primary = true,
    this.danger = false,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onTap,
      style:
          FilledButton.styleFrom(
            minimumSize: const Size(64, 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: danger
                ? cs.error
                : (primary ? const Color(0xFF131316) : cs.surface),
            foregroundColor: (primary || danger) ? Colors.white : cs.onSurface,
            side: (primary || danger)
                ? null
                : const BorderSide(color: Colors.black, width: 1.5),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ).copyWith(
            // Design spec: feedback lands on pointer-down and is strong enough for
            // sunlight. Overlay darkens the fill instantly; nothing animates layout.
            overlayColor: WidgetStateProperty.resolveWith(
              (s) => danger
                  ? const Color(0xCC000000)
                  : (primary
                        ? const Color(0xCC000000)
                        : const Color(0x1A000000)),
            ),
          ),
      child: child,
    );
  }
}

/// Small color dot for team differentiation (blue = A, red = B).
class TeamDot extends StatelessWidget {
  final int colorValue;
  final double size;
  const TeamDot(this.colorValue, {this.size = 12, super.key});
  @override
  Widget build(BuildContext context) {
    final team = colorValue == MatchStore.teamAColor ? 'Team A' : 'Team B';
    return Semantics(
      label: '$team color',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color(colorValue),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black26, width: 1),
        ),
      ),
    );
  }
}

/// − value + stepper.
class StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final String? hint;
  const StepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.hint,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (hint != null)
                Text(
                  hint!,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          tooltip: label.isEmpty ? 'Decrease' : 'Decrease $label',
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 40,
          // ScaleDown: the stepper keeps its rhythm at a 2x system text size
          // instead of letting a two-digit value overflow a 40dp box.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          tooltip: label.isEmpty ? 'Increase' : 'Increase $label',
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// Vibrant glare-proof ball badges. Solid fills only — no borders.
/// Ordered by impact: W > 6 > 4 > extras > routine > dot.
class BallBadge extends StatelessWidget {
  final Ball ball;
  const BallBadge(this.ball, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = ball.badge;
    late Color bg;
    late Color fg;
    final isWicketBadge = t == 'W' || RegExp(r'^W\+\d+$').hasMatch(t);
    if (isWicketBadge) {
      bg = const Color(0xFFDC143C); // crimson
      fg = Colors.white;
    } else if (t == '6' || t.startsWith('N6')) {
      bg = const Color(0xFFEC008C); // hyper magenta
      fg = Colors.white;
    } else if (t == '4' || t.startsWith('N4')) {
      bg = const Color(0xFF15803D); // deep green, white numeral
      fg = Colors.white;
    } else if (t.startsWith('N') || t == 'NB') {
      bg = const Color(0xFF7B2CBF);
      fg = Colors.white;
    } else if (t.startsWith('WD')) {
      bg = const Color(0xFFFFBA08);
      fg = Colors.black;
    } else if (t.startsWith('B') || t.startsWith('LB')) {
      bg = const Color(0xFF00B4D8);
      fg = Colors.black;
    } else if (t == '0') {
      bg = const Color(0xFF131316); // carbon black
      fg = Colors.white;
    } else if (t == '1') {
      bg = const Color(0xFFA5F3FC); // light cyan
      fg = Colors.black;
    } else if (t == '2') {
      bg = const Color(0xFF22D3EE); // cyan
      fg = Colors.black;
    } else if (t == '3') {
      bg = const Color(0xFF0E7490); // deep cyan
      fg = Colors.white;
    } else {
      bg = const Color(0xFF334155);
      fg = Colors.white;
    }
    // Every badge identical — no borders, glow, scale or markers.
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        t,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w900,
          // W+2 style badges get a smaller numeral to hold the circle.
          fontSize: t.length > 2 ? 10 : 12,
        ),
      ),
    );
  }
}

/// Big rapid-input key (72px) with strong borders for glare.
class KeyBtn extends StatelessWidget {
  final String label;
  final String sub;
  final VoidCallback? onTap;
  final Color? color;
  final Color? fg;
  final bool armed;
  final double radius;
  const KeyBtn({
    required this.label,
    required this.sub,
    required this.onTap,
    this.color,
    this.fg,
    this.armed = false,
    this.radius = 14,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    final bg = armed ? const Color(0xFFFFBA08) : color;
    final onFg = armed ? Colors.black : fg;
    return SizedBox(
      height: 72,
      child: FilledButton(
        onPressed: onTap,
        style:
            FilledButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: onFg,
              padding: EdgeInsets.zero,
              side: const BorderSide(color: Colors.black38, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ).copyWith(
              // Instant, high-contrast press state. A ripple is invisible in
              // direct sun; the fill visibly darkens the moment the finger lands.
              overlayColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.pressed)
                    ? const Color(0x40000000)
                    : const Color(0x00000000),
              ),
            ),
        // Fitted, not clipped: the 72dp key cannot grow (the grid is fixed),
        // so at a 2x system text size the label scales down instead of
        // overflowing the button with stripes.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centers content with a max width for responsive phone/desktop layouts.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsiveCenter({required this.child, this.maxWidth = 560, super.key});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// One-shot route guard: pushes [dest] exactly once — repeated rebuilds
/// (undo, celebration frames, stream ticks) can never queue duplicate
/// navigations, which was the post-innings flashing bug.
/// All app transitions are instant (see [_NoTransition] in theme.dart),
/// so no slide ever runs against in-flight celebrations or strip motion.
void goOnce(BuildContext context, String dest) {
  if (ModalRoute.of(context)?.settings.name == dest) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    if (ModalRoute.of(context)?.settings.name == dest) return;
    Navigator.pushReplacementNamed(context, dest);
  });
}

/// One-shot numeral-only celebration on boundary/wicket.
/// Layout-frozen primitives only: Transform, Opacity, ShaderMask,
/// text color/shadow, Positioned overlays. Nothing here may change size.
class Celebrate extends StatefulWidget {
  final String mode; // off/pop/flash/glow/shake/blink/glitch/crt/slowmo
  final String valueKey; // score string — change re-fires
  final bool fire; // true when last ball deserves it
  final Color tint; // event color (boundary tint / wicket red)
  final String text;
  final TextStyle style;
  const Celebrate({
    required this.mode,
    required this.valueKey,
    required this.fire,
    required this.tint,
    required this.text,
    required this.style,
    super.key,
  });
  @override
  State<Celebrate> createState() => _CelebrateState();
}

class _CelebrateState extends State<Celebrate>
    with SingleTickerProviderStateMixin {
  // Created eagerly in initState, NOT as a lazy `late final`. With mode 'off'
  // the build path returns before touching the controller, so a lazy field was
  // first *created* inside dispose() — and creating a ticker there looks up
  // TickerMode on an already-deactivated element, which throws. Selecting the
  // "Off" celebration and then navigating away hit exactly that.
  late final AnimationController _c;
  String _last = '';

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: Motion.celebrate);
    _last = widget.valueKey;
  }

  @override
  void didUpdateWidget(Celebrate old) {
    super.didUpdateWidget(old);
    if (widget.valueKey != _last) {
      _last = widget.valueKey;
      if (widget.fire && widget.mode != 'off') _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Text _text(Color color, {List<Shadow>? shadows}) => Text(
    widget.text,
    style: widget.style.copyWith(color: color, shadows: shadows),
  );

  @override
  Widget build(BuildContext context) {
    final base = widget.style.color ?? Colors.black;
    // Reduced motion: static numerals, zero animation.
    if (widget.mode == 'off' ||
        !widget.fire ||
        MediaQuery.disableAnimationsOf(context)) {
      return _text(base);
    }
    final tint = widget.tint;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = Curves.easeOutCubic.transform(_c.value);
        switch (widget.mode) {
          case 'glitch': // chromatic-aberration snap, numerals never move
            final g = sin(t * 3.14159) * 4 * (1 - t * 0.3);
            return _text(
              base,
              shadows: [
                Shadow(
                  color: const Color(0xFFFF004C)
                      .withValues(alpha: 0.9 * (1 - t)),
                  offset: Offset(-g, 0),
                  blurRadius: 0,
                ),
                Shadow(
                  color: const Color(0xFF00E5FF)
                      .withValues(alpha: 0.9 * (1 - t)),
                  offset: Offset(g, 0),
                  blurRadius: 0,
                ),
              ],
            );
          case 'crt': // faint CRT refresh flicker, settles clean
            final f = 0.9 + 0.1 * sin(t * 55);
            return Opacity(opacity: t > 0.9 ? 1.0 : f, child: _text(base));
          case 'slowmo': // long swell to 1.15x, eases back exactly
            return Transform.scale(
              scale: 1 + 0.15 * sin(t * 3.14159),
              child: _text(base),
            );
          case 'rise': // retired — falls to pop
          case 'flash': // numerals tint to event color, ease back
            final k = t < 0.35 ? t / 0.35 : 1 - (t - 0.35) / 0.65;
            return _text(Color.lerp(base, tint, k.clamp(0.0, 1.0))!);
          case 'glow': // soft bloom behind numerals, decays
            return _text(
              base,
              shadows: [
                Shadow(
                  color: tint.withValues(alpha: 0.85 * (1 - t)),
                  blurRadius: 28 * (1 - t) + 2,
                ),
                Shadow(
                  color: tint.withValues(alpha: 0.5 * (1 - t)),
                  blurRadius: 60 * (1 - t) + 4,
                ),
              ],
            );
          case 'roll': // retired — falls to pop
          case 'shake': // tiny decaying shiver, tile stays put
            final d = (1 - t) * 3 * sin(t * 24);
            return Transform.translate(
              offset: Offset(d, 0),
              child: _text(base),
            );
          case 'blink': // two quick scoreboard dips
            final o = (t * 4) % 2 < 1 ? 0.35 : 1.0;
            return Opacity(opacity: t > 0.85 ? 1.0 : o, child: _text(base));
          case 'sweep': // retired — falls to glow
          case 'ring': // retired (sized layout) — falls to glow
          case 'burst': // retired — falls to rise
          default: // pop — single gentle bump, settles exactly at 1x
            return Transform.scale(
              scale: 1 + 0.07 * sin(t * 3.14159),
              child: _text(base),
            );
        }
      },
    );
  }
}

/// The single name-picker row: name on the left, selection affordance on the
/// right. Every picker that offers a person uses this, so a name is never a
/// pill and every list scans the same way.
class PlayerRow extends StatelessWidget {
  final String name;

  /// Secondary line under the name (role, style, figures). Null hides it.
  final String? subtitle;

  /// True when this row is the chosen one — renders the filled indicator.
  final bool selected;

  /// Tapping does nothing and the row is dimmed (XI full, just bowled, …).
  final bool enabled;

  /// Why the row is disabled. Shown in the subtitle when there is no other
  /// subtitle, so a dimmed row always explains itself.
  final String? blockedReason;

  /// Trailing widget replaces the default indicator (e.g. a "+" affordance).
  final Widget? trailing;

  final VoidCallback? onTap;

  const PlayerRow({
    super.key,
    required this.name,
    this.subtitle,
    this.selected = false,
    this.enabled = true,
    this.blockedReason,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dim = !enabled;
    final sub = subtitle ?? blockedReason;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        // 48dp minimum: a name row is a target, not a line of text.
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          // Selection is a filled slab, not a tint: readable in sunlight.
          color: selected ? const Color(0xFF131316) : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: dim
                          ? cs.onSurface.withValues(alpha: 0.45)
                          : (selected ? Colors.white : cs.onSurface),
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? Colors.white70
                            : cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected
                    ? const Color(0xFF22C55E)
                    : cs.onSurface.withValues(alpha: dim ? 0.25 : 0.5),
              ),
          ],
        ),
      ),
    );
  }
}

/// Detail row — the shared "person" line format across the app.
///
/// Bold name with a quiet subtitle on the left, a small caps label over a bold
/// value on the right, hairline separator beneath. Club roster, setup squads
/// and the scorecard all use it, so the same person is never drawn two ways.
class DetailRow extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Small caps caption above the value (e.g. "MATCHES", "ECON").
  final String? valueLabel;

  /// The number itself. Tabular figures so live values do not jitter.
  final String? value;

  /// Trailing affordance (check, chevron, arrow).
  final Widget? trailing;

  final VoidCallback? onTap;
  final bool enabled;

  /// Dims the row and blocks the tap (XI full, already picked elsewhere).
  final bool dimmed;

  const DetailRow({
    super.key,
    required this.title,
    this.subtitle,
    this.valueLabel,
    this.value,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ink = dimmed ? cs.onSurface.withValues(alpha: 0.4) : cs.onSurface;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: ink.withValues(alpha: 0.65),
                      ),
                    ),
                ],
              ),
            ),
            if (valueLabel != null || value != null) ...[
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (valueLabel != null)
                    Text(
                      valueLabel!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: ink.withValues(alpha: 0.6),
                      ),
                    ),
                  if (value != null)
                    Text(
                      value!,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// The one empty state. A screen with nothing in it is a normal state, not an
/// error: say what belongs here, how it gets here, and never leave the user
/// looking at a single grey line in dead centre.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  /// Tighter rhythm for an empty region inside a card (a squad pool), rather
  /// than a whole empty screen.
  final bool compact;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 24,
        vertical: compact ? 12 : 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 28 : 44,
            color: cs.onSurface.withValues(alpha: 0.4),
          ),
          SizedBox(height: compact ? 6 : 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              fontSize: compact ? 11 : 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Heading above a group of rows.
///
/// The plain form was 11px/w900 directly above 14px/w800 player names — the
/// heading was SMALLER than the content it introduced and one weight step
/// apart, so a picker read as one flat list of names. [color] turns it into a
/// filled band, which separates the group by size, weight AND colour at once
/// (colour alone fails the sunlight rule).
class RowSectionLabel extends StatelessWidget {
  final String text;
  final Color? color;

  /// Render as a filled band with white text rather than a plain caption.
  final bool filled;
  const RowSectionLabel(
    this.text, {
    super.key,
    this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 11,
        letterSpacing: 1.2,
        color: filled
            ? Colors.white
            : (color ?? Theme.of(context).colorScheme.onSurface),
      ),
    );
    if (!filled) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2, left: 10),
        child: label,
      );
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: color ?? Theme.of(context).colorScheme.primary,
      child: label,
    );
  }
}

/// One-line bowler summary for use as a row subtitle.
///
/// Spelled out rather than `2.4-0-26-1`: that string needs a legend, and a
/// umpire reading it mid-over should not have to remember which position is
/// which. The penalty runs are named as being INCLUDED, because they are
/// inside the runs total (Law 41.14) and showing them separately without
/// saying so reads as double counting.
String bowlerFigureLine(BowlingCard c) {
  if (!c.bowledAny) return 'Yet to bowl';
  final parts = <String>[
    '${c.oversDisplay} ov',
    '${c.runsConceded} runs',
    if (c.wickets > 0) '${c.wickets} ${c.wickets == 1 ? 'wicket' : 'wickets'}',
    if (c.maidens > 0) '${c.maidens} ${c.maidens == 1 ? 'maiden' : 'maidens'}',
  ];
  final extras = <String>[];
  if (c.wides > 0) extras.add('${c.wides} wd');
  if (c.noBalls > 0) extras.add('${c.noBalls} nb');
  if (extras.isNotEmpty) parts.add('incl ${extras.join(', ')}');
  return parts.join(' • ');
}

/// Right-hand figure cluster: overs and economy as two labelled readouts.
class BowlerFigureBlock extends StatelessWidget {
  final BowlingCard c;
  final bool compact;
  const BowlerFigureBlock(this.c, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              c.oversDisplay,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: compact ? 13 : 15,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'OV',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_down, size: 11, color: Color(0xFFF59E0B)),
            const SizedBox(width: 2),
            Text(
              fmt2(c.economy),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: Color(0xFFF59E0B),
              ),
            ),
            Text(
              ' ECON',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Full bowling card, shown after the match: every figure named, nothing
/// encoded. Extras stay broken out under the runs they are already inside.
class BowlingFiguresPanel extends StatelessWidget {
  final BowlingCard c;
  const BowlingFiguresPanel(this.c, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget cell(String label, String value, {Color? color, bool big = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: big ? 16 : 13,
                color: color ?? cs.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    final extras = <String>[];
    if (c.wides > 0) extras.add('${c.wides} wd');
    if (c.noBalls > 0) extras.add('${c.noBalls} nb');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        cell('Overs', c.oversDisplay, big: true),
        cell('Runs given', '${c.runsConceded}'),
        cell(
          'Wickets',
          '${c.wickets}',
          color: c.wickets > 0 ? const Color(0xFF22C55E) : null,
        ),
        cell('Maidens', '${c.maidens}'),
        cell('Average', fmt2(c.average)),
        cell('Economy', fmt2(c.economy)),
        cell('Strike rate', fmt2(c.strikeRate)),
        cell('Wides', '${c.wides}'),
        cell('No balls', '${c.noBalls}'),
        if (extras.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Runs given already includes ${extras.join(' and ')}',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
      ],
    );
  }
}

/// Two-decimal stat with an em-dash for "not applicable" (0 wickets, no overs).
String fmt2(double? v) => v == null ? '—' : v.toStringAsFixed(2);

/// Rounded team pill — the innings switcher on the scorecard.
///
/// The selected side is a SOLID slab in the team's colour (sunlight-legible,
/// no tint), the other is an outline. One tap switches which innings the card
/// shows; the card never shows both innings' players at once.
class TeamPill extends StatelessWidget {
  final String label;
  final String figure;
  final bool selected;
  final int colorValue;
  final VoidCallback? onTap;
  final bool enabled;

  const TeamPill({
    super.key,
    required this.label,
    required this.figure,
    required this.selected,
    required this.colorValue,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final team = Color(colorValue);
    final on = selected ? Colors.white : cs.onSurface;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? team : Colors.transparent,
            border: Border.all(
              color: selected ? team : cs.onSurface.withValues(alpha: 0.35),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              TeamDot(selected ? 0xFFFFFFFF : colorValue, size: 10),
              const SizedBox(width: 8),
              // The name gives way first, the score never gets cut: a pill
              // that says "302-9 (5…" is worse than one that says "EAG…".
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: on,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    figure,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: selected ? Colors.white : cs.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circle with the player's initials.
///
/// There are no player photos in this app, so the avatar is a solid team-colour
/// disc with white initials: it reads as a portrait slot without pretending to
/// be a picture, and it survives direct sunlight.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final int colorValue;
  final double size;
  const InitialsAvatar(
    this.name, {
    super.key,
    required this.colorValue,
    this.size = 26,
  });

  static String initialsOf(String n) {
    final parts = n.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(colorValue),
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.38,
          height: 1,
        ),
      ),
    );
  }
}

/// Underlined tab strip — the switch between the scorecard and the summary.
///
/// An underline, not a pill: the tab reads as a heading, the underline says
/// which one is open, and nothing moves when the selection changes.
class UnderlineTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  const UnderlineTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1,
                        color: i == selected
                            ? cs.onSurface
                            : cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 2.5,
                      color: i == selected ? cs.onSurface : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
