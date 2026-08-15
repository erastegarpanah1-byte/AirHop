import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// سرویس ذخیره‌سازی فایل‌های دریافتی.
///
/// فایل‌ها در `<Downloads>/AirHop/` ذخیره می‌شوند (در دسکتاپ) یا
/// دایرکتوری اسناد اپ (در موبایل).
class ReceiveService {
  const ReceiveService();

  /// مسیر پوشه‌ی مقصد (Downloads/AirHop).
  Future<Directory> _targetDirectory() async {
    final downloads = await getDownloadsDirectory();
    final base = downloads?.path ?? (await getApplicationDocumentsDirectory()).path;
    final dir = Directory('$base${Platform.pathSeparator}AirHop');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// ذخیره‌ی یک فایل دریافتی و برگرداندن مسیر کامل.
  Future<String> saveFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final dir = await _targetDirectory();
    var path = '${dir.path}${Platform.pathSeparator}$fileName';

    // جلوگیری از بازنویسی: در صورت وجود، شماره اضافه کن
    final file = File(path);
    if (await file.exists()) {
      final ext = fileName.contains('.')
          ? fileName.substring(fileName.lastIndexOf('.'))
          : '';
      final base = fileName.contains('.')
          ? fileName.substring(0, fileName.lastIndexOf('.'))
          : fileName;
      var i = 1;
      while (await file.exists()) {
        path = '${dir.path}${Platform.pathSeparator}${base}_($i)$ext';
        i++;
      }
    }

    await File(path).writeAsBytes(bytes);
    return path;
  }

  /// مسیر پوشه‌ی مقصد (برای نمایش به کاربر).
  Future<String> get targetDirectoryPath async {
    final dir = await _targetDirectory();
    return dir.path;
  }
}
