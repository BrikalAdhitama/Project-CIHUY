import { createHash, timingSafeEqual } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

export const kinds = ['progress', 'motivation'];
export function preferences(input) {
  if (!input || typeof input.enabled !== 'boolean' || !['local', 'push'].includes(input.mode)) throw new Error('invalid-settings');
  for (const key of ['progressTime', 'motivationTime']) {
    if (typeof input[key] !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(input[key])) throw new Error('invalid-time');
  }
  if (typeof input.timezone !== 'string' || input.timezone.length > 100) throw new Error('invalid-timezone');
  new Intl.DateTimeFormat('en', { timeZone: input.timezone });
  return Object.fromEntries(['enabled', 'mode', 'progressTime', 'motivationTime', 'timezone'].map(k => [k, input[k]]));
}
export function localSlot(now, timezone) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
  }).formatToParts(now).map(p => [p.type, p.value]));
  return { date: `${parts.year}-${parts.month}-${parts.day}`, time: `${parts.hour}:${parts.minute}` };
}
export function schedulerAuthorized(header, secret) {
  if (!secret || secret.length < 32) return false;
  const actual = Buffer.from(header ?? '');
  const expected = Buffer.from(`Bearer ${secret}`);
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

export class NotificationStore {
  constructor(path = ':memory:') {
    this.db = new DatabaseSync(path);
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
      CREATE TABLE IF NOT EXISTS devices(id TEXT PRIMARY KEY, uid TEXT NOT NULL, token TEXT UNIQUE NOT NULL, settings TEXT NOT NULL, updated INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS deliveries(id TEXT PRIMARY KEY, device TEXT NOT NULL, uid TEXT NOT NULL, kind TEXT NOT NULL, claimed INTEGER NOT NULL, status TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS limits(id TEXT PRIMARY KEY, bucket INTEGER NOT NULL, count INTEGER NOT NULL);`);
  }
  register(uid, body, now = Date.now()) {
    if (!body || typeof body.deviceId !== 'string' || !/^[a-f0-9-]{36}$/.test(body.deviceId) || typeof body.token !== 'string' || body.token.length < 20 || body.token.length > 4096) throw new Error('invalid-device');
    const settings = preferences(body.settings);
    const existing = this.db.prepare('SELECT uid FROM devices WHERE id=? OR token=?').all(body.deviceId, body.token);
    if (existing.some(row => row.uid !== uid)) throw new Error('device-conflict');
    const result = this.db.prepare(`INSERT INTO devices VALUES(?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET token=excluded.token,settings=excluded.settings,updated=excluded.updated WHERE devices.uid=excluded.uid`).run(body.deviceId, uid, body.token, JSON.stringify(settings), now);
    if (!result.changes) throw new Error('device-conflict');
  }
  remove(uid, id) { this.db.prepare('DELETE FROM devices WHERE uid=? AND id=?').run(uid, id); }
  rateLimit(key, now = Date.now(), maximum = 60) {
    const bucket = Math.floor(now / 60000);
    const row = this.db.prepare(`INSERT INTO limits VALUES(?,?,1) ON CONFLICT(id) DO UPDATE SET bucket=excluded.bucket,count=CASE WHEN limits.bucket=excluded.bucket THEN limits.count+1 ELSE 1 END RETURNING count`).get(key, bucket);
    return row.count <= maximum;
  }
  async send(device, kind, slot, send, now) {
    const current = this.db.prepare('SELECT uid,token,settings FROM devices WHERE id=?').get(device.id);
    if (!current || current.uid !== device.uid || current.token !== device.token) return false;
    const settings = JSON.parse(current.settings);
    if (!settings.enabled || settings.mode !== 'push') return false;
    // The unique claim survives restarts and concurrent workers. Never retry an
    // ambiguous provider result: avoiding duplicate sends takes precedence.
    const id = createHash('sha256').update(`${device.uid}/${device.id}/${kind}/${slot}`).digest('hex');
    const claim = this.db.prepare("INSERT OR IGNORE INTO deliveries VALUES(?,?,?,?,?,'claimed')").run(id, device.id, device.uid, kind, now.getTime());
    if (!claim.changes) return false;
    try {
      await send({ token: device.token, data: { uid: device.uid, kind, deliveryId: id }, android: { priority: 'high', ttl: 3600000 } });
      this.db.prepare("UPDATE deliveries SET status='sent' WHERE id=?").run(id);
    } catch (error) {
      this.db.prepare("UPDATE deliveries SET status='failed' WHERE id=?").run(id);
      if (['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(error.code)) this.remove(device.uid, device.id);
    }
    return true;
  }
  async dispatch(send, now = new Date(), onlyUid = null) {
    let claimed = 0;
    // Expire abandoned installations; the app renews registration when opened.
    const devices = this.db.prepare('SELECT * FROM devices WHERE updated>?').all(now.getTime() - 30 * 86400000);
    for (const device of devices) {
      if (onlyUid && device.uid !== onlyUid) continue;
      const settings = JSON.parse(device.settings);
      if (!settings.enabled || settings.mode !== 'push') continue;
      const slot = localSlot(now, settings.timezone);
      for (const kind of kinds) {
        if (onlyUid || slot.time === settings[`${kind}Time`]) {
          // One delivery per kind/device/local date, even after schedule changes
          // or a repeated wall-clock minute during DST.
          const key = onlyUid ? `test/${Math.floor(now.getTime() / 60000)}` : slot.date;
          if (await this.send(device, kind, key, send, now)) claimed++;
          if (onlyUid) break;
        }
      }
    }
    return claimed;
  }
  close() { this.db.close(); }
}
