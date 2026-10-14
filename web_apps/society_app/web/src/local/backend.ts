// Offline backend for the Android demo build (VITE_LOCAL=1): runs the server's own route table,
// seed data and state builder against SQLite compiled to WebAssembly, saved in the phone's storage.
import initSqlJs, { type Database } from 'sql.js';
import wasmUrl from 'sql.js/dist/sql-wasm.wasm?url';
import { resolveSession } from '../../../server/src/auth';
import { matchRoute, runRoute, type Deps } from '../../../server/src/routes';
import { seedDemo } from '../../../server/src/seed';
import { StoredOtp } from '../../../server/src/services/otp';
import { ConsoleNotifier } from '../../../server/src/services/notifier';
import { StubPaymentProvider } from '../../../server/src/services/payments';
import { HttpError, prepareSchema, type Row, type SqlValue, type Store } from '../../../server/src/store';
import { ApiError } from '../lib/api';

const KEY = 'sr.localdb.v2';
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
    prepareSchema(db);
    seedDemo(db);
    persist(db, true);
    const notifier = new ConsoleNotifier();
    const deps: Deps = { payments: new StubPaymentProvider(1200), notifier, demo: true, otp: new StoredOtp(db, (p, c) => notifier.sendOtp(p, c), DEMO_OTP, true) };
    return { db, deps };
  })();
}

/** Saves the database whenever something changed (including delayed writes such as demo auto-approvals). */
function persist(db: SqlJsStore, force = false) {
  const total = db.value<number>('SELECT total_changes()');
  if (!force && total === savedChanges) return;
  savedChanges = total;
  try { localStorage.setItem(KEY, toB64(db.raw.export())); } catch { /* storage full or unavailable */ }
}

async function readBody(body: unknown) {
  if (!(body instanceof FormData)) return { body, file: undefined };
  const fields: Record<string, string> = {};
  let file: { filename: string; originalname: string; size: number } | undefined;
  body.forEach((v, k) => { if (typeof v === 'string') fields[k] = v; else file = { filename: '', originalname: v.name, size: v.size }; });
  return { body: fields, file };
}

/** Same contract as fetch('/api' + path): runs the server's route table on the phone. */
export async function localApi(method: string, path: string, rawBody: unknown, token: string | null) {
  const { db, deps } = await open();
  try {
    const [p, qs] = path.split('?');
    const read = await readBody(rawBody);
    const body = method === 'GET' ? Object.fromEntries(new URLSearchParams(qs ?? '')) : read.body;
    const m = matchRoute(method, p);
    if (!m) throw new HttpError(404, 'not_found');
    const session = m.route.auth === 'public' ? undefined : resolveSession(db, token ?? undefined);
    const result = await runRoute(m.route, { db, deps, session, token: token ?? undefined, params: m.params, body, file: read.file });
    return JSON.parse(JSON.stringify(result ?? null));
  } catch (e) {
    if (e instanceof HttpError) throw new ApiError(e.status, e.message);
    console.error(e);
    throw new ApiError(500, 'server_error');
  } finally {
    persist(db);
  }
}
