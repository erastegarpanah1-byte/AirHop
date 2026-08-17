import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../domain/models.dart';

/// نوع پیام‌های سیگنالینگ بین دو peer.
enum SignalType {
  offer,
  answer,
  ice,
  ready,
  welcome,
  peerLeft,
  error,
  deviceInfo,
  relayHeader,
  relayEnd,
}

/// یک پیام سیگنالینگ.
class SignalMessage {
  const SignalMessage({required this.type, this.sdp, this.candidate, this.payload});

  final SignalType type;
  final String? sdp;
  final Map<String, dynamic>? candidate;
  final Map<String, dynamic>? payload;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (sdp != null) 'sdp': sdp,
        if (candidate != null) 'candidate': candidate,
        if (payload != null) 'payload': payload,
      };

  factory SignalMessage.fromJson(Map<String, dynamic> json) => SignalMessage(
        type: SignalType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => SignalType.error,
        ),
        sdp: json['sdp'] as String?,
        candidate: json['candidate'] as Map<String, dynamic>?,
        payload: json['payload'] as Map<String, dynamic>?,
      );
}

/// نتایج اتصال به سرور سیگنالینگ.
class RoomInfo {
  const RoomInfo({
    required this.code,
    required this.peerId,
    required this.role,
    required this.peerCount,
    required this.roomReady,
  });

  final String code;
  final String peerId;
  final String role;
  final int peerCount;
  final bool roomReady;
}

/// وب‌سوکت کلاینت به سرور سیگنالینگ، با پشتیبانی از چند سرور (fallback).
class SignalingService {
  SignalingService({this.server = AppConfig.signalingServer});

  final String server;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  String? _peerId;
  String? _role;
  String? _activeServer;

  bool get isConnected => _channel != null;

  final StreamController<SignalMessage> _messages =
      StreamController<SignalMessage>.broadcast();
  Stream<SignalMessage> get messages => _messages.stream;

  final StreamController<RoomInfo> _events = StreamController<RoomInfo>.broadcast();
  Stream<RoomInfo> get events => _events.stream;

  final StreamController<DeviceInfo> _peerDevice =
      StreamController<DeviceInfo>.broadcast();
  Stream<DeviceInfo> get peerDevice => _peerDevice.stream;

  final StreamController<Uint8List> _relayChunks =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get relayChunks => _relayChunks.stream;

  void sendDeviceInfo(DeviceInfo device) {
    send(SignalMessage(type: SignalType.deviceInfo, payload: device.toJson()));
  }

  /// ساخت اتاق — از سرور اصلی، و در صورت خطا از سرورهای fallback.
  Future<String> createRoom() async {
    final servers = [server, ...AppConfig.fallbackSignalingServers];
    Object? lastError;
    for (final s in servers) {
      try {
        final code = await _createRoomOn(s);
        _activeServer = s;
        return code;
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('createRoom failed on all servers: $lastError');
  }

  Future<String> _createRoomOn(String server) async {
    final uri = Uri.parse('$server/room');
    final response = await http.post(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('createRoom failed: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['code'] as String;
  }

  /// اتصال وب‌سوکت به اتاق.
  Future<void> joinRoom(String code, {required String role}) async {
    final base = _activeServer ?? server;
    final wsUri = Uri.parse(
      '$base/room/$code/ws?role=$role'
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://'),
    );
    _channel = WebSocketChannel.connect(wsUri);
    _role = role;

    _sub = _channel!.stream.listen(
      (dynamic data) {
        if (data is String) {
          final Map<String, dynamic> json =
              jsonDecode(data) as Map<String, dynamic>;
          _handleMessage(json);
        } else if (data is List<int>) {
          _relayChunks.add(Uint8List.fromList(data));
        }
      },
      onError: (Object e) => _messages.addError(e),
      onDone: () => _events.add(const RoomInfo(
        code: '', peerId: '', role: '', peerCount: 0, roomReady: false,
      )),
    );
  }

  /// ارسال چانک باینری از طریق سرور (fallback relay).
  void sendRelayChunk(Uint8List chunk) {
    _channel?.sink.add(chunk);
  }

  void _handleMessage(Map<String, dynamic> json) {
    final String? type = json['type'] as String?;

    if (type == 'welcome') {
      _peerId = json['peerId'] as String?;
      _events.add(RoomInfo(
        code: '',
        peerId: _peerId ?? '',
        role: _role ?? '',
        peerCount: json['peerCount'] as int? ?? 0,
        roomReady: json['roomReady'] as bool? ?? false,
      ));
      return;
    }

    if (type == 'ready') {
      _events.add(RoomInfo(
        code: '',
        peerId: _peerId ?? '',
        role: _role ?? '',
        peerCount: 2,
        roomReady: true,
      ));
      // تصحیح مهم: sender باید از طریق messages بتواند offer بسازد.
      _messages.add(const SignalMessage(type: SignalType.ready));
      return;
    }

    final signal = SignalMessage.fromJson(json);

    if (signal.type == SignalType.deviceInfo && signal.payload != null) {
      _peerDevice.add(DeviceInfo.fromJson(signal.payload!));
      return;
    }

    _messages.add(signal);
  }

  void send(SignalMessage message) {
    _channel?.sink.add(jsonEncode(message.toJson()));
  }

  void dispose() {
    _sub?.cancel();
    _channel?.sink.close();
    _messages.close();
    _events.close();
    _peerDevice.close();
    _relayChunks.close();
  }
}
