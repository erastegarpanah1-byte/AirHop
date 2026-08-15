/**
 * AirHop — Signaling Server
 * Cloudflare Workers + Durable Objects
 *
 * نقش: فقط رد و بدل کردن پیام‌های WebRTC (offer/answer/ICE) بین دو کلاینت.
 * هیچ فایلی از اینجا عبور نمی‌کند؛ انتقال فایل کاملاً peer-to-peer است.
 */

export interface Env {
	ROOMS: DurableObjectNamespace<Room>;
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		const url = new URL(request.url);

		if (request.method === 'OPTIONS') {
			return new Response(null, {
				status: 204,
				headers: {
					'Access-Control-Allow-Origin': '*',
					'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
					'Access-Control-Allow-Headers': 'Content-Type',
				},
			});
		}

		const path = url.pathname;

		// ایجاد اتاق جدید
		if (path === '/room' && request.method === 'POST') {
			const code = generateCode();
			const id = env.ROOMS.idFromName(code);
			const stub = env.ROOMS.get(id);
			await stub.fetch('https://do/init', { method: 'POST' });
			return json({ code, expiresInSeconds: ROOM_TTL_SECONDS });
		}

		// اتصال WebSocket به اتاق
		const match = path.match(/^\/room\/([A-Z0-9]+)\/ws$/);
		if (match && request.method === 'GET') {
			const code = match[1];
			const role = url.searchParams.get('role') ?? 'peer';
			const id = env.ROOMS.idFromName(code);
			const stub = env.ROOMS.get(id);
			return stub.fetch(request);
		}

		return json({ error: 'not_found' }, 404);
	},
};

function json(data: unknown, status = 200): Response {
	return new Response(JSON.stringify(data), {
		status,
		headers: {
			'Content-Type': 'application/json',
			'Access-Control-Allow-Origin': '*',
		},
	});
}

function generateCode(): string {
	const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // بدون I, O, 0, 1
	const bytes = new Uint8Array(6);
	crypto.getRandomValues(bytes);
	let out = '';
	for (let i = 0; i < 6; i++) {
		out += ALPHABET[bytes[i] % ALPHABET.length];
	}
	return out;
}

const ROOM_TTL_SECONDS = 10 * 60; // 10 دقیقه
const MAX_CLIENTS = 2;

export class Room implements DurableObject {
	private state: DurableObjectState;
	private clients: Map<string, WebSocket> = new Map();

	constructor(state: DurableObjectState) {
		this.state = state;
	}

	async fetch(request: Request): Promise<Response> {
		const url = new URL(request.url);

		// init
		if (url.pathname === '/init' && request.method === 'POST') {
			const current = await this.state.storage.getAlarm();
			if (current === null) {
				this.state.storage.setAlarm(Date.now() + ROOM_TTL_SECONDS * 1000);
			}
			return json({ ok: true });
		}

		// WebSocket connection
		if (request.headers.get('Upgrade') === 'websocket') {
			const role = url.searchParams.get('role') ?? 'peer';

			if (this.clients.size >= MAX_CLIENTS) {
				return json({ error: 'room_full' }, 409);
			}

			const pair = new WebSocketPair();
			const client = pair[0];
			const server = pair[1];

			this.state.acceptWebSocket(server);
			const id = crypto.randomUUID();
			this.clients.set(id, server);

			const clientCount = this.clients.size;

			// ارسال welcome بعد از برقراری connection (بدون hydrate)
			server.send(JSON.stringify({
				type: 'welcome',
				peerId: id,
				role,
				peerCount: clientCount,
				roomReady: clientCount >= MAX_CLIENTS,
			}));

			// اگر room کامل شد، notify ready
			if (clientCount >= MAX_CLIENTS) {
				this.broadcast({ type: 'ready' });
			}

			return new Response(null, { status: 101, webSocket: client });
		}

		return json({ error: 'not_found' }, 404);
	}

	async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
		if (typeof message !== 'string') return;
		this.broadcast(JSON.parse(message), ws);
	}

	async webSocketClose(ws: WebSocket): Promise<void> {
		for (const [id, c] of this.clients) {
			if (c === ws) this.clients.delete(id);
		}
		if (this.clients.size > 0) {
			this.broadcast({ type: 'peer-left' });
		}
	}

	async alarm(): Promise<void> {
		for (const ws of this.clients.values()) {
			try { ws.close(1000, 'room expired'); } catch (_) {}
		}
		this.clients.clear();
	}

	private broadcast(message: object, except?: WebSocket): void {
		const data = JSON.stringify(message);
		for (const ws of this.clients.values()) {
			if (ws === except) continue;
			try { ws.send(data); } catch (_) {}
		}
	}
}
