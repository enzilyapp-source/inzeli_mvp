import 'package:flutter/material.dart';

/// Unified snackbar used across the app (matches login styling).
void showAppSnack(
  BuildContext context,
  String text, {
  bool error = false,
  bool success = false,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final locale = Localizations.localeOf(context);
  final bool isArabic = locale.languageCode.toLowerCase().startsWith('ar') ||
      Directionality.of(context) == TextDirection.rtl;
  final textDir = isArabic ? TextDirection.rtl : TextDirection.ltr;

  final Color accent = error
      ? scheme.error
      : success
          ? scheme.primary
          : scheme.secondary;
  final Color fg = scheme.onSurface;
  final Color bg = scheme.surface.withValues(alpha: 0.95);

  final IconData icon = error
      ? Icons.close
      : success
          ? Icons.check_circle
          : Icons.info_outline;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: accent.withValues(alpha: 0.25)),
      ),
      content: Directionality(
        textDirection: textDir,
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(begin: const Offset(0, 0.15), end: Offset.zero),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          builder: (ctx, offset, child) => Transform.translate(
            offset: offset * 20,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: 1,
              child: child,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
