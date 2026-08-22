import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/io_client.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../domain/models.dart';

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
  fileAck,
  fileNack,
}

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

class SignalingService {
  SignalingService({this.server = AppConfig.signalingServer});

  final String server;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  String? _peerId;
  String? _role;
  String? _activeServer;

  bool get isConnected => _channel != null;
  bool _closedIntentionally = false;

  final List<SignalMessage> _replayed = [];
  final StreamController<SignalMessage> _messages = StreamController<SignalMessage>.broadcast();
  Stream<SignalMessage> get messages => _messages.stream;

  final StreamController<RoomInfo> _events = StreamController<RoomInfo>.broadcast();
  Stream<RoomInfo> get events => _events.stream;

  final StreamController<DeviceInfo> _peerDevice = StreamController<DeviceInfo>.broadcast();
  Stream<DeviceInfo> get peerDevice => _peerDevice.stream;

  final StreamController<Uint8List> _relayChunks = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get relayChunks => _relayChunks.stream;

  final StreamController<String> _errors = StreamController<String>.broadcast();
  Stream<String> get errors => _errors.stream;

  void _log(String m) => print('[AirHop-signaling] $m');

  void sendDeviceInfo(DeviceInfo device) {
    send(SignalMessage(type: SignalType.deviceInfo, payload: device.toJson()));
  }

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
    final client = _buildClient();
    try {
      final response = await client.post(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw Exception('createRoom failed: ${response.statusCode}');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['code'] as String;
    } finally {
      client.close();
    }
  }

  IOClient _buildClient() {
    final io = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(io);
  }

  Future<void> joinRoom(String code, {required String role}) async {
    final bases = <String>[
      if (_activeServer != null) _activeServer!,
      server,
      ...AppConfig.fallbackSignalingServers,
    ];
    final seen = <String>{};
    final unique = <String>[];
    for (final b in bases) {
      if (seen.add(b)) unique.add(b);
    }

    Object? lastErr;
    for (final base in unique) {
      try {
        await _joinRoomOn(base, code, role);
        _activeServer = base;
        _log('joined via $base');
        return;
      } catch (e) {
        _log('join failed on $base: $e');
        lastErr = e;
      }
    }
    throw Exception('joinRoom failed on all servers: $lastErr');
  }

  Future<void> _joinRoomOn(String base, String code, String role) async {
    final wsUri = Uri.parse(
      '$base/room/$code/ws?role=$role'
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://'),
    );
    _log('connecting to $wsUri');

    final httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        _log('accepting cert for $host');
        return true;
      };

    final socket = await WebSocket.connect(
      wsUri.toString(),
      customClient: httpClient,
    ).timeout(const Duration(seconds: 15));

    _channel = IOWebSocketChannel(socket);
    _role = role;
    _closedIntentionally = false;

    await _sub?.cancel();
    _sub = _channel!.stream.listen(
      (dynamic data) {
        if (data is String) {
          try {
            _handleMessage(jsonDecode(data) as Map<String, dynamic>);
          } catch (e) {
            _log('invalid websocket JSON: $e');
          }
        } else if (data is List<int>) {
          _relayChunks.add(Uint8List.fromList(data));
        }
      },
      onError: (Object e) {
        _log('ws error: $e');
        _errors.add('WebSocket error: $e');
        _messages.addError(e);
      },
      onDone: () {
        _sub = null;
        _channel = null;
        _peerId = null;
        if (_closedIntentionally) {
          _log('ws closed (intentional)');
          return;
        }
        _log('ws done (room/session closed)');
        _errors.add('اتصال اتاق قطع یا حذف شد');
        _events.add(const RoomInfo(
          code: '',
          peerId: '',
          role: '',
          peerCount: 0,
          roomReady: false,
        ));
      },
      cancelOnError: false,
    );
  }

  void sendRelayChunk(Uint8List chunk) {
    if (!isConnected) throw StateError('اتصال سیگنالینگ قطع شده است');
    _channel!.sink.add(chunk);
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
      final ready = const SignalMessage(type: SignalType.ready);
      _events.add(RoomInfo(
        code: '',
        peerId: _peerId ?? '',
        role: _role ?? '',
        peerCount: 2,
        roomReady: true,
      ));
      _messages.add(ready);
      _replayed.add(ready);
      return;
    }

    if (type == 'peer-left') {
      _log('peer-left received');
      _messages.add(const SignalMessage(type: SignalType.peerLeft));
      _events.add(RoomInfo(
        code: '',
        peerId: _peerId ?? '',
        role: _role ?? '',
        peerCount: 1,
        roomReady: false,
      ));
      _closeAfterPeerLeft();
      return;
    }

    final signal = SignalMessage.fromJson(json);
    if (signal.type == SignalType.deviceInfo && signal.payload != null) {
      _peerDevice.add(DeviceInfo.fromJson(signal.payload!));
      return;
    }

    _messages.add(signal);
    _replayed.add(signal);
  }

  void _closeAfterPeerLeft() {
    if (_closedIntentionally) return;
    _closedIntentionally = true;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    _peerId = null;
  }

  Stream<SignalMessage> replayMessages() async* {
    for (final m in List<SignalMessage>.from(_replayed)) {
      yield m;
    }
    yield* _messages.stream;
  }

  void send(SignalMessage message) {
    if (!isConnected) return;
    try {
      _channel!.sink.add(jsonEncode(message.toJson()));
    } catch (e) {
      _log('send failed: $e');
    }
  }

  void dispose() {
    _closedIntentionally = true;
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _peerId = null;
    _messages.close();
    _events.close();
    _peerDevice.close();
    _relayChunks.close();
    _errors.close();
  }
}
