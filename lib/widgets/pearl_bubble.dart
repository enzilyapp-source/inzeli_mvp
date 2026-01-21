import 'package:flutter/material.dart';

class PearlBubble extends StatelessWidget {
  final int pearls;
  const PearlBubble({super.key, required this.pearls});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$pearls', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Image.asset(
            'lib/assets/pearl.png',
            width: 18,
            height: 18,
          ),
        ],
      ),
    );
  }
}
//lib/widgets/pearl_bubble.dart
