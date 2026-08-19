import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/receive_service.dart';
import 'data/signaling_service.dart';
import 'data/webrtc_service.dart';
import 'data/history_provider.dart';
import 'domain/models.dart';

/// State سراسری جلسه ی جفت ساز/انتقال.
class SessionState {
  const SessionState({
    this.pairingCode = '',
    this.status = PairingStatus.creating,
    this.progress = const TransferProgress(receivedBytes: 0, totalBytes: 0),
    this.currentFile,
    this.peerDevice,
    this.files = const [],
    this.error,
  });

  final String pairingCode;
  final PairingStatus status;
  final TransferProgress progress;
  final FileMetadata? currentFile;
  final DeviceInfo? peerDevice;
  final List<FileMetadata> files;
  final String? error;

  SessionState copyWith({
    String? pairingCode,
    PairingStatus? status,
    TransferProgress? progress,
    FileMetadata? currentFile,
    DeviceInfo? peerDevice,
    List<FileMetadata>? files,
    String? error,
  }) =>
      SessionState(
        pairingCode: pairingCode ?? this.pairingCode,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        currentFile: currentFile ?? this.currentFile,
        peerDevice: peerDevice ?? this.peerDevice,
        files: files ?? this.files,
        error: error ?? this.error,
      );
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier(this._ref) : super(const SessionState());

  final Ref _ref;

  SignalingService? _signaling;
  WebRtcService? _webrtc;
  StreamSubscription? _eventsSub;
  StreamSubscription? _peerDeviceSub;
  StreamSubscription? _messagesSub;

  DeviceInfo _myDevice = const DeviceInfo(name: 'دستگاه', platform: 'unknown');

  void _log(String msg) => print('[AirHop] $msg');

  /// ثبت listener های signaling. بعد از این، roomReady و deviceInfo درست مدیریت می‌شوند.
  void _attachSignalingListeners(PeerRole role) {
    _eventsSub ??= _signaling!.events.listen((info) {
      _log('[$role] event: roomReady=${info.roomReady} peerCount=${info.peerCount}');
      if (info.roomReady) {
        _log('[$role] room ready');
        _signaling!.sendDeviceInfo(_myDevice);
        if (role == PeerRole.receiver) {
          _log('[$role] -> status connected');
          state = state.copyWith(status: PairingStatus.connected);
        } else {
          // sender: مستقیم به حالت آماده ارسال برو (بدون انتظار deviceInfo)
          _log('[$role] -> status readyToSend');
          state = state.copyWith(status: PairingStatus.readyToSend);
        }
      }
    });

    _peerDeviceSub ??= _signaling!.peerDevice.listen((device) {
      _log('[$role] peer device: ${device.name} (${device.platform})');
      state = state.copyWith(peerDevice: device);
      if (role == PeerRole.sender) {
        _log('[$role] -> status readyToSend');
        state = state.copyWith(status: PairingStatus.readyToSend);
      }
    });

    _messagesSub ??= _signaling!.messages.listen((m) {
      _log('[$role] signal: ${m.type.name}');
    });

    _signaling!.errors.listen((err) {
      _log('[$role] ERROR from signaling: $err');
      state = state.copyWith(status: PairingStatus.failed, error: err);
    });
  }

  Future<void> startSending(DeviceInfo myDevice) async {
    _myDevice = myDevice;
    _log('=== startSending (sender) ===');
    state = state.copyWith(status: PairingStatus.creating);

    _signaling = SignalingService();
    _attachSignalingListeners(PeerRole.sender);

    try {
      final code = await _signaling!.createRoom();
      _log('room created: $code');
      await _signaling!.joinRoom(code, role: 'sender');
      _log('joined room as sender');

      state = state.copyWith(pairingCode: code, status: PairingStatus.waiting);
      await initializeWebRtc(PeerRole.sender);
      _log('sender webrtc initialized');
    } catch (e) {
      _log('startSending FAILED: $e');
      state = state.copyWith(status: PairingStatus.failed, error: e.toString());
    }
  }

  Future<void> startReceiving(String code, DeviceInfo myDevice) async {
    _myDevice = myDevice;
    _log('=== startReceiving (receiver) code=$code ===');
    state = state.copyWith(status: PairingStatus.creating, pairingCode: code);

    _signaling = SignalingService();
    _attachSignalingListeners(PeerRole.receiver);

    try {
      await _signaling!.joinRoom(code, role: 'receiver');
      _log('joined room as receiver');
      state = state.copyWith(status: PairingStatus.waiting);
      await initializeWebRtc(PeerRole.receiver);
      _log('receiver webrtc initialized');
    } catch (e) {
      _log('startReceiving FAILED: $e');
      state = state.copyWith(status: PairingStatus.failed, error: e.toString());
    }
  }

  Future<void> initializeWebRtc(PeerRole role) async {
    if (_webrtc != null) return;

    _webrtc = WebRtcService(signaling: _signaling!, role: role);
    await _webrtc!.initialize();

    if (role == PeerRole.receiver) {
      _webrtc!.fileReceived.listen((received) async {
        _log('file received: ${received.fileName} (${received.bytes.length} bytes)');
        final savedPath = await const ReceiveService().saveFile(
          fileName: received.fileName,
          bytes: received.bytes,
        );
        _log('saved to: $savedPath');
        _recordHistory(
          fileName: received.fileName,
          fileSize: received.bytes.length,
          direction: false,
          success: true,
        );
        state = state.copyWith(
          status: PairingStatus.completed,
          currentFile: FileMetadata(
            id: received.fileName,
            name: received.fileName,
            size: received.bytes.length,
          ),
        );
      });
    }

    _webrtc!.progress.listen((p) {
      state = state.copyWith(status: PairingStatus.transferring, progress: p);
    });
  }

  void _recordHistory({
    required String fileName,
    required int fileSize,
    required bool direction, // true=sent, false=received
    required bool success,
  }) {
    try {
      _ref.read(historyProvider.notifier).add(TransferRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        fileName: fileName,
        fileSize: fileSize,
        direction: direction,
        completedAt: DateTime.now(),
        success: success,
      ));
    } catch (e) {
      _log('history add failed: $e');
    }
  }

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

    // ثبت تاریخچه برای هر فایل ارسال‌شده
    for (final f in files) {
      _recordHistory(
        fileName: f.name,
        fileSize: f.size,
        direction: true,
        success: true,
      );
    }
    state = state.copyWith(status: PairingStatus.completed);
  }

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
    _log('=== reset ===');
    _eventsSub?.cancel();
    _peerDeviceSub?.cancel();
    _messagesSub?.cancel();
    _eventsSub = null;
    _peerDeviceSub = null;
    _messagesSub = null;
    state = const SessionState();
    _signaling?.dispose();
    _webrtc?.dispose();
    _signaling = null;
    _webrtc = null;
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(ref);
});
