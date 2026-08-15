import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/widgets/gradient_background.dart';
import '../pairing/pairing_screen.dart';

/// صفحه‌ی اصلی — دو دکمه‌ی بزرگ «ارسال» و «دریافت».
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
                const Spacer(flex: 2),
                const Text(
                  'AirHop',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -1),
                ),
                const SizedBox(height: 8),
                const Text(
                  'انتقال فایل بین دستگاه‌ها، سریع و امن',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                ),
                const Spacer(flex: 3),
                GlassButton(
                  label: 'ارسال فایل',
                  icon: Icons.upload_rounded,
                  accentColor: AppColors.primary,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairingScreen(isSender: true))),
                ),
                const SizedBox(height: 24),
                GlassButton(
                  label: 'دریافت فایل',
                  icon: Icons.download_rounded,
                  accentColor: AppColors.accent,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairingScreen(isSender: false))),
                ),
                const SizedBox(height: 32),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.history, color: AppColors.textSecondary),
                  label: const Text('تاریخچه انتقال‌ها', style: TextStyle(color: AppColors.textSecondary)),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
