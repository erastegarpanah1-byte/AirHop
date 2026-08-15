# AirHop — Flutter App

اپ cross-platform (Android + Desktop) برای انتقال فایل p2p.

## ساختار کد

```
lib/
├── main.dart
├── core/
│   ├── config/
│   ├── theme/
│   ├── domain/
│   ├── data/
│   ├── providers.dart
│   └── widgets/
└── features/
    ├── home/
    ├── pairing/
    ├── transfer/
    └── history/
```

## State Management: Riverpod

- `sessionProvider` — وضعیت جلسه‌ی جفت‌سازی/انتقال.
- `historyProvider` — تاریخچه‌ی انتقال‌ها.

## اجرا

```bash
flutter pub get
flutter run -d <device>
```

قبل از اجرا، `AppConfig.signalingServer` را روی URL دیپلوی‌شده‌ی Worker خود تنظیم کنید.
