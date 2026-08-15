import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/widgets/gradient_background.dart';
import '../pairing/pairing_screen.dart';

/// صفحه‌ی اصلی AirHop — انتخاب «ارسال» یا «دریافت».
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 3),
                // لوگو: یک آیکون شیشه‌ای + نام برند
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowGlow,
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'AirHop',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'انتقال فایل بین دستگاه‌هایت\nمستقیم، سریع و امن',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const Spacer(flex: 4),
                // دکمه‌ی ارسال
                GlassButton(
                  label: 'ارسال فایل',
                  icon: Icons.upload_rounded,
                  accentColor: AppColors.primary,
                  height: 76,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PairingScreen(isSender: true),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                // دکمه‌ی دریافت
                GlassButton(
                  label: 'دریافت فایل',
                  icon: Icons.download_rounded,
                  accentColor: AppColors.accent,
                  height: 76,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PairingScreen(isSender: false),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
