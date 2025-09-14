import 'dart:math' as math;
import 'package:flutter/material.dart';

class GameRing extends StatelessWidget {
  /// If null, we’ll compute a responsive size from screen width.
  final double? size;
  final double fill01; // 0..1

  const GameRing({
    super.key,
    this.size,
    required this.fill01,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    // Responsive ring size: 36% of screen width on phones, min 90, max 160
    final S = (size ?? (w * 0.36)).clamp(90.0, 160.0);
    // Stroke thickness scales with size
    final stroke = (S * 0.12).clamp(8.0, 16.0);

    return SizedBox(
      width: S,
      height: S,
      child: CustomPaint(
        painter: _RingPainter(fill01: fill01, stroke: stroke),
        child: Center(
          child: Text(
            '${(fill01 * 100).round()}%',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: (S * 0.22).clamp(16, 28), // readable center label
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fill01;
  final double stroke;
  _RingPainter({required this.fill01, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = (size.width / 2) - stroke / 2;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFF3A2A22).withOpacity(0.20);
    canvas.drawCircle(center, r, bg);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFC5533C);

    // 270° arc (nice “gauge” feel)
    final totalSweep = 1.5 * math.pi; // 270°
    final start = -math.pi * 3 / 4;   // -135°
    final sweep = totalSweep * fill01.clamp(0, 1);

    canvas.drawArc(Rect.fromCircle(center: center, radius: r), start, sweep, false, arc);

    // Optional small dot at the start (visual anchor)
    final dotAngle = start;
    final dx = center.dx + r * math.cos(dotAngle);
    final dy = center.dy + r * math.sin(dotAngle);
    canvas.drawCircle(Offset(dx, dy), stroke * 0.22, Paint()..color = const Color(0xFFC5533C));
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fill01 != fill01 || old.stroke != stroke;
}
