// AirHop Desktop — Renderer Logic
// مدیریت view ها، رویدادها و ارتباط با main process از طریق window.airhop.

const state = {
  currentView: 'home',
  role: null,
  code: null,
  selectedFiles: [], // { path, name, size }
  deviceName: '',
  peerDevice: null,
  startTime: null,
  totalBytes: 0,
  receivedBytes: 0,
};

// --- Elements ---
const $ = (sel) => document.querySelector(sel);
const views = {
  home: $('#view-home'),
  send: $('#view-send'),
  receive: $('#view-receive'),
  transfer: $('#view-transfer'),
};

function showView(name) {
  state.currentView = name;
  document.querySelectorAll('.view').forEach((v) => v.classList.remove('active'));
  views[name].classList.add('active');
  document.querySelectorAll('.side-btn').forEach((b) => {
    b.classList.toggle('active', b.dataset.view === name || (name === 'send' && b.dataset.view === 'send'));
  });
}

// --- Sidebar ---
document.querySelectorAll('.side-btn[data-view]').forEach((btn) => {
  btn.addEventListener('click', () => {
    const v = btn.dataset.view;
    if (v === 'receive') showReceive();
    else if (v === 'send') showSend();
    else showView('home');
  });
});

// --- Home buttons ---
$('#btn-send-home').addEventListener('click', showSend);
$('#btn-receive-home').addEventListener('click', showReceive);
$('#btn-folder').addEventListener('click', () => window.airhop.openAirhopFolder());

// --- Send flow ---
async function showSend() {
  showView('send');
  $('#send-pairing').classList.remove('hidden');
  $('#send-files').classList.add('hidden');
  state.role = 'sender';
  clearCodeBoxes();

  const res = await window.airhop.createRoom();
  if (res.error) { alert('خطا: ' + res.error); return; }
  state.code = res.code;
  state.deviceName = res.deviceName;
  renderQR(res.code);
  renderCodeBoxes(res.code);
}

// --- Receive flow ---
function showReceive() {
  showView('receive');
  state.role = 'receiver';
  $('#receive-status').textContent = 'منتظر وارد کردن کد...';
  $('#code-input').value = '';
  $('#code-input').focus();
}

$('#code-input').addEventListener('input', (e) => {
  const v = e.target.value.toUpperCase();
  if (v.length === 6) {
    window.airhop.joinRoom(v).then((res) => {
      if (res.error) { alert('خطا: ' + res.error); return; }
      state.code = v;
      state.deviceName = res.deviceName;
      $('#receive-status').textContent = 'در حال اتصال...';
    });
  }
});

// --- Pick files (send) ---
$('#btn-pick').addEventListener('click', async () => {
  const res = await window.airhop.pickFiles();
  if (res.files && res.files.length) {
    state.selectedFiles.push(...res.files);
    renderFileList();
  }
});

// --- Dropzone drag & drop ---
const dz = $('#dropzone');
dz.addEventListener('click', () => $('#btn-pick').click());
dz.addEventListener('dragover', (e) => { e.preventDefault(); dz.classList.add('dragover'); });
dz.addEventListener('dragleave', () => dz.classList.remove('dragover'));
dz.addEventListener('drop', (e) => {
  e.preventDefault();
  dz.classList.remove('dragover');
  const files = Array.from(e.dataTransfer.files);
  for (const f of files) {
    state.selectedFiles.push({ path: f.path, name: f.name, size: f.size });
  }
  renderFileList();
});

// --- Send files ---
$('#btn-send').addEventListener('click', async () => {
  const paths = state.selectedFiles.map((f) => f.path);
  showView('transfer');
  state.startTime = Date.now();
  window.airhop.sendFiles(paths);
});

function renderFileList() {
  const list = $('#file-list');
  list.innerHTML = '';
  state.selectedFiles.forEach((f, i) => {
    const ext = f.name.split('.').pop().toLowerCase();
    const item = document.createElement('div');
    item.className = 'file-item';
    item.innerHTML = `
      <div class="fi-ico" style="background:${iconColor(ext)}22;color:${iconColor(ext)}">${iconGlyph(ext)}</div>
      <div class="fi-name">${f.name}</div>
      <div class="fi-size">${formatBytes(f.size)}</div>
      <button class="fi-remove" data-i="${i}">✕</button>
    `;
    item.querySelector('.fi-remove').addEventListener('click', () => {
      state.selectedFiles.splice(i, 1);
      renderFileList();
    });
    list.appendChild(item);
  });
  $('#btn-send').classList.toggle('hidden', state.selectedFiles.length === 0);
}

// --- QR ---
function renderQR(text) {
  try {
    new QRCode($('#qr-canvas'), { text, width: 180, height: 180, colorDark: '#000', colorLight: '#fff', correctLevel: QRCode.CorrectLevel.M });
  } catch (e) {}
}

function renderCodeBoxes(code) {
  const boxes = $('#code-boxes');
  boxes.innerHTML = '';
  const digits = code.padEnd(6, '·').split('');
  digits.forEach((d) => {
    const box = document.createElement('div');
    box.className = 'code-box';
    box.textContent = d;
    boxes.appendChild(box);
  });
}
function clearCodeBoxes() { $('#code-boxes').innerHTML = ''; }

// --- Events از main process ---
window.airhop.on('ready', () => {
  if (state.role === 'sender') {
    $('#send-pairing').classList.add('hidden');
    $('#send-files').classList.remove('hidden');
  } else {
    $('#receive-status').textContent = 'متصل شد! منتظر فایل...';
  }
});

window.airhop.on('peer-device', (payload) => {
  state.peerDevice = payload;
  $('#waiting-text').textContent = `متصل به ${payload?.name || 'دستگاه'}...`;
});

window.airhop.on('file-header', (meta) => {
  showView('transfer');
  state.totalBytes = meta.size;
  state.receivedBytes = 0;
  state.startTime = Date.now();
  $('#transfer-name').textContent = meta.name;
  $('#transfer-size').textContent = formatBytes(meta.size);
  $('#ring-state').textContent = 'در حال دریافت...';
  updateRing(0);
});

window.airhop.on('transfer-start', (info) => {
  state.totalBytes = info.size;
  state.receivedBytes = 0;
  state.startTime = Date.now();
  $('#transfer-name').textContent = info.name;
  $('#transfer-size').textContent = formatBytes(info.size);
  updateRing(0);
});

window.airhop.on('transfer-progress', (p) => {
  state.receivedBytes = p.receivedBytes;
  state.totalBytes = p.totalBytes || state.totalBytes;
  const percent = state.totalBytes > 0 ? Math.round((state.receivedBytes / state.totalBytes) * 100) : 0;
  updateRing(percent);
  updateStats();
});

window.airhop.on('transfer-complete', () => {
  if (state.role === 'sender') {
    $('#ring-state').textContent = 'ارسال کامل شد';
    $('#ring-percent').textContent = '100%';
    updateRing(100);
  }
});

window.airhop.on('file-saved', (info) => {
  updateRing(100);
  $('#ring-percent').textContent = '100%';
  $('#ring-state').textContent = 'ذخیره شد';
  $('#transfer-name').textContent = info.name;
  $('#saved-box').classList.remove('hidden');
  $('#btn-open-folder').onclick = () => window.airhop.openAirhopFolder();
});

window.airhop.on('connection-state', (s) => {
  console.log('connection state:', s);
});

window.airhop.on('signaling-error', (e) => {
  console.error('signaling error:', e);
});

// --- Update ring ---
function updateRing(percent) {
  const ring = $('#ring');
  ring.style.background = `conic-gradient(#3b82f6 0%, #7c3aed ${percent}%, rgba(255,255,255,0.07) ${percent}%)`;
  $('#ring-percent').textContent = percent + '%';
}

function updateStats() {
  const elapsed = (Date.now() - state.startTime) / 1000;
  if (elapsed > 0 && state.receivedBytes > 0) {
    const speedBps = state.receivedBytes / elapsed;
    $('#stat-speed').textContent = (speedBps / 1024 / 1024).toFixed(1) + ' MB/s';
    const remaining = state.totalBytes - state.receivedBytes;
    const remainingSec = speedBps > 0 ? Math.round(remaining / speedBps) : 0;
    $('#stat-time').textContent = remainingSec > 0 ? formatDuration(remainingSec) : '—';
  }
}

// --- Helpers ---
function formatBytes(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  return (bytes / (1024 * 1024 * 1024)).toFixed(2) + ' GB';
}

function formatDuration(sec) {
  if (sec < 60) return sec + ' ثانیه';
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return m + ' دقیقه ' + s + ' ثانیه';
}

function iconGlyph(ext) {
  const map = {
    jpg:'🖼', jpeg:'🖼', png:'🖼', gif:'🖼', webp:'🖼',
    mp4:'🎬', mov:'🎬', mkv:'🎬', avi:'🎬',
    mp3:'🎵', wav:'🎵', flac:'🎵',
    pdf:'📄', doc:'📝', docx:'📝', txt:'📝',
    zip:'🗜', rar:'🗜', '7z':'🗜',
  };
  return map[ext] || '📄';
}

function iconColor(ext) {
  if (['jpg','jpeg','png','gif','webp'].includes(ext)) return '#34d399';
  if (['mp4','mov','mkv','avi'].includes(ext)) return '#ec4899';
  if (['mp3','wav','flac'].includes(ext)) return '#06b6d4';
  if (['pdf'].includes(ext)) return '#f87171';
  if (['zip','rar','7z'].includes(ext)) return '#fbbf24';
  return '#a78bfa';
}
