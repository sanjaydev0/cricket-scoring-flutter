import 'package:flutter/material.dart';
import 'dart:math' show sin;
import '../models.dart';
import '../store.dart';

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
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (hint != null)
                Text(hint!,
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant)),
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
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900)),
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
    if (t == 'W') {
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
              color: fg, fontWeight: FontWeight.w900, fontSize: 12)),
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
                style: const TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800)),
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
  const ResponsiveCenter(
      {required this.child, this.maxWidth = 560, super.key});
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

/// One-shot numeral-only celebration on boundary/wicket.
/// Never changes layout: font size, tile padding and geometry stay fixed.
/// Only the numerals (or a clipped overlay above them) animate.
class Celebrate extends StatefulWidget {
  final String mode; // off/rise/pop/flash/glow/roll/shake/sweep/ring/burst/blink
  final String valueKey; // score string — change re-fires
  final bool fire; // true when last ball deserves it
  final String label; // floating tag: +4 / +6 / W
  final Color tint; // event color (boundary tint / wicket red)
  final String text;
  final TextStyle style;
  const Celebrate({
    required this.mode,
    required this.valueKey,
    required this.fire,
    required this.label,
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
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  String _last = '';

  @override
  void initState() {
    super.initState();
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

  Text _text(Color color, {List<Shadow>? shadows}) =>
      Text(widget.text, style: widget.style.copyWith(color: color, shadows: shadows));

  @override
  Widget build(BuildContext context) {
    final base = widget.style.color ?? Colors.black;
    if (widget.mode == 'off' || !widget.fire) return _text(base);
    final label = widget.label;
    final tint = widget.tint;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(_c.value);
        switch (widget.mode) {
          case 'rise': // floating +4/+6/W tag rises and dissolves
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                _text(base),
                Positioned(
                  top: -8 - t * 44,
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Text(label,
                        style: TextStyle(
                            color: tint,
                            fontSize: 26,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            );
          case 'flash': // numerals tint to event color, ease back
            final k = t < 0.35 ? t / 0.35 : 1 - (t - 0.35) / 0.65;
            return _text(Color.lerp(base, tint, k.clamp(0.0, 1.0))!);
          case 'glow': // soft bloom behind numerals, decays
            return _text(base, shadows: [
              Shadow(color: tint.withValues(alpha: 0.85 * (1 - t)), blurRadius: 28 * (1 - t) + 2),
              Shadow(color: tint.withValues(alpha: 0.5 * (1 - t)), blurRadius: 60 * (1 - t) + 4),
            ]);
          case 'roll': // quick vertical roll into the new number
            return ClipRect(
              child: Transform.translate(
                offset: Offset(0, 26 * (1 - t) * (1 - t)),
                child: Opacity(opacity: 0.25 + 0.75 * t, child: _text(base)),
              ),
            );
          case 'shake': // tiny decaying shiver, tile stays put
            final d = (1 - t) * 4 * sin(t * 28);
            return Transform.translate(offset: Offset(d, 0), child: _text(base));
          case 'sweep': // light band sweeps the numerals once
            return ShaderMask(
              shaderCallback: (r) => LinearGradient(
                colors: [base, Colors.white, base],
                stops: [0.0, (0.15 + t * 0.7).clamp(0.0, 1.0), (0.35 + t * 0.7).clamp(0.0, 1.0)],
              ).createShader(r),
              child: _text(Colors.white),
            );
          case 'ring': // thin ring pings behind numerals, clipped
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 200 + t * 90,
                  height: 84 + t * 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: tint.withValues(alpha: (1 - t) * 0.8),
                        width: 4 * (1 - t) + 1),
                  ),
                ),
                _text(base),
              ],
            );
          case 'burst': // three chips drift out and dissolve
            const offs = [Offset(-46, -30), Offset(0, -52), Offset(46, -30)];
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                _text(base),
                for (var i = 0; i < 3; i++)
                  Positioned(
                    left: offs[i].dx * t,
                    top: 8 + offs[i].dy * t,
                    child: Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: tint,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ),
              ],
            );
          case 'blink': // two quick scoreboard dips
            final o = (t * 4) % 2 < 1 ? 0.35 : 1.0;
            return Opacity(
                opacity: t > 0.85 ? 1.0 : o, child: _text(base));
          default: // pop — single gentle bump, settles exactly at 1x
            return Transform.scale(
                scale: 1 + 0.07 * sin(t * 3.14159),
                child: _text(base));
        }
      },
    );
  }
}
