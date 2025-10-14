import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A small hex/coin-style chip that shows a pearl count.
/// Used in ProfilePage milestones row.
class PearlChip extends StatelessWidget {
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  const PearlChip({
    super.key,
    required this.count,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = selected
        ? cs.primary.withOpacity(.12)
        : cs.surfaceVariant.withOpacity(.4);

    final border = selected
        ? cs.primary
        : cs.onSurface.withOpacity(.25);

    final textColor = selected ? cs.primary : cs.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // small hex coin
              SizedBox(
                width: 18,
                height: 18,
                child: CustomPaint(
                  painter: _HexPainter(
                    fill: selected ? cs.primary : cs.onSurface.withOpacity(.6),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                'لؤلؤة',
                style: TextStyle(
                  fontSize: 11,
                  color: textColor.withOpacity(.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  final Color fill;
  _HexPainter({required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(size.width / 2, size.height / 2);

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = (math.pi / 3) * i - math.pi / 2;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    final paint = Paint()..color = fill;
    canvas.drawPath(path, paint);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = fill.withOpacity(.85);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _HexPainter oldDelegate) =>
      oldDelegate.fill != fill;
}
