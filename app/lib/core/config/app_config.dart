/// پیکربندی سراسری برای اتصال به سرور سیگنالینگ و TURN.
class AppConfig {
  AppConfig._();

  /// آدرس سرور سیگنالینگ اصلی (سرور deployment).
  /// سرور از طریق nginx روی پورت 443 با TLS (wss) سرو داده می‌شود،
  /// بنابراین باید https (و به تبع آن wss) استفاده شود.
  static const signalingServer = 'https://181.41.194.56';

  /// سرورهای سیگنالینگ جایگزین (اولویت بعد از سرور اصلی).
  /// (فعلاً خالی — فقط سرور اختصاصی استفاده می‌شود.)
  static const fallbackSignalingServers = <String>[];

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
