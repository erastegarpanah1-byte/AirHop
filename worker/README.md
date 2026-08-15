# Signaling Server (Cloudflare Worker)

سرور سیگنالینگ برای جفت‌سازی peer ها و رد و بدل کردن پیام‌های WebRTC.

## API

| متد | مسیر | توضیح |
|-----|------|-------|
| POST | `/room` | ساخت اتاق جدید → برمی‌گرداند `{ code, expiresInSeconds }` |
| GET | `/room/:code/ws?role=sender\|receiver` | اتصال WebSocket به اتاق |
| GET | `/turn` | برمی‌گرداند TURN credentials (اختیاری) |

## پیام‌های WebSocket

### Server → Client
```json
{ "type": "welcome", "peerId": "...", "role": "sender", "peerCount": 1, "roomReady": false }
{ "type": "ready" }
{ "type": "peer-left" }
```

### Client ↔ Client (relay شده)
```json
{ "type": "offer", "sdp": "..." }
{ "type": "answer", "sdp": "..." }
{ "type": "ice", "candidate": { "candidate": "...", "sdpMid": "...", "sdpMLineIndex": 0 } }
```

## اجرا

```bash
npm install
npm run dev       # توسعه لوکال
npm run deploy    # دیپلوی به کلادفلیر
```
