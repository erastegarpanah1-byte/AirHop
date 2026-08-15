import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/history_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_background.dart';

/// صفحه‌ی تاریخچه‌ی انتقال‌ها.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary)),
                    const Spacer(),
                    const Text('تاریخچه انتقال‌ها', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(onPressed: () => ref.read(historyProvider.notifier).clear(), icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Expanded(
                child: history.isEmpty
                    ? const Center(child: Text('هنوز انتقالی انجام نشده است', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final record = history[index];
                          return GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  record.direction ? Icons.upload_rounded : Icons.download_rounded,
                                  color: record.direction ? AppColors.primary : AppColors.accent,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(record.fileName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(_formatBytes(record.fileSize), style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Icon(
                                  record.success ? Icons.check_circle : Icons.error,
                                  color: record.success ? AppColors.success : AppColors.error,
                                  size: 20,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
