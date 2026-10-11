// Offline backend for the Android demo build (VITE_LOCAL=1): runs the server's own route table,
// seed data and state builder against SQLite compiled to WebAssembly, saved in the phone's storage.
import initSqlJs, { type Database } from 'sql.js';
import wasmUrl from 'sql.js/dist/sql-wasm.wasm?url';
import { matchRoute, runRoute, type Deps } from '../../../server/src/routes';
import { seed } from '../../../server/src/seed';
import { ConsoleNotifier } from '../../../server/src/services/notifier';
import { StubPaymentProvider } from '../../../server/src/services/payments';
import { HttpError, SCHEMA, type Row, type SqlValue, type Store, type User } from '../../../server/src/store';
import { ApiError } from '../lib/api';

const KEY = 'sr.localdb';
const DEMO_OTP = '123456';

class SqlJsStore implements Store {
  constructor(readonly raw: Database) {}
  all<T = Row>(sql: string, ...params: SqlValue[]): T[] {
    const st = this.raw.prepare(sql);
    try {
      st.bind(params as any);
      const rows: T[] = [];
      while (st.step()) rows.push(st.getAsObject() as T);
      return rows;
    } finally { st.free(); }
  }
  get<T = Row>(sql: string, ...params: SqlValue[]) { return this.all<T>(sql, ...params)[0]; }
  run(sql: string, ...params: SqlValue[]) {
    this.raw.run(sql, params as any);
    const changes = this.raw.getRowsModified();
    return { changes, id: Number(this.value('SELECT last_insert_rowid()')) };
  }
  value<T = number>(sql: string, ...params: SqlValue[]): T {
    const row = this.get(sql, ...params);
    return (row ? Object.values(row)[0] : undefined) as T;
  }
  tx<T>(fn: () => T): T {
    this.raw.exec('BEGIN');
    try { const r = fn(); this.raw.exec('COMMIT'); return r; }
    catch (e) { this.raw.exec('ROLLBACK'); throw e; }
  }
  setting(key: string) { return this.get<{ value: string }>('SELECT value FROM settings WHERE key = ?', key)?.value; }
}

const toB64 = (u8: Uint8Array) => { let s = ''; for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode(...u8.subarray(i, i + 0x8000)); return btoa(s); };
const fromB64 = (b64: string) => Uint8Array.from(atob(b64), c => c.charCodeAt(0));

let ready: Promise<{ db: SqlJsStore; deps: Deps }> | null = null;
let savedChanges = 0;

function open() {
  return ready ??= (async () => {
    const SQL = await initSqlJs({ locateFile: () => wasmUrl });
    let saved: string | null = null;
    try { saved = localStorage.getItem(KEY); } catch { /* storage unavailable */ }
    const db = new SqlJsStore(saved ? new SQL.Database(fromB64(saved)) : new SQL.Database());
    db.raw.exec(SCHEMA);
    seed(db);
    persist(db, true);
    return { db, deps: { payments: new StubPaymentProvider(1200), notifier: new ConsoleNotifier(), demo: true } };
  })();
}

/** Saves the database whenever something changed (including delayed writes such as demo auto-approvals). */
function persist(db: SqlJsStore, force = false) {
  const total = db.value<number>('SELECT total_changes()');
  if (!force && total === savedChanges) return;
  savedChanges = total;
  try { localStorage.setItem(KEY, toB64(db.raw.export())); } catch { /* storage full or unavailable */ }
}

const normalizePhone = (raw: unknown) => {
  const d = String(raw ?? '').replace(/\D/g, '');
  const ten = d.length === 12 && d.startsWith('91') ? d.slice(2) : d;
  return /^[6-9]\d{9}$/.test(ten) ? ten : null;
};

async function readBody(body: unknown) {
  if (!(body instanceof FormData)) return { body, file: undefined };
  const fields: Record<string, string> = {};
  let file: { filename: string; originalname: string } | undefined;
  body.forEach((v, k) => { if (typeof v === 'string') fields[k] = v; else file = { filename: undefined as unknown as string, originalname: v.name }; });
  return { body: fields, file };
}

export async function localApi(method: string, path: string, rawBody: unknown, token: string | null) {
  const { db, deps } = await open();
  try {
    const { body, file } = await readBody(rawBody) as { body: any; file?: { filename: string; originalname: string } };
    const userBy = (sql: string, v: SqlValue) => db.get<User>(sql, v);
    const tokenFor = (u: User) => ({ token: `local:${u.id}` });

    if (path === '/config') return { demo: true, local: true };
    if (path === '/auth/demo') return tokenFor(userBy('SELECT * FROM users WHERE role = ? ORDER BY id LIMIT 1', String(body?.role)) ?? (() => { throw new HttpError(404, 'not_found'); })());
    if (path === '/auth/otp' || path === '/auth/verify') {
      const phone = normalizePhone(body?.phone) ?? (() => { throw new HttpError(400, 'phone_invalid'); })();
      const user = userBy('SELECT * FROM users WHERE phone = ?', phone) ?? (() => { throw new HttpError(404, 'phone_unknown'); })();
      if (path === '/auth/otp') return { sent: true, devCode: DEMO_OTP };
      if (String(body?.code) !== DEMO_OTP) throw new HttpError(400, 'otp_invalid');
      return tokenFor(user);
    }

    const user = token?.startsWith('local:') ? userBy('SELECT * FROM users WHERE id = ?', Number(token.slice(6))) : undefined;
    if (!user) throw new HttpError(401, 'unauthenticated');
    if (path === '/auth/logout') return { ok: true };
    const m = matchRoute(method, path);
    if (!m) throw new HttpError(404, 'not_found');
    const result = await runRoute(m.route, { db, deps, user, params: m.params, body, file });
    return JSON.parse(JSON.stringify(result ?? null));
  } catch (e) {
    if (e instanceof HttpError) throw new ApiError(e.status, e.message);
    console.error(e);
    throw new ApiError(500, 'server_error');
  } finally {
    persist(db);
  }
}
