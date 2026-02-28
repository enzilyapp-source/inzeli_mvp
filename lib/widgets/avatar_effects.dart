// lib/widgets/avatar_effects.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class AvatarEffect extends StatefulWidget {
  final Widget child;
  final AvatarEffectType effect;
  final double size;
  final Duration duration;
  final bool animate;

  const AvatarEffect({
    super.key,
    required this.child,
    required this.effect,
    this.size = 96,
    this.duration = const Duration(milliseconds: 2400),
    this.animate = true,
  });

  @override
  State<AvatarEffect> createState() => _AvatarEffectState();
}

class _AvatarEffectState extends State<AvatarEffect> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    if (widget.animate) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant AvatarEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.animate && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                painter: _AuraPainter(
                  effect: widget.effect,
                  progress: widget.animate ? _ctrl.value : 1.0,
                ),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: widget.size * 0.68,
              height: widget.size * 0.68,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

enum AvatarEffectType {
  blueThunder,
  goldLightning,
  kuwaitSparkles,
  greenLeaf,
  flameBlue,
  whiteSparkle,
}

class _AuraPainter extends CustomPainter {
  final AvatarEffectType effect;
  final double progress; // 0..1
  _AuraPainter({required this.effect, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    switch (effect) {
      case AvatarEffectType.blueThunder:
        _paintFlame(canvas, size, const Color(0xFF6EC6FF), const Color(0xFF0D47A1));
        break;
      case AvatarEffectType.goldLightning:
        _paintLightning(canvas, size, const Color(0xFFFFE082), const Color(0xFFFFC107));
        break;
      case AvatarEffectType.kuwaitSparkles:
        _paintFlagRing(canvas, size, const [
          Color(0xFFe53935),
          Color(0xFF000000),
          Color(0xFFFFFFFF),
          Color(0xFF1b5e20),
        ]);
        break;
      case AvatarEffectType.greenLeaf:
        _paintLeaves(canvas, size, const Color(0xFF66BB6A), const Color(0xFF2E7D32));
        break;
      case AvatarEffectType.flameBlue:
        _paintFlame(canvas, size, const Color(0xFF64B5F6), const Color(0xFF0D47A1));
        break;
      case AvatarEffectType.whiteSparkle:
        _paintSparkles(canvas, size, const [Colors.white]);
        break;
    }
  }

  void _paintFlame(Canvas canvas, Size size, Color outer, Color inner) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final spikes = 42;
    final path = Path();
    for (int i = 0; i <= spikes; i++) {
      final t = i / spikes;
      final angle = 2 * math.pi * t;
      final flicker = math.sin(angle * 6 + progress * 2 * math.pi) * 0.12;
      final r = radius * (0.72 + 0.18 * (1 + flicker));
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final flamePaint = Paint()
      ..shader = RadialGradient(
        colors: [outer.withValues(alpha: 0.9), inner.withValues(alpha: 0.35), Colors.transparent],
        stops: const [0.55, 0.8, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, flamePaint);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.18
      ..color = outer.withValues(alpha: 0.35);
    canvas.drawCircle(center, radius * 0.55, glow);
  }

  void _paintLightning(Canvas canvas, Size size, Color glow, Color bolt) {
    _paintFlame(canvas, size, glow, bolt);
  }

  void _paintSparkles(Canvas canvas, Size size, List<Color> colors) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final sparkles = 36;
    final maxR = radius * 0.9;

    for (int i = 0; i < sparkles; i++) {
      final color = colors[i % colors.length];
      final angle = (2 * math.pi / sparkles) * i + progress * math.pi * 2.2;
      final dist = radius * 0.35 + (progress * maxR * 0.7);
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final fade = (1 - progress) * 0.6 + 0.2;
      final paint = Paint()..color = color.withValues(alpha: fade);
      final dotR = (1.5 + (i % 3)) * (1 - progress * 0.4);
      canvas.drawCircle(pos, dotR, paint);
    }
  }

  void _paintFlagRing(Canvas canvas, Size size, List<Color> colors) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2.05;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.14;

    final seg = 2 * math.pi / colors.length;
    for (int i = 0; i < colors.length; i++) {
      ringPaint.color = colors[i].withValues(alpha: 0.9);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.78),
        -math.pi / 2 + seg * i,
        seg,
        false,
        ringPaint,
      );
    }

    _paintSparkles(canvas, size, colors);
  }

  void _paintLeaves(Canvas canvas, Size size, Color light, Color dark) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final leaves = 18;
    final spin = progress * 2 * math.pi; // دوران مستمر
    final sway = math.sin(progress * 2 * math.pi) * 0.18; // تمايل بسيط

    for (int i = 0; i < leaves; i++) {
      final t = i / leaves;
      final angle = t * 2 * math.pi + spin;
      final baseR = radius * (0.58 + 0.08 * math.sin(spin + i));
      final start = center + Offset(math.cos(angle), math.sin(angle)) * (radius * 0.42);
      final end = center + Offset(math.cos(angle + sway), math.sin(angle + sway)) * baseR;

      // شكل ورقة إهليلجي صغير عند النهاية
      final leafPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [
            light.withValues(alpha: 0.95),
            dark.withValues(alpha: 0.75),
            dark.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: end, radius: radius * 0.12));

      // ساق الورقة
      final stemPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.018
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [dark.withValues(alpha: 0.7), light.withValues(alpha: 0.8)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      final ctrl1 = Offset.lerp(start, end, 0.35)! +
          Offset(-math.sin(angle), math.cos(angle)) * radius * 0.08;
      final ctrl2 = Offset.lerp(start, end, 0.65)! +
          Offset(math.sin(angle), -math.cos(angle)) * radius * 0.1;

      final stem = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, end.dx, end.dy);
      canvas.drawPath(stem, stemPaint);

      // ورقة عند الطرف
      canvas.drawOval(
        Rect.fromCenter(center: end, width: radius * 0.18, height: radius * 0.3),
        leafPaint,
      );
    }

    // هالة خضراء خفيفة حول الصورة
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.18
      ..color = light.withValues(alpha: 0.16);
    canvas.drawCircle(center, radius * 0.62, halo);
  }

  @override
  bool shouldRepaint(covariant _AuraPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.effect != effect;
  }
}
