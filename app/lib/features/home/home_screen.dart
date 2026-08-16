import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/history_provider.dart';
import '../../core/domain/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_ui.dart';
import '../../core/widgets/airhop_footer.dart';
import '../../core/widgets/floating_navbar.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_text.dart';
import '../history/history_screen.dart';
import '../pairing/pairing_screen.dart';
import '../settings/settings_screen.dart';

/// صفحه اصلی AirHop.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              FloatingNavbar(
                title: 'Airhop',
                onHistory: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
                onSettings: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28),

                      // تیتر دو-رنگ
                      Row(
                        children: const [
                          Text(
                            'انتقال فایل ',
                            style: TextStyle(
                              color: AppColors.textHigh,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          GradientText(
                            'سریع و امن',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'فایل‌های خود را در چند ثانیه و بدون نیاز به اینترنت منتقل کنید',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 26),

                      // دو کارت ارسال / دریافت
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.upload_rounded,
                              title: 'ارسال فایل',
                              subtitle: 'فایل‌های خود را ارسال کنید',
                              gradient: AppColors.purpleGradient,
                              glow: AppColors.glowPurple,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const PairingScreen(isSender: true),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.download_rounded,
                              title: 'دریافت فایل',
                              subtitle: 'فایل‌ها را دریافت کنید',
                              gradient: AppColors.blueGradient,
                              glow: AppColors.glowBlue,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const PairingScreen(isSender: false),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      // هدر «آخرین انتقال‌ها»
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'آخرین انتقال‌ها',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'مشاهده همه',
                                style: TextStyle(
                                  color: AppColors.accentLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_left_rounded,
                                color: AppColors.accentLight,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // لیست آخرین انتقال‌ها
                      if (history.isEmpty)
                        _EmptyHistory()
                      else
                        for (final record in history.take(3)) ...[
                          _HistoryItem(record: record),
                          const SizedBox(height: 10),
                        ],

                      // لینک مشاهده همه (کلیک)
                      if (history.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Center(
                            child: InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HistoryScreen(),
                                ),
                              ),
                              child: const Text(
                                'مشاهده همه',
                                style: TextStyle(
                                  color: AppColors.accentLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
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

/// کارت بزرگ ارسال/دریافت.
class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.glow,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final Color glow;
  final VoidCallback onTap;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.96 : (_hovered ? 1.03 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: widget.gradient,
              boxShadow: [
                BoxShadow(
                  color: widget.glow.withOpacity(_hovered ? 0.5 : 0.22),
                  blurRadius: _hovered ? 30 : 16,
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.5),
                color: AppColors.backgroundMid,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: widget.gradient,
                      boxShadow: [
                        BoxShadow(
                          color: widget.glow.withOpacity(0.4),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
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

/// آیتم تاریخچه در صفحه اصلی.
class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.record});

  final TransferRecord record;

  @override
  Widget build(BuildContext context) {
    final color = FileUi.colorFor(record.fileName);
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // آیکون فایل رنگی
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color.withOpacity(0.15),
            ),
            child: Icon(FileUi.iconFor(record.fileName), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          // نام + حجم + منبع
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${FileUi.formatBytes(record.fileSize)} • ${_sourceLabel(record)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // وضعیت موفق + تیک
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.brandGradient,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'موفق',
                style: TextStyle(color: AppColors.success, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _sourceLabel(TransferRecord r) =>
      r.direction ? 'ارسال شد' : 'دریافت شد';
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.swap_horiz_rounded,
              color: AppColors.textMuted.withOpacity(0.5), size: 40),
          const SizedBox(height: 10),
          const Text(
            'هنوز انتقالی انجام نشده',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}
