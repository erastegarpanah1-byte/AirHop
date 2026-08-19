import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/connectivity_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_text.dart';

/// صفحه‌ی آفلاین — وقتی به اینترنت (و در نتیجه به سرور سیگنالینگ) وصل نیستیم
/// نمایش داده می‌شود و به محض برقراری اتصال، کاربر به داخل برنامه هدایت می‌شود.
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
                    tween: Tween(begin: 0.85, end: 1.0),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeInOutSine,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.purpleGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.glowPurple.withOpacity(0.4),
                            blurRadius: 35,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(
                        reconnect ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 58,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  GradientText(
                    reconnect ? 'در حال برقراری ارتباط...' : 'عدم اتصال به شبکه',
                    gradient: AppColors.purpleGradient,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    reconnect
                        ? 'اتصال پایدار برقرار شد! در حال انتقال خودکار به برنامه...'
                        : 'برای استفاده از AirHop و جفت‌سازی دستگاه‌ها به اینترنت نیاز دارید.\nبه محض اتصال، به صورت کاملاً خودکار و آنی وارد برنامه می‌شوید.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 36),

                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    glowColor: AppColors.glowPurple,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.accentLight,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          reconnect ? 'در حال ورود به برنامه...' : 'در انتظار اتصال پایدار به اینترنت...',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'AirHop — انتقال بی مرز، پرسرعت و ایمن فایل',
                    style: TextStyle(
                      color: AppColors.textMuted.withOpacity(0.6),
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
