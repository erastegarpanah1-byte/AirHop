import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/app_config.dart';
import '../domain/models.dart';
import 'signaling_service.dart';

/// سرویس WebRTC — برقراری اتصال peer-to-peer و انتقال فایل از طریق DataChannel.
class WebRtcService {
  WebRtcService({required this.signaling, this.role = PeerRole.sender});

  final SignalingService signaling;
  final PeerRole role;

  RTCPeerConnection? _pc;
  RTCDataChannel? _channel;
  StreamSubscription? _signalSub;

  String? _currentFilePath;
  int _currentFileSize = 0;
  int _receivedBytes = 0;
  final List<int> _buffer = [];

  final StreamController<TransferProgress> _progress =
      StreamController<TransferProgress>.broadcast();
  Stream<TransferProgress> get progress => _progress.stream;

  final StreamController<ReceivedFile> _fileReceived =
      StreamController<ReceivedFile>.broadcast();
  Stream<ReceivedFile> get fileReceived => _fileReceived.stream;

  Future<void> initialize() async {
    final configuration = <String, dynamic>{
      'iceServers': [
        for (final url in AppConfig.iceServers) {'urls': url},
      ],
      'sdpSemantics': 'unified-plan',
    };

    _pc = await createPeerConnection(configuration);

    _pc!.onIceCandidate = (candidate) {
      signaling.send(SignalMessage(type: SignalType.ice, candidate: candidate.toMap()));
    };

    _pc!.onConnectionState = (state) {};

    if (role == PeerRole.sender) {
      _channel = await _pc!.createDataChannel(
        'file-transfer',
        RTCDataChannelInit()..ordered = true,
      );
      _setupChannel();
    } else {
      _pc!.onDataChannel = (channel) {
        _channel = channel;
        _setupChannel();
      };
    }

    _signalSub = signaling.messages.listen(_handleSignal);
  }

  void _setupChannel() {
    _channel!.onMessage = (RTCDataChannelMessage message) {
      if (message.isBinary) {
        _handleBinaryChunk(message.binary);
      } else {
        _handleTextMessage(message.text);
      }
    };
  }

  Future<void> _handleSignal(SignalMessage message) async {
    switch (message.type) {
      case SignalType.offer:
        await _pc!.setRemoteDescription(
          RTCSessionDescription(message.sdp, 'offer'),
        );
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        signaling.send(SignalMessage(type: SignalType.answer, sdp: answer.sdp));
        break;
      case SignalType.answer:
        await _pc!.setRemoteDescription(
          RTCSessionDescription(message.sdp, 'answer'),
        );
        break;
      case SignalType.ice:
        final candidate = RTCIceCandidate(
          message.candidate!['candidate'] as String,
          message.candidate!['sdpMid'] as String?,
          message.candidate!['sdpMLineIndex'] as int?,
        );
        await _pc!.addCandidate(candidate);
        break;
      case SignalType.ready:
        if (role == PeerRole.sender) {
          await _createOffer();
        }
        break;
      default:
        break;
    }
  }

  Future<void> _createOffer() async {
    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    signaling.send(SignalMessage(type: SignalType.offer, sdp: offer.sdp));
  }

  Future<void> sendFile(FileMetadata metadata, List<int> content) async {
    _channel!.send(RTCDataChannelMessage(
      jsonEncode({'type': 'file-header', 'metadata': metadata.toJson()}),
    ));

    final chunkSize = AppConfig.chunkSize;
    int sent = 0;
    final total = content.length;

    while (sent < total) {
      final end = (sent + chunkSize < total) ? sent + chunkSize : total;
      final Uint8List chunk = Uint8List.fromList(content.sublist(sent, end));
      await _sendChunk(chunk);
      sent = end;
      _progress.add(TransferProgress(receivedBytes: sent, totalBytes: total));
    }

    _channel!.send(RTCDataChannelMessage(jsonEncode({'type': 'file-end'})));
  }

  Future<void> _sendChunk(Uint8List data) async {
    _channel!.send(RTCDataChannelMessage.fromBinary(data));
    await Future<void>.delayed(Duration.zero);
  }

  void _handleTextMessage(String text) {
    final Map<String, dynamic> json = jsonDecode(text) as Map<String, dynamic>;
    final String? type = json['type'] as String?;

    if (type == 'file-header') {
      final metadata =
          FileMetadata.fromJson(json['metadata'] as Map<String, dynamic>);
      _currentFilePath = metadata.name;
      _currentFileSize = metadata.size;
      _receivedBytes = 0;
      _buffer.clear();
    } else if (type == 'file-end') {
      _finalizeFile();
    }
  }

  void _handleBinaryChunk(Uint8List bytes) {
    _buffer.addAll(bytes);
    _receivedBytes += bytes.length;
    _progress.add(TransferProgress(
      receivedBytes: _receivedBytes,
      totalBytes: _currentFileSize,
    ));
  }

  void _finalizeFile() {
    _fileReceived.add(ReceivedFile(
      fileName: _currentFilePath ?? 'received-file',
      bytes: Uint8List.fromList(_buffer),
    ));
  }

  Future<void> dispose() async {
    _signalSub?.cancel();
    await _channel?.close();
    await _pc?.close();
    await _progress.close();
    await _fileReceived.close();
  }
}
