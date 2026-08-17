/// پیکربندی سراسری برای اتصال به سرور سیگنالینگ و TURN.
class AppConfig {
  AppConfig._();

  /// آدرس سرور سیگنالینگ اصلی — سرور ایران (مسیر داخلی، سریع و بدون فیلترینگ).
  /// فعلاً HTTP/WS چون هنوز دامنه و TLS نداریم.
  static const signalingServer = 'http://45.156.186.140:8080';

  /// سرورهای سیگنالینگ جایگزین (اولویت بعد از سرور اصلی).
  static const fallbackSignalingServers = <String>[
    'http://45.156.186.140:8787',
    'https://airhop-signaling.e-rastegarpanah1.workers.dev',
  ];

  /// TURN server (برای عبور از NAT سخت).
  static const turnUrl = 'turn:181.41.194.56:3478';
  static const turnUsername = 'airhop';
  static const turnCredential = 'AirhopTurn2026!';

  static const pairingCodeLength = 6;
  static const chunkSize = 64 * 1024; // 64 KB

  /// STUN + TURN سرورها برای NAT traversal.
  static const iceServers = [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
    turnUrl,
  ];
}
