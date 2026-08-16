import 'package:flutter/material.dart';

/// پالت رنگی AirHop — Dark glassmorphism نئونی بنفش-آبی.
///
/// مطابق بریف دقیق: پس‌زمینه navy بسیار تیره (#0A0A18 → #0D0B22)،
/// گرادیان برند بنفش→آبی، سطوح شیشه‌ای و گلوی نئونی.
class AppColors {
  AppColors._();

  // --- پس‌زمینه ---
  static const backgroundTop = Color(0xFF0A0A18); // navy عمیق
  static const backgroundMid = Color(0xFF0D0B22); // navy با ته‌رنگ بنفش
  static const backgroundBottom = Color(0xFF0B0B24);

  // --- برند ---
  static const primary = Color(0xFF7C3AED); // بنفش
  static const primaryLight = Color(0xFFA855F7);
  static const primarySoft = Color(0xFFC084FC);
  static const accent = Color(0xFF3B82F6); // آبی
  static const accentLight = Color(0xFF60A5FA);
  static const cyan = Color(0xFF22D3EE); // فیروزه‌ای (لوگو)
  static const pink = Color(0xFFEC4899); // صورتی

  // --- گرادیان برند (بنفش→آبی) ---
  static const brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFA855F7), Color(0xFFC084FC), Color(0xFF3B82F6), Color(0xFF60A5FA)],
  );
  static const purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA855F7), Color(0xFF7C3AED), Color(0xFF6D28D9)],
  );
  static const blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF60A5FA), Color(0xFF3B82F6), Color(0xFF2563EB)],
  );
  static const cyanBlueGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF22D3EE), Color(0xFF3B82F6)],
  );

  // --- متن ---
  static const textPrimary = Color(0xFFF4F4FF); // سفید
  static const textHigh = Color(0xFFE9E4FF); // سفید بنفش‌فام
  static const textSecondary = Color(0xFF8B87A8); // خاکستری بنفش کم‌کنتراست
  static const textMuted = Color(0xFF5C5875);

  // --- سطوح شیشه‌ای ---
  static const glassBg = Color(0x0DFFFFFF); // ~5%
  static const glassBgStrong = Color(0x14FFFFFF); // ~8%
  static const glassBorder = Color(0x26FFFFFF); // ~15%
  static const glassHighlight = Color(0x40FFFFFF); // ~25%

  // --- وضعیت ---
  static const success = Color(0xFF34D399);
  static const successNeon = Color(0xFF4ADE80); // سبز نئونی تاریخچه
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);

  // --- سایه / glow ---
  static const glowPurple = Color(0x667C3AED);
  static const glowBlue = Color(0x663B82F6);
  static const glowCyan = Color(0x6622D3EE);
  static const shadowDeep = Color(0x66000000);

  /// گرادیان سراسری پس‌زمینه.
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundTop, backgroundMid, backgroundBottom],
    stops: [0.0, 0.5, 1.0],
  );

  /// گرادیان متن (تیتر دو-رنگ).
  static const textGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFC084FC), Color(0xFFA855F7), Color(0xFF3B82F6)],
  );
}
