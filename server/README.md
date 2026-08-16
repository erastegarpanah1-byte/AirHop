# AirHop — سرور سیگنالینگ + TURN (Node.js)

جایگزین **Cloudflare Worker** برای اجرا روی سرور ایران.

## معماری
- **سیگنالینگ** (Node.js + `ws`): فقط SDP/ICE را بین دو دستگاه رله می‌کند.
- **انتقال فایل**:
  1. **P2P مستقیم** (WebRTC DataChannel؛ STUN برای NAT ساده + TURN برای NAT سخت).
  2. **Fallback از سرور**: اگر P2P برقرار نشد، فایل chunk‌به‌chunk از سرور relay می‌شود.
- **TURN** (coturn): عبور از NAT سخت.

## نصب روی سرور ایران
```bash
sudo mkdir -p /opt/airhop/server
sudo cp -r server/src server/package.json server/deploy.sh /opt/airhop/server/
cd /opt/airhop/server
sudo TURN_PASS='رمز_قوی' bash deploy.sh
```

## بررسی
```bash
curl http://127.0.0.1:8787/health
systemctl status airhop-signaling coturn
```

## پورت‌ها
| پورت | پروتکل | کاربرد |
|------|--------|--------|
| 8787 | TCP | سیگنالینگ |
| 3478 | TCP/UDP | TURN |
| 49152-65535 | UDP | TURN relay media |

## کلاینت Flutter
در `app/lib/core/config/app_config.dart`:
```dart
static const signalingServer = 'https://YOUR_PUBLIC_IP:8787';
static const turnUrl = 'turn:YOUR_PUBLIC_IP:3478';
static const turnUsername = 'airhop';
static const turnCredential = 'رمز_قوی';
```
