/// پیکربندی سراسری برای اتصال به سرور سیگنالینگ.
///
/// در محیط توسعه، این مقدار را روی URL لوکال Worker (`wrangler dev`)
/// یا URL دیپلوی‌شده‌ی Cloudflare تنظیم کنید.
class AppConfig {
  AppConfig._();

  /// URL سرور سیگنالینگ (Cloudflare Worker).
  /// تبدیل `https://` → `wss://` به صورت خودکار داخل SignalingService انجام می‌شود.
  static const signalingServer =
      'https://airhop-signaling.e-rastegarpanah1.workers.dev';

  /// حداکثر تعداد اتاق‌ها / کد جفت‌سازی.
  static const pairingCodeLength = 6;

  /// اندازه‌ی هر chunk در انتقال فایل (بایت).
  static const chunkSize = 64 * 1024; // 64 KB

  /// STUN server عمومی برای NAT traversal.
  static const iceServers = [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
  ];
}
