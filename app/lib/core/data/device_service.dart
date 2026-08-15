import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';

/// سرویس شناسایی اسم دستگاه + پلتفرم.
class DeviceService {
  const DeviceService();

  /// خواندن خودکار اسم دستگاه و پلتفرم جاری.
  Future<DeviceInfo> detect() async {
    final info = DeviceInfoPlugin();

    if (Platform.isWindows) {
      final d = await info.windowsInfo;
      return DeviceInfo(name: d.computerName, platform: 'windows');
    }
    if (Platform.isLinux) {
      final d = await info.linuxInfo;
      return DeviceInfo(name: d.prettyName.isNotEmpty ? d.prettyName : 'Linux', platform: 'linux');
    }
    if (Platform.isMacOS) {
      final d = await info.macOsInfo;
      return DeviceInfo(name: d.computerName, platform: 'macos');
    }
    if (Platform.isAndroid) {
      final d = await info.androidInfo;
      final model = d.model.isNotEmpty ? d.model : d.device;
      return DeviceInfo(name: model, platform: 'android');
    }
    if (Platform.isIOS) {
      final d = await info.iosInfo;
      return DeviceInfo(name: d.name.isNotEmpty ? d.name : d.model, platform: 'ios');
    }
    return const DeviceInfo(name: 'دستگاه', platform: 'web');
  }

  /// اسم پلتفرم به صورت خوانا.
  static String platformLabel(String platform) {
    switch (platform) {
      case 'android':
        return 'Android';
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'linux':
        return 'Linux';
      case 'ios':
        return 'iOS';
      default:
        return platform;
    }
  }
}

/// سرویس (provider) برای detect دستگاه.
final deviceServiceProvider = Provider<DeviceService>((ref) => const DeviceService());

/// نگه‌داری DeviceInfo جاری (detect + rename).
class DeviceNotifier extends StateNotifier<DeviceInfo> {
  DeviceNotifier(this._service) : super(const DeviceInfo(name: '', platform: '')) {
    _init();
  }

  final DeviceService _service;

  Future<void> _init() async {
    try {
      state = await _service.detect();
    } catch (_) {
      state = const DeviceInfo(name: 'دستگاه', platform: 'unknown');
    }
  }

  /// تغییر دستی نام دستگاه.
  void rename(String name) {
    state = DeviceInfo(name: name, platform: state.platform);
  }

  /// صبر کردن تا detect کامل شود و DeviceInfo معتبر برگردد.
  Future<DeviceInfo> ensureReady() async {
    if (state.name.isNotEmpty) return state;
    // منتظر completion _init
    for (var i = 0; i < 50 && state.name.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return state.name.isEmpty
        ? const DeviceInfo(name: 'دستگاه', platform: 'unknown')
        : state;
  }
}

final deviceProvider = StateNotifierProvider<DeviceNotifier, DeviceInfo>((ref) {
  return DeviceNotifier(ref.read(deviceServiceProvider));
});
