# AirHop — Cross-Network File Transfer

انتقال فایل peer-to-peer بین کامپیوتر و موبایل، حتی وقتی دستگاه‌ها روی شبکه‌های اینترنتی متفاوت هستند (نه Wi-Fi مشترک). شبیه AirDrop / Send Anywhere.

## استک تکنولوژی

| لایه | تکنولوژی | نقش |
|------|-----------|-----|
| سیگنالینگ | Cloudflare Workers + Durable Objects | جفت‌سازی + رد و بدل SDP/ICE |
| انتقال فایل | WebRTC DataChannel | انتقال مستقیم peer-to-peer |
| NAT traversal | STUN + TURN (Cloudflare Calls) | عبور از فایروال/NAT |
| کلاینت | Flutter/Dart (موبایل + دسکتاپ) | اپ واحد cross-platform |
| CI/CD | GitHub Actions | build + deploy خودکار |

---

## ساختار مونوریپو

```
airhop/
├── app/                      # اپ Flutter (موبایل + دسکتاپ)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── config/       # AppConfig (endpoints, chunk size, ICE)
│   │   │   ├── theme/        # رنگ‌ها + تم (گلس‌مورفیسم)
│   │   │   ├── domain/       # مدل‌های دامنه (فایل، پیشرفت، تاریخچه)
│   │   │   ├── data/         # signaling, webrtc, history
│   │   │   ├── providers.dart    # Riverpod (session state)
│   │   │   └── widgets/      # GlassButton, GlassCard, GradientBackground
│   │   └── features/
│   │       ├── home/         # صفحه اصلی (ارسال/دریافت)
│   │       ├── pairing/      # جفت‌سازی (QR + کد)
│   │       ├── transfer/     # صفحه انتقال (پیشرفت)
│   │       └── history/      # تاریخچه
│   ├── android/ ios/ windows/ macos/ linux/
│   └── pubspec.yaml
├── worker/                   # سرور سیگنالینگ Cloudflare
│   ├── src/index.ts          # Worker + Durable Object
│   ├── wrangler.toml
│   ├── package.json
│   └── tsconfig.json
└── .github/workflows/        # CI/CD
    ├── build-android.yml
    ├── build-desktop.yml
    ├── deploy-worker.yml
    └── release.yml
```

---

## معماری — چرا این انتخاب؟

### لایه ۱: سیگنالینگ (Cloudflare Workers + Durable Objects)

Worker فقط پیام‌های WebRTC (SDP/ICE) را بین دو peer جابه‌جا می‌کند؛ **هیچ فایلی** از این مسیر عبور نمی‌کند. هر اتاق جفت‌سازی یک Durable Object است که:

- **Single instance + consistent state** → هماهنگی WebSocket بین دو کلاینت بدون race condition.
- **WebSocket Hibernation** → اتصال‌های idle تقریباً رایگان.
- **TTL alarm** → اتاق‌ها بعد از چند دقیقه خودکار پاک می‌شوند.

### لایه ۲: انتقال فایل (WebRTC)

بعد از هندشیک، دو کلاینت مستقیماً از طریق DataChannel به هم متصل می‌شوند:

- **STUN** (`stun.l.google.com`) برای NAT traversal در اکثر موارد (~85%).
- **TURN** (Cloudflare Calls) به عنوان fallback وقتی اتصال مستقیم ممکن نیست — **رایگان** و هم‌استک با Workers.
- **Chunking 64KB** + امکان resume.
- **E2E encryption** در سطح اپلیکیشن برای فایل‌های حساس (علاوه بر DTLS پیش‌فرض).

---

## چرا این معماری نسبت به گزینه‌های دیگر؟

### چرا Cloudflare Workers به‌جای Node.js سنتی؟

| معیار | Cloudflare Workers | Node.js سنتی (VPS) |
|-------|--------------------|----------------------|
| هزینه | رایگان (تا threshold بالا) | هزینه ثابت VPS ماهیانه |
| مقیاس‌پذیری | خودکار، edge global | نیاز به load balancer / داکر |
| Latency | نزدیک به کاربر (edge) | وابسته به موقعیت سرور |
| نگهداری | صفر (serverless) | آپدیت/پچ/مانیتور |
| WebSocket لحظه‌ای | Durable Objects عالی | نیاز به redis/pubsub |

**نتیجه:** برای سیگنالینگ که فقط پیام‌های سبک جابه‌جا می‌کند، serverless edge بهترین انتخاب است.

### چرا Flutter به‌جای React Native؟

| معیار | Flutter | React Native |
|-------|---------|--------------|
| یک کدبیس برای همه پلتفرم‌ها | ✅ موبایل + دسکتاپ (Win/Mac/Linux) | ❌ دسکتاپ ضعیف/نیاز به Electron |
| عملکرد UI | Native-compiled (Skia) | JS bridge |
| WebRTC پشتیبانی | `flutter_webrtc` بالغ و کامل | `react-native-webrtc` ناپایدارتر |
| هماهنگی UI بین پلتفرم‌ها | پیکسل-پرفکت | وابسته به پلتفرم |

**نتیجه:** چون هدف هم موبایل و هم دسکتاپ است با یک کدبیس، Flutter تنها گزینه‌ای است که هر دو را بومی (native) پوشش می‌دهد.

### کدام state management؟ → Riverpod

- **بدون وابستگی به context/BuildContext** → تست‌پذیرتر.
- **پیچیدگی کمتر** نسبت به Bloc.
- **compile-safe** (اکثر خطاها در compile time).

---

## راه‌اندازی

### 1. دیپلوی Worker

```bash
cd worker
npm install
npx wrangler login
npx wrangler deploy
```

سپس URL دیپلوی‌شده را در `app/lib/core/config/app_config.dart` قرار دهید.

### 2. اجرای اپ Flutter

```bash
cd app
flutter pub get
flutter run -d windows   # یا android / macos / linux
```

---

## GitHub Secrets مورد نیاز

| Secret | نیاز در | توضیح |
|--------|---------|-------|
| `CLOUDFLARE_API_TOKEN` | deploy-worker | توکن API کلادفلیر |
| `CLOUDFLARE_ACCOUNT_ID` | deploy-worker | شناسه اکانت کلادفلیر |
