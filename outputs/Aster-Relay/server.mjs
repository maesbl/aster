import { createServer } from 'node:http';
import { createHash, timingSafeEqual } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { WebSocketServer, WebSocket } from 'ws';

// The relay never receives the encryption key or decodes application payloads.
// A single process owns all rooms; run one replica until a shared router exists.
export function createRelay({ maxRooms = 500, maxPayload = 2_000_000 } = {}) {
  const rooms = new Map();
  const buckets = new Map();
  const http = createServer((request, response) => {
    response.setHeader('Cache-Control', 'no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    if (request.method === 'GET' && request.url === '/health') {
      response.writeHead(200, { 'Content-Type': 'application/json' });
      return response.end(JSON.stringify({ service: 'aster-relay', version: 1, status: 'ok' }));
    }
    response.writeHead(404); response.end();
  });
  http.headersTimeout = 10_000; http.requestTimeout = 15_000;
  const wss = new WebSocketServer({ noServer: true, maxPayload, perMessageDeflate: false });
  const presence = (room) => {
    for (const role of ['mac', 'phone']) {
      if (room[role]?.readyState === WebSocket.OPEN) room[role].send(JSON.stringify({ type: 'presence', online: room[role === 'mac' ? 'phone' : 'mac']?.readyState === WebSocket.OPEN }));
    }
  };
  const reject = (socket, status) => { socket.end(`HTTP/1.1 ${status}\r\nConnection: close\r\nContent-Length: 0\r\n\r\n`); };
  http.on('upgrade', (request, socket, head) => {
    socket.on('error', () => {});
    const ip = request.socket.remoteAddress; // Never trust caller-supplied forwarded headers.
    const now = Date.now();
    let bucket = buckets.get(ip);
    if (!bucket || now - bucket.start > 60_000) { bucket = { start: now, count: 0 }; buckets.set(ip, bucket); }
    if (++bucket.count > 120 || wss.clients.size >= maxRooms * 2) return reject(socket, '429 Too Many Requests');
    const roomID = request.headers['x-aster-room'];
    const role = request.headers['x-aster-role'];
    const authorization = request.headers.authorization;
    if (request.url !== '/v1/connect' || request.headers.origin || !['mac', 'phone'].includes(role) || !/^[0-9a-f-]{36}$/.test(roomID ?? '') || !/^Bearer [A-Za-z0-9_-]{43}$/.test(authorization ?? '')) return reject(socket, '401 Unauthorized');
    const hash = createHash('sha256').update(authorization).digest();
    let room = rooms.get(roomID);
    if (room && !timingSafeEqual(hash, room.hash)) return reject(socket, '403 Forbidden');
    if (!room) {
      if (rooms.size >= maxRooms) return reject(socket, '503 Service Unavailable');
      room = { hash, touched: now, mac: null, phone: null }; rooms.set(roomID, room);
    }
    wss.handleUpgrade(request, socket, head, (ws) => {
      const previous = room[role]; room[role] = ws;
      previous?.close(4001, 'Replaced by the paired device');
      room.touched = Date.now(); ws.alive = true;
      let windowStart = Date.now(), bytes = 0, messages = 0;
      ws.on('error', () => {});
      ws.on('pong', () => { ws.alive = true; });
      ws.on('message', (data, binary) => {
        if (room[role] !== ws) return;
        if (Date.now() - windowStart > 1000) { windowStart = Date.now(); bytes = 0; messages = 0; }
        bytes += data.length; messages++;
        if (!binary || bytes > 12_000_000 || messages > 40) return ws.close(4002, 'Invalid or excessive traffic');
        room.touched = Date.now();
        const peer = room[role === 'mac' ? 'phone' : 'mac'];
        if (peer?.readyState !== WebSocket.OPEN) return; // No queue, no replay, no payload storage.
        if (peer.bufferedAmount > 2_000_000) return peer.close(4003, 'Slow connection');
        peer.send(data, { binary: true }, () => {});
      });
      ws.on('close', () => { if (room[role] === ws) { room[role] = null; room.touched = Date.now(); presence(room); } });
      presence(room);
    });
  });
  const timer = setInterval(() => {
    for (const ws of wss.clients) { if (!ws.alive) ws.terminate(); else { ws.alive = false; ws.ping(); } }
    const now = Date.now();
    for (const [id, room] of rooms) if (!room.mac && !room.phone && now - room.touched > 3_600_000) rooms.delete(id);
    for (const [id, bucket] of buckets) if (now - bucket.start > 60_000) buckets.delete(id);
  }, 25_000);
  timer.unref();
  return {
    http,
    async close() { clearInterval(timer); for (const ws of wss.clients) ws.terminate(); await new Promise(resolve => wss.close(resolve)); await new Promise(resolve => http.close(resolve)); },
  };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const relay = createRelay();
  relay.http.listen(Number(process.env.PORT || 8787), process.env.HOST || '127.0.0.1', () => console.log('Aster Relay ready'));
  for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, async () => { await relay.close(); process.exit(0); });
}
