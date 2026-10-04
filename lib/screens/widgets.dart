import 'package:flutter/material.dart';
import 'dart:math' show sin;
import '../models.dart';
import '../store.dart';
import '../theme.dart';

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
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: danger
            ? cs.error
            : (primary ? const Color(0xFF131316) : cs.surface),
        foregroundColor: (primary || danger) ? Colors.white : cs.onSurface,
        side: (primary || danger)
            ? null
            : const BorderSide(color: Colors.black, width: 1.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
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
                Text(hint!,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 40,
          child: Text('$value',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        ),
        IconButton.filledTonal(
          onPressed: value < max ? () => onChanged(value + 1) : null,
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
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(t,
          style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              // W+2 style badges get a smaller numeral to hold the circle.
              fontSize: t.length > 2 ? 10 : 12)),
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
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: onFg,
          padding: EdgeInsets.zero,
          side: const BorderSide(color: Colors.black38, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900, height: 1)),
            Text(sub,
                style:
                    const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
          ],
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

  Text _text(Color color, {List<Shadow>? shadows}) => Text(widget.text,
      style: widget.style.copyWith(color: color, shadows: shadows));

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
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(_c.value);
        switch (widget.mode) {
          case 'glitch': // chromatic-aberration snap, numerals never move
            final g = sin(t * 3.14159) * 4 * (1 - t * 0.3);
            return _text(base, shadows: [
              Shadow(
                  color:
                      const Color(0xFFFF004C).withValues(alpha: 0.9 * (1 - t)),
                  offset: Offset(-g, 0),
                  blurRadius: 0),
              Shadow(
                  color:
                      const Color(0xFF00E5FF).withValues(alpha: 0.9 * (1 - t)),
                  offset: Offset(g, 0),
                  blurRadius: 0),
            ]);
          case 'crt': // faint CRT refresh flicker, settles clean
            final f = 0.9 + 0.1 * sin(t * 55);
            return Opacity(opacity: t > 0.9 ? 1.0 : f, child: _text(base));
          case 'slowmo': // long swell to 1.15x, eases back exactly
            return Transform.scale(
                scale: 1 + 0.15 * sin(t * 3.14159), child: _text(base));
          case 'rise': // retired — falls to pop
          case 'flash': // numerals tint to event color, ease back
            final k = t < 0.35 ? t / 0.35 : 1 - (t - 0.35) / 0.65;
            return _text(Color.lerp(base, tint, k.clamp(0.0, 1.0))!);
          case 'glow': // soft bloom behind numerals, decays
            return _text(base, shadows: [
              Shadow(
                  color: tint.withValues(alpha: 0.85 * (1 - t)),
                  blurRadius: 28 * (1 - t) + 2),
              Shadow(
                  color: tint.withValues(alpha: 0.5 * (1 - t)),
                  blurRadius: 60 * (1 - t) + 4),
            ]);
          case 'roll': // retired — falls to pop
          case 'shake': // tiny decaying shiver, tile stays put
            final d = (1 - t) * 3 * sin(t * 24);
            return Transform.translate(
                offset: Offset(d, 0), child: _text(base));
          case 'blink': // two quick scoreboard dips
            final o = (t * 4) % 2 < 1 ? 0.35 : 1.0;
            return Opacity(opacity: t > 0.85 ? 1.0 : o, child: _text(base));
          case 'sweep': // retired — falls to glow
          case 'ring': // retired (sized layout) — falls to glow
          case 'burst': // retired — falls to rise
          default: // pop — single gentle bump, settles exactly at 1x
            return Transform.scale(
                scale: 1 + 0.07 * sin(t * 3.14159), child: _text(base));
        }
      },
    );
  }
}
