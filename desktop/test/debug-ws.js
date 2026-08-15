// Debug ساده — تست WebSocket signaling تنها (بدون WebRTC)
const WebSocket = require('ws');
const SIGNALING = 'https://airhop-signaling.e-rastegarpanah1.workers.dev';
const WS = SIGNALING.replace('https://', 'wss://');

async function main() {
  const createResp = await fetch(`${SIGNALING}/room`, { method: 'POST' });
  const { code } = await createResp.json();
  console.log('کد:', code);

  const ws1 = new WebSocket(`${WS}/room/${code}/ws?role=sender`);
  const ws2 = new WebSocket(`${WS}/room/${code}/ws?role=receiver`);

  ws1.on('open', () => console.log('ws1 (sender) open'));
  ws2.on('open', () => console.log('ws2 (receiver) open'));

  ws1.on('message', (d) => console.log('ws1 received:', d.toString()));
  ws2.on('message', (d) => console.log('ws2 received:', d.toString()));

  ws1.on('error', (e) => console.log('ws1 error:', e.message));
  ws2.on('error', (e) => console.log('ws2 error:', e.message));
  ws1.on('close', (c, r) => console.log('ws1 close:', c, r));
  ws2.on('close', (c, r) => console.log('ws2 close:', c, r));

  setTimeout(() => { console.log('--- done ---'); process.exit(0); }, 8000);
}
main();
