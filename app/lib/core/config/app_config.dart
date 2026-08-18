/// پیکربندی سراسری برای اتصال به سرور سیگنالینگ و TURN.
class AppConfig {
  AppConfig._();

  /// آدرس سرور سیگنالینگ اصلی — سرور ایران (مسیر داخلی، سریع و بدون فیلترینگ).
  static const signalingServer = 'http://45.156.186.140:8080';

  /// سرورهای سیگنالینگ جایگزین (اولویت بعد از سرور اصلی).
  /// نکته: سرور ایران از داخل ایران در دسترس است؛ سرورهای خارجی را
  /// حذف کردیم چون از ایران کند یا ناممکن هستند و باعث تأخیر/timeout می‌شدند.
  static const fallbackSignalingServers = <String>[];

  /// TURN سرور موقتاً غیرفعال — سرور هلند از ایران در دسترس نیست.
  /// (برای TURN روی سرور ایران، اینجا مقداردهی می‌شود.)
  static const turnUrl = '';
  static const turnUsername = '';
  static const turnCredential = '';

  static const pairingCodeLength = 6;
  static const chunkSize = 256 * 1024; // 256 KB — سریع‌تر از 64KB

  /// STUN سرورها برای NAT traversal.
  static const iceServers = [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
    'stun:stun3.l.google.com:19302',
  ];
}
