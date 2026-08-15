// AirHop Desktop — Main Process
// مسئولیت‌ها: مدیریت پنجره، WebSocket signaling، WebRTC DataChannel (node-datachannel)،
// و ذخیره‌ی فایل‌های دریافتی در Downloads/AirHop.
//
// پروتکل کاملاً منطبق با اپ Flutter است:
//   - signaling: welcome / ready / offer / answer / ice / deviceInfo
//   - فایل‌ها: file-header (JSON) → chunks باینری 64KB → file-end (JSON)

const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const os = require('os');
const https = require('https');
const http = require('http');
const WebSocket = require('ws');
const nodeDataChannel = require('node-datachannel');

// --- پیکربندی (منطبق با app_config.dart در Flutter) ---
const SIGNALING_SERVER = 'https://airhop-signaling.e-rastegarpanah1.workers.dev';
const WS_SERVER = SIGNALING_SERVER.replace('https://', 'wss://').replace('http://', 'ws://');
const CHUNK_SIZE = 64 * 1024; // 64 KB — مشابه Flutter
const ICE_SERVERS = [
  'stun:stun.l.google.com:19302',
  'stun:stun1.l.google.com:19302',
];
// نام دستگاه ویندوز
const DEVICE_NAME = require('child_process').execSync('hostname').toString().trim();

let mainWindow = null;

// وضعیت جلسه
let session = {
  ws: null,
  pc: null,
  dc: null,
  role: null, // 'sender' | 'receiver'
  code: null,
  peerId: null,
  currentFileName: null,
  currentFileSize: 0,
  receivedBytes: 0,
  buffer: [],
};

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1080,
    height: 720,
    minWidth: 900,
    minHeight: 640,
    show: false,
    backgroundColor: '#060A1A',
    title: 'AirHop',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
  mainWindow.once('ready-to-show', () => mainWindow.show());
  mainWindow.on('closed', () => (mainWindow = null));
}

// از کار انداختن پروکسی سیستم — تا ترافیک مستقیم به اینترنت برود
// (در غیر این صورت VPN/proxy ممکن است DNS را به IP داخلی اشتباه هدایت کند).
app.commandLine.appendSwitch('no-proxy-server');
app.commandLine.appendSwitch('proxy-bypass-list', '*');

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  cleanup();
  if (process.platform !== 'darwin') app.quit();
});

// ---------------------------------------------------------------------------
// IPC Handlers (renderer ↔ main)
// ---------------------------------------------------------------------------

ipcMain.handle('airhop:create-room', async () => {
  try {
    const body = await httpPostJson(`${SIGNALING_SERVER}/room`, {});
    session.role = 'sender';
    session.code = body.code;
    initPeerConnection(); // sender: pc آماده می‌شود
    connectWebSocket(body.code, 'sender');
    return { code: body.code, deviceName: DEVICE_NAME };
  } catch (e) {
    return { error: String(e) };
  }
});

ipcMain.handle('airhop:join-room', async (event, code) => {
  try {
    session.role = 'receiver';
    session.code = code;
    initPeerConnection(); // receiver: pc آماده می‌شود
    connectWebSocket(code, 'receiver');
    return { ok: true, deviceName: DEVICE_NAME };
  } catch (e) {
    return { error: String(e) };
  }
});

ipcMain.handle('airhop:pick-files', async () => {
  const result = await dialog.showOpenDialog(mainWindow, {
    properties: ['openFile', 'multiSelections'],
  });
  if (result.canceled || !result.filePaths.length) return { files: [] };
  return {
    files: result.filePaths.map((p) => ({
      path: p,
      name: path.basename(p),
      size: fs.statSync(p).size,
    })),
  };
});

ipcMain.handle('airhop:send-files', async (event, filePaths) => {
  if (!session.dc) return { error: 'کانال آماده نیست' };
  try {
    for (const fp of filePaths) await sendFile(fp);
    return { ok: true };
  } catch (e) {
    return { error: String(e) };
  }
});

ipcMain.handle('airhop:open-airhop-folder', async () => {
  const dir = getSaveDirectory();
  fs.mkdirSync(dir, { recursive: true });
  shell.openPath(dir);
  return { dir };
});

ipcMain.handle('airhop:reset', async () => {
  cleanup();
  return { ok: true };
});

// ---------------------------------------------------------------------------
// Signaling (WebSocket)
// ---------------------------------------------------------------------------

function connectWebSocket(code, role) {
  const wsUrl = `${WS_SERVER}/room/${code}/ws?role=${role}`;
  const ws = new WebSocket(wsUrl);
  session.ws = ws;

  ws.on('open', () => {
    sendToRenderer('signaling-open', { code });
  });

  ws.on('message', (data) => {
    const msg = JSON.parse(data.toString());
    handleSignalMessage(msg);
  });

  ws.on('error', (err) => sendToRenderer('signaling-error', String(err)));
}

function handleSignalMessage(msg) {
  const type = msg.type;

  switch (type) {
    case 'welcome':
      session.peerId = msg.peerId;
      sendToRenderer('welcome', {
        peerId: msg.peerId,
        peerCount: msg.peerCount,
        roomReady: msg.roomReady,
      });
      break;

    case 'ready':
      sendToRenderer('ready', {});
      // sender: ساخت data channel + ارسال device info + ساخت offer
      if (session.role === 'sender') {
        createDataChannel();
        sendSignal({ type: 'deviceInfo', payload: { name: DEVICE_NAME, platform: 'windows' } });
        // delay کوتاه تا channel ثبت شود
        setTimeout(() => createOffer(), 100);
      } else {
        // receiver: معرفی خودش
        sendSignal({ type: 'deviceInfo', payload: { name: DEVICE_NAME, platform: 'windows' } });
      }
      break;

    case 'deviceInfo':
      sendToRenderer('peer-device', msg.payload);
      break;

    case 'offer':
      handleOffer(msg.sdp);
      break;

    case 'answer':
      handleAnswer(msg.sdp);
      break;

    case 'ice':
      handleIce(msg.candidate);
      break;

    case 'peer-left':
      sendToRenderer('peer-left', {});
      cleanup();
      break;
  }
}

// ---------------------------------------------------------------------------
// WebRTC (node-datachannel)
// ---------------------------------------------------------------------------

function initPeerConnection() {
  if (session.pc) return session.pc;

  const pc = new nodeDataChannel.PeerConnection('AirHop', {
    iceServers: ICE_SERVERS,
    iceTransportPolicy: 'all',
  });

  // receiver: منتظر incoming data channel
  if (session.role === 'receiver') {
    pc.onDataChannel((dc) => setupDataChannel(dc));
  }

  pc.onLocalDescription((sdp, type) => {
    // type: 'Offer' | 'Answer' | 'Unspec'
    const signalType = type === 'Answer' ? 'answer' : 'offer';
    sendSignal({ type: signalType, sdp });
    sendToRenderer('log', { evt: 'local-description', type: signalType });
  });

  pc.onLocalCandidate((candidate, mid) => {
    sendSignal({ type: 'ice', candidate: { candidate, sdpMid: mid, sdpMLineIndex: 0 } });
  });

  pc.onStateChange((state) => {
    sendToRenderer('connection-state', state);
  });

  session.pc = pc;
  return pc;
}

function createDataChannel() {
  const dc = session.pc.createDataChannel('file-transfer', { ordered: true });
  setupDataChannel(dc);
}

function setupDataChannel(dc) {
  session.dc = dc;
  dc.onOpen(() => sendToRenderer('channel-open', {}));
  dc.onMessage((msg) => {
    if (typeof msg === 'string') handleTextMessage(msg);
    else handleBinaryChunk(Buffer.from(msg));
  });
  dc.onClosed(() => sendToRenderer('channel-closed', {}));
}

// sender: ساخت offer بعد از channel
function createOffer() {
  // در node-datachannel، ست کردن local description به صورت دستی
  // اتصال از طریق onLocalDescription callback کامل می‌شود.
  // libdatachannel با disableAutoNegotiation=false خودش negotiation می‌کند.
  // چون ما auto-negotiation داریم، فقط کافی است channel ساخته شود و
  // سپس از طریق onLocalDescription، offer ارسال می‌شود.
  sendToRenderer('log', { evt: 'offer-created' });
}

function handleOffer(sdp) {
  const pc = initPeerConnection();
  pc.setRemoteDescription(sdp, 'Offer');
  // پاسخ (answer) به صورت خودکار از طریق onLocalDescription ارسال می‌شود.
  sendToRenderer('log', { evt: 'answer-sending' });
}

function handleAnswer(sdp) {
  session.pc.setRemoteDescription(sdp, 'Answer');
  sendToRenderer('log', { evt: 'answer-received' });
}

function handleIce(candidate) {
  if (candidate && candidate.candidate) {
    session.pc.addRemoteCandidate(candidate.candidate, candidate.sdpMid || '0');
  }
}

function sendSignal(msg) {
  if (session.ws && session.ws.readyState === WebSocket.OPEN) {
    session.ws.send(JSON.stringify(msg));
  }
}

// ---------------------------------------------------------------------------
// انتقال فایل (پروتکل منطبق با Flutter)
// ---------------------------------------------------------------------------

async function sendFile(filePath) {
  const fileName = path.basename(filePath);
  const fileSize = fs.statSync(filePath).size;

  // ۱. header
  session.dc.sendMessage(JSON.stringify({
    type: 'file-header',
    metadata: {
      id: fileName,
      name: fileName,
      size: fileSize,
      mimeType: path.extname(fileName).slice(1) || null,
    },
  }));

  sendToRenderer('transfer-start', { name: fileName, size: fileSize });

  // ۲. بدنه — 64KB chunks با backpressure
  const fd = fs.openSync(filePath, 'r');
  const buffer = Buffer.alloc(CHUNK_SIZE);
  let offset = 0;
  let bytesRead;
  while ((bytesRead = fs.readSync(fd, buffer, 0, CHUNK_SIZE, offset)) > 0) {
    const chunk = buffer.subarray(0, bytesRead);
    while (session.dc.bufferedAmount() > 4 * 1024 * 1024) {
      await sleep(5);
    }
    session.dc.sendMessageBinary(chunk);
    offset += bytesRead;
    sendToRenderer('transfer-progress', {
      name: fileName,
      receivedBytes: offset,
      totalBytes: fileSize,
    });
  }
  fs.closeSync(fd);

  // ۳. پایان
  session.dc.sendMessage(JSON.stringify({ type: 'file-end' }));
  sendToRenderer('transfer-complete', { name: fileName });
}

function handleTextMessage(text) {
  const msg = JSON.parse(text);
  if (msg.type === 'file-header') {
    const m = msg.metadata;
    session.currentFileName = m.name;
    session.currentFileSize = m.size;
    session.receivedBytes = 0;
    session.buffer = [];
    sendToRenderer('file-header', m);
  } else if (msg.type === 'file-end') {
    finalizeFile();
  }
}

function handleBinaryChunk(chunk) {
  session.buffer.push(chunk);
  session.receivedBytes += chunk.length;
  sendToRenderer('transfer-progress', {
    name: session.currentFileName,
    receivedBytes: session.receivedBytes,
    totalBytes: session.currentFileSize,
  });
}

function finalizeFile() {
  const fileName = session.currentFileName;
  const fullBuffer = Buffer.concat(session.buffer);
  session.buffer = [];

  const dir = getSaveDirectory();
  fs.mkdirSync(dir, { recursive: true });

  let savePath = path.join(dir, fileName);
  if (fs.existsSync(savePath)) {
    const ext = path.extname(fileName);
    const base = path.basename(fileName, ext);
    let i = 1;
    while (fs.existsSync(savePath)) savePath = path.join(dir, `${base} (${i})${ext}`), i++;
  }
  fs.writeFileSync(savePath, fullBuffer);

  sendToRenderer('file-saved', { name: fileName, path: savePath, size: fullBuffer.length });
  session.currentFileName = null;
  session.currentFileSize = 0;
  session.receivedBytes = 0;
}

function getSaveDirectory() {
  return path.join(os.homedir(), 'Downloads', 'AirHop');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// درخواست HTTP POST با بدنه‌ی JSON (بدون اتکا به fetch سراسری که در Electron
/// گاهی با «fetch failed» شکست می‌خورد).
function httpPostJson(url, data) {
  return new Promise((resolve, reject) => {
    const target = new URL(url);
    const mod = target.protocol === 'https:' ? https : http;
    const payload = JSON.stringify(data);

    const req = mod.request(
      {
        hostname: target.hostname,
        port: target.port || (target.protocol === 'https:' ? 443 : 80),
        path: target.pathname + target.search,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
        timeout: 10000,
      },
      (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => {
          try {
            resolve(JSON.parse(body));
          } catch (_) {
            resolve(body);
          }
        });
      },
    );

    req.on('timeout', () => req.destroy(new Error('timeout')));
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

function sendToRenderer(channel, payload) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send(channel, payload);
  }
}

function cleanup() {
  try { if (session.dc) session.dc.close(); } catch (_) {}
  try { if (session.pc) { session.pc.close(); session.pc.destroy(); } } catch (_) {}
  try { if (session.ws) session.ws.close(); } catch (_) {}
  session = {
    ws: null, pc: null, dc: null, role: null, code: null, peerId: null,
    currentFileName: null, currentFileSize: 0, receivedBytes: 0, buffer: [],
  };
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}
