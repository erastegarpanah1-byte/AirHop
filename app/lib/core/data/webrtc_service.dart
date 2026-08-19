import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/app_config.dart';
import '../domain/models.dart';
import 'signaling_service.dart';

/// سرویس وب‌رتی‌سی — اتصال P2P از طریق DataChannel + fallback به relay در صورت بسته بودن.
class WebRtcService {
  WebRtcService({required this.signaling, this.role = PeerRole.sender});

  final SignalingService signaling;
  final PeerRole role;

  RTCPeerConnection? _pc;
  RTCDataChannel? _channel;
  StreamSubscription? _signalSub;
  StreamSubscription? _relaySub;

  String? _currentFilePath;
  int _currentFileSize = 0;
  int _receivedBytes = 0;
  IOSink? _sink;
  File? _tempFile;

  // متغیرهای کمکی جدید برای پیگیری و محاسبه واقعی پیشرفت فرستنده از طریق بافر شبکه
  int _currentFileTotalBytes = 0;
  int _currentFileSentToBuffer = 0;

  final StreamController<TransferProgress> _progress =
      StreamController<TransferProgress>.broadcast();
  Stream<TransferProgress> get progress => _progress.stream;

  final StreamController<ReceivedFile> _fileReceived =
      StreamController<ReceivedFile>.broadcast();
  Stream<ReceivedFile> get fileReceived => _fileReceived.stream;

  Future<void> initialize() async {
    final configuration = <String, dynamic>{
      'iceServers': [
        for (final url in AppConfig.iceServers)
          if (url == AppConfig.turnUrl)
            {
              'urls': url,
              'username': AppConfig.turnUsername,
              'credential': AppConfig.turnCredential,
            }
          else
            {'urls': url},
      ],
      'sdpSemantics': 'unified-plan',
    };

    _pc = await createPeerConnection(configuration);

    _pc!.onIceCandidate = (candidate) {
      signaling.send(SignalMessage(type: SignalType.ice, candidate: candidate.toMap()));
    };

    if (role == PeerRole.sender) {
      _channel = await _pc!.createDataChannel('file-transfer', RTCDataChannelInit()..ordered = true);
      _setupChannel();
    } else {
      _pc!.onDataChannel = (channel) {
        _channel = channel;
        _setupChannel();
      };
    }

    _signalSub = signaling.messages.listen(_handleSignal);
    _relaySub = signaling.relayChunks.listen(_onRelayChunk);
  }

  void _setupChannel() {
    _channel!.onMessage = (RTCDataChannelMessage message) {
      if (message.isBinary) {
        _onBinaryChunk(message.binary);
      } else {
        _onTextMessage(message.text);
      }
    };

    // اصلاح درصد پیشرفت واقعی فرستنده بر اساس بایت‌های ارسال شده واقعی روی کارت شبکه (نه صرفاً بایت‌های کپی شده در رم)
    if (role == PeerRole.sender) {
      _channel!.onBufferedAmountChange = (int currentBufferedAmount) {
        if (_currentFileTotalBytes > 0) {
          int actualSentOnNetwork = _currentFileSentToBuffer - currentBufferedAmount;
          if (actualSentOnNetwork < 0) actualSentOnNetwork = 0;
          if (actualSentOnNetwork > _currentFileTotalBytes) actualSentOnNetwork = _currentFileTotalBytes;

          _progress.add(TransferProgress(
            receivedBytes: actualSentOnNetwork,
            totalBytes: _currentFileTotalBytes,
          ));
        }
      };
    }
  }

  Future<void> _handleSignal(SignalMessage message) async {
    switch (message.type) {
      case SignalType.offer:
        await _pc!.setRemoteDescription(RTCSessionDescription(message.sdp, 'offer'));
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        signaling.send(SignalMessage(type: SignalType.answer, sdp: answer.sdp));
        break;
      case SignalType.answer:
        await _pc!.setRemoteDescription(RTCSessionDescription(message.sdp, 'answer'));
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
        if (role == PeerRole.sender) await _createOffer();
        break;
      case SignalType.relayHeader:
        _onRelayHeader(message.payload);
        break;
      case SignalType.relayEnd:
        _finalizeFile();
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

  bool get _p2pReady =>
      _channel != null &&
      _pc?.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
      _channel!.state == RTCDataChannelState.RTCDataChannelOpen;

  Future<void> sendFile(FileMetadata metadata, List<int> content) async {
    if (_p2pReady) {
      try {
        await _sendP2P(metadata, content);
        return;
      } catch (e) {
        // اگر در حین ارسال P2P قطع شد، فوراً فالبک کند به relay سرور تا ارسال قطع نشود
      }
    }
    await _sendRelay(metadata, content);
  }

  Future<void> _sendP2P(FileMetadata metadata, List<int> content) async {
    if (_channel == null ||
        _channel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('DataChannel باز نیست — انتقال P2P ممکن نیست');
    }

    _currentFileTotalBytes = content.length;
    _currentFileSentToBuffer = 0;

    _channel!.send(RTCDataChannelMessage(
      jsonEncode({'type': 'file-header', 'metadata': metadata.toJson()}),
    ));

    final chunkSize = AppConfig.chunkSize;
    int sent = 0;
    final total = content.length;
    while (sent < total) {
      final end = (sent + chunkSize < total) ? sent + chunkSize : total;
      final chunk = Uint8List.fromList(content.sublist(sent, end));
      await _sendChunk(chunk);
      sent = end;
      _currentFileSentToBuffer = sent;
      
      // بروزرسانی موقت محلی در صورت بروز هرگونه تغییرات سریع یا تاخیر رویداد بافر
      final buffered = _channel!.bufferedAmount ?? 0;
      int actualSent = sent - buffered;
      if (actualSent < 0) actualSent = 0;
      if (actualSent > total) actualSent = total;
      
      _progress.add(TransferProgress(receivedBytes: actualSent, totalBytes: total));
    }
    _channel!.send(RTCDataChannelMessage(jsonEncode({'type': 'file-end'})));
  }

  Future<void> _sendRelay(FileMetadata metadata, List<int> content) async {
    _currentFileTotalBytes = content.length;
    _currentFileSentToBuffer = 0;

    signaling.send(SignalMessage(
      type: SignalType.relayHeader,
      payload: metadata.toJson(),
    ));

    final chunkSize = AppConfig.chunkSize;
    int sent = 0;
    final total = content.length;
    while (sent < total) {
      final end = (sent + chunkSize < total) ? sent + chunkSize : total;
      final chunk = Uint8List.fromList(content.sublist(sent, end));
      signaling.sendRelayChunk(chunk);
      sent = end;
      _currentFileSentToBuffer = sent;
      _progress.add(TransferProgress(receivedBytes: sent, totalBytes: total));
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    signaling.send(const SignalMessage(type: SignalType.relayEnd));
  }

  Future<void> _sendChunk(Uint8List data) async {
    // Backpressure: جلوگیری از کرش کلاینت در صورتی که بافر وب‌رتی‌سی پر از دیتا شده باشد
    while (_channel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      final buffered = _channel!.bufferedAmount;
      if (buffered == null || buffered <= 4 * 1024 * 1024) break;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (_channel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('DataChannel بسته شد — ارسال بایت‌ها لغو گردید');
    }
    _channel!.send(RTCDataChannelMessage.fromBinary(data));
    await Future<void>.delayed(Duration.zero);
  }

  void _onTextMessage(String text) {
    final Map<String, dynamic> json = jsonDecode(text) as Map<String, dynamic>;
    final type = json['type'] as String?;
    if (type == 'file-header') {
      final metadata = FileMetadata.fromJson(json['metadata'] as Map<String, dynamic>);
      _currentFilePath = metadata.name;
      _currentFileSize = metadata.size;
      _receivedBytes = 0;
      _openTempFile();
    } else if (type == 'file-end') {
      _finalizeFile();
    }
  }

  void _onRelayHeader(Map<String, dynamic>? payload) {
    if (payload == null) return;
    final metadata = FileMetadata.fromJson(payload);
    _currentFilePath = metadata.name;
    _currentFileSize = metadata.size;
    _receivedBytes = 0;
    _openTempFile();
  }

  void _onBinaryChunk(Uint8List bytes) => _appendChunk(bytes);

  void _onRelayChunk(Uint8List bytes) => _appendChunk(bytes);

  void _openTempFile() {
    _sink?.close();
    _tempFile = File(
      '${Directory.systemTemp.path}/airhop_recv_${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    _sink = _tempFile!.openWrite();
  }

  void _appendChunk(Uint8List bytes) {
    _sink?.add(bytes);
    _receivedBytes += bytes.length;
    _progress.add(TransferProgress(
      receivedBytes: _receivedBytes,
      totalBytes: _currentFileSize,
    ));
  }

  Future<void> _finalizeFile() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    final f = _tempFile;
    _tempFile = null;
    if (f == null) return;

    final name = _currentFilePath ?? 'received-file';

    _fileReceived.add(ReceivedFile(fileName: name, tempFilePath: f.path));
  }

  Future<void> dispose() async {
    _signalSub?.cancel();
    _relaySub?.cancel();
    await _sink?.close();
    try {
      if (_tempFile != null) await _tempFile!.delete();
    } catch (_) {}
    await _channel?.close();
    await _pc?.close();
    await _progress.close();
    await _fileReceived.close();
  }
}