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

  // پیشرفت واقعی فرستنده: تنها معیار درست میزان بایت‌هایی است که از بافر شبکه خارج شده‌اند.
  int _senderTotalBytes = 0;
  int _senderPushedToBuffer = 0;
  bool _senderFileActive = false;

  Completer<void> _ackCompleter = Completer<void>();

  final StreamController<TransferProgress> _progress =
      StreamController<TransferProgress>.broadcast();
  Stream<TransferProgress> get progress => _progress.stream;

  final StreamController<ReceivedFile> _fileReceived =
      StreamController<ReceivedFile>.broadcast();
  Stream<ReceivedFile> get fileReceived => _fileReceived.stream;

  bool get _p2pReady =>
      _channel != null &&
      _pc?.connectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
      _channel!.state == RTCDataChannelState.RTCDataChannelOpen;

  bool get p2pReady => _p2pReady;

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
      signaling.send(
          SignalMessage(type: SignalType.ice, candidate: candidate.toMap()));
    };

    if (role == PeerRole.sender) {
      _channel = await _pc!
          .createDataChannel('file-transfer', RTCDataChannelInit()..ordered = true);
      _setupChannel();
    } else {
      _pc!.onDataChannel = (channel) {
        _channel = channel;
        _setupChannel();
      };
    }

    _signalSub = signaling.replayMessages().listen(_handleSignal);
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

    if (role == PeerRole.sender) {
      _channel!.onBufferedAmountChange =
          (int currentAmount, int changedAmount) {
        if (!_senderFileActive || _senderTotalBytes <= 0) return;
        final int actuallySent = _senderPushedToBuffer - currentAmount;
        final int clamped = actuallySent < 0
            ? 0
            : (actuallySent > _senderTotalBytes
                ? _senderTotalBytes
                : actuallySent);
        _progress.add(TransferProgress(
          receivedBytes: clamped,
          totalBytes: _senderTotalBytes,
        ));
      };
    }
  }

  Future<void> _handleSignal(SignalMessage message) async {
    switch (message.type) {
      case SignalType.offer:
        await _pc!.setRemoteDescription(
            RTCSessionDescription(message.sdp, 'offer'));
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        signaling.send(SignalMessage(type: SignalType.answer, sdp: answer.sdp));
        break;
      case SignalType.answer:
        await _pc!.setRemoteDescription(
            RTCSessionDescription(message.sdp, 'answer'));
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
      case SignalType.fileAck:
        if (role == PeerRole.sender && !_ackCompleter.isCompleted) {
          _ackCompleter.complete();
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

  Future<void> sendFile(FileMetadata metadata,
      {List<int>? content, String? path}) async {
    if (metadata.size <= 0) throw StateError('فایل خالی است');

    if (_p2pReady) {
      try {
        await _sendP2P(metadata, content: content, path: path);
        return;
      } catch (_) {
        rethrow;
      }
    }
    await _sendRelay(metadata, content: content, path: path);
  }

  Future<void> _sendP2P(FileMetadata metadata,
      {List<int>? content, String? path}) async {
    if (_channel == null ||
        _channel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('DataChannel باز نیست — انتقال P2P ممکن نیست');
    }

    if (_ackCompleter.isCompleted) {
      _ackCompleter = Completer<void>();
    }

    final int total = metadata.size;
    _senderTotalBytes = total;
    _senderPushedToBuffer = 0;
    _senderFileActive = true;

    _channel!.send(RTCDataChannelMessage(
      jsonEncode({'type': 'file-header', 'metadata': metadata.toJson()}),
    ));

    final chunkSize = AppConfig.chunkSize;
    int sent = 0;

    RandomAccessFile? raf;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      raf = await File(path).open();
    }

    try {
      while (sent < total) {
        final int end = (sent + chunkSize < total) ? sent + chunkSize : total;
        final int len = end - sent;
        Uint8List chunk;
        if (raf != null) {
          chunk = Uint8List(len);
          await raf.readInto(chunk, sent, 0, len);
        } else {
          chunk = Uint8List.fromList(content!.sublist(sent, end));
        }
        await _sendChunk(chunk);
        sent = end;
        _senderPushedToBuffer = sent;
      }

      _channel!.send(RTCDataChannelMessage(jsonEncode({'type': 'file-end'})));

      await Future.any([
        _ackCompleter.future,
        Future<void>.delayed(const Duration(seconds: 15)),
      ]);
    } finally {
      await raf?.close();
      _senderFileActive = false;
    }

    final int buffered = _channel!.bufferedAmount ?? 0;
    int actuallySent = _senderPushedToBuffer - buffered;
    if (actuallySent < 0) actuallySent = 0;
    if (actuallySent > total) actuallySent = total;
    _progress.add(
        TransferProgress(receivedBytes: actuallySent, totalBytes: total));
  }

  Future<void> _sendRelay(FileMetadata metadata,
      {List<int>? content, String? path}) async {
    final int total = metadata.size;

    if (_ackCompleter.isCompleted) {
      _ackCompleter = Completer<void>();
    }

    _senderTotalBytes = total;
    _senderPushedToBuffer = 0;
    _senderFileActive = true;

    signaling.send(SignalMessage(
      type: SignalType.relayHeader,
      payload: metadata.toJson(),
    ));

    final chunkSize = AppConfig.chunkSize;
    int sent = 0;

    RandomAccessFile? raf;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      raf = await File(path).open();
    }

    try {
      while (sent < total) {
        final int end = (sent + chunkSize < total) ? sent + chunkSize : total;
        final int len = end - sent;
        Uint8List chunk;
        if (raf != null) {
          chunk = Uint8List(len);
          await raf.readInto(chunk, sent, 0, len);
        } else {
          chunk = Uint8List.fromList(content!.sublist(sent, end));
        }
        signaling.sendRelayChunk(chunk);
        sent = end;
        _senderPushedToBuffer = sent;
        _progress.add(TransferProgress(receivedBytes: sent, totalBytes: total));
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      signaling.send(const SignalMessage(type: SignalType.relayEnd));

      await Future.any([
        _ackCompleter.future,
        Future<void>.delayed(const Duration(seconds: 15)),
      ]);
    } finally {
      await raf?.close();
      _senderFileActive = false;
    }
  }

  Future<void> _sendChunk(Uint8List data) async {
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
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = json['type'] as String?;
    if (type == 'file-header') {
      final metadata =
          FileMetadata.fromJson(json['metadata'] as Map<String, dynamic>);
      _currentFilePath = metadata.name;
      _currentFileSize = metadata.size;
      _receivedBytes = 0;
      _openTempFile();
    } else if (type == 'file-end') {
      _finalizeFile();
    } else if (type == 'file-ack') {
      if (role == PeerRole.sender && !_ackCompleter.isCompleted) {
        _ackCompleter.complete();
      }
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

    _sendAck();

    _fileReceived.add(ReceivedFile(fileName: name, tempFilePath: f.path));
  }

  void _sendAck() {
    if (_channel != null &&
        _channel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _channel!.send(RTCDataChannelMessage(jsonEncode({'type': 'file-ack'})));
    } else {
      signaling.send(const SignalMessage(type: SignalType.fileAck));
    }
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
