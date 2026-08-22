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
          if (url == AppConfig.turnUrl && url.isNotEmpty)
            {
              'urls': url,
              'username': AppConfig.turnUsername,
              'credential': AppConfig.turnCredential,
            }
          else if (url.isNotEmpty)
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
    try {
      switch (message.type) {
        case SignalType.offer:
          await _pc!.setRemoteDescription(
              RTCSessionDescription(message.sdp, 'offer'));
          final answer = await _pc!.createAnswer();
          await _pc!.setLocalDescription(answer);
          signaling.send(
              SignalMessage(type: SignalType.answer, sdp: answer.sdp));
          break;
        case SignalType.answer:
          await _pc!.setRemoteDescription(
              RTCSessionDescription(message.sdp, 'answer'));
          break;
        case SignalType.ice:
          final candidateMap = message.candidate;
          if (candidateMap == null || candidateMap['candidate'] == null) {
            break;
          }
          final candidate = RTCIceCandidate(
            candidateMap['candidate'] as String,
            candidateMap['sdpMid'] as String?,
            candidateMap['sdpMLineIndex'] as int?,
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
          unawaited(_finalizeFile());
          break;
        case SignalType.fileAck:
          if (role == PeerRole.sender && !_ackCompleter.isCompleted) {
            _ackCompleter.complete();
          }
          break;
        case SignalType.fileNack:
          if (role == PeerRole.sender && !_ackCompleter.isCompleted) {
            final reason = message.payload?['reason']?.toString() ??
                'گیرنده فایل کامل دریافت نکرد';
            _ackCompleter.completeError(
                StateError('تأیید انتقال ناموفق بود: $reason'));
          }
          break;
        default:
          break;
      }
    } catch (e) {
      if (role == PeerRole.sender && !_ackCompleter.isCompleted) {
        _ackCompleter.completeError(e);
      }
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
      await _sendP2P(metadata, content: content, path: path);
      return;
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

    try {
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (!await file.exists()) throw StateError('فایل پیدا نشد: $path');
        final actualSize = await file.length();
        if (actualSize != total) {
          throw StateError(
              'اندازه فایل تغییر کرده است ($actualSize != $total)');
        }
        raf = await file.open();
      } else {
        if (content == null || content.length != total) {
          throw StateError('محتوای فایل با metadata سازگار نیست');
        }
      }

      while (sent < total) {
        final int end = (sent + chunkSize < total) ? sent + chunkSize : total;
        final int len = end - sent;
        Uint8List chunk;
        if (raf != null) {
          chunk = Uint8List(len);
          final read = await raf.readInto(chunk);
          if (read != len) {
            throw StateError('خواندن فایل ناقص بود ($read/$len bytes)');
          }
        } else {
          chunk = Uint8List.fromList(content!.sublist(sent, end));
        }
        await _sendChunk(chunk);
        sent = end;
        _senderPushedToBuffer = sent;
      }

      if (_channel!.state != RTCDataChannelState.RTCDataChannelOpen) {
        throw StateError('DataChannel قبل از پایان انتقال بسته شد');
      }
      _channel!.send(RTCDataChannelMessage(jsonEncode({'type': 'file-end'})));

      await Future.any([
        _ackCompleter.future,
        Future<void>.delayed(const Duration(seconds: 20)).then((_) {
          throw TimeoutException('تأیید دریافت فایل از دستگاه مقصد دریافت نشد');
        }),
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
    RandomAccessFile? raf;

    try {
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (!await file.exists()) throw StateError('فایل پیدا نشد: $path');
        final actualSize = await file.length();
        if (actualSize != total) {
          throw StateError(
              'اندازه فایل تغییر کرده است ($actualSize != $total)');
        }
        raf = await file.open();
      } else if (content == null || content.length != total) {
        throw StateError('محتوای فایل با metadata سازگار نیست');
      }

      signaling.send(SignalMessage(
        type: SignalType.relayHeader,
        payload: metadata.toJson(),
      ));

      final chunkSize = AppConfig.chunkSize;
      int sent = 0;
      while (sent < total) {
        final int end = (sent + chunkSize < total) ? sent + chunkSize : total;
        final int len = end - sent;
        Uint8List chunk;
        if (raf != null) {
          chunk = Uint8List(len);
          final read = await raf.readInto(chunk);
          if (read != len) {
            throw StateError('خواندن فایل ناقص بود ($read/$len bytes)');
          }
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
        Future<void>.delayed(const Duration(seconds: 20)).then((_) {
          throw TimeoutException('تأیید دریافت فایل از دستگاه مقصد دریافت نشد');
        }),
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
      try {
        final metadata =
            FileMetadata.fromJson(json['metadata'] as Map<String, dynamic>);
        _currentFilePath = metadata.name;
        _currentFileSize = metadata.size;
        _receivedBytes = 0;
        _openTempFile();
      } catch (_) {
        _sendNack('metadata نامعتبر است');
      }
    } else if (type == 'file-end') {
      unawaited(_finalizeFile());
    } else if (type == 'file-ack') {
      if (role == PeerRole.sender && !_ackCompleter.isCompleted) {
        _ackCompleter.complete();
      }
    } else if (type == 'file-nack') {
      if (role == PeerRole.sender && !_ackCompleter.isCompleted) {
        final reason = json['reason']?.toString() ?? 'دریافت ناقص بود';
        _ackCompleter.completeError(StateError(reason));
      }
    }
  }

  void _onRelayHeader(Map<String, dynamic>? payload) {
    if (payload == null) return;
    try {
      final metadata = FileMetadata.fromJson(payload);
      _currentFilePath = metadata.name;
      _currentFileSize = metadata.size;
      _receivedBytes = 0;
      _openTempFile();
    } catch (_) {
      _sendNack('metadata نامعتبر است');
    }
  }

  void _onBinaryChunk(Uint8List bytes) => _appendChunk(bytes);

  void _onRelayChunk(Uint8List bytes) => _appendChunk(bytes);

  void _openTempFile() {
    unawaited(_sink?.close());
    _tempFile = File(
      '${Directory.systemTemp.path}/airhop_recv_${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    _sink = _tempFile!.openWrite();
  }

  void _appendChunk(Uint8List bytes) {
    if (_sink == null || _currentFileSize <= 0) return;
    if (_receivedBytes + bytes.length > _currentFileSize) {
      _sendNack('تعداد بایت‌های دریافتی بیشتر از اندازه اعلام‌شده است');
      return;
    }
    _sink!.add(bytes);
    _receivedBytes += bytes.length;
    _progress.add(TransferProgress(
      receivedBytes: _receivedBytes,
      totalBytes: _currentFileSize,
    ));
  }

  Future<void> _finalizeFile() async {
    final expected = _currentFileSize;
    final received = _receivedBytes;
    final f = _tempFile;

    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    _tempFile = null;

    if (f == null) {
      _sendNack('فایل موقت پیدا نشد');
      return;
    }

    if (received != expected) {
      try {
        await f.delete();
      } catch (_) {}
      _sendNack('انتقال ناقص است: $received/$expected bytes');
      return;
    }

    final actualSize = await f.length();
    if (actualSize != expected) {
      try {
        await f.delete();
      } catch (_) {}
      _sendNack('فایل ذخیره‌شده ناقص است: $actualSize/$expected bytes');
      return;
    }

    final name = _currentFilePath ?? 'received-file';
    _sendAck();
    _fileReceived.add(ReceivedFile(fileName: name, tempFilePath: f.path));
  }

  void _sendNack(String reason) {
    final payload = {'reason': reason};
    if (_channel != null &&
        _channel!.state == RTCDataChannelState.RTCDataChannelStateOpen) {
      _channel!.send(RTCDataChannelMessage(
          jsonEncode({'type': 'file-nack', ...payload})));
    } else if (signaling.isConnected) {
      signaling.send(SignalMessage(type: SignalType.fileNack, payload: payload));
    }
  }

  void _sendAck() {
    if (_channel != null &&
        _channel!.state == RTCDataChannelState.RTCDataChannelStateOpen) {
      _channel!.send(RTCDataChannelMessage(jsonEncode({'type': 'file-ack'})));
    } else if (signaling.isConnected) {
      signaling.send(const SignalMessage(type: SignalType.fileAck));
    }
  }

  Future<void> dispose() async {
    await _signalSub?.cancel();
    await _relaySub?.cancel();
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
