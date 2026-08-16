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

/// صفحه تاریخچه انتقال‌ها.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _filter; // null = all, 'sent', 'received'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) return 'امروز';
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'دیروز';
    }
    return '${dt.day} روز پیش';
  }

  String _timeLabel(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);

    final filtered = history.where((r) {
      if (_filter == 'sent' && !r.direction) return false;
      if (_filter == 'received' && r.direction) return false;
      if (_query.isNotEmpty &&
          !r.fileName.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              FloatingNavbar(
                title: 'تاریخچه انتقال‌ها',
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Text(
                        'همه فایل‌های ارسال و دریافت شده',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // جستجو + فیلتر
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SearchField(
                              controller: _searchController,
                              onChanged: (v) => setState(() => _query = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _FilterButton(
                            active: _filter,
                            onSelect: (f) => setState(() => _filter = f),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // لیست
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'چیزی پیدا نشد',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 4),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final r = filtered[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _HistoryRow(
                                    record: r,
                                    dateLabel: _dateLabel(r.completedAt),
                                    timeLabel: _timeLabel(r.completedAt),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
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

/// ردیف تاریخچه کامل (مطابق بریف).
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.record,
    required this.dateLabel,
    required this.timeLabel,
  });

  final TransferRecord record;
  final String dateLabel;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final ext = FileUi.extensionOf(record.fileName).toUpperCase();
    final color = FileUi.colorFor(record.fileName);
    final dirLabel = record.direction ? 'ارسال به' : 'دریافت از';

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // تیک سبز نئونی (وضعیت موفق)
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.cyan, AppColors.successNeon],
              ),
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
          ),
          const SizedBox(width: 10),

          // اطلاعات فایل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dateLabel • $timeLabel',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 2),
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
                const SizedBox(height: 2),
                Text(
                  '${FileUi.formatBytes(record.fileSize)} • $dirLabel ${record.direction ? 'دستگاه' : 'دستگاه'}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // badge رنگی فایل
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FileUi.iconFor(record.fileName), color: color, size: 18),
                const SizedBox(height: 2),
                Text(
                  ext.isEmpty ? 'FILE' : ext,
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'جستجو در تاریخچه...',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onSelect});

  final String? active;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final next = switch (active) {
          null => 'sent',
          'sent' => 'received',
          _ => null,
        };
        onSelect(next);
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: active == null
              ? AppColors.glassBg
              : AppColors.primary.withOpacity(0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active == null ? AppColors.glassBorder : AppColors.primary,
          ),
        ),
        child: Icon(
          switch (active) {
            'sent' => Icons.upload_rounded,
            'received' => Icons.download_rounded,
            _ => Icons.filter_list_rounded,
          },
          color: active == null ? AppColors.textSecondary : AppColors.primarySoft,
          size: 22,
        ),
      ),
    );
  }
}
