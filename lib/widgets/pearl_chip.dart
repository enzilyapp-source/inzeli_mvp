import 'package:flutter/material.dart';

/// كبسولة لؤلؤة بشكل حديث تُستخدم بجانب الاسم أو داخل الكروت.
class PearlChip extends StatelessWidget {
  final int pearls;
  final EdgeInsetsGeometry? padding;
  final double iconSize;
  final TextStyle? textStyle;
  const PearlChip({
    super.key,
    required this.pearls,
    this.padding,
    this.iconSize = 16,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: on.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: on.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // أيقونة لؤلؤة مبسّطة
          Icon(Icons.brightness_5_rounded, size: iconSize),
          const SizedBox(width: 6),
          Text(
            '$pearls',
            style: textStyle ??
                const TextStyle(fontWeight: FontWeight.w900, height: 1.1),
          ),
        ],
      ),
    );
  }
}
