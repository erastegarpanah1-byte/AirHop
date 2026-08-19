import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// نتیجه‌ی بررسی اتصال اینترنت.
enum ConnectivityStatus {
  checking,
  online,
  offline,
}

/// بررسی و پایش اتصال اینترنت.
class ConnectivityNotifier extends StateNotifier<ConnectivityStatus> {
  ConnectivityNotifier() : super(ConnectivityStatus.checking) {
    _init();
  }

  Timer? _timer;

  Future<void> _init() async {
    await _check();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  Future<void> _check() async {
    final bool online = await _pingServer();
    if (!mounted) return;
    state = online ? ConnectivityStatus.online : ConnectivityStatus.offline;
  }

  Future<bool> _pingServer() async {
    final String url =
        '${AppConfig.signalingServer.replaceFirst(RegExp(r'/$'), '')}/health';
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 4000);
      try {
        final req = await client
            .getUrl(Uri.parse(url))
            .timeout(const Duration(milliseconds: 4000));
        final resp =
            await req.close().timeout(const Duration(milliseconds: 4000));
        return resp.statusCode == 200;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityStatus>((ref) {
  return ConnectivityNotifier();
});
