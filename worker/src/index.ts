/**
 * AirHop — Signaling Server
 * Cloudflare Workers + Durable Objects
 *
 * نقش: فقط رد و بدل کردن پیام‌های WebRTC (offer/answer/ICE) بین دو کلاینت.
 * هیچ فایلی از اینجا عبور نمی‌کند؛ انتقال فایل کاملاً peer-to-peer است.
 *
 * نکات کلیدی پیاده‌سازی:
 *  - هر اتاق جفت‌سازی (room) یک Durable Object است → single instance، consistent state.
 *  - کد جفت‌سازی حداکثر ۶ کاراکتری (base32) با TTL چند دقیقه‌ای.
 *  - WebSocket Hibernation API برای کاهش هزینه‌ی اتصال‌های idle.
 *  - پیام‌های SDP/ICE فقط relay می‌شوند.
 */

export interface Env {
	TURN_SERVICE?: { get: (path: string) => Promise<Response> };
	ROOMS: DurableObjectNamespace<Room>;
}

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		const url = new URL(request.url);

		if (request.method === 'OPTIONS') {
			return handleCors();
		}

		const path = url.pathname;

		if (path === '/room' && request.method === 'POST') {
			return await createRoom(env);
		}

		const match = path.match(/^\/room\/([A-Z0-9]+)\/ws$/);
		if (match && request.method === 'GET') {
			const code = match[1];
			const role = url.searchParams.get('role') ?? 'peer';
			const id = env.ROOMS.idFromName(code);
			const stub = env.ROOMS.get(id);
			return await stub.fetch(makeWsRequest(request, code, role));
		}

		if (path === '/turn' && request.method === 'GET') {
			return await getTurnCredentials(env, request);
		}

		return json({ error: 'not_found' }, 404);
	},
};

function handleCors(): Response {
	return new Response(null, {
		status: 204,
		headers: {
			'Access-Control-Allow-Origin': '*',
			'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
			'Access-Control-Allow-Headers': 'Content-Type',
		},
	});
}

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
	const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
	const bytes = new Uint8Array(6);
	crypto.getRandomValues(bytes);
	let out = '';
	for (let i = 0; i < 6; i++) {
		out += ALPHABET[bytes[i] % ALPHABET.length];
	}
	return out;
}

async function createRoom(env: Env): Promise<Response> {
	const code = generateCode();
	const id = env.ROOMS.idFromName(code);
	const stub = env.ROOMS.get(id);
	await stub.fetch(new Request('https://do/init', { method: 'POST' }));
	return json({ code, expiresInSeconds: ROOM_TTL_SECONDS });
}

function makeWsRequest(request: Request, code: string, role: string): Request {
	const url = new URL(request.url);
	url.pathname = '/_ws';
	return new Request(url.toString(), {
		method: request.method,
		headers: {
			Upgrade: 'websocket',
			Connection: 'Upgrade',
			'x-room-code': code,
			'x-room-role': role,
		},
	});
}

async function getTurnCredentials(env: Env, request: Request): Promise<Response> {
	if (env.TURN_SERVICE) {
		const resp = await env.TURN_SERVICE.get('/turn-credentials');
		if (resp.ok) {
			const body = await resp.text();
			return new Response(body, {
				headers: { 'Content-Type': resp.headers.get('content-type') ?? 'application/json',
					'Access-Control-Allow-Origin': '*' },
			});
		}
	}
	return json({ error: 'turn_not_configured' }, 501);
}

const ROOM_TTL_SECONDS = 10 * 60;
const MAX_CLIENTS = 2;

export class Room {
	private state: DurableObjectState;
	private clients: Map<string, WebSocket> = new Map();
	private roles: Map<string, string> = new Map();

	constructor(state: DurableObjectState) {
		this.state = state;
	}

	async fetch(request: Request): Promise<Response> {
		const url = new URL(request.url);

		if (url.pathname === '/init' && request.method === 'POST') {
			await this.ensureAlarm();
			return json({ ok: true });
		}

		if (url.pathname === '/_ws') {
			const code = request.headers.get('x-room-code') ?? '';
			const role = request.headers.get('x-room-role') ?? 'peer';

			if (this.clients.size >= MAX_CLIENTS) {
				return json({ error: 'room_full' }, 409);
			}

			const pair = new WebSocketPair();
			const [client, server] = Object.values(pair);

			this.state.acceptWebSocket(server);
			const id = crypto.randomUUID();

			this.clients.set(id, client);
			this.roles.set(id, role);

			const clientCount = this.clients.size;

			const welcomePayload = JSON.stringify({
				type: 'welcome',
				peerId: id,
				role,
				peerCount: clientCount,
				roomReady: clientCount >= MAX_CLIENTS,
			});
			client.send(welcomePayload);
			this.track(id);

			if (this.clients.size >= MAX_CLIENTS) {
				this.broadcast({ type: 'ready' }, undefined);
			}

			return new Response(null, { status: 101, webSocket: client });
		}

		return json({ error: 'not_found' }, 404);
	}

	async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
		if (typeof message !== 'string') {
			return;
		}
		this.broadcast(JSON.parse(message), ws);
	}

	async webSocketClose(ws: WebSocket, code: number, reason: string): Promise<void> {
		this.untrack(ws);
		await this.broadcast({ type: 'peer-left' }, ws);
	}

	async webSocketError(ws: WebSocket, error: unknown): Promise<void> {
		this.untrack(ws);
	}

	async alarm(): Promise<void> {
		for (const [id, ws] of this.clients) {
			ws.close(1000, 'room expired');
		}
		this.clients.clear();
		this.roles.clear();
	}

	private track(id: string): void {
		// (ذخیره‌سازی state برای hibernation) — در این نسخه ساده، فقط در حافظه
	}

	private untrack(ws: WebSocket): void {
		for (const [id, c] of this.clients) {
			if (c === ws) {
				this.clients.delete(id);
				this.roles.delete(id);
				break;
			}
		}
	}

	private broadcast(message: object, except?: WebSocket): void {
		const data = JSON.stringify(message);
		for (const [id, ws] of this.clients) {
			if (ws === except) continue;
			try {
				ws.send(data);
			} catch {
				// ignore — connection احتمالاً بسته است
			}
		}
	}

	private async ensureAlarm(): Promise<void> {
		const current = await this.state.storage.getAlarm();
		if (current === null) {
			this.state.storage.setAlarm(Date.now() + ROOM_TTL_SECONDS * 1000);
		}
	}
}
