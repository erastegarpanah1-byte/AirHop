import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/device_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/airhop_footer.dart';
import '../../core/widgets/floating_navbar.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../about/about_screen.dart';

/// صفحه تنظیمات AirHop.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _encryption = true;
  bool _notifications = true;
  bool _confirmReceive = true;
  bool _saveHistory = true;
  bool _wifiOnly = true;

  @override
  Widget build(BuildContext context) {
    final device = ref.watch(deviceProvider);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              FloatingNavbar(
                title: 'تنظیمات',
                onBack: () => Navigator.pop(context),
                onHelp: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        'تنظیمات',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'مدیریت تنظیمات برنامه و شخصی‌سازی تجربه',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _ToggleRow(
                        title: 'رمزنگاری فایل‌ها',
                        subtitle: 'رمزنگاری سرتاسری حین انتقال',
                        icon: Icons.lock_rounded,
                        value: _encryption,
                        onChanged: (v) => setState(() => _encryption = v),
                      ),
                      const SizedBox(height: 10),
                      _ToggleRow(
                        title: 'اعلان دریافت و ارسال',
                        subtitle: 'نمایش اعلان هنگام دریافت و ارسال فایل',
                        icon: Icons.notifications_rounded,
                        value: _notifications,
                        onChanged: (v) => setState(() => _notifications = v),
                      ),
                      const SizedBox(height: 10),
                      _ToggleRow(
                        title: 'تأیید قبل از دریافت فایل',
                        subtitle: 'دریافت فایل فقط پس از تأیید شما',
                        icon: Icons.verified_user_rounded,
                        value: _confirmReceive,
                        onChanged: (v) => setState(() => _confirmReceive = v),
                      ),
                      const SizedBox(height: 10),

                      _EditableNameRow(
                        icon: Icons.phone_iphone_rounded,
                        title: 'نام نمایشی دستگاه',
                        value: device.name,
                        onSave: (name) {
                          ref.read(deviceProvider.notifier).rename(name);
                        },
                      ),
                      const SizedBox(height: 10),

                      _ToggleRow(
                        title: 'ذخیره تاریخچه انتقال',
                        subtitle: 'نگهداری لیست فایل‌های منتقل‌شده',
                        icon: Icons.history_rounded,
                        value: _saveHistory,
                        onChanged: (v) => setState(() => _saveHistory = v),
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

                      const _NavRow(
                        title: 'مکان ذخیره فایل‌ها',
                        value: 'حافظه داخلی',
                        icon: Icons.sd_storage_rounded,
                      ),
                      const SizedBox(height: 10),
                      const _NavRow(
                        title: 'درباره برنامه',
                        value: 'نسخه 1.0.0',
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

/// ردیف با سوییچ گرادیانی (آگاه از جهت RTL).
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
          _NeonSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// ردیف نام دستگاه با امکان ویرایش (با دیالوگ).
class _EditableNameRow extends StatelessWidget {
  const _EditableNameRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onSave,
  });

  final IconData icon;
  final String title;
  final String value;
  final ValueChanged<String> onSave;

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
                  value.isEmpty ? 'تعیین نشده' : value,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showEditDialog(context),
            child: const Icon(
              Icons.edit_rounded,
              color: AppColors.accentLight,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF17162B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'نام دستگاه',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'مثلاً «گوشی من»',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.glassBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.glassBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'انصراف',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text(
              'ذخیره',
              style: TextStyle(color: AppColors.accentLight),
            ),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      onSave(result);
    }
  }
}

/// سوییچ گرادیانی بنفش-آبی (آگاه از جهت RTL).
class _NeonSwitch extends StatelessWidget {
  const _NeonSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
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
