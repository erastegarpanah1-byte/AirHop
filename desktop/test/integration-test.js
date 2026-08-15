// تست integration — شبیه‌سازی دو peer (sender + receiver) با node-datachannel
// برای اطمینان از اینکه پروتکل signaling و انتقال فایل درست کار می‌کند.

const WebSocket = require('ws');
const nodeDataChannel = require('node-datachannel');

const SIGNALING = 'https://airhop-signaling.e-rastegarpanah1.workers.dev';
const WS = SIGNALING.replace('https://', 'wss://');
const ICE = ['stun:stun.l.google.com:19302'];
const CHUNK_SIZE = 64 * 1024;

async function test() {
  console.log('1. ساخت room (sender)...');
  const createResp = await fetch(`${SIGNALING}/room`, { method: 'POST' });
  const { code } = await createResp.json();
  console.log('   کد جفت‌سازی:', code);

  // --- Sender ---
  console.log('2. اتصال sender به WebSocket...');
  const senderWs = new WebSocket(`${WS}/room/${code}/ws?role=sender`);
  const receiverWs = new WebSocket(`${WS}/room/${code}/ws?role=receiver`);

  let senderPC, receiverPC, senderDC, receiverDC;
  let senderReady = false, receiverReady = false;

  // Sender PeerConnection
  senderPC = new nodeDataChannel.PeerConnection('Sender', { iceServers: ICE });
  senderPC.onLocalDescription((sdp, type) => {
    console.log('   sender onLocalDescription:', type);
    senderWs.send(JSON.stringify({ type: type === 'Answer' ? 'answer' : 'offer', sdp }));
  });
  senderPC.onLocalCandidate((candidate, mid) => {
    senderWs.send(JSON.stringify({ type: 'ice', candidate: { candidate, sdpMid: mid } }));
  });

  // Receiver PeerConnection
  receiverPC = new nodeDataChannel.PeerConnection('Receiver', { iceServers: ICE });
  receiverPC.onLocalDescription((sdp, type) => {
    console.log('   receiver onLocalDescription:', type);
    receiverWs.send(JSON.stringify({ type: type === 'Answer' ? 'answer' : 'offer', sdp }));
  });
  receiverPC.onLocalCandidate((candidate, mid) => {
    receiverWs.send(JSON.stringify({ type: 'ice', candidate: { candidate, sdpMid: mid } }));
  });
  receiverPC.onDataChannel((dc) => {
    receiverDC = dc;
    console.log('   receiver onDataChannel دریافت شد');
    dc.onMessage((msg) => {
      if (typeof msg === 'string') {
        const m = JSON.parse(msg);
        if (m.type === 'file-header') {
          console.log('   receiver دریافت file-header:', m.metadata);
        } else if (m.type === 'file-end') {
          console.log('   receiver دریافت file-end — انتقال کامل شد ✅');
          console.log('\n✅ تست موفق بود! پروتکل درست کار می‌کند.');
          process.exit(0);
        }
      }
    });
  });

  // handler پیام‌های signaling
  function handleSenderMsg(msg) {
    if (msg.type === 'ready') {
      senderReady = true;
      console.log('   sender دریافت ready');
      senderDC = senderPC.createDataChannel('file-transfer', { ordered: true });
      senderDC.onOpen(() => {
        console.log('   sender data channel باز شد — شروع انتقال');
        // ارسال یک فایل تستی
        const testData = Buffer.from('Hello AirHop! این یک تست انتقال فایل است.'.repeat(1000));
        senderDC.sendMessage(JSON.stringify({
          type: 'file-header',
          metadata: { id: 'test.txt', name: 'test.txt', size: testData.length },
        }));
        let offset = 0;
        while (offset < testData.length) {
          const end = Math.min(offset + CHUNK_SIZE, testData.length);
          senderDC.sendMessageBinary(testData.subarray(offset, end));
          offset = end;
        }
        senderDC.sendMessage(JSON.stringify({ type: 'file-end' }));
        console.log('   sender فایل را کامل ارسال کرد');
      });
    } else if (msg.type === 'offer') {
      senderPC.setRemoteDescription(msg.sdp, 'Offer');
    } else if (msg.type === 'answer') {
      senderPC.setRemoteDescription(msg.sdp, 'Answer');
    } else if (msg.type === 'ice') {
      senderPC.addRemoteCandidate(msg.candidate.candidate, msg.candidate.sdpMid || '0');
    }
  }

  function handleReceiverMsg(msg) {
    if (msg.type === 'ready') {
      receiverReady = true;
      console.log('   receiver دریافت ready');
    } else if (msg.type === 'offer') {
      receiverPC.setRemoteDescription(msg.sdp, 'Offer');
    } else if (msg.type === 'answer') {
      receiverPC.setRemoteDescription(msg.sdp, 'Answer');
    } else if (msg.type === 'ice') {
      receiverPC.addRemoteCandidate(msg.candidate.candidate, msg.candidate.sdpMid || '0');
    }
  }

  senderWs.on('message', (d) => {
    const msg = JSON.parse(d.toString());
    if (msg.type === 'welcome') { console.log('   sender welcome peerId=', msg.peerId); return; }
    handleSenderMsg(msg);
  });
  receiverWs.on('message', (d) => {
    const msg = JSON.parse(d.toString());
    if (msg.type === 'welcome') { console.log('   receiver welcome peerId=', msg.peerId); return; }
    handleReceiverMsg(msg);
  });

  // timeout
  setTimeout(() => {
    console.log('\n❌ timeout — تست کامل نشد');
    process.exit(1);
  }, 20000);
}

test().catch((e) => {
  console.error('خطا:', e);
  process.exit(1);
});
