import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import { once } from 'node:events';
import WebSocket from 'ws';
import { createRelay } from '../server.mjs';

test('pairs devices, rejects wrong credentials, isolates rooms and does not queue commands', async () => {
  const relay = createRelay(); relay.http.listen(0, '127.0.0.1'); await once(relay.http, 'listening');
  const url = `ws://127.0.0.1:${relay.http.address().port}/v1/connect`;
  const sockets = [];
  async function join(room, token, role) {
    const ws = new WebSocket(url, { headers: { 'X-Aster-Room': room, 'X-Aster-Role': role, Authorization: `Bearer ${token}` } }); sockets.push(ws);
    ws.on('error', () => {}); const inbox = []; ws.on('message', (data, binary) => inbox.push({ data, binary }));
    await once(ws, 'open'); return { ws, inbox };
  }
  const room = randomUUID(), token = randomBytes(32).toString('base64url');
  try {
    const mac = await join(room, token, 'mac');
    await assert.rejects(join(room, randomBytes(32).toString('base64url'), 'phone'), /403/);
    const phone = await join(room, token, 'phone');
    const other = await join(randomUUID(), randomBytes(32).toString('base64url'), 'phone');
    const ciphertext = randomBytes(128);
    const received = once(phone.ws, 'message'); mac.ws.send(ciphertext); const [message, binary] = await received;
    assert.equal(binary, true); assert.deepEqual(message, ciphertext);
    assert.equal(other.inbox.filter(x => x.binary).length, 0);
    phone.ws.close(); await once(phone.ws, 'close');
    mac.ws.send(Buffer.from('must not replay'));
    await new Promise(r => setTimeout(r, 40));
    const rejoined = await join(room, token, 'phone');
    await new Promise(r => setTimeout(r, 40));
    assert.equal(rejoined.inbox.filter(x => x.binary).length, 0);
    const closed = once(rejoined.ws, 'close'); rejoined.ws.send('plaintext forbidden'); assert.equal((await closed)[0], 4002);
    const response = await fetch(url.replace('ws:', 'http:').replace('/v1/connect', '/health')); assert.equal(response.status, 200);
  } finally { for (const ws of sockets) ws.terminate(); await relay.close(); }
});
