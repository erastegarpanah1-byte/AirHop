import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_ui.dart';
import '../../core/widgets/airhop_footer.dart';
import '../../core/widgets/floating_navbar.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_text.dart';

/// صفحه انتقال فایل.
class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '—';
    if (seconds < 60) return '$seconds ثانیه';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m دقیقه $s ثانیه';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final progress = session.progress;
    final isDone = session.status == PairingStatus.completed;
    final isTransferring = session.status == PairingStatus.transferring;

    final fileName = progress.currentFileName.isNotEmpty
        ? progress.currentFileName
        : (session.currentFile?.name ?? 'فایل');

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              FloatingNavbar(
                title: 'انتقال فایل',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        isDone ? 'ارسال شد' : 'در حال ارسال...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!isDone) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'لطفاً دستگاه‌ها را نزدیک نگه دارید',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      GlassCard(
                        padding: const EdgeInsets.all(22),
                        glowColor: AppColors.glowPurple,
                        child: Column(
                          children: [
                            const _DeviceStream(),
                            const SizedBox(height: 18),

                            _ProgressRing(
                              percent: isDone ? 100 : progress.percent,
                              done: isDone,
                              active: isTransferring,
                            ),
                            const SizedBox(height: 12),

                            Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              FileUi.formatBytes(progress.totalBytes),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 16),

                            const Divider(color: AppColors.glassBorder, height: 1),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: _StatRow(
                                    icon: Icons.speed_rounded,
                                    label: 'سرعت انتقال',
                                    value:
                                        '${(progress.speedBytesPerSecond / 1024 / 1024).toStringAsFixed(1)} MB/s',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatRow(
                                    icon: Icons.timer_outlined,
                                    label: 'زمان باقی‌مانده',
                                    value: _formatDuration(progress.remainingSeconds),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (isDone)
                        TextButton(
                          onPressed: () {
                            ref.read(sessionProvider.notifier).reset();
                            Navigator.popUntil(context, (r) => r.isFirst);
                          },
                          child: const Text(
                            'بازگشت به خانه',
                            style: TextStyle(
                              color: AppColors.accentLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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

/// دو دستگاه + جریان ذرات نورانی.
class _DeviceStream extends StatefulWidget {
  const _DeviceStream();

  @override
  State<_DeviceStream> createState() => _DeviceStreamState();
}

class _DeviceStreamState extends State<_DeviceStream>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const _DeviceIcon(
            icon: Icons.smartphone_rounded,
            gradient: AppColors.purpleGradient,
            glow: AppColors.glowPurple,
          ),
          SizedBox(
            width: 100,
            height: 20,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ParticleStreamPainter(progress: _c.value),
                );
              },
            ),
          ),
          const _DeviceIcon(
            icon: Icons.laptop_mac_rounded,
            gradient: AppColors.blueGradient,
            glow: AppColors.glowBlue,
          ),
        ],
      ),
    );
  }
}

class _DeviceIcon extends StatelessWidget {
  const _DeviceIcon({
    required this.icon,
    required this.gradient,
    required this.glow,
  });

  final IconData icon;
  final Gradient gradient;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: glow.withOpacity(0.35),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class _ParticleStreamPainter extends CustomPainter {
  _ParticleStreamPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentLight.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final r = math.Random(12345);

    for (var i = 0; i < 8; i++) {
      final speed = 0.6 + r.nextDouble() * 0.4;
      final offset = (progress * speed + (i * 0.15)) % 1.0;

      final x = size.width * offset;
      final y = size.height / 2 + math.sin(offset * math.pi * 2 + i) * 6;

      canvas.drawCircle(Offset(x, y), 2.2 + r.nextDouble() * 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleStreamPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// رینگ پیشرفت دایره‌ای زیبا با شتاب ملایم.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.percent,
    required this.done,
    required this.active,
  });

  final int percent;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final displayPercent = done ? 100 : percent;

    return SizedBox(
      width: 154,
      height: 154,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ShaderMask(
            shaderCallback: (rect) {
              return AppColors.purpleGradient.createShader(rect);
            },
            child: Container(
              width: 146,
              height: 146,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.04), width: 1.5),
              ),
            ),
          ),
          SizedBox(
            width: 130,
            height: 130,
            child: CircularProgressIndicator(
              value: displayPercent / 100.0,
              strokeWidth: 9.0,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentLight),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (done)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.accentLight,
                  size: 38,
                )
              else ...[
                GradientText(
                  '$displayPercent%',
                  gradient: AppColors.purpleGradient,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  active ? 'در حال دریافت' : 'در انتظار',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accentLight, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}