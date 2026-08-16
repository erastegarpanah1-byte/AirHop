import http from 'node:http';
import { parse as parseUrl } from 'node:url';
import { WebSocketServer, WebSocket } from 'ws';

/**
 * AirHop — Signaling Server (Node.js)
 * جایگزین Cloudflare Worker + Durable Objects.
 * وظایف: ساخت اتاق + رله سیگنالینگ + (اختیاری) relay فایل.
 */

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || '0.0.0.0';
const ROOM_TTL_MS = Number(process.env.ROOM_TTL_MS || 10 * 60 * 1000);
const MAX_CLIENTS = 2;

const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function generateCode(len = 6) {
  const bytes = new Uint8Array(len);
  crypto.getRandomValues(bytes);
  let out = '';
  for (let i = 0; i < len; i++) out += ALPHABET[bytes[i] % ALPHABET.length];
  return out;
}

function json(data, status = 200) {
  return JSON.stringify({ ...data, ok: status < 400 });
}

/** @type {Map<string, any>} */
const rooms = new Map();

function createRoom(code) {
  const room = {
    code,
    createdAt: Date.now(),
    clients: new Map(),
    ttlTimer: setTimeout(() => expireRoom(code), ROOM_TTL_MS),
  };
  rooms.set(code, room);
  return room;
}

function expireRoom(code) {
  const room = rooms.get(code);
  if (!room) return;
  for (const { ws } of room.clients.values()) {
    try { ws.close(1000, 'room expired'); } catch (_) {}
  }
  room.clients.clear();
  rooms.delete(code);
}

function broadcast(room, message, except) {
  const data = typeof message === 'string' ? message : JSON.stringify(message);
  for (const { ws } of room.clients.values()) {
    if (ws === except) continue;
    if (ws.readyState === WebSocket.OPEN) {
      try { ws.send(data); } catch (_) {}
    }
  }
}

export function startServer() {
  const server = http.createServer((req, res) => {
    const url = parseUrl(req.url, true);
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

    if (url.pathname === '/health' && req.method === 'GET') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(json({ status: 'ok', rooms: rooms.size }));
      return;
    }

    if (url.pathname === '/room' && req.method === 'POST') {
      let code = generateCode();
      while (rooms.has(code)) code = generateCode();
      createRoom(code);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(json({ code, expiresInSeconds: Math.floor(ROOM_TTL_MS / 1000) }));
      return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(json({ error: 'not_found' }, 404));
  });

  const wss = new WebSocketServer({ server });

  wss.on('connection', (ws, req) => {
    const url = parseUrl(req.url, true);
    const match = url.pathname.match(/^\/room\/([A-Z0-9]+)\/ws$/);
    if (!match) { ws.close(1008, 'bad_path'); return; }
    const code = match[1];
    const role = url.query.role ?? 'peer';

    const room = rooms.get(code);
    if (!room) { ws.close(1008, 'room_not_found'); return; }
    if (room.clients.size >= MAX_CLIENTS) { ws.close(1013, 'room_full'); return; }

    const peerId = crypto.randomUUID();
    room.clients.set(peerId, { ws, role });
    const peerCount = room.clients.size;
    const roomReady = peerCount >= MAX_CLIENTS;

    ws.send(JSON.stringify({ type: 'welcome', peerId, role, peerCount, roomReady }));
    if (roomReady) broadcast(room, { type: 'ready' });

    ws.on('message', (data, isBinary) => {
      if (isBinary) { broadcast(room, data, ws); return; }
      try { JSON.parse(data.toString()); } catch (_) { return; }
      broadcast(room, data, ws);
    });

    ws.on('close', () => {
      room.clients.delete(peerId);
      if (room.clients.size > 0) broadcast(room, { type: 'peer-left' });
    });
    ws.on('error', () => {});

    if (room.ttlTimer) clearTimeout(room.ttlTimer);
    room.ttlTimer = setTimeout(() => expireRoom(code), ROOM_TTL_MS);
  });

  server.listen(PORT, HOST, () => {
    console.log(`AirHop signaling server listening on ${HOST}:${PORT}`);
  });

  return server;
}
