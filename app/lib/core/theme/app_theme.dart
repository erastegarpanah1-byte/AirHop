import 'package:flutter/material.dart';
import 'app_colors.dart';

/// تم اصلی برنامه — Material 3 with custom colors.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = isDark ? _darkScheme : _lightScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: base,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, height: 1.4),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: Colors.black,
    error: AppColors.error,
    onError: Colors.white,
    surface: Color(0xFF1E1B4B),
    onSurface: AppColors.textPrimary,
  );

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: Colors.black,
    error: AppColors.error,
    onError: Colors.white,
    surface: Color(0xFFF1F5F9),
    onSurface: Color(0xFF0F172A),
  );
}
