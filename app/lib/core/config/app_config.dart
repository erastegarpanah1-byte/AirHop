/// پیکربندی سراسری برای اتصال به سرور سیگنالینگ و TURN.
class AppConfig {
  AppConfig._();

  /// آدرس سرور سیگنالینگ اصلی (سرور ایران).
  static const signalingServer = 'https://45.156.186.140:8787';

  /// سرورهای سیگنالینگ جایگزین (اولویت بعد از سرور اصلی).
  static const fallbackSignalingServers = [
    'https://airhop-signaling.e-rastegarpanah1.workers.dev',
  ];

  /// TURN server (برای عبور از NAT سخت).
  static const turnUrl = 'turn:45.156.186.140:3478';
  static const turnUsername = 'airhop';
  static const turnCredential = 'CHANGE_ME_TURN_PASSWORD';

  static const pairingCodeLength = 6;
  static const chunkSize = 64 * 1024; // 64 KB

  /// STUN + TURN سرورها برای NAT traversal.
  static const iceServers = [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
    turnUrl,
  ];
}
