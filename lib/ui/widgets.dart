import 'package:flutter/material.dart';

/// Basic color helpers used by some quick widgets.
class AppColors {
  static const lightSurface = Color(0xFFE9F0FF);
  static const deepBlue = Color(0xFF4A3EE6);
}

/// Text styles used by the helpers below.
class AppText {
  static const label = TextStyle(fontWeight: FontWeight.w800);
  static const caption = TextStyle(fontSize: 12, color: Colors.black54);
}

/// A simple rounded game tile (kept here so old imports keep working).
class GameTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const GameTile({
    super.key,
    required this.label,
    this.icon = Icons.sports_esports,
    this.active = false,
    this.onTap,
  });

  /// Backwards-compat helper (old code called `roundedTile(...)`)
  static Widget roundedTile({
    required String label,
    IconData icon = Icons.sports_esports,
    bool active = false,
    VoidCallback? onTap,
  }) {
    return GameTile(label: label, icon: icon, active: active, onTap: onTap);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: active ? cs.primaryContainer : AppColors.lightSurface,
              border: Border.all(
                color: active ? cs.primary : cs.outlineVariant,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 30, color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppText.label),
        ],
      ),
    );
  }
}
//ui/widgets.dart