/// پیکربندی سراسری برای اتصال به سرور سیگنالینگ.
class AppConfig {
  AppConfig._();

  /// URL سرور سیگنالینگ (Cloudflare Worker).
  static const signalingServer = 'wss://airhop-signaling.YOUR_SUBDOMAIN.workers.dev';

  /// کد جفت‌سازی.
  static const pairingCodeLength = 6;

  /// اندازه‌ی هر chunk در انتقال فایل (بایت).
  static const chunkSize = 64 * 1024; // 64 KB

  /// STUN server عمومی برای NAT traversal.
  static const iceServers = [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
  ];
}
