import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/airhop_footer.dart';
import '../../core/widgets/floating_navbar.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';

/// صفحه تنظیمات AirHop.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _encryption = true;
  bool _notifications = true;
  bool _autoRun = false;
  bool _darkMode = true;
  bool _saveHistory = true;
  bool _compress = false;
  bool _wifiOnly = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              FloatingNavbar(
                title: 'تنظیمات',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        'تنظیمات',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'مدیریت تنظیمات برنامه و شخصی‌سازی تجربه',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // تنظیمات با سوییچ
                      _ToggleRow(
                        title: 'رمزنگاری فایل‌ها',
                        subtitle: 'رمزنگاری سرتاسری حین انتقال',
                        icon: Icons.lock_rounded,
                        value: _encryption,
                        onChanged: (v) => setState(() => _encryption = v),
                      ),
                      const SizedBox(height: 10),
                      _ToggleRow(
                        title: 'اعلان‌ها',
                        subtitle: 'نمایش اعلان هنگام دریافت فایل',
                        icon: Icons.notifications_rounded,
                        value: _notifications,
                        onChanged: (v) => setState(() => _notifications = v),
                      ),
                      const SizedBox(height: 10),
                      _ToggleRow(
                        title: 'اجرای خودکار',
                        subtitle: 'اجرای خودکار در شروع سیستم',
                        icon: Icons.play_circle_rounded,
                        value: _autoRun,
                        onChanged: (v) => setState(() => _autoRun = v),
                      ),
                      const SizedBox(height: 10),
                      _ToggleRow(
                        title: 'حالت تاریک',
                        subtitle: 'ظاهر تاریک دائم',
                        icon: Icons.dark_mode_rounded,
                        value: _darkMode,
                        onChanged: (v) => setState(() => _darkMode = v),
                      ),
                      const SizedBox(height: 10),
                      _ToggleRow(
                        title: 'ذخیره تاریخچه انتقال‌ها',
                        subtitle: 'نگهداری لیست فایل‌های منتقل‌شده',
                        icon: Icons.history_rounded,
                        value: _saveHistory,
                        onChanged: (v) => setState(() => _saveHistory = v),
                      ),
                      const SizedBox(height: 10),
                      _ToggleRow(
                        title: 'فشرده‌سازی فایل‌ها',
                        subtitle: 'فشرده‌سازی قبل از انتقال',
                        icon: Icons.compress_rounded,
                        value: _compress,
                        onChanged: (v) => setState(() => _compress = v),
                      ),
                      const SizedBox(height: 10),
                      _ToggleRow(
                        title: 'فقط با Wi-Fi',
                        subtitle: 'استفاده از اینترنت فقط با Wi-Fi',
                        icon: Icons.wifi_rounded,
                        value: _wifiOnly,
                        onChanged: (v) => setState(() => _wifiOnly = v),
                      ),
                      const SizedBox(height: 18),

                      // ردیف‌های ناوبری
                      const _NavRow(
                        title: 'زبان برنامه',
                        value: 'فارسی',
                        icon: Icons.language_rounded,
                      ),
                      const SizedBox(height: 10),
                      const _NavRow(
                        title: 'مکان ذخیره فایل‌ها',
                        value: 'حافظه داخلی',
                        icon: Icons.sd_storage_rounded,
                      ),
                      const SizedBox(height: 10),
                      const _NavRow(
                        title: 'درباره برنامه',
                        value: 'نسخه ۱.۰.۵',
                        icon: Icons.info_outline_rounded,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const AirhopFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

/// ردیف با سوییچ گرادیانی.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // آیکون گرد
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.15),
            ),
            child: Icon(icon, color: AppColors.primarySoft, size: 21),
          ),
          const SizedBox(width: 12),
          // عنوان + توضیح
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // سوییچ
          _NeonSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// سوییچ گرادیانی بنفش-آبی (آگاه از جهت RTL).
class _NeonSwitch extends StatelessWidget {
  const _NeonSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // در RTL، سوییچ روشن باید به سمت چپ (شروع متن) بیفتد.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final alignment = value
        ? (isRtl ? Alignment.centerLeft : Alignment.centerRight)
        : (isRtl ? Alignment.centerRight : Alignment.centerLeft);

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: 50,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: value
              ? AppColors.brandGradient
              : const LinearGradient(
                  colors: [Color(0xFF2A2740), Color(0xFF2A2740)],
                ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: alignment,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// ردیف ناوبری ساده (بدون سوییچ).
class _NavRow extends StatelessWidget {
  const _NavRow({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withOpacity(0.15),
            ),
            child: Icon(icon, color: AppColors.accentLight, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_left_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }
}
