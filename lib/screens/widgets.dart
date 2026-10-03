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

/// Vibrant glare-proof ball badges. Saturated solid fills, bolddark/light
/// text, ordered by impact: W > 6 > 4 > extras > routine > dot.
class BallBadge extends StatelessWidget {
  final Ball ball;
  final bool isLatest;
  const BallBadge(this.ball, {this.isLatest = false, super.key});

  @override
  Widget build(BuildContext context) {
    final t = ball.badge;
    late Color bg;
    late Color fg;
    bool hollow = false;
    if (t == 'W') {
      bg = const Color(0xFFE5383B);
      fg = Colors.white;
    } else if (t == '6' || t.startsWith('N6')) {
      bg = const Color(0xFFF48C06);
      fg = Colors.black;
    } else if (t == '4' || t.startsWith('N4')) {
      bg = const Color(0xFF2DC653);
      fg = Colors.black;
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
      hollow = true;
      bg = Colors.transparent;
      fg = Colors.grey;
    } else {
      bg = const Color(0xFF334155);
      fg = Colors.white;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: hollow ? Colors.transparent : bg,
        shape: BoxShape.circle,
        border: Border.all(
            color: hollow
                ? const Color(0xFF64748B)
                : (isLatest ? Colors.black : bg),
            width: isLatest ? 3 : 2),
      ),
      alignment: Alignment.center,
      child: Text(t,
          style: TextStyle(
              color: hollow ? const Color(0xFF64748B) : fg,
              fontWeight: FontWeight.w900,
              fontSize: 12)),
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

/// One-shot hero celebration on boundary/wicket. Single 700ms run,
/// ease-out, never loops, never blocks input.
class Celebrate extends StatefulWidget {
  final String mode; // off/pulse/glow/shimmer
  final String valueKey; // changes per ball
  final bool fire; // true when last ball deserves it
  final Color accent;
  final Widget child;
  const Celebrate({
    required this.mode,
    required this.valueKey,
    required this.fire,
    required this.accent,
    required this.child,
    super.key,
  });
  @override
  State<Celebrate> createState() => _CelebrateState();
}

class _CelebrateState extends State<Celebrate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  String _last = '';

  @override
  void didUpdateWidget(Celebrate old) {
    super.didUpdateWidget(old);
    if (widget.valueKey != _last) {
      _last = widget.valueKey;
      if (widget.fire && widget.mode != 'off') {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _last = widget.valueKey;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == 'off' || !widget.fire) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(_c.value);
        switch (widget.mode) {
          case 'glow':
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 220 + t * 130,
                  height: 110 + t * 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: widget.accent
                            .withValues(alpha: (1 - t) * 0.9),
                        width: 5 * (1 - t) + 1),
                  ),
                ),
                widget.child,
              ],
            );
          case 'shimmer':
            return ShaderMask(
              shaderCallback: (r) => LinearGradient(
                colors: [
                  widget.accent,
                  Colors.white,
                  widget.accent,
                ],
                stops: [0.0, 0.2 + t * 0.6, 0.4 + t * 0.6],
              ).createShader(r),
              child: widget.child,
            );
          default: // pulse — single gentle bump, settles exactly at 1x
            return Transform.scale(
                scale: 1 + 0.08 * sin(t * 3.14159),
                child: widget.child);
        }
      },
    );
  }
}
