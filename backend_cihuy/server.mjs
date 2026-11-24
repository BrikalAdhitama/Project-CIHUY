import { createServer } from 'node:http';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { NotificationStore, schedulerAuthorized } from './notifications.mjs';

export function createApi({ store, verify, send, schedulerSecret }) {
  return createServer(async (request, response) => {
    const reply = (status, data) => { response.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); response.end(JSON.stringify(data)); };
    try {
      const path = new URL(request.url, 'http://localhost').pathname;
      if (request.method === 'GET' && path === '/health') return reply(200, { configured: Boolean(verify && send) });
      if (!verify || !send) return reply(503, { error: 'Layanan push belum dikonfigurasi.' });
      if (path === '/internal/dispatch' && request.method === 'POST') {
        if (!schedulerAuthorized(request.headers.authorization, schedulerSecret)) return reply(403, { error: 'Forbidden' });
        return reply(200, { claimed: await store.dispatch(send) });
      }
      const bearer = request.headers.authorization?.match(/^Bearer (\S+)$/)?.[1];
      if (!bearer) return reply(401, { error: 'Authentication required' });
      let identity;
      try { identity = await verify(bearer); } catch { return reply(401, { error: 'Invalid session' }); }
      if (!identity?.uid) return reply(401, { error: 'Invalid session' });
      if (!store.rateLimit(identity.uid)) return reply(429, { error: 'Terlalu banyak permintaan.' });
      if (path === '/v1/device' && request.method === 'PUT') {
        let body = '';
        for await (const chunk of request) { body += chunk; if (Buffer.byteLength(body) > 10000) return reply(413, { error: 'Payload too large' }); }
        store.register(identity.uid, JSON.parse(body));
        return reply(200, { saved: true });
      }
      if (path.startsWith('/v1/device/') && request.method === 'DELETE') {
        store.remove(identity.uid, decodeURIComponent(path.slice('/v1/device/'.length)));
        return reply(200, { removed: true });
      }
      if (path === '/v1/test' && request.method === 'POST') {
        if (!store.rateLimit(`test:${identity.uid}`, Date.now(), 1)) return reply(429, { error: 'Tunggu satu menit sebelum mencoba lagi.' });
        return reply(200, { claimed: await store.dispatch(send, new Date(), identity.uid) });
      }
      return reply(404, { error: 'Not found' });
    } catch (error) {
      // Do not log tokens, message bodies, or credential-bearing exceptions.
      const bad = error instanceof SyntaxError || error instanceof RangeError || ['invalid-settings', 'invalid-time', 'invalid-timezone', 'invalid-device', 'device-conflict'].includes(error.message);
      reply(bad ? 400 : 500, { error: bad ? 'Data notifikasi tidak valid.' : 'Permintaan belum berhasil.' });
    }
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const path = resolve(process.env.DATABASE_PATH || './data/notifications.sqlite');
  mkdirSync(dirname(path), { recursive: true });
  let verify, send;
  if (process.env.GOOGLE_CLOUD_PROJECT) {
    try {
    const { initializeApp, applicationDefault } = await import('firebase-admin/app');
    const { getAuth } = await import('firebase-admin/auth');
    const { getMessaging } = await import('firebase-admin/messaging');
    const credential = applicationDefault();
    await credential.getAccessToken();
    initializeApp({ credential, projectId: process.env.GOOGLE_CLOUD_PROJECT });
    verify = token => getAuth().verifyIdToken(token, true);
    send = message => getMessaging().send(message);
    } catch { console.error('Firebase credentials unavailable. API will return 503 until configured.'); }
  }
  const server = createApi({ store: new NotificationStore(path), verify, send, schedulerSecret: process.env.SCHEDULER_SECRET });
  server.listen(Number(process.env.PORT || 8080), process.env.HOST || '127.0.0.1', () => console.log(`Notification API listening; configured=${Boolean(verify)}`));
}
