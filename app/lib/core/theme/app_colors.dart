import 'package:flutter/material.dart';

/// پالت رنگی AirHop — فقط Dark mode با طیف آبی → بنفش (glassmorphism).
///
/// برای گلس‌مورفیسم، پس‌زمینه باید گرادیان پررنگ و اشباع باشد تا
/// افکت frosted glass واقعاً دیده شود.
class AppColors {
  AppColors._();

  // --- گرادیان پس‌زمینه: آبی تیره → بنفش تیره → بنفش روشن‌تر ---
  static const gradientTop = Color(0xFF0B1026); // آبی-مشکی بسیار تیره
  static const gradientMid = Color(0xFF1B1B4D); // indigo عمیق
  static const gradientBottom = Color(0xFF4C1D95); // بنفش عمیق

  // --- رنگ‌های لهجه: طیف آبی → بنفش ---
  static const primary = Color(0xFF7C3AED); // violet-600 (بنفش اصلی)
  static const primaryLight = Color(0xFFA78BFA); // violet-400
  static const accent = Color(0xFF3B82F6); // blue-500 (آبی لهجه)
  static const accentLight = Color(0xFF60A5FA); // blue-400
  static const cyan = Color(0xFF06B6D4); // cyan-500 برای جزئیات

  // --- سطح‌های شیشه‌ای ---
  static const glassBg = Color(0x12FFFFFF); // سفید با opacity ~7%
  static const glassBorder = Color(0x2EFFFFFF); // border نیمه‌شفاف ~18%
  static const glassHighlight = Color(0x40FFFFFF); // هایلایت ~25%

  // --- متن ---
  static const textPrimary = Color(0xFFF4F5FB); // سفید-آبی خیلی روشن
  static const textSecondary = Color(0xFF9CA3C0); // آبی-خاکستری
  static const textMuted = Color(0xFF6B7290); // خاکستری-آبی کمرنگ

  // --- وضعیت ---
  static const success = Color(0xFF34D399); // emerald-400
  static const warning = Color(0xFFFBBF24); // amber-400
  static const error = Color(0xFFF87171); // red-400

  // --- سایه‌های دکمه ۲.۵ بعدی ---
  static const shadowSoft = Color(0x30000000);
  static const shadowGlow = Color(0x667C3AED); // glow بنفش دور دکمه‌ها

  /// گرادیان پس‌زمینه‌ی سراسری (آبی → بنفش)
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientTop, gradientMid, gradientBottom],
    stops: [0.0, 0.45, 1.0],
  );

  /// گرادیان لهجه برای دکمه‌ها و نوار پیشرفت (آبی → بنفش)
  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, primary, primaryLight],
    stops: [0.0, 0.55, 1.0],
  );
}
