import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/receive_service.dart';
import 'data/signaling_service.dart';
import 'data/webrtc_service.dart';
import 'domain/models.dart';

/// State سراسری جلسه‌ی جفت‌سازی/انتقال.
class SessionState {
  const SessionState({
    this.pairingCode = '',
    this.status = PairingStatus.creating,
    this.progress = const TransferProgress(receivedBytes: 0, totalBytes: 0),
    this.currentFile,
    this.peerDevice,
    this.files = const [],
  });

  final String pairingCode;
  final PairingStatus status;
  final TransferProgress progress;
  final FileMetadata? currentFile;

  /// نام/پلتفرم دستگاه مقصد (برای نمایش «داری به [نام] می‌فرستی»).
  final DeviceInfo? peerDevice;

  /// فایل‌های انتخاب‌شده برای ارسال (multi-file).
  final List<FileMetadata> files;

  SessionState copyWith({
    String? pairingCode,
    PairingStatus? status,
    TransferProgress? progress,
    FileMetadata? currentFile,
    DeviceInfo? peerDevice,
    List<FileMetadata>? files,
  }) =>
      SessionState(
        pairingCode: pairingCode ?? this.pairingCode,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        currentFile: currentFile ?? this.currentFile,
        peerDevice: peerDevice ?? this.peerDevice,
        files: files ?? this.files,
      );
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState());

  SignalingService? _signaling;
  WebRtcService? _webrtc;

  /// شروع جلسه‌ی ارسال: ساخت room + منتظر ماندن برای peer.
  Future<void> startSending(DeviceInfo myDevice) async {
    state = state.copyWith(status: PairingStatus.creating);

    _signaling = SignalingService();
    final code = await _signaling!.createRoom();
    await _signaling!.joinRoom(code, role: 'sender');

    state = state.copyWith(
      pairingCode: code,
      status: PairingStatus.waiting,
    );

    // معرفی خودمان به peer (وقتی وصل شد)
    _signaling!.events.listen((info) {
      if (info.roomReady) {
        _signaling!.sendDeviceInfo(myDevice);
      }
    });

    // شنیدن معرفی دستگاه مقصد
    _signaling!.peerDevice.listen((device) {
      state = state.copyWith(peerDevice: device, status: PairingStatus.readyToSend);
    });
  }

  /// شروع جلسه‌ی دریافت: همان کد را وارد/اسکن می‌کند.
  Future<void> startReceiving(String code, DeviceInfo myDevice) async {
    state = state.copyWith(status: PairingStatus.creating, pairingCode: code);

    _signaling = SignalingService();
    await _signaling!.joinRoom(code, role: 'receiver');

    state = state.copyWith(status: PairingStatus.waiting);

    _signaling!.events.listen((info) {
      if (info.roomReady) {
        _signaling!.sendDeviceInfo(myDevice);
        state = state.copyWith(status: PairingStatus.connected);
      }
    });

    _signaling!.peerDevice.listen((device) {
      state = state.copyWith(peerDevice: device);
    });

    // راه‌اندازی WebRTC برای دریافت
    await initializeWebRtc(PeerRole.receiver);
  }

  /// بعد از اتصال، سرویس WebRTC را راه‌اندازی کن.
  Future<void> initializeWebRtc(PeerRole role) async {
    _webrtc = WebRtcService(signaling: _signaling!, role: role);
    await _webrtc!.initialize();

    if (role == PeerRole.receiver) {
      _webrtc!.fileReceived.listen((received) async {
        // ذخیره‌ی فایل در Downloads/AirHop
        final savedPath = await const ReceiveService().saveFile(
          fileName: received.fileName,
          bytes: received.bytes,
        );
        state = state.copyWith(
          status: PairingStatus.completed,
          currentFile: FileMetadata(
            id: received.fileName,
            name: received.fileName,
            size: received.bytes.length,
            mimeType: savedPath,
          ),
        );
      });
    }

    _webrtc!.progress.listen((p) {
      state = state.copyWith(
        status: PairingStatus.transferring,
        progress: p,
      );
    });
  }

  /// انتخاب فایل‌ها و شروع ارسال (multi-file).
  Future<void> sendFiles(List<FileMetadata> files) async {
    state = state.copyWith(files: files, status: PairingStatus.transferring);

    if (_webrtc == null) {
      await initializeWebRtc(PeerRole.sender);
    }

    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      state = state.copyWith(currentFile: f);
      await _webrtc!.sendFile(f, f.bytes ?? const <int>[]);
    }

    state = state.copyWith(status: PairingStatus.completed);
  }

  /// (سازگاری با کد قبلی) ارسال تک‌فایل.
  Future<void> sendFile(FileMetadata metadata, List<int> content) async {
    await sendFiles([
      FileMetadata(
        id: metadata.id,
        name: metadata.name,
        size: metadata.size,
        mimeType: metadata.mimeType,
        bytes: content as dynamic,
      ),
    ]);
  }

  void reset() {
    state = const SessionState();
    _signaling?.dispose();
    _webrtc?.dispose();
    _signaling = null;
    _webrtc = null;
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});
