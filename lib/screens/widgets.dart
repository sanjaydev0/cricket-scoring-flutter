import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
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
        ),
      ),
    );
  }
}

/// − value + stepper (overs, players, penalties).
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: ShadTheme.of(context).textTheme.small),
              if (hint != null)
                Text(hint!,
                    style: ShadTheme.of(context)
                        .textTheme
                        .muted
                        .copyWith(fontSize: 11)),
            ],
          ),
        ),
        ShadButton.outline(
          size: ShadButtonSize.sm,
          onPressed: value > min ? () => onChanged(value - 1) : null,
          child: const Text('−', style: TextStyle(fontSize: 18)),
        ),
        SizedBox(
          width: 44,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        ShadButton.outline(
          size: ShadButtonSize.sm,
          onPressed: value < max ? () => onChanged(value + 1) : null,
          child: const Text('+', style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}

/// Ball badge colors by impact / visual hierarchy:
/// W red (danger) > 6 gold (peak) > 4 emerald (boundary) >
/// extras warm family (NB orange, WD yellow, B/LB teal) >
/// routine runs neutral > dot hollow (least weight).
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
      bg = const Color(0xFFDC2626);
      fg = Colors.white;
    } else if (t == '6' || t.startsWith('N6')) {
      bg = const Color(0xFFF59E0B);
      fg = Colors.black;
    } else if (t == '4' || t.startsWith('N4')) {
      bg = const Color(0xFF059669);
      fg = Colors.white;
    } else if (t.startsWith('N') || t == 'NB') {
      bg = const Color(0xFFEA580C);
      fg = Colors.white;
    } else if (t.startsWith('WD')) {
      bg = const Color(0xFFEAB308);
      fg = Colors.black;
    } else if (t.startsWith('B') || t.startsWith('LB')) {
      bg = const Color(0xFF14B8A6);
      fg = Colors.black;
    } else if (t == '0') {
      hollow = true;
      bg = Colors.transparent;
      fg = Colors.grey;
    } else {
      final dark = Theme.of(context).brightness == Brightness.dark;
      bg = dark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7);
      fg = dark ? Colors.white : Colors.black;
    }
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: hollow ? Colors.transparent : bg,
        shape: BoxShape.circle,
        border: Border.all(
            color: hollow ? Colors.grey : (isLatest ? fg : Colors.transparent),
            width: isLatest ? 2.5 : 1.2),
      ),
      alignment: Alignment.center,
      child: Text(t,
          style: TextStyle(
              color: hollow ? Colors.grey.shade600 : fg,
              fontWeight: FontWeight.w900,
              fontSize: 12)),
    );
  }
}

/// Big tactile scoring key (70px) in shadcn button styling.
class KeyBtn extends StatelessWidget {
  final String label;
  final String sub;
  final VoidCallback? onTap;
  final Color? color;
  final Color? fg;
  final bool armed;
  const KeyBtn({
    required this.label,
    required this.sub,
    required this.onTap,
    this.color,
    this.fg,
    this.armed = false,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    final bg = armed ? const Color(0xFFEAB308) : color;
    return SizedBox(
      height: 70,
      child: ShadButton(
        backgroundColor: bg,
        foregroundColor: armed ? Colors.black : fg,
        onPressed: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900)),
            Text(sub,
                style:
                    const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
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
