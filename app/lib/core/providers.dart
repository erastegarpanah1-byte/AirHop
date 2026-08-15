import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/signaling_service.dart';
import 'data/webrtc_service.dart';
import 'domain/models.dart';

class SessionState {
  const SessionState({
    this.pairingCode = '',
    this.status = PairingStatus.creating,
    this.progress = const TransferProgress(receivedBytes: 0, totalBytes: 0),
    this.currentFile,
  });

  final String pairingCode;
  final PairingStatus status;
  final TransferProgress progress;
  final FileMetadata? currentFile;

  SessionState copyWith({String? pairingCode, PairingStatus? status, TransferProgress? progress, FileMetadata? currentFile}) =>
      SessionState(
        pairingCode: pairingCode ?? this.pairingCode,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        currentFile: currentFile ?? this.currentFile,
      );
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(const SessionState());

  SignalingService? _signaling;
  WebRtcService? _webrtc;

  Future<void> startSending() async {
    state = state.copyWith(status: PairingStatus.creating);
    _signaling = SignalingService();
    final code = await _signaling!.createRoom();
    await _signaling!.joinRoom(code, role: 'sender');
    state = state.copyWith(pairingCode: code, status: PairingStatus.waiting);
    _signaling!.events.listen((info) {
      if (info.roomReady) state = state.copyWith(status: PairingStatus.connected);
    });
  }

  Future<void> startReceiving(String code) async {
    state = state.copyWith(status: PairingStatus.creating, pairingCode: code);
    _signaling = SignalingService();
    await _signaling!.joinRoom(code, role: 'receiver');
    state = state.copyWith(status: PairingStatus.waiting);
    _signaling!.events.listen((info) {
      if (info.roomReady) state = state.copyWith(status: PairingStatus.connected);
    });
  }

  Future<void> initializeWebRtc(PeerRole role) async {
    _webrtc = WebRtcService(signaling: _signaling!, role: role);
    await _webrtc!.initialize();
    if (role == PeerRole.receiver) {
      _webrtc!.fileReceived.listen((path) {
        state = state.copyWith(status: PairingStatus.completed);
      });
    }
    _webrtc!.progress.listen((p) {
      state = state.copyWith(status: PairingStatus.transferring, progress: p);
    });
  }

  Future<void> sendFile(FileMetadata metadata, List<int> content) async {
    await _webrtc?.sendFile(metadata, content);
    state = state.copyWith(status: PairingStatus.completed);
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
