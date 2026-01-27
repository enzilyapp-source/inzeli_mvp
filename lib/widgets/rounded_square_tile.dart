import 'package:flutter/material.dart';

class RoundedSquareTile extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool filled;         // للحالات المختارة مسبقًا

  const RoundedSquareTile({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.filled = false,
  });

  @override
  State<RoundedSquareTile> createState() => _RoundedSquareTileState();
}

class _RoundedSquareTileState extends State<RoundedSquareTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool active = _pressed || widget.filled;

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onHighlightChanged: (v) => setState(() => _pressed = v),
      onTap: widget.onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: active ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: .5),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon ?? Icons.sports_esports,
              size: 34,
              color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .9),
            ),
          ),
        ],
      ),
    );
  }
}


//widgets/rounded_square_tile.dart