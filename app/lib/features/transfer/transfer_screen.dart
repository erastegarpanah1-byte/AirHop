import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';

/// صفحه‌ی انتقال فایل — نمایش پیشرفت، سرعت و زمان باقی‌مانده.
class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '--';
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

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isDone
                          ? const Icon(Icons.check_circle_rounded, key: ValueKey('done'), color: AppColors.success, size: 72)
                          : const Icon(Icons.swap_horiz_rounded, key: ValueKey('progress'), color: AppColors.primary, size: 72),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      session.currentFile?.name ?? 'در حال انتقال...',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text('${progress.percent}%', style: const TextStyle(color: AppColors.textPrimary, fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -1)),
                    const SizedBox(height: 24),
                    _GlassProgressBar(progress: progress),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Stat(label: 'دریافت شده', value: _formatBytes(progress.receivedBytes)),
                        _Stat(label: 'حجم کل', value: _formatBytes(progress.totalBytes)),
                        _Stat(label: 'زمان باقی‌مانده', value: _formatDuration(progress.remainingSeconds)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (isDone)
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('بازگشت به خانه', style: TextStyle(color: AppColors.accent)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassProgressBar extends StatelessWidget {
  const _GlassProgressBar({required this.progress});

  final TransferProgress progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      decoration: BoxDecoration(color: AppColors.glassBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.glassBorder)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth * progress.ratio;
            return Stack(
              children: [
                Container(color: Colors.transparent),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: width,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 12)],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}
