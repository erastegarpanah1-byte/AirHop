import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// ذخیره‌سازی فایل‌های دریافتی.
///
/// - اندروید ۱۰+ (API 29+): از طریق MethodChannel (`airhop/file_storage`)
///   در MediaStore ذخیره می‌کند — بدون نیاز به مجوز، در گالری و
///   File Manager نشان داده می‌شود.
/// - اندروید ۹- (API 28-): مسیر مستقیم `/storage/emulated/0/AirHop/...` با مجوز
///   WRITE_EXTERNAL_STORAGE (همراه با اسکن گالری).
/// - دسکتاپ: Downloads/AirHop.
class ReceiveService {
  const ReceiveService();

  static const _channel = MethodChannel('airhop/file_storage');

  // ---------------------------------------------------------------- دسته‌بندی

  String _categoryFor(String fileName, String? mimeType) {
    final mime = (mimeType ?? '').toLowerCase();
    final ext = fileName.contains('.')
        ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
        : '';

    if (mime.startsWith('image/')) return 'تصاویر';
    if (mime.startsWith('video/')) return 'ویدیوها';
    if (mime.startsWith('audio/')) return 'آهنگ';
    if (mime.isNotEmpty) return 'فایل‌ها';

    const images = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif', 'svg'];
    const videos = ['mp4', 'mkv', 'mov', 'avi', 'webm', '3gp', 'flv', 'm4v', 'ts'];
    const audio = ['mp3', 'wav', 'aac', 'ogg', 'm4a', 'flac', 'opus', 'amr', 'wma'];
    if (images.contains(ext)) return 'تصاویر';
    if (videos.contains(ext)) return 'ویدیوها';
    if (audio.contains(ext)) return 'آهنگ';
    return 'فایل‌ها';
  }

  String _mimeFor(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
        : '';
    const map = <String, String>{
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif', 'webp': 'image/webp', 'bmp': 'image/bmp',
      'heic': 'image/heic', 'heif': 'image/heif', 'svg': 'image/svg+xml',
      'mp4': 'video/mp4', 'mkv': 'video/x-matroska', 'mov': 'video/quicktime',
      'avi': 'video/x-msvideo', 'webm': 'video/webm', '3gp': 'video/3gpp',
      'm4v': 'video/x-m4v', 'mp3': 'audio/mpeg', 'wav': 'audio/wav',
      'aac': 'audio/aac', 'ogg': 'audio/ogg', 'm4a': 'audio/mp4',
      'flac': 'audio/flac', 'opus': 'audio/opus', 'amr': 'audio/amr',
      'pdf': 'application/pdf', 'zip': 'application/zip',
      'txt': 'text/plain', 'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'apk': 'application/vnd.android.package-archive',
      'json': 'application/json', 'csv': 'text/csv', 'html': 'text/html',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  // ---------------------------------------------------------------- ذخیره از بایت‌ها

  /// فایل را از [bytes] ذخیره کن و مسیر نهایی را برگردان.
  Future<String> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final category = _categoryFor(fileName, mimeType);
    final mime = mimeType ?? _mimeFor(fileName);

    if (Platform.isAndroid) {
      // راه اصلی: MethodChannel → MediaStore (اندروید ۱۰+) یا فایل مستقیم (اندروید ≤۹)
      try {
        final path = await _channel.invokeMethod<String>('saveFile', {
          'fileName': fileName,
          'mimeType': mime,
          'category': category,
          'bytes': bytes,
        });
        if (path != null && path.isNotEmpty) return path;
      } catch (_) {
        // fallback زیر
      }

      // fallback: مسیر مستقیم (اگر مجوز داشته باشیم)
      return _saveLegacyDart(fileName: fileName, bytes: bytes, category: category);
    }

    return _saveToDownloads(fileName: fileName, bytes: bytes, category: category);
  }

  /// فایل را از یک مسیر موقت (فایل روی دیسک) با stream-copy ذخیره کن.
  /// برای فایل‌های بزرگ به کار می‌رود تا کل فایل در RAM بارگذاری نشود.
  Future<String> saveFromTempFile({
    required String fileName,
    required String tempFilePath,
    String? mimeType,
  }) async {
    final category = _categoryFor(fileName, mimeType);
    final mime = mimeType ?? _mimeFor(fileName);

    if (Platform.isAndroid) {
      // برای اندروید ۷، ۸، ۹ کپی مستقیم با بافر انجام می‌دهیم تا رم پر نشود و کرش نکند
      final status = await Permission.storage.request();
      if (status.isGranted) {
        final extDir = await getExternalStorageDirectory();
        final root = extDir != null ? extDir.path.split('Android')[0] : '/storage/emulated/0';
        final dir = Directory('$root/AirHop/$category');
        if (!await dir.exists()) await dir.create(recursive: true);
        var path = '${dir.path}/$fileName';

        final file = File(path);
        if (await file.exists()) {
          final dot = fileName.lastIndexOf('.');
          final ext = dot >= 0 ? fileName.substring(dot) : '';
          final base = dot >= 0 ? fileName.substring(0, dot) : fileName;
          var i = 1;
          while (await File(path).exists()) {
            path = '${dir.path}/${base}_($i)$ext';
            i++;
          }
        }
        
        // کپی استریمی با بافر بسیار کوچک (۶۴ کیلوبایت) برای جلوگیری از کرش رم (OOM) در فایل‌های بزرگ روی اندروید ۷
        final source = File(tempFilePath);
        final dest = File(path);
        final ios = source.openRead();
        final iosSink = dest.openWrite();
        await ios.pipe(iosSink);
        
        // فراخوانی کانال بومی صرفاً برای اسکن گالری (بدون انتقال بایت‌های سنگین از حافظه Dart به Java)
        try {
          await _channel.invokeMethod<String>('scanFileOnly', {
            'path': path,
            'mimeType': mime,
          });
        } catch (_) {}
        
        return path;
      }

      // اندروید ۱۰+ (از طریق مدیااستور اگر فایل کوچک باشد یا کانال استریمی)
      try {
        final bytes = await File(tempFilePath).readAsBytes();
        final path = await _channel.invokeMethod<String>('saveFile', {
          'fileName': fileName,
          'mimeType': mime,
          'category': category,
          'bytes': bytes,
        });
        if (path != null && path.isNotEmpty) return path;
      } catch (_) {}
    }
    // دسکتاپ: کپی مستقیم بدون بارگذاری کل فایل
    final downloads = await getDownloadsDirectory();
    final base = downloads?.path ?? (await getApplicationDocumentsDirectory()).path;
    final dir = Directory('$base${Platform.pathSeparator}AirHop${Platform.pathSeparator}$category');
    if (!await dir.exists()) await dir.create(recursive: true);
    var path = '${dir.path}${Platform.pathSeparator}$fileName';
    var i = 1;
    while (await File(path).exists()) {
      final dot = fileName.lastIndexOf('.');
      final ext = dot >= 0 ? fileName.substring(dot) : '';
      final baseN = dot >= 0 ? fileName.substring(0, dot) : fileName;
      path = '${dir.path}${Platform.pathSeparator}${baseN}_($i)$ext';
      i++;
    }
    await File(tempFilePath).copy(path);
    return path;
  }

  // ---------------------------------------------------------------- legacy (Dart fallback)

  Future<String> _saveLegacyDart({
    required String fileName,
    required Uint8List bytes,
    required String category,
  }) async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      final extDir = await getExternalStorageDirectory();
      final root = extDir != null ? extDir.path.split('Android')[0] : '/storage/emulated/0';
      final dir = Directory('$root/AirHop/$category');
      if (!await dir.exists()) await dir.create(recursive: true);
      var path = '${dir.path}/$fileName';

      final file = File(path);
      if (await file.exists()) {
        final dot = fileName.lastIndexOf('.');
        final ext = dot >= 0 ? fileName.substring(dot) : '';
        final base = dot >= 0 ? fileName.substring(0, dot) : fileName;
        var i = 1;
        while (await File(path).exists()) {
          path = '${dir.path}/${base}_($i)$ext';
          i++;
        }
      }
      await File(path).writeAsBytes(bytes);
      return path;
    }

    // آخرین راه: داخل دایرکتوری خصوصی اپ
    return _saveToDownloads(fileName: fileName, bytes: bytes, category: category);
  }

  // ---------------------------------------------------------------- دسکتاپ

  Future<String> _saveToDownloads({
    required String fileName,
    required Uint8List bytes,
    required String category,
  }) async {
    final downloads = await getDownloadsDirectory();
    final base = downloads?.path ?? (await getApplicationDocumentsDirectory()).path;
    final dir = Directory('$base${Platform.pathSeparator}AirHop${Platform.pathSeparator}$category');
    if (!await dir.exists()) await dir.create(recursive: true);

    var path = '${dir.path}${Platform.pathSeparator}$fileName';
    final file = File(path);
    if (await file.exists()) {
      final dot = fileName.lastIndexOf('.');
      final ext = dot >= 0 ? fileName.substring(dot) : '';
      final baseN = dot >= 0 ? fileName.substring(0, dot) : fileName;
      var i = 1;
      while (await File(path).exists()) {
        path = '${dir.path}${Platform.pathSeparator}${baseN}_($i)$ext';
        i++;
      }
    }
    await File(path).writeAsBytes(bytes);
    return path;
  }

  /// پیام خوانا برای نمایش مقصد ذخیره.
  Future<String> get targetDirectoryPath async {
    if (Platform.isAndroid) return 'حافظه داخلی/AirHop';
    final downloads = await getDownloadsDirectory();
    final base = downloads?.path ?? (await getApplicationDocumentsDirectory()).path;
    return '$base${Platform.pathSeparator}AirHop';
  }
}