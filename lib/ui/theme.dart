// lib/ui/theme.dart
import 'package:flutter/material.dart';

/// ألوان إنزلي الرئيسية
class AppColors {
  static const Color tealDark = Color(0xFF232E4A);  // الخلفية الأغمق
  static const Color tealMain = Color(0xFF34677A);  // الأزرق
  static const Color tealSoft = Color(0xFF4A8CA0);  // أفتح شوي
  static const Color greenAction = Color(0xFF25C94A); // زر إنشاء روم
  static const Color pearlBadge = Color(0xFF0F172A);  // كرت النقاط الأسود
  static const Color orangeAccent = Color(0xFFF7A525); // "إنزلي"
}

class AppTheme {
  /// تدرّج الخلفية لصفحة الألعاب
  static const LinearGradient gamesBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      AppColors.tealDark,
      AppColors.tealMain,
      AppColors.tealSoft,
    ],
  );

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.tealDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.tealMain,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.tealDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.tealDark,
        indicatorColor: Colors.white24,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  static ThemeData get dark {
    // نفس الألوان تقريباً حتى لو كان النظام داكن
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.tealDark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.tealMain,
        brightness: Brightness.dark,
      ),
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.tealDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.tealDark,
        indicatorColor: Colors.white24,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
//ui/theme.dart