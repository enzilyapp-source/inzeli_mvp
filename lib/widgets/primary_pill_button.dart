// lib/widgets/primary_pill_button.dart
import 'package:flutter/material.dart';

/// Reusable pill-style primary button to keep CTAs consistent across screens.
class PrimaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;
  final bool loading;
  final double? maxWidth;

  const PrimaryPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.padding,
    this.loading = false,
    this.maxWidth,
  });

  static const Color _accent = Color(0xFFF1A949);

  @override
  Widget build(BuildContext context) {
    final bool disabled = loading || onPressed == null;

    final btn = TextButton(
      onPressed: disabled ? null : onPressed,
      style: _style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _accent,
              ),
            )
          else if (icon != null) ...[
            Icon(icon, color: _accent),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: _accent,
            ),
          ),
        ],
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: 60,
          maxWidth: maxWidth ?? 360,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment(-0.6, -0.8),
              end: Alignment(0.9, 0.9),
              colors: [
                Color(0xFFEFF6FB),
                Color(0xFFD8E7F4),
                Color(0xFFC7DBED),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: btn,
        ),
      ),
    );
  }

  ButtonStyle get _style => TextButton.styleFrom(
        foregroundColor: _accent,
        padding: padding ?? const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      );
}
