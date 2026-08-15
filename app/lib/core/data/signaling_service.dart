import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';

enum SignalType { offer, answer, ice, ready, welcome, peerLeft, error }

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
        type: SignalType.values.firstWhere((t) => t.name == json['type'], orElse: () => SignalType.error),
        sdp: json['sdp'] as String?,
        candidate: json['candidate'] as Map<String, dynamic>?,
        payload: json['payload'] as Map<String, dynamic>?,
      );
}

class RoomInfo {
  const RoomInfo({required this.code, required this.peerId, required this.role, required this.peerCount, required this.roomReady});

  final String code;
  final String peerId;
  final String role;
  final int peerCount;
  final bool roomReady;
}

class SignalingService {
  SignalingService({this.server = AppConfig.signalingServer});

  final String server;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  String? _peerId;
  String? _role;

  bool get isConnected => _channel != null;

  final _messages = StreamController<SignalMessage>.broadcast();
  Stream<SignalMessage> get messages => _messages.stream;

  final _events = StreamController<RoomInfo>.broadcast();
  Stream<RoomInfo> get events => _events.stream;

  Future<String> createRoom() async {
    final uri = _toHttp('$server/room');
    final response = await _httpPost(uri);
    final body = jsonDecode(response);
    final code = body['code'] as String;
    return code;
  }

  Future<void> joinRoom(String code, {required String role}) async {
    final wsUri = _toWs('$server/room/$code/ws?role=$role');
    _channel = WebSocketChannel.connect(Uri.parse(wsUri));
    _role = role;

    _sub = _channel!.stream.listen(
      (dynamic data) {
        if (data is String) {
          final json = jsonDecode(data) as Map<String, dynamic>;
          _handleMessage(json);
        }
      },
      onError: (Object e) => _messages.addError(e),
      onDone: () => _events.add(const RoomInfo(code: '', peerId: '', role: '', peerCount: 0, roomReady: false)),
    );
  }

  void _handleMessage(Map<String, dynamic> json) {
    final type = json['type'] as String?;

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
      _events.add(RoomInfo(code: '', peerId: _peerId ?? '', role: _role ?? '', peerCount: 2, roomReady: true));
      return;
    }

    final signal = SignalMessage.fromJson(json);
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
  }

  Uri _toWs(String url) => Uri.parse(url.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://'));
  Uri _toHttp(String url) => Uri.parse(url);

  Future<String> _httpPost(Uri uri) async {
    throw UnimplementedError('HTTP POST باید با package:http پیاده‌سازی شود.');
  }
}
