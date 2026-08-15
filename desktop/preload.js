// AirHop Desktop — Preload Script
// پل امن بین renderer و main process با contextIsolation.

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('airhop', {
  // --- IPC (invoke) ---
  createRoom: () => ipcRenderer.invoke('airhop:create-room'),
  joinRoom: (code) => ipcRenderer.invoke('airhop:join-room', code),
  pickFiles: () => ipcRenderer.invoke('airhop:pick-files'),
  sendFiles: (paths) => ipcRenderer.invoke('airhop:send-files', paths),
  openAirhopFolder: () => ipcRenderer.invoke('airhop:open-airhop-folder'),
  reset: () => ipcRenderer.invoke('airhop:reset'),

  // --- Events (main → renderer) ---
  on: (channel, callback) => {
    const valid = [
      'signaling-open',
      'signaling-error',
      'welcome',
      'ready',
      'peer-device',
      'peer-left',
      'connection-state',
      'channel-open',
      'channel-closed',
      'file-header',
      'transfer-start',
      'transfer-progress',
      'transfer-complete',
      'file-saved',
      'log',
    ];
    if (valid.includes(channel)) {
      ipcRenderer.on(channel, (event, payload) => callback(payload));
    }
  },
});
