# AirHop Desktop (Electron)

اپ دسکتاپ ویندوز AirHop — ساخته‌شده با Electron.

## معماری

- **main.js** — main process: مدیریت پنجره، WebSocket signaling، WebRTC (node-datachannel)، ذخیره فایل.
- **preload.js** — پل امن (contextBridge) بین renderer و main.
- **renderer/** — UI (HTML/CSS/JS): گلس‌مورفیسم آبی-بنفش + سایدبار جزیره‌ای + drag-drop.

## پروتکل (منطبق با اپ Flutter)

- Signaling: `welcome` / `ready` / `offer` / `answer` / `ice` / `deviceInfo`
- فایل: `file-header` (JSON) → chunks باینری 64KB → `file-end` (JSON)
- انتقال peer-to-peer از طریق WebRTC DataChannel (نام channel: `file-transfer`)

## اجرا (توسعه)

```bash
npm install
npm start
```

## Build نصبی ویندوز

```bash
npm run build     # electron-builder --win (NSIS installer)
```

خروجی در `dist/AirHop-Setup-1.0.0.exe`.

## محل ذخیره فایل‌های دریافتی

`Downloads/AirHop/`
