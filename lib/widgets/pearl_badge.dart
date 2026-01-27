import 'package:flutter/material.dart';

/// Small rounded chip that displays a pearls count.
/// Self-contained — no imports of state or pages.
class PearlBadge extends StatelessWidget {
  final int pearls;
  final bool emphasized; // use true for headers, false elsewhere
  const PearlBadge({super.key, required this.pearls, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final bg = emphasized ? c.primary.withValues(alpha: .12) : c.surfaceContainerHighest.withValues(alpha: .5);
    final border = emphasized ? c.primary : c.outlineVariant;
    final text = emphasized ? c.primary : c.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'lib/assets/pearl.png',
            width: 16,
            height: 16,
          ),
          const SizedBox(width: 6),
          Text('$pearls', style: TextStyle(fontWeight: FontWeight.w900, color: text)),
          const SizedBox(width: 6),
          Text('لآلئ', style: TextStyle(color: text.withValues(alpha: .75))),
        ],
      ),
    );
  }
}


//lib/widgets/pearl_badge.dart
