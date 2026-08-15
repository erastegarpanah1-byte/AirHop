import 'package:flutter/material.dart';

/// پالت رنگی برنامه — Dark mode به عنوان پیش‌فرض.
class AppColors {
  AppColors._();

  static const gradientTop = Color(0xFF1E1B4B); // indigo-950
  static const gradientMid = Color(0xFF312E81); // indigo-900
  static const gradientBottom = Color(0xFF6D28D9); // violet-700

  static const primary = Color(0xFF8B5CF6); // violet-500
  static const primaryLight = Color(0xFFA78BFA); // violet-400
  static const accent = Color(0xFF22D3EE); // cyan-400

  static const glassBg = Color(0x14FFFFFF);
  static const glassBorder = Color(0x33FFFFFF);
  static const glassHighlight = Color(0x40FFFFFF);

  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);

  static const shadowSoft = Color(0x33000000);
  static const shadowGlow = Color(0x668B5CF6);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientTop, gradientMid, gradientBottom],
    stops: [0.0, 0.5, 1.0],
  );
}
