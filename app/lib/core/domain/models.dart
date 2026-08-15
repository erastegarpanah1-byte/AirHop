// مدل‌های دامنه‌ی انتقال فایل.

/// وضعیت یک جلسه‌ی جفت‌سازی (pairing).
enum PairingStatus {
  creating, // در حال ساخت اتاق
  waiting, // منتظر اتصال peer
  connected, // دو peer متصل شدند
  transferring, // در حال انتقال فایل
  completed, // انتقال کامل شد
  failed, // خطا
  expired, // TTL تمام شد
}

/// نقش هر دستگاه در یک اتاق.
enum PeerRole {
  sender, // فرستنده‌ی فایل
  receiver, // گیرنده‌ی فایل
}

/// متادیتای یک فایل قبل/حین انتقال.
class FileMetadata {
  const FileMetadata({
    required this.id,
    required this.name,
    required this.size,
    this.mimeType,
  });

  final String id;
  final String name;
  final int size; // بایت
  final String? mimeType;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'size': size,
        'mimeType': mimeType,
      };

  factory FileMetadata.fromJson(Map<String, dynamic> json) => FileMetadata(
        id: json['id'] as String,
        name: json['name'] as String,
        size: json['size'] as int,
        mimeType: json['mimeType'] as String?,
      );
}

/// وضعیت پیشرفت انتقال.
class TransferProgress {
  const TransferProgress({
    required this.receivedBytes,
    required this.totalBytes,
    this.speedBytesPerSecond = 0,
  });

  final int receivedBytes;
  final int totalBytes;
  final int speedBytesPerSecond;

  double get ratio =>
      totalBytes == 0 ? 0.0 : receivedBytes / totalBytes;

  int get percent => (ratio * 100).round();

  /// زمان باقی‌مانده‌ی تخمینی (ثانیه).
  int get remainingSeconds {
    if (speedBytesPerSecond <= 0) return 0;
    final remaining = totalBytes - receivedBytes;
    return (remaining / speedBytesPerSecond).round();
  }

  TransferProgress copyWith({
    int? receivedBytes,
    int? totalBytes,
    int? speedBytesPerSecond,
  }) =>
      TransferProgress(
        receivedBytes: receivedBytes ?? this.receivedBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      );
}

/// یک رکورد در تاریخچه‌ی انتقال‌ها.
class TransferRecord {
  const TransferRecord({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.direction,
    required this.completedAt,
    required this.success,
  });

  final String id;
  final String fileName;
  final int fileSize;
  final bool direction; // true = sent, false = received
  final DateTime completedAt;
  final bool success;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'fileSize': fileSize,
        'direction': direction,
        'completedAt': completedAt.toIso8601String(),
        'success': success,
      };

  factory TransferRecord.fromJson(Map<String, dynamic> json) => TransferRecord(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        fileSize: json['fileSize'] as int,
        direction: json['direction'] as bool,
        completedAt: DateTime.parse(json['completedAt'] as String),
        success: json['success'] as bool,
      );
}
