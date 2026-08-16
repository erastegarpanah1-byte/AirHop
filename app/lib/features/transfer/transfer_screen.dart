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
                        isDone ? 'انتقال کامل شد' : 'در حال ارسال...',
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

/// نقاش جریان ذرات بین دو دستگاه.
class _ParticleStreamPainter extends CustomPainter {
  _ParticleStreamPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final linePaint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [AppColors.primary, AppColors.accent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawLine(Offset(8, centerY), Offset(size.width - 8, centerY), linePaint);

    for (var i = 0; i < 5; i++) {
      final p = (progress + i / 5) % 1.0;
      final x = 8 + p * (size.width - 16);
      final opacity = math.sin(p * math.pi).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, centerY),
        2.5,
        Paint()..color = AppColors.primarySoft.withOpacity(opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleStreamPainter oldDelegate) =>
      oldDelegate.progress != progress;
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
          BoxShadow(color: glow.withOpacity(0.4), blurRadius: 18),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

/// حلقه پیشرفت دایره‌ای گرادیانی.
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
    const size = 150.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(percent: percent),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GradientText(
                done ? '100%' : '$percent%',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
              ),
              Text(
                done ? 'کامل شد' : 'در حال ارسال',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.percent});

  final int percent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const stroke = 11.0;

    final bgPaint = Paint()
      ..color = AppColors.glassBgStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, bgPaint);

    final sweep = (percent / 100) * 2 * math.pi;
    if (sweep > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final progressPaint = Paint()
        ..shader = const SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [
            AppColors.accent,
            AppColors.primary,
            AppColors.primarySoft,
            AppColors.accent,
          ],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);

      final tipAngle = -math.pi / 2 + sweep;
      final tip = Offset(
        center.dx + radius * math.cos(tipAngle),
        center.dy + radius * math.sin(tipAngle),
      );
      canvas.drawCircle(
        tip,
        6,
        Paint()..color = AppColors.primarySoft.withOpacity(0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.percent != percent;
}

/// ردیف آمار (آیکون + مقدار + برچسب).
class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(height: 6),
        GradientText(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
