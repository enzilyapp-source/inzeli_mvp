import 'package:flutter/material.dart';

/// شارة "على نارك" تظهر عند سلسلة انتصارات متتالية.
class FireBadge extends StatelessWidget {
  final int streak; // كم فوز متتالي
  const FireBadge({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    if (streak < 3) return const SizedBox.shrink(); // تظهر من 3 وفوق
    final on = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC371), Color(0xFFFF5F6D)],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            'على نارك ×$streak',
            style: TextStyle(
              color: on.computeLuminance() > 0.5 ? Colors.black : Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
