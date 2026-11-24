import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { randomUUID } from 'node:crypto';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { existsSync, unlinkSync } from 'node:fs';
import { NotificationStore, preferences, localSlot, schedulerAuthorized } from '../notifications.mjs';
import { createApi } from '../server.mjs';

const now = new Date('2026-11-03T00:00:00Z');
const settings = { enabled: true, mode: 'push', progressTime: '08:00', motivationTime: '20:00', timezone: 'Asia/Makassar' };
const device = (suffix = 'a') => ({ deviceId: `${suffix.repeat(8)}-${suffix.repeat(4)}-${suffix.repeat(4)}-${suffix.repeat(4)}-${suffix.repeat(12)}`, token: suffix.repeat(60), settings });

test('validates schedules/timezones; timezone follows local date', () => {
  assert.throws(() => preferences({ ...settings, progressTime: '25:00' }));
  assert.throws(() => preferences({ ...settings, timezone: 'invalid' }));
  assert.throws(() => preferences({ ...settings, enabled: 'true' }));
  assert.deepEqual(localSlot(now, 'Asia/Makassar'), { date: '2026-11-03', time: '08:00' });
});
test('unique durable claims prevent repeated/concurrent sends', async () => {
  const store = new NotificationStore();
  try {
    store.register('A', device(), now.getTime());
    const messages = [];
    const send = async message => messages.push(message);
    await Promise.all([store.dispatch(send, now), store.dispatch(send, now)]);
    await store.dispatch(send, now);
    assert.equal(messages.length, 1);
    assert.equal(messages[0].data.uid, 'A');
    assert.equal(messages[0].notification, undefined, 'no auto-displayed sensitive payload');
    assert.deepEqual(Object.keys(messages[0].data).sort(), ['deliveryId', 'kind', 'uid']);
    store.register('A', { ...device(), settings: { ...settings, progressTime: '08:01' } }, now.getTime());
    await store.dispatch(send, new Date(now.getTime() + 60000));
    assert.equal(messages.length, 1, 'editing a schedule cannot resend the same day');
  } finally { store.close(); }
});
test('opt-out, local mode and expired installations do not send', async () => {
  const store = new NotificationStore();
  try {
    store.register('A', { ...device('a'), settings: { ...settings, enabled: false } }, now.getTime());
    store.register('B', { ...device('b'), settings: { ...settings, mode: 'local' } }, now.getTime());
    store.register('C', device('c'), now.getTime() - 31 * 86400000);
    assert.equal(await store.dispatch(async () => assert.fail('unexpected send'), now), 0);
  } finally { store.close(); }
});
test('delivery claims survive a backend restart', async () => {
  const path = join(tmpdir(), `cihuy-notification-test-${randomUUID()}.sqlite`);
  let store = new NotificationStore(path);
  try {
    store.register('A', device(), now.getTime());
    await store.dispatch(async () => {}, now);
    store.close();
    store = new NotificationStore(path);
    assert.equal(await store.dispatch(async () => assert.fail('duplicate after restart'), now), 0);
  } finally {
    store.close();
    for (const file of [path, `${path}-wal`, `${path}-shm`]) { if (existsSync(file)) unlinkSync(file); }
  }
});
test('failed/ambiguous sends are not retried; invalid tokens removed', async () => {
  const store = new NotificationStore();
  try {
    store.register('A', device(), now.getTime());
    let calls = 0;
    const send = async () => { calls++; throw Object.assign(new Error(), { code: 'messaging/registration-token-not-registered' }); };
    await store.dispatch(send, now);
    await store.dispatch(send, now);
    assert.equal(calls, 1);
    assert.equal(store.db.prepare('SELECT count(*) AS count FROM devices').get().count, 0);
  } finally { store.close(); }
});
test('token rotation preserves ownership; cross-account mutation rejected', () => {
  const store = new NotificationStore();
  try {
    store.register('A', device(), now.getTime());
    store.register('A', { ...device(), token: 'rotated'.repeat(10) }, now.getTime());
    assert.throws(() => store.register('B', device()), /device-conflict/);
    store.remove('B', device().deviceId);
    assert.equal(store.db.prepare('SELECT uid,token FROM devices').get().uid, 'A');
    store.remove('A', device().deviceId);
    assert.equal(store.db.prepare('SELECT count(*) AS count FROM devices').get().count, 0);
  } finally { store.close(); }
});
test('API uses verified UID, enforces access controls, limits test sends', async () => {
  const store = new NotificationStore();
  const messages = [];
  const server = createApi({ store, verify: async token => { if (!['A', 'B'].includes(token)) throw new Error(); return { uid: token }; }, send: async m => messages.push(m), schedulerSecret: 'x'.repeat(32) });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const url = `http://127.0.0.1:${server.address().port}`;
  const request = (path, method, token, body) => fetch(url + path, { method, headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}), 'Content-Type': 'application/json' }, ...(body ? { body: JSON.stringify(body) } : {}) });
  try {
    assert.equal((await request('/v1/device', 'PUT', null, device())).status, 401);
    assert.equal((await request('/v1/device', 'PUT', 'bad', device())).status, 401);
    assert.equal((await request('/internal/dispatch', 'POST', 'A')).status, 403);
    assert.equal((await request('/v1/device', 'PUT', 'A', { ...device(), uid: 'B' })).status, 200);
    assert.equal((await request('/v1/device', 'PUT', 'B', device('b'))).status, 200);
    assert.equal((await request('/v1/test', 'POST', 'A', { uid: 'B' })).status, 200);
    assert.equal(messages.length, 1);
    assert.equal(messages[0].data.uid, 'A');
    assert.equal((await request('/v1/test', 'POST', 'A')).status, 429);
    assert.equal(schedulerAuthorized('Bearer x', ''), false);
  } finally { server.close(); await once(server, 'close'); store.close(); }
});
test('API stays available without credentials and refuses sends', async () => {
  const store = new NotificationStore();
  const server = createApi({ store });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  const url = `http://127.0.0.1:${server.address().port}`;
  try {
    assert.deepEqual(await fetch(url + '/health').then(r => r.json()), { configured: false });
    assert.equal((await fetch(url + '/v1/test', { method: 'POST' })).status, 503);
  } finally { server.close(); await once(server, 'close'); store.close(); }
});
