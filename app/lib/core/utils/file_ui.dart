import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ابزارهای مشترک برای نمایش فایل.
class FileUi {
  FileUi._();

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String extensionOf(String name) {
    if (!name.contains('.')) return '';
    return name.split('.').last.toLowerCase();
  }

  static IconData iconFor(String name) {
    final ext = extensionOf(name);
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'heic':
      case 'bmp':
        return Icons.image_rounded;
      case 'mp4':
      case 'mov':
      case 'mkv':
      case 'avi':
      case 'webm':
        return Icons.videocam_rounded;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
        return Icons.audiotrack_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
        return Icons.folder_zip_rounded;
      case 'doc':
      case 'docx':
      case 'txt':
      case 'md':
        return Icons.description_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  /// رنگ آیکون بر اساس نوع فایل (طبق بریف).
  static Color colorFor(String name) {
    final ext = extensionOf(name);
    switch (ext) {
      case 'mp4':
      case 'mov':
      case 'mkv':
      case 'avi':
        return AppColors.primarySoft; // بنفش (MP4)
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return AppColors.accentLight; // آبی (JPG)
      case 'pdf':
        return const Color(0xFFF87171); // قرمز (PDF)
      case 'zip':
      case 'rar':
      case '7z':
        return const Color(0xFFFBBF24); // نارنجی/زرد (ZIP)
      case 'ppt':
      case 'pptx':
        return const Color(0xFFFB923C); // نارنجی‌قرمز (PPTX)
      case 'mp3':
      case 'wav':
      case 'flac':
        return AppColors.cyan; // فیروزه‌ای (MP3)
      case 'txt':
      case 'md':
        return const Color(0xFF9CA3AF); // خاکستری (TXT)
      default:
        return AppColors.primaryLight;
    }
  }
}
