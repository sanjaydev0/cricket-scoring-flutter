import 'package:flutter/material.dart';
import '../models.dart';

class BallBadge extends StatelessWidget {
  final Ball ball;
  final bool isLatest;
  const BallBadge(this.ball, {this.isLatest = false, super.key});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg = Colors.white;
    final t = ball.badge;
    if (t == 'W') {
      bg = const Color(0xFFE11D48);
    } else if (t == '4') {
      bg = const Color(0xFF059669);
    } else if (t == '6') {
      bg = const Color(0xFF4F46E5);
    } else if (t.startsWith('WD') || t.startsWith('N') || t == 'NB') {
      bg = const Color(0xFFF59E0B);
      fg = Colors.black;
    } else if (t.startsWith('B') || t.startsWith('LB')) {
      bg = Colors.teal;
    } else if (t == '0') {
      bg = Colors.grey.shade400;
      fg = Colors.black87;
    } else {
      bg = Theme.of(context).colorScheme.primary;
      fg = Theme.of(context).colorScheme.onPrimary;
    }
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: isLatest ? Border.all(color: fg, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(t,
          style: TextStyle(
              color: fg, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }
}

class KeyBtn extends StatelessWidget {
  final String label;
  final String sub;
  final VoidCallback onTap;
  final Color? color;
  final Color? fg;
  final bool armed;
  const KeyBtn(
      {required this.label,
      required this.sub,
      required this.onTap,
      this.color,
      this.fg,
      this.armed = false,
      super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: armed
              ? Colors.amber
              : (color ?? Theme.of(context).colorScheme.surfaceContainerHighest),
          foregroundColor: armed
              ? Colors.black
              : (fg ?? Theme.of(context).colorScheme.onSurface),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: EdgeInsets.zero,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(sub,
                style: const TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
