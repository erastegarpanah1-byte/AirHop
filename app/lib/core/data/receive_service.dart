import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ReceiveService {
  const ReceiveService();

  static const _channel = MethodChannel('airhop/file_storage');

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

  Future<String> saveFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final category = _categoryFor(fileName, mimeType);
    final mime = mimeType ?? _mimeFor(fileName);

    if (Platform.isAndroid) {
      try {
        final path = await _channel.invokeMethod<String>('saveFile', {
          'fileName': fileName,
          'mimeType': mime,
          'category': category,
          'bytes': bytes,
        });
        if (path != null && path.isNotEmpty) return path;
      } catch (_) {}
      return _saveLegacyDart(fileName: fileName, bytes: bytes, category: category);
    }

    return _saveToDownloads(fileName: fileName, bytes: bytes, category: category);
  }

  Future<String> saveFromTempFile({
    required String fileName,
    required String tempFilePath,
    String? mimeType,
  }) async {
    final category = _categoryFor(fileName, mimeType);
    final mime = mimeType ?? _mimeFor(fileName);

    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (status.isGranted) {
        final extDir = await getExternalStorageDirectory();
        final root =
            extDir != null ? extDir.path.split('Android')[0] : '/storage/emulated/0';
        final dir = Directory('$root/AirHop/$category');
        if (!await dir.exists()) await dir.create(recursive: true);
        final path = await _uniquePath(dir.path, fileName);
        await _streamCopy(tempFilePath, path);
        try {
          await _channel.invokeMethod<String>('scanFileOnly', {
            'path': path,
            'mimeType': mime,
          });
        } catch (_) {}
        return path;
      }

      try {
        final path = await _channel.invokeMethod<String>('saveStreamedFile', {
          'fileName': fileName,
          'mimeType': mime,
          'category': category,
          'sourcePath': tempFilePath,
        });
        if (path != null && path.isNotEmpty) return path;
      } catch (_) {}

      return await _copyStreamingToAppDir(
        fileName: fileName,
        tempFilePath: tempFilePath,
        category: category,
      );
    }

    return await _copyStreamingToAppDir(
      fileName: fileName,
      tempFilePath: tempFilePath,
      category: category,
    );
  }

  Future<String> _copyStreamingToAppDir({
    required String fileName,
    required String tempFilePath,
    required String category,
  }) async {
    final downloads = await getDownloadsDirectory();
    final base = downloads?.path ?? (await getApplicationDocumentsDirectory()).path;
    final dir = Directory(
        '$base${Platform.pathSeparator}AirHop${Platform.pathSeparator}$category');
    if (!await dir.exists()) await dir.create(recursive: true);

    final path = await _uniquePath(dir.path, fileName);
    await _streamCopy(tempFilePath, path);
    return path;
  }

  Future<void> _streamCopy(String source, String dest) async {
    final sourceFile = File(source);
    final destFile = File(dest);
    final input = sourceFile.openRead();
    final output = destFile.openWrite();
    await input.pipe(output);
  }

  Future<String> _uniquePath(String dirPath, String fileName) async {
    var path = '$dirPath${Platform.pathSeparator}$fileName';
    if (!await File(path).exists()) return path;

    final dot = fileName.lastIndexOf('.');
    final ext = dot >= 0 ? fileName.substring(dot) : '';
    final base = dot >= 0 ? fileName.substring(0, dot) : fileName;
    var i = 1;
    while (await File(path).exists()) {
      path = '$dirPath${Platform.pathSeparator}${base}_($i)$ext';
      i++;
    }
    return path;
  }

  Future<String> _saveLegacyDart({
    required String fileName,
    required Uint8List bytes,
    required String category,
  }) async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      final extDir = await getExternalStorageDirectory();
      final root =
          extDir != null ? extDir.path.split('Android')[0] : '/storage/emulated/0';
      final dir = Directory('$root/AirHop/$category');
      if (!await dir.exists()) await dir.create(recursive: true);
      final path = await _uniquePath(dir.path, fileName);
      await File(path).writeAsBytes(bytes);
      return path;
    }
    return _saveToDownloads(fileName: fileName, bytes: bytes, category: category);
  }

  Future<String> _saveToDownloads({
    required String fileName,
    required Uint8List bytes,
    required String category,
  }) async {
    final downloads = await getDownloadsDirectory();
    final base = downloads?.path ?? (await getApplicationDocumentsDirectory()).path;
    final dir = Directory(
        '$base${Platform.pathSeparator}AirHop${Platform.pathSeparator}$category');
    if (!await dir.exists()) await dir.create(recursive: true);

    final path = await _uniquePath(dir.path, fileName);
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<String> get targetDirectoryPath async {
    if (Platform.isAndroid) return 'حافظه داخلی/AirHop';
    final downloads = await getDownloadsDirectory();
    final base = downloads?.path ?? (await getApplicationDocumentsDirectory()).path;
    return '$base${Platform.pathSeparator}AirHop';
  }
}
