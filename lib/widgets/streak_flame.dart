import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Simple “on fire” badge for streaks (uses 🔥 + wobble/pulse)
class StreakFlame extends StatefulWidget {
  final int streak;          // consecutive wins
  final bool compact;        // small in chips, large in profile
  const StreakFlame({super.key, required this.streak, this.compact = false});

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streak <= 1) return const SizedBox.shrink();
    final size = widget.compact ? 14.0 : 18.0;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value; // 0..1
        final wobble = math.sin(t * math.pi * 2) * 0.06;
        final scale = 1 + (widget.compact ? 0.05 : 0.1) * (0.5 + 0.5 * math.sin(t * math.pi * 2));
        return Transform.rotate(
          angle: wobble,
          child: Transform.scale(
            scale: scale,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🔥', style: TextStyle(fontSize: size)),
                const SizedBox(width: 4),
                Text('x${widget.streak}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: widget.compact ? 11 : 13,
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}
