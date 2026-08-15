/// مدل‌های دامنه‌ی انتقال فایل.

enum PairingStatus {
  creating,
  waiting,
  connected,
  transferring,
  completed,
  failed,
  expired,
}

enum PeerRole {
  sender,
  receiver,
}

class FileMetadata {
  const FileMetadata({required this.id, required this.name, required this.size, this.mimeType});

  final String id;
  final String name;
  final int size;
  final String? mimeType;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'size': size, 'mimeType': mimeType};

  factory FileMetadata.fromJson(Map<String, dynamic> json) => FileMetadata(
        id: json['id'] as String,
        name: json['name'] as String,
        size: json['size'] as int,
        mimeType: json['mimeType'] as String?,
      );
}

class TransferProgress {
  const TransferProgress({required this.receivedBytes, required this.totalBytes, this.speedBytesPerSecond = 0});

  final int receivedBytes;
  final int totalBytes;
  final int speedBytesPerSecond;

  double get ratio => totalBytes == 0 ? 0.0 : receivedBytes / totalBytes;
  int get percent => (ratio * 100).round();

  int get remainingSeconds {
    if (speedBytesPerSecond <= 0) return 0;
    final remaining = totalBytes - receivedBytes;
    return (remaining / speedBytesPerSecond).round();
  }
}

class TransferRecord {
  const TransferRecord({required this.id, required this.fileName, required this.fileSize, required this.direction, required this.completedAt, required this.success});

  final String id;
  final String fileName;
  final int fileSize;
  final bool direction; // true = sent, false = received
  final DateTime completedAt;
  final bool success;

  Map<String, dynamic> toJson() => {
        'id': id, 'fileName': fileName, 'fileSize': fileSize, 'direction': direction,
        'completedAt': completedAt.toIso8601String(), 'success': success,
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
