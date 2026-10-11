// Member actions as a transport-neutral route table. The Express server mounts these under /api,
// and the offline app build runs the same table against an in-browser SQLite database.
import { SLOTS } from './seed.js';
import type { Notifier } from './services/notifier.js';
import type { PaymentProvider, PayMethod } from './services/payments.js';
import { buildState, defaulters, guestParkingFree } from './state.js';
import { HttpError, randomDigits, type Role, type Store, type User } from './store.js';
import { addDays, nowHM, nowIso, period, today } from './time.js';

export interface Deps {
  payments: PaymentProvider;
  notifier: Notifier;
  /** Enables simulated replies from flats that have no app user. */
  demo: boolean;
}
export interface UploadedFile { filename: string; originalname: string }
export interface RouteCtx { db: Store; deps: Deps; user: User; params: Record<string, string>; body: any; file?: UploadedFile }
export interface Route {
  method: 'GET' | 'POST' | 'PUT';
  path: string;
  roles?: Role[];
  /** Multipart field holding an optional image/PDF upload. */
  upload?: string;
  handle(c: RouteCtx): unknown;
}

const PURPOSES = ['guest', 'delivery', 'cab', 'service', 'courier'];
const COMPLAINT_CATS = ['plumb', 'elec', 'lift', 'clean', 'sec', 'other'];
const EXPENSE_CATS = ['security', 'light', 'clean', 'repair', 'water', 'event'];
const SOS_TYPES = ['medical', 'fire', 'theft', 'lift'];
const GU_MONTHS = ['જાન્યુઆરી', 'ફેબ્રુઆરી', 'માર્ચ', 'એપ્રિલ', 'મે', 'જૂન', 'જુલાઈ', 'ઓગસ્ટ', 'સપ્ટેમ્બર', 'ઓક્ટોબર', 'નવેમ્બર', 'ડિસેમ્બર'];

export const str = (v: unknown, max = 500) => String(v ?? '').trim().slice(0, max);
export const bad = (msg: string): never => { throw new HttpError(400, msg); };
export const notFound = (): never => { throw new HttpError(404, 'not_found'); };
const myFlat = (u: User) => u.flat_id ?? bad('no_flat');
const id = (c: RouteCtx) => Number(c.params.id);
const ADMIN: Role[] = ['secretary', 'treasurer'];
const MEMBERS: Role[] = ['resident', 'secretary', 'treasurer'];

const nextReceiptNo = (db: Store) => {
  const seq = Number(db.setting('receipt_seq')) + 1;
  db.run("UPDATE settings SET value = ? WHERE key = 'receipt_seq'", String(seq));
  return `SR-${period().slice(2, 4)}-${String(seq).padStart(4, '0')}`;
};

export const routes: Route[] = [
  { method: 'GET', path: '/state', handle: c => buildState(c.db, c.user, c.deps.demo) },

  // Bills & payments
  {
    method: 'POST', path: '/bills/pay', async handle({ db, deps, user, body }) {
      const flat = myFlat(user);
      const method = str(body?.method, 10) as PayMethod;
      if (!['upi', 'card', 'net'].includes(method)) bad('method_invalid');
      const ids: number[] = (Array.isArray(body?.billIds) ? body.billIds : []).map(Number).filter(Number.isInteger);
      if (!ids.length) bad('no_bills');
      const marks = ids.map(() => '?').join(',');
      const bills = db.all<{ id: number; amount: number; title_gu: string; title_en: string }>(
        `SELECT id, amount, title_gu, title_en FROM bills WHERE flat_id = ? AND payment_id IS NULL AND id IN (${marks})`, flat, ...ids);
      if (bills.length !== ids.length) bad('bills_unavailable');
      const amount = bills.reduce((a, b) => a + b.amount, 0);
      const charge = await deps.payments.charge({ amount, method, flatId: flat, description: bills.map(b => b.title_en).join(', ') });
      if (!charge.ok) throw new HttpError(402, charge.error ?? 'payment_failed');
      const payment = db.tx(() => {
        // Re-check inside the transaction so a double tap cannot pay the same bill twice.
        if (db.value<number>(`SELECT COUNT(*) FROM bills WHERE payment_id IS NULL AND id IN (${marks})`, ...ids) !== ids.length) bad('bills_unavailable');
        const many = bills.length > 1;
        const monthEn = new Date().toLocaleString('en-IN', { month: 'long', timeZone: 'Asia/Kolkata' });
        const titleGu = many ? `${GU_MONTHS[Number(today().slice(5, 7)) - 1]} બિલ (${bills.length})` : bills[0].title_gu;
        const titleEn = many ? `${monthEn} bills (${bills.length})` : bills[0].title_en;
        const receiptNo = nextReceiptNo(db);
        const pid = db.run('INSERT INTO payments (receipt_no, flat_id, amount, method, title_gu, title_en, period, created_at, recorded_by, provider_ref) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          receiptNo, flat, amount, method, titleGu, titleEn, period(), nowIso(), user.id, charge.providerRef ?? null).id;
        for (const b of bills) db.run('UPDATE bills SET payment_id = ? WHERE id = ?', pid, b.id);
        db.run('INSERT INTO fund_ledger (amount, reason, ref, created_at) VALUES (?, ?, ?, ?)', amount, 'Payment', receiptNo, nowIso());
        return { id: pid, receiptNo, amount, method, flat, createdAt: nowIso(), time: nowHM() };
      });
      return { payment };
    },
  },
  {
    method: 'PUT', path: '/autopay', handle({ db, user, body }) {
      db.run('UPDATE flats SET autopay = ? WHERE id = ?', body?.enabled ? 1 : 0, myFlat(user));
      return { ok: true };
    },
  },

  // Gate
  {
    method: 'POST', path: '/visitors', roles: ['watchman'], upload: 'photo', async handle({ db, deps, user, body, file }) {
      const name = str(body?.name, 80) || 'Visitor';
      const flat = str(body?.flat, 10).toUpperCase() || bad('flat_required');
      if (!db.get('SELECT id FROM flats WHERE id = ?', flat)) bad('flat_unknown');
      const purpose = PURPOSES.includes(body?.purpose) ? body.purpose : 'guest';
      const vid = db.run("INSERT INTO visitors (name, flat_id, purpose, photo, status, in_at, logged_by) VALUES (?, ?, ?, ?, 'waiting', ?, ?)",
        name, flat, purpose, file?.filename ?? null, nowIso(), user.id).id;
      await deps.notifier.visitorAtGate(flat, name);
      // Demo only: flats without an app user "approve on a call" after a few seconds.
      const autoApprove = deps.demo && !db.get("SELECT id FROM users WHERE flat_id = ? AND role <> 'watchman'", flat);
      if (autoApprove) {
        const t: any = setTimeout(() => db.run("UPDATE visitors SET status = 'inside' WHERE id = ? AND status = 'waiting'", vid), 3000);
        t.unref?.();
      }
      return { id: vid, autoApprove };
    },
  },
  {
    method: 'POST', path: '/visitors/:id/decision', roles: MEMBERS, handle(c) {
      const v = c.db.get<{ flat_id: string; status: string }>('SELECT flat_id, status FROM visitors WHERE id = ?', id(c)) ?? notFound();
      if (v.flat_id !== c.user.flat_id) throw new HttpError(403, 'forbidden');
      if (v.status !== 'waiting') bad('already_decided');
      c.db.run('UPDATE visitors SET status = ?, decided_by = ? WHERE id = ?', c.body?.approve ? 'inside' : 'denied', c.user.id, id(c));
      return { ok: true };
    },
  },
  {
    method: 'POST', path: '/visitors/:id/exit', roles: ['watchman'], handle(c) {
      if (!c.db.run("UPDATE visitors SET status = 'out', out_at = ? WHERE id = ? AND status = 'inside'", nowIso(), id(c)).changes) bad('not_inside');
      return { ok: true };
    },
  },
  {
    method: 'POST', path: '/passes', roles: MEMBERS, handle({ db, user, body }) {
      const flat = myFlat(user);
      const name = str(body?.name, 80) || 'Guest';
      const validOn = body?.when === 'tomorrow' ? addDays(today(), 1) : today();
      let code: string;
      do code = randomDigits(6);
      while (db.get('SELECT id FROM gate_passes WHERE code = ? AND valid_on >= ?', code, today()));
      db.run("INSERT INTO gate_passes (flat_id, name, valid_on, window_gu, window_en, code, created_by, created_at) VALUES (?, ?, ?, '', '', ?, ?, ?)",
        flat, name, validOn, code, user.id, nowIso());
      return { code };
    },
  },
  {
    method: 'POST', path: '/passes/verify', roles: ['watchman'], handle({ db, body }) {
      const p = db.get<{ name: string; flat_id: string }>('SELECT name, flat_id FROM gate_passes WHERE code = ? AND valid_on = ?', str(body?.code, 10), today());
      return p ? { valid: true, name: p.name, flat: p.flat_id } : { valid: false };
    },
  },
  {
    method: 'POST', path: '/staff/:id/attendance', roles: ['watchman'], handle(c) {
      if (!c.db.get('SELECT id FROM staff WHERE id = ?', id(c))) notFound();
      const open = c.db.get<{ id: number }>('SELECT id FROM staff_attendance WHERE staff_id = ? AND date = ? AND out_time IS NULL ORDER BY id DESC LIMIT 1', id(c), today());
      if (open) c.db.run('UPDATE staff_attendance SET out_time = ? WHERE id = ?', nowHM(), open.id);
      else c.db.run('INSERT INTO staff_attendance (staff_id, date, in_time) VALUES (?, ?, ?)', id(c), today(), nowHM());
      return { in: !open };
    },
  },
  {
    method: 'POST', path: '/sos', async handle({ db, deps, user, body }) {
      const type = SOS_TYPES.includes(body?.type) ? body.type : 'medical';
      const sid = db.run('INSERT INTO sos_alerts (flat_id, user_id, type, created_at) VALUES (?, ?, ?, ?)', user.flat_id, user.id, type, nowIso()).id;
      await deps.notifier.sosAlert(user.flat_id, type);
      return { id: sid };
    },
  },
  {
    method: 'POST', path: '/sos/:id/resolve', roles: ['watchman', ...ADMIN], handle(c) {
      c.db.run('UPDATE sos_alerts SET resolved_at = ?, resolved_by = ? WHERE id = ? AND resolved_at IS NULL', nowIso(), c.user.id, id(c));
      return { ok: true };
    },
  },

  // Community
  {
    method: 'POST', path: '/complaints', roles: MEMBERS, upload: 'photo', handle({ db, user, body, file }) {
      const flat = myFlat(user);
      const text = str(body?.text, 1000) || bad('text_required');
      const category = COMPLAINT_CATS.includes(body?.category) ? body.category : 'other';
      const code = db.tx(() => {
        const seq = Number(db.setting('complaint_seq')) + 1;
        db.run("UPDATE settings SET value = ? WHERE key = 'complaint_seq'", String(seq));
        db.run("INSERT INTO complaints (code, flat_id, category, text_gu, text_en, status, attachment, attachment_name, created_at, created_by) VALUES (?, ?, ?, ?, ?, 'open', ?, ?, ?, ?)",
          `C-${seq}`, flat, category, text, text, file?.filename ?? null, file?.originalname ?? null, nowIso(), user.id);
        return `C-${seq}`;
      });
      return { code };
    },
  },
  {
    method: 'POST', path: '/complaints/:id/advance', roles: ADMIN, handle(c) {
      c.db.run("UPDATE complaints SET status = CASE status WHEN 'open' THEN 'progress' ELSE 'resolved' END WHERE id = ?", id(c));
      return { ok: true };
    },
  },
  {
    method: 'POST', path: '/notices', roles: ['secretary'], async handle({ db, deps, user, body }) {
      const title = str(body?.title, 140) || bad('title_required');
      const text = str(body?.body, 2000);
      db.run('INSERT INTO notices (title_gu, title_en, body_gu, body_en, pinned, created_at, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
        title, title, text, text, body?.pinned ? 1 : 0, nowIso(), user.id);
      const flats = Number(db.setting('total_flats'));
      await deps.notifier.broadcastNotice(title, flats);
      return { flats };
    },
  },
  {
    method: 'POST', path: '/events/:id/rsvp', handle(c) {
      if (!c.db.get('SELECT id FROM events WHERE id = ?', id(c))) notFound();
      const r = c.db.run('DELETE FROM event_rsvps WHERE event_id = ? AND user_id = ?', id(c), c.user.id);
      if (!r.changes) c.db.run('INSERT INTO event_rsvps (event_id, user_id) VALUES (?, ?)', id(c), c.user.id);
      return { going: !r.changes };
    },
  },
  {
    method: 'POST', path: '/polls/:id/vote', handle(c) {
      const poll = c.db.get<{ ends_on: string }>('SELECT ends_on FROM polls WHERE id = ?', id(c)) ?? notFound();
      if (poll.ends_on < today()) bad('poll_closed');
      const option = Number(c.body?.optionId);
      if (!c.db.get('SELECT id FROM poll_options WHERE id = ? AND poll_id = ?', option, id(c))) bad('option_invalid');
      if (!c.db.run('INSERT OR IGNORE INTO poll_votes (poll_id, user_id, option_id) VALUES (?, ?, ?)', id(c), c.user.id, option).changes) bad('already_voted');
      return { ok: true };
    },
  },

  // Facilities
  {
    method: 'POST', path: '/bookings', handle({ db, user, body }) {
      const flat = myFlat(user);
      const a = db.get<{ id: string; fee: number }>('SELECT id, fee FROM amenities WHERE id = ?', str(body?.amenity, 20)) ?? bad('amenity_invalid');
      const date = str(body?.date, 10);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || date < today() || date > addDays(today(), 30)) bad('date_invalid');
      const slot = str(body?.slot, 10);
      if (!SLOTS.includes(slot)) bad('slot_invalid');
      const r = db.run('INSERT OR IGNORE INTO amenity_bookings (amenity_id, date, slot, flat_id, fee, created_at) VALUES (?, ?, ?, ?, ?, ?)', a.id, date, slot, flat, a.fee, nowIso());
      if (!r.changes) throw new HttpError(409, 'slot_taken');
      return { id: r.id };
    },
  },
  {
    method: 'POST', path: '/guest-parking', handle({ db, user }) {
      const flat = myFlat(user);
      const n = db.tx(() => {
        if (guestParkingFree(db) <= 0) throw new HttpError(409, 'parking_full');
        const n = db.value<number>('SELECT COALESCE(MAX(slot_no), 0) + 1 FROM guest_parking WHERE date = ?', today());
        db.run('INSERT INTO guest_parking (date, slot_no, flat_id, created_at) VALUES (?, ?, ?, ?)', today(), n, flat, nowIso());
        return n;
      });
      return { slot: `G-${String(n).padStart(2, '0')}` };
    },
  },

  // Finance (committee)
  {
    method: 'POST', path: '/expenses', roles: ['treasurer'], upload: 'file', handle({ db, user, body, file }) {
      const amount = Math.round(Number(String(body?.amount ?? '').replace(/[^\d.]/g, '')));
      if (!(amount > 0)) bad('amount_required');
      const title = str(body?.vendor, 140) || bad('vendor_required');
      const category = EXPENSE_CATS.includes(body?.category) ? body.category : 'repair';
      const eid = db.run("INSERT INTO expenses (category, title_gu, title_en, amount, status, attachment, attachment_name, submitted_by, submitted_at) VALUES (?, ?, ?, ?, 'pending', ?, ?, ?, ?)",
        category, title, title, amount, file?.filename ?? null, file?.originalname ?? null, user.id, nowIso()).id;
      return { id: eid };
    },
  },
  {
    method: 'POST', path: '/expenses/:id/decision', roles: ['secretary'], handle(c) {
      c.db.tx(() => {
        const e = c.db.get<{ amount: number; title_en: string }>("SELECT amount, title_en FROM expenses WHERE id = ? AND status = 'pending'", id(c)) ?? notFound();
        const approve = !!c.body?.approve;
        c.db.run('UPDATE expenses SET status = ?, decided_by = ?, decided_at = ? WHERE id = ?', approve ? 'approved' : 'rejected', c.user.id, nowIso(), id(c));
        if (approve) c.db.run('INSERT INTO fund_ledger (amount, reason, ref, created_at) VALUES (?, ?, ?, ?)', -e.amount, `Expense: ${e.title_en}`, `E-${id(c)}`, nowIso());
      });
      return { ok: true };
    },
  },
  {
    method: 'POST', path: '/cash', roles: ['treasurer'], handle({ db, user, body }) {
      const flat = str(body?.flat, 10);
      const payment = db.tx(() => {
        const bills = db.all<{ id: number; amount: number }>('SELECT id, amount FROM bills WHERE flat_id = ? AND payment_id IS NULL', flat);
        if (!bills.length) bad('nothing_due');
        const amount = bills.reduce((a, b) => a + b.amount, 0);
        const receiptNo = nextReceiptNo(db);
        const pid = db.run("INSERT INTO payments (receipt_no, flat_id, amount, method, title_gu, title_en, period, created_at, recorded_by) VALUES (?, ?, ?, 'cash', ?, ?, ?, ?, ?)",
          receiptNo, flat, amount, 'રોકડ ચુકવણી', 'Cash payment', period(), nowIso(), user.id).id;
        for (const b of bills) db.run('UPDATE bills SET payment_id = ? WHERE id = ?', pid, b.id);
        db.run('INSERT INTO fund_ledger (amount, reason, ref, created_at) VALUES (?, ?, ?, ?)', amount, 'Cash payment', receiptNo, nowIso());
        return { id: pid, receiptNo, amount };
      });
      return { payment };
    },
  },
  {
    method: 'POST', path: '/reminders', roles: ADMIN, async handle({ db, deps, user, body }) {
      const flat = body?.flat ? str(body.flat, 10) : null;
      const targets = defaulters(db).filter(d => !flat || d.flat === flat);
      for (const d of targets) {
        db.run('INSERT INTO reminders (flat_id, sent_at, sent_by) VALUES (?, ?, ?)', d.flat, today() + 'T' + nowHM(), user.id);
        await deps.notifier.sendDuesReminder(d.flat, d.amount);
      }
      return { sent: targets.length };
    },
  },
];

/** Finds the route for a method and path (relative to /api), with its :params. */
export function matchRoute(method: string, path: string) {
  const parts = path.split('?')[0].split('/').filter(Boolean);
  for (const r of routes) {
    if (r.method !== method) continue;
    const pat = r.path.split('/').filter(Boolean);
    if (pat.length !== parts.length) continue;
    const params: Record<string, string> = {};
    if (pat.every((p, i) => p.startsWith(':') ? (params[p.slice(1)] = decodeURIComponent(parts[i]), true) : p === parts[i])) return { route: r, params };
  }
  return null;
}

/** Runs a matched route after the role check. */
export async function runRoute(route: Route, ctx: RouteCtx) {
  if (route.roles && !route.roles.includes(ctx.user.role)) throw new HttpError(403, 'forbidden');
  return route.handle(ctx);
}
