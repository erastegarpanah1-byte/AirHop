import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:airhop/core/domain/models.dart';

void main() {
  group('DeviceInfo', () {
    test('toJson / fromJson roundtrip', () {
      const device = DeviceInfo(name: 'Pixel 7', platform: 'android');
      final json = device.toJson();

      expect(json['name'], 'Pixel 7');
      expect(json['platform'], 'android');

      final restored = DeviceInfo.fromJson(json);
      expect(restored.name, device.name);
      expect(restored.platform, device.platform);
    });

    test('fromJson falls back to defaults on missing fields', () {
      final device = DeviceInfo.fromJson(const {});
      expect(device.name, 'دستگاه');
      expect(device.platform, 'unknown');
    });
  });

  group('FileMetadata', () {
    test('toJson omits bytes (never sent over the wire)', () {
      const metadata = FileMetadata(
        id: 'f1',
        name: 'report.pdf',
        size: 2048,
        mimeType: 'application/pdf',
      );
      final json = metadata.toJson();

      expect(json['id'], 'f1');
      expect(json['name'], 'report.pdf');
      expect(json['size'], 2048);
      expect(json['mimeType'], 'application/pdf');
      expect(json.containsKey('bytes'), isFalse);
    });

    test('fromJson roundtrip', () {
      const metadata = FileMetadata(
        id: 'f2',
        name: 'photo.png',
        size: 512,
      );
      final restored = FileMetadata.fromJson(metadata.toJson());

      expect(restored.id, metadata.id);
      expect(restored.name, metadata.name);
      expect(restored.size, metadata.size);
      expect(restored.mimeType, isNull);
      expect(restored.bytes, isNull);
    });
  });

  group('TransferProgress', () {
    test('ratio and percent are computed correctly', () {
      const progress = TransferProgress(
        receivedBytes: 50,
        totalBytes: 200,
      );

      expect(progress.ratio, closeTo(0.25, 1e-9));
      expect(progress.percent, 25);
    });

    test('ratio is zero when totalBytes is zero (no division by zero)', () {
      const progress = TransferProgress(
        receivedBytes: 0,
        totalBytes: 0,
      );

      expect(progress.ratio, 0.0);
      expect(progress.percent, 0);
    });

    test('remainingSeconds uses speed to estimate time left', () {
      const progress = TransferProgress(
        receivedBytes: 100,
        totalBytes: 300,
        speedBytesPerSecond: 50,
      );

      // 200 bytes left at 50 bytes/sec -> 4 seconds
      expect(progress.remainingSeconds, 4);
    });

    test('remainingSeconds is zero when speed is unknown', () {
      const progress = TransferProgress(
        receivedBytes: 100,
        totalBytes: 300,
      );

      expect(progress.remainingSeconds, 0);
    });

    test('copyWith overrides only provided fields', () {
      const progress = TransferProgress(
        receivedBytes: 10,
        totalBytes: 100,
        currentFileName: 'a.txt',
      );

      final updated = progress.copyWith(receivedBytes: 50);

      expect(updated.receivedBytes, 50);
      expect(updated.totalBytes, 100);
      expect(updated.currentFileName, 'a.txt');
    });
  });

  group('TransferRecord', () {
    test('toJson / fromJson roundtrip', () {
      final now = DateTime.now();
      final record = TransferRecord(
        id: 'r1',
        fileName: 'notes.txt',
        fileSize: 1024,
        direction: true,
        completedAt: now,
        success: true,
      );

      final restored = TransferRecord.fromJson(record.toJson());

      expect(restored.id, record.id);
      expect(restored.fileName, record.fileName);
      expect(restored.fileSize, record.fileSize);
      expect(restored.direction, record.direction);
      expect(restored.success, record.success);
      expect(restored.completedAt, now);
    });
  });

  group('ReceivedFile', () {
    test('holds filename and bytes', () {
      final received = ReceivedFile(
        fileName: 'image.png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(received.fileName, 'image.png');
      expect(received.bytes, [1, 2, 3]);
    });
  });
}
