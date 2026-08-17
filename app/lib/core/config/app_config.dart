/// پیکربندی سراسری برای اتصال به سرور سیگنالینگ و TURN.
class AppConfig {
  AppConfig._();

  /// آدرس سرور سیگنالینگ اصلی (Cloudflare Worker).
  /// از ایران در دسترس است و گواهی معتبر Cloudflare دارد (نیازی به self-signed نیست).
  static const signalingServer = 'https://airhop-signaling.e-rastegarpanah1.workers.dev';

  /// سرورهای سیگنالینگ جایگزین (اولویت بعد از سرور اصلی).
  /// VPS اختصاصی (هلند) به عنوان fallback.
  static const fallbackSignalingServers = <String>[
    'https://181.41.194.56',
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
