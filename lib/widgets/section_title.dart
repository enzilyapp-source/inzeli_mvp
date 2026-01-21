import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry? padding;
  const SectionTitle({super.key, required this.text, this.padding});

  @override
  Widget build(BuildContext context) {
    final on = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: on,
          fontSize: 16,
        ),
      ),
    );
  }
}
//widgets/section_title.dart