import 'package:flutter/material.dart';

class GradientHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final List<Color>? colors;
  const GradientHeader({
    super.key,
    required this.title,
    this.trailing,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: colors ??
              [
                cs.primaryContainer.withOpacity(.7),
                cs.secondaryContainer.withOpacity(.6),
              ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
//lib/widgets/gradient_header.dart