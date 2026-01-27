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
        ? cs.primary.withValues(alpha: .12)
        : cs.surfaceContainerHighest.withValues(alpha: .4);

    final border = selected
        ? cs.primary
        : cs.onSurface.withValues(alpha: .25);

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
              Image.asset(
                'lib/assets/pearl.png',
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 8),
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
                  color: textColor.withValues(alpha: .75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//lib/widgests/pearl_chip.dart
