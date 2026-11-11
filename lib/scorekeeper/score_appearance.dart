import 'package:flutter/material.dart';

/// Same navy/orange palette as main.dart. Keep WebView and native chrome aligned
/// so opening the optional score screen never flashes a light background.
abstract final class ScoreAppearance {
  static const background = Color(0xFF223448);
  static const panel = Color(0xFF1C273B);
  static const field = Color(0xFF27364D);
  static const primary = Color(0xFFE49A2C);
  static const secondary = Color(0xFF5E9EB4);
  static const foreground = Color(0xFFE5ECF7);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Tajawal',
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          onPrimary: Color(0xFF142137),
          secondary: secondary,
          surface: panel,
          onSurface: foreground,
          error: Color(0xFFE2A5AB),
          outline: Color(0xFF496078),
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: panel,
          foregroundColor: foreground,
        ),
        cardTheme: const CardThemeData(color: panel),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: field,
        ),
      );
}
