import 'package:flutter/material.dart';
import 'app_colors.dart';

/// تم AirHop — فقط Dark (بدون Light mode).
class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.accent,
          onSecondary: Colors.white,
          error: AppColors.error,
          onError: Colors.white,
          surface: Color(0xFF14142A),
          onSurface: AppColors.textPrimary,
        ),
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.transparent, // گرادیان پس‌زمینه است
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: AppColors.textPrimary),
          bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textSecondary),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      );
}
