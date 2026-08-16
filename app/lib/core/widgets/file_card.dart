import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/file_ui.dart';
import 'glass_card.dart';

/// کارت نمایش یک فایل در لیست‌ها (زمان انتخاب فایل).
class FileCard extends StatelessWidget {
  const FileCard({
    super.key,
    required this.name,
    this.size,
    this.subtitle,
    this.onRemove,
  });

  final String name;
  final int? size;
  final String? subtitle;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final color = FileUi.colorFor(name);
    final ext = FileUi.extensionOf(name).toUpperCase();
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // badge رنگی فایل
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FileUi.iconFor(name), color: color, size: 20),
                if (ext.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    ext,
                    style: TextStyle(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // نام + حجم
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (size != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle != null
                        ? '${FileUi.formatBytes(size!)} • $subtitle'
                        : FileUi.formatBytes(size!),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
