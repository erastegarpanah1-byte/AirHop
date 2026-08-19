import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/connectivity_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_text.dart';

/// صفحه‌ی آفلاین — وقتی به اینترنت (سرور سیگنالینگ) وصل نیستیم نمایش داده می‌شود
/// و به محض برقراری اتصال، کاربر به داخل برنامه هدایت می‌شود.
class OfflineScreen extends ConsumerWidget {
  const OfflineScreen({super.key, required this.onConnected});

  final VoidCallback onConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityProvider);

    if (status == ConnectivityStatus.online) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onConnected());
    }

    final bool reconnect = status == ConnectivityStatus.online;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.9, end: 1.0),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.cyanBlueGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.glowCyan,
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        reconnect ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 62,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  GradientText(
                    reconnect ? 'در حال اتصال...' : 'اتصال اینترنت برقرار نیست',
                    gradient: AppColors.textGradient,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    reconnect
                        ? 'اتصال برقرار شد، در حال ورود به برنامه...'
                        : 'برای استفاده از AirHop به اتصال اینترنت نیاز دارید.\nبه محض اتصال، به‌صورت خودکار وارد برنامه می‌شوید.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),

                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    glowColor: AppColors.glowCyan,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.cyan,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'در حال بررسی اتصال به سرور...',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'AirHop — انتقال فایل سریع و امن',
                    style: TextStyle(
                      color: AppColors.textMuted.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
