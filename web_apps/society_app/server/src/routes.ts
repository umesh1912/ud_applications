// Every API action as a transport-neutral route table. The Express server mounts these under /api,
// and the offline demo build runs the same table against an in-browser SQLite database.
import { createSession, normalizePhone, upsertUser } from './auth.js';
import { DEMO_PHONES, SLOTS } from './seed.js';
import type { Notifier } from './services/notifier.js';
import type { OtpSender } from './services/otp.js';
import type { PaymentProvider, PayMethod } from './services/payments.js';
import { createSociety, ensureMonthlyBills, getSociety, MONTHS, nextReceiptNo, type WingSpec } from './society.js';
import { buildState, defaulters, dueFlats, guestParkingFree, isAdmin } from './state.js';
import { HttpError, randomDigits, ROLES, type Account, type Role, type Store, type User } from './store.js';
import { addDays, nowHM, nowIso, period, today } from './time.js';

export interface Deps {
  /** Online card/UPI gateway. Absent in production until one is configured: residents then pay to the society's UPI ID. */
  payments?: PaymentProvider;
  notifier: Notifier;
  otp: OtpSender;
  /** Enables one-tap demo logins and simulated replies from flats that have no app user. */
  demo: boolean;
}
export interface UploadedFile { filename: string; originalname: string; size?: number }
export interface RouteCtx {
  db: Store; deps: Deps; params: Record<string, string>; body: any; file?: UploadedFile; token?: string;
  account: Account; user: User;
}
type Auth = 'public' | 'account' | 'member';
export interface Route {
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  path: string;
  /** public: no login; account: logged in, maybe without a society yet; member (default): active society member. */
  auth?: Auth;
  roles?: Role[];
  /** Multipart field holding an optional image/PDF upload. */
  upload?: string;
  handle(c: RouteCtx): unknown;
}

const PURPOSES = ['guest', 'delivery', 'cab', 'service', 'courier'];
const COMPLAINT_CATS = ['plumb', 'elec', 'lift', 'clean', 'sec', 'other'];
const EXPENSE_CATS = ['security', 'light', 'clean', 'repair', 'water', 'event'];
const SOS_TYPES = ['medical', 'fire', 'theft', 'lift'];
const RECORD_METHODS = ['cash', 'upi', 'cheque', 'bank'];

export const str = (v: unknown, max = 500) => String(v ?? '').trim().slice(0, max);
export const bad = (msg: string): never => { throw new HttpError(400, msg); };
export const notFound = (): never => { throw new HttpError(404, 'not_found'); };
const forbidden = (): never => { throw new HttpError(403, 'forbidden'); };
const myFlat = (u: User) => u.flat_id ?? bad('no_flat');
const id = (c: RouteCtx) => Number(c.params.id);
const num = (v: unknown) => Math.round(Number(String(v ?? '').replace(/[^\d.]/g, '')));
const isDate = (s: string) => /^\d{4}-\d{2}-\d{2}$/.test(s) && !Number.isNaN(Date.parse(s));
const ADMIN: Role[] = ['secretary', 'treasurer'];
const RESIDENTS: Role[] = ['resident', 'secretary', 'treasurer'];

const flatExists = (db: Store, sid: number, flat: string) => !!db.get('SELECT id FROM flats WHERE society_id = ? AND id = ?', sid, flat);

function memberships(db: Store, userId: number) {
  return db.all(`SELECT m.id, m.society_id AS societyId, s.name AS society, s.name_gu AS societyGu, s.city, m.flat_id AS flat, m.role, m.status
    FROM members m JOIN societies s ON s.id = m.society_id WHERE m.user_id = ? AND m.status IN ('active','pending') ORDER BY m.id`, userId);
}

/** Marks bills paid by a confirmed payment and credits the society fund. */
function settle(db: Store, sid: number, paymentId: number, billIds: number[], amount: number, receiptNo: string) {
  for (const b of billIds) db.run('UPDATE bills SET payment_id = ? WHERE id = ? AND society_id = ? AND payment_id IS NULL', paymentId, b, sid);
  db.run('INSERT INTO fund_ledger (society_id, amount, reason, ref, created_at) VALUES (?, ?, ?, ?, ?)', sid, amount, 'Payment', receiptNo, nowIso());
}

const billsTitle = (n: number, single?: { title_gu: string; title_en: string }) => {
  if (n === 1 && single) return [single.title_gu, single.title_en];
  const [gu, en] = MONTHS[Number(today().slice(5, 7)) - 1];
  return [`${gu} બિલ (${n})`, `${en} bills (${n})`];
};

export const routes: Route[] = [
  // ── Sign in ──────────────────────────────────────────────
  { method: 'GET', path: '/config', auth: 'public', handle: ({ deps }) => ({ demo: deps.demo, onlinePay: !!deps.payments }) },
  {
    method: 'POST', path: '/auth/otp', auth: 'public', async handle({ deps, body }) {
      const phone = normalizePhone(body?.phone) ?? bad('phone_invalid');
      const r = await deps.otp.start(phone);
      return { sent: true, devCode: r.devCode };
    },
  },
  {
    method: 'POST', path: '/auth/verify', auth: 'public', async handle({ db, deps, body }) {
      const phone = normalizePhone(body?.phone) ?? bad('phone_invalid');
      const code = str(body?.code, 8);
      if (!/^\d{4,8}$/.test(code) || !(await deps.otp.check(phone, code))) bad('otp_invalid');
      const u = upsertUser(db, phone);
      return { token: createSession(db, u.id), isNew: u.isNew };
    },
  },
  {
    method: 'POST', path: '/auth/demo', auth: 'public', handle({ db, deps, body }) {
      if (!deps.demo) forbidden();
      const phone = DEMO_PHONES[str(body?.role, 20) as keyof typeof DEMO_PHONES] ?? notFound();
      const u = db.get<{ id: number }>('SELECT id FROM users WHERE phone = ?', phone) ?? notFound();
      return { token: createSession(db, u.id) };
    },
  },
  {
    method: 'POST', path: '/auth/logout', auth: 'account', handle({ db, token }) {
      db.run('DELETE FROM sessions WHERE token = ?', token ?? '');
      return { ok: true };
    },
  },

  // ── Account & onboarding ─────────────────────────────────
  {
    method: 'GET', path: '/me', auth: 'account', handle({ db, account, user }) {
      return { account: { id: account.id, name: account.name, nameGu: account.name_gu, phone: account.phone }, memberships: memberships(db, account.id), activeMemberId: user?.member_id ?? null };
    },
  },
  {
    method: 'PUT', path: '/me', auth: 'account', handle({ db, account, body }) {
      const name = str(body?.name, 60) || bad('name_required');
      db.run('UPDATE users SET name = ?, name_gu = ? WHERE id = ?', name, str(body?.nameGu, 60), account.id);
      return { ok: true };
    },
  },
  {
    method: 'POST', path: '/societies', auth: 'account', handle({ db, account, token, body }) {
      if (!account.name) bad('name_required');
      const wings: WingSpec[] = (Array.isArray(body?.wings) ? body.wings : []).slice(0, 26)
        .map((w: any) => ({ name: str(w?.name, 6), floors: Number(w?.floors), perFloor: Number(w?.perFloor) }));
      const name = str(body?.name, 80) || bad('society_name_required');
      const city = str(body?.city, 60) || bad('city_required');
      const flat = str(body?.flat, 12).toUpperCase();
      const upiId = str(body?.upiId, 60);
      if (upiId && !/^[\w.\-]{2,}@[a-zA-Z]{2,}$/.test(upiId)) bad('upi_invalid');
      return db.tx(() => {
        const sid = createSociety(db, { name, nameGu: str(body?.nameGu, 80), city, cityGu: str(body?.cityGu, 60), address: str(body?.address, 200), wings,
          maintenance: num(body?.maintenance) || 0, dueDay: Number(body?.dueDay) || 10, upiId }, account.id);
        if (flat && !flatExists(db, sid, flat)) bad('flat_unknown');
        const mid = db.run("INSERT INTO members (society_id, user_id, flat_id, role, status, created_at) VALUES (?, ?, ?, 'secretary', 'active', ?)", sid, account.id, flat || null, nowIso()).id;
        if (flat) db.run('UPDATE flats SET owner = ? WHERE society_id = ? AND id = ?', account.name, sid, flat);
        db.run('UPDATE sessions SET member_id = ? WHERE token = ?', mid, token ?? '');
        ensureMonthlyBills(db, sid);
        return { societyId: sid, code: getSociety(db, sid).code };
      });
    },
  },
  {
    method: 'GET', path: '/societies/lookup', auth: 'account', handle({ db, body }) {
      const s = db.get<{ id: number; name: string; name_gu: string; city: string }>('SELECT id, name, name_gu, city FROM societies WHERE code = ?', str(body?.code, 10).toUpperCase())
        ?? (() => { throw new HttpError(404, 'code_unknown'); })();
      const flats = db.all<{ id: string }>('SELECT id FROM flats WHERE society_id = ? ORDER BY wing, length(id), id', s.id).map(f => f.id);
      return { name: s.name, nameGu: s.name_gu, city: s.city, flats };
    },
  },
  {
    method: 'POST', path: '/societies/join', auth: 'account', async handle({ db, deps, account, body }) {
      if (!account.name) bad('name_required');
      const s = db.get<{ id: number }>('SELECT id FROM societies WHERE code = ?', str(body?.code, 10).toUpperCase()) ?? (() => { throw new HttpError(404, 'code_unknown'); })();
      const role: Role = body?.role === 'watchman' ? 'watchman' : 'resident';
      const flat = role === 'watchman' ? null : str(body?.flat, 12).toUpperCase();
      if (role === 'resident' && (!flat || !flatExists(db, s.id, flat))) bad('flat_unknown');
      const occupancy = body?.occupancy === 'tenant' ? 'tenant' : 'owner';
      const existing = db.get<{ id: number; status: string }>('SELECT id, status FROM members WHERE society_id = ? AND user_id = ?', s.id, account.id);
      if (existing?.status === 'active') bad('already_member');
      if (existing) db.run("UPDATE members SET flat_id = ?, role = ?, occupancy = ?, status = 'pending', created_at = ?, decided_by = NULL WHERE id = ?", flat, role, occupancy, nowIso(), existing.id);
      else db.run("INSERT INTO members (society_id, user_id, flat_id, role, status, occupancy, created_at) VALUES (?, ?, ?, ?, 'pending', ?, ?)", s.id, account.id, flat, role, occupancy, nowIso());
      await deps.notifier.joinRequest(s.id, account.name, flat);
      return { ok: true };
    },
  },
  {
    method: 'DELETE', path: '/memberships/:id', auth: 'account', handle(c) {
      // Cancel your own pending request, or leave a society.
      const m = c.db.get<{ society_id: number; role: string; status: string }>('SELECT society_id, role, status FROM members WHERE id = ? AND user_id = ?', id(c), c.account.id) ?? notFound();
      if (m.status === 'active' && m.role === 'secretary' && c.db.value<number>("SELECT COUNT(*) FROM members WHERE society_id = ? AND role = 'secretary' AND status = 'active'", m.society_id) <= 1) bad('last_secretary');
      c.db.run("UPDATE members SET status = 'removed' WHERE id = ?", id(c));
      return { ok: true };
    },
  },
  {
    method: 'POST', path: '/session/member', auth: 'account', handle({ db, account, token, body }) {
      const m = db.get<{ id: number }>("SELECT id FROM members WHERE id = ? AND user_id = ? AND status = 'active'", Number(body?.memberId), account.id) ?? notFound();
      db.run('UPDATE sessions SET member_id = ? WHERE token = ?', m.id, token ?? '');
      return { ok: true };
    },
  },

  // ── Society administration ───────────────────────────────
  { method: 'GET', path: '/state', handle: ({ db, deps, user }) => buildState(db, user, { demo: deps.demo, onlinePay: !!deps.payments }) },
  {
    method: 'POST', path: '/members/:id/decision', roles: ['secretary'], handle(c) {
      const sid = c.user.society_id;
      const m = c.db.get<{ user_id: number; flat_id: string | null; occupancy: string }>("SELECT user_id, flat_id, occupancy FROM members WHERE id = ? AND society_id = ? AND status = 'pending'", id(c), sid) ?? notFound();
      if (!c.body?.approve) { c.db.run("UPDATE members SET status = 'rejected', decided_by = ? WHERE id = ?", c.user.id, id(c)); return { ok: true }; }
      const role: Role = ROLES.includes(c.body?.role) ? c.body.role : m.flat_id ? 'resident' : 'watchman';
      if (role !== 'watchman' && !m.flat_id) bad('flat_required');
      c.db.run("UPDATE members SET status = 'active', role = ?, decided_by = ? WHERE id = ?", role, c.user.id, id(c));
      if (m.flat_id && m.occupancy === 'owner') {
        const name = c.db.value<string>('SELECT name FROM users WHERE id = ?', m.user_id);
        c.db.run("UPDATE flats SET owner = ? WHERE society_id = ? AND id = ? AND owner = ''", name, sid, m.flat_id);
      }
      return { ok: true };
    },
  },
  {
    method: 'PUT', path: '/members/:id', roles: ['secretary'], handle(c) {
      const sid = c.user.society_id;
      const m = c.db.get<{ role: Role; flat_id: string | null }>("SELECT role, flat_id FROM members WHERE id = ? AND society_id = ? AND status = 'active'", id(c), sid) ?? notFound();
      const role: Role = ROLES.includes(c.body?.role) ? c.body.role : m.role;
      if (role !== 'watchman' && !m.flat_id) bad('flat_required');
      if (m.role === 'secretary' && role !== 'secretary' && c.db.value<number>("SELECT COUNT(*) FROM members WHERE society_id = ? AND role = 'secretary' AND status = 'active'", sid) <= 1) bad('last_secretary');
      c.db.run('UPDATE members SET role = ? WHERE id = ?', role, id(c));
      return { ok: true };
    },
  },
  {
    method: 'DELETE', path: '/members/:id', roles: ['secretary'], handle(c) {
      const sid = c.user.society_id;
      const m = c.db.get<{ role: Role }>("SELECT role FROM members WHERE id = ? AND society_id = ? AND status = 'active'", id(c), sid) ?? notFound();
      if (m.role === 'secretary' && c.db.value<number>("SELECT COUNT(*) FROM members WHERE society_id = ? AND role = 'secretary' AND status = 'active'", sid) <= 1) bad('last_secretary');
      c.db.run("UPDATE members SET status = 'removed', decided_by = ? WHERE id = ?", c.user.id, id(c));
      return { ok: true };
    },
  },
  {
    method: 'PUT', path: '/society', roles: ['secretary'], handle({ db, user, body }) {
      const s = getSociety(db, user.society_id);
      const upiId = body?.upiId === undefined ? s.upi_id : str(body.upiId, 60);
      if (upiId && !/^[\w.\-]{2,}@[a-zA-Z]{2,}$/.test(upiId)) bad('upi_invalid');
      db.run(`UPDATE societies SET name = ?, name_gu = ?, city = ?, address = ?, maintenance = ?, due_day = ?, upi_id = ?, guest_parking_total = ? WHERE id = ?`,
        str(body?.name, 80) || s.name, body?.nameGu === undefined ? s.name_gu : str(body.nameGu, 80), str(body?.city, 60) || s.city,
        body?.address === undefined ? s.address : str(body.address, 200),
        body?.maintenance === undefined ? s.maintenance : Math.max(0, num(body.maintenance) || 0),
        body?.dueDay === undefined ? s.due_day : Math.min(28, Math.max(1, Number(body.dueDay) || s.due_day)),
        upiId, body?.guestParking === undefined ? s.guest_parking_total : Math.min(500, Math.max(0, Number(body.guestParking) || 0)), s.id);
      return { ok: true };
    },
  },

  // ── Bills & payments ─────────────────────────────────────
  {
    method: 'POST', path: '/bills', roles: ADMIN, handle({ db, user, body }) {
      const sid = user.society_id;
      const title = str(body?.title, 80) || bad('title_required');
      const amount = num(body?.amount);
      if (!(amount > 0)) bad('amount_required');
      const due = str(body?.dueDate, 10);
      if (!isDate(due)) bad('date_invalid');
      const target = str(body?.flat, 12).toUpperCase();
      const flats = target && target !== 'ALL' ? [target] : db.all<{ id: string }>('SELECT id FROM flats WHERE society_id = ?', sid).map(f => f.id);
      if (target && target !== 'ALL' && !flatExists(db, sid, target)) bad('flat_unknown');
      db.tx(() => { for (const f of flats)
        db.run("INSERT INTO bills (society_id, flat_id, kind, icon, title_gu, title_en, amount, due_date, period, created_at) VALUES (?, ?, 'charge', 'IconReceipt', ?, ?, ?, ?, ?, ?)",
          sid, f, title, title, amount, due, due.slice(0, 7), nowIso()); });
      return { count: flats.length };
    },
  },
  {
    method: 'POST', path: '/bills/pay', roles: RESIDENTS, async handle({ db, deps, user, body }) {
      // Online gateway checkout (demo stub, or a real gateway once configured).
      if (!deps.payments) bad('online_pay_unavailable');
      const sid = user.society_id, flat = myFlat(user);
      const method = str(body?.method, 10) as PayMethod;
      if (!['upi', 'card', 'net'].includes(method)) bad('method_invalid');
      const ids: number[] = (Array.isArray(body?.billIds) ? body.billIds : []).map(Number).filter(Number.isInteger);
      if (!ids.length) bad('no_bills');
      const marks = ids.map(() => '?').join(',');
      const bills = db.all<{ id: number; amount: number; title_gu: string; title_en: string }>(
        `SELECT id, amount, title_gu, title_en FROM bills WHERE society_id = ? AND flat_id = ? AND payment_id IS NULL AND id IN (${marks})`, sid, flat, ...ids);
      if (bills.length !== ids.length) bad('bills_unavailable');
      const amount = bills.reduce((a, b) => a + b.amount, 0);
      const charge = await deps.payments!.charge({ amount, method, flatId: flat, description: bills.map(b => b.title_en).join(', ') });
      if (!charge.ok) throw new HttpError(402, charge.error ?? 'payment_failed');
      const payment = db.tx(() => {
        // Re-check inside the transaction so a double tap cannot pay the same bill twice.
        if (db.value<number>(`SELECT COUNT(*) FROM bills WHERE society_id = ? AND payment_id IS NULL AND id IN (${marks})`, sid, ...ids) !== ids.length) bad('bills_unavailable');
        const [titleGu, titleEn] = billsTitle(bills.length, bills[0]);
        const receiptNo = nextReceiptNo(db, sid);
        const pid = db.run('INSERT INTO payments (society_id, receipt_no, flat_id, amount, method, title_gu, title_en, period, created_at, recorded_by, provider_ref) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          sid, receiptNo, flat, amount, method, titleGu, titleEn, period(), nowIso(), user.id, charge.providerRef ?? null).id;
        settle(db, sid, pid, ids, amount, receiptNo);
        return { id: pid, receiptNo, amount, method, flat, createdAt: nowIso(), time: nowHM() };
      });
      return { payment };
    },
  },
  {
    method: 'POST', path: '/bills/claim', roles: RESIDENTS, handle({ db, user, body }) {
      // Resident paid the society's UPI ID directly; the treasurer confirms it against the bank statement.
      const sid = user.society_id, flat = myFlat(user);
      const ids: number[] = (Array.isArray(body?.billIds) ? body.billIds : []).map(Number).filter(Number.isInteger);
      if (!ids.length) bad('no_bills');
      const bills = db.all<{ id: number; amount: number; title_gu: string; title_en: string }>(
        `SELECT id, amount, title_gu, title_en FROM bills WHERE society_id = ? AND flat_id = ? AND payment_id IS NULL AND id IN (${ids.map(() => '?').join(',')})`, sid, flat, ...ids);
      if (bills.length !== ids.length) bad('bills_unavailable');
      const reference = str(body?.reference, 40);
      if (!/^[A-Za-z0-9]{6,30}$/.test(reference)) bad('reference_invalid');
      const amount = bills.reduce((a, b) => a + b.amount, 0);
      const [titleGu, titleEn] = billsTitle(bills.length, bills[0]);
      const pid = db.run("INSERT INTO payments (society_id, flat_id, amount, method, title_gu, title_en, period, created_at, recorded_by, status, bill_ids, reference) VALUES (?, ?, ?, 'upi', ?, ?, ?, ?, ?, 'pending', ?, ?)",
        sid, flat, amount, titleGu, titleEn, period(), nowIso(), user.id, ids.join(','), reference).id;
      return { id: pid, amount };
    },
  },
  {
    method: 'POST', path: '/payments/:id/decision', roles: ADMIN, handle(c) {
      const sid = c.user.society_id;
      return c.db.tx(() => {
        const p = c.db.get<{ bill_ids: string; amount: number }>("SELECT bill_ids, amount FROM payments WHERE id = ? AND society_id = ? AND status = 'pending'", id(c), sid) ?? notFound();
        if (!c.body?.approve) { c.db.run("UPDATE payments SET status = 'rejected' WHERE id = ?", id(c)); return { ok: true }; }
        const receiptNo = nextReceiptNo(c.db, sid);
        c.db.run("UPDATE payments SET status = 'confirmed', receipt_no = ?, period = ? WHERE id = ?", receiptNo, period(), id(c));
        settle(c.db, sid, id(c), p.bill_ids.split(',').map(Number), p.amount, receiptNo);
        return { ok: true, receiptNo };
      });
    },
  },
  {
    method: 'POST', path: '/payments/record', roles: ADMIN, handle({ db, user, body }) {
      // Treasurer records money received outside the app (cash, cheque, bank transfer, UPI) for all of a flat's unpaid bills.
      const sid = user.society_id;
      const flat = str(body?.flat, 12).toUpperCase();
      const method = RECORD_METHODS.includes(body?.method) ? body.method : 'cash';
      const payment = db.tx(() => {
        const bills = db.all<{ id: number; amount: number }>('SELECT id, amount FROM bills WHERE society_id = ? AND flat_id = ? AND payment_id IS NULL', sid, flat);
        if (!bills.length) bad('nothing_due');
        const amount = bills.reduce((a, b) => a + b.amount, 0);
        const receiptNo = nextReceiptNo(db, sid);
        const label = { cash: ['રોકડ ચુકવણી', 'Cash payment'], upi: ['UPI ચુકવણી', 'UPI payment'], cheque: ['ચેક ચુકવણી', 'Cheque payment'], bank: ['બેંક ટ્રાન્સફર', 'Bank transfer'] }[method as string]!;
        const pid = db.run('INSERT INTO payments (society_id, receipt_no, flat_id, amount, method, title_gu, title_en, period, created_at, recorded_by, reference) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          sid, receiptNo, flat, amount, method, label[0], label[1], period(), nowIso(), user.id, str(body?.reference, 40) || null).id;
        settle(db, sid, pid, bills.map(b => b.id), amount, receiptNo);
        return { id: pid, receiptNo, amount };
      });
      return { payment };
    },
  },
  {
    method: 'PUT', path: '/autopay', roles: RESIDENTS, handle({ db, user, body }) {
      db.run('UPDATE flats SET autopay = ? WHERE society_id = ? AND id = ?', body?.enabled ? 1 : 0, user.society_id, myFlat(user));
      return { ok: true };
    },
  },
  {
    method: 'POST', path: '/reminders', roles: ADMIN, async handle({ db, deps, user, body }) {
      const flat = body?.flat ? str(body.flat, 12) : null;
      const targets = defaulters(db, user.society_id).filter(d => !flat || d.flat === flat);
      for (const d of targets) {
        db.run('INSERT INTO reminders (society_id, flat_id, sent_at, sent_by) VALUES (?, ?, ?, ?)', user.society_id, d.flat, today() + 'T' + nowHM(), user.id);
        await deps.notifier.sendDuesReminder(d.flat, d.amount);
      }
      return { sent: targets.length };
    },
  },

  // ── Gate ─────────────────────────────────────────────────
  {
    method: 'POST', path: '/visitors', roles: ['watchman'], upload: 'photo', async handle({ db, deps, user, body, file }) {
      const sid = user.society_id;
      const name = str(body?.name, 80) || 'Visitor';
      const flat = str(body?.flat, 12).toUpperCase() || bad('flat_required');
      if (!flatExists(db, sid, flat)) bad('flat_unknown');
      const purpose = PURPOSES.includes(body?.purpose) ? body.purpose : 'guest';
      const vid = db.run("INSERT INTO visitors (society_id, name, flat_id, purpose, photo, status, in_at, logged_by) VALUES (?, ?, ?, ?, ?, 'waiting', ?, ?)",
        sid, name, flat, purpose, file?.filename ?? null, nowIso(), user.id).id;
      await deps.notifier.visitorAtGate(flat, name);
      // Demo only: flats without an app user "approve on a call" after a few seconds.
      const autoApprove = deps.demo && !db.get("SELECT id FROM members WHERE society_id = ? AND flat_id = ? AND status = 'active'", sid, flat);
      if (autoApprove) {
        const t: any = setTimeout(() => db.run("UPDATE visitors SET status = 'inside' WHERE id = ? AND status = 'waiting'", vid), 3000);
        t.unref?.();
      }
      return { id: vid, autoApprove };
    },
  },
  {
    method: 'POST', path: '/visitors/:id/decision', roles: RESIDENTS, handle(c) {
      const v = c.db.get<{ flat_id: string; status: string }>('SELECT flat_id, status FROM visitors WHERE id = ? AND society_id = ?', id(c), c.user.society_id) ?? notFound();
      if (v.flat_id !== c.user.flat_id) forbidden();
      if (v.status !== 'waiting') bad('already_decided');
      c.db.run('UPDATE visitors SET status = ?, decided_by = ? WHERE id = ?', c.body?.approve ? 'inside' : 'denied', c.user.id, id(c));
      return { ok: true };
    },
  },
  {
    method: 'POST', path: '/visitors/:id/exit', roles: ['watchman'], handle(c) {
      if (!c.db.run("UPDATE visitors SET status = 'out', out_at = ? WHERE id = ? AND society_id = ? AND status = 'inside'", nowIso(), id(c), c.user.society_id).changes) bad('not_inside');
      return { ok: true };
    },
  },
  {
    method: 'POST', path: '/passes', roles: RESIDENTS, handle({ db, user, body }) {
      const sid = user.society_id, flat = myFlat(user);
      const name = str(body?.name, 80) || 'Guest';
      const validOn = body?.when === 'tomorrow' ? addDays(today(), 1) : today();
      let code: string;
      do code = randomDigits(6);
      while (db.get('SELECT id FROM gate_passes WHERE society_id = ? AND code = ? AND valid_on >= ?', sid, code, today()));
      db.run("INSERT INTO gate_passes (society_id, flat_id, name, valid_on, window_gu, window_en, code, created_by, created_at) VALUES (?, ?, ?, ?, '', '', ?, ?, ?)",
        sid, flat, name, validOn, code, user.id, nowIso());
      return { code };
    },
  },
  {
    method: 'POST', path: '/passes/verify', roles: ['watchman'], handle({ db, user, body }) {
      const p = db.get<{ name: string; flat_id: string }>('SELECT name, flat_id FROM gate_passes WHERE society_id = ? AND code = ? AND valid_on = ?', user.society_id, str(body?.code, 10), today());
      return p ? { valid: true, name: p.name, flat: p.flat_id } : { valid: false };
    },
  },
  {
    method: 'POST', path: '/staff', roles: ['watchman', 'secretary'], handle({ db, user, body }) {
      const name = str(body?.name, 60) || bad('name_required');
      const role = str(body?.role, 40) || bad('role_required');
      const sid = db.run('INSERT INTO staff (society_id, name_gu, name_en, role_gu, role_en, flats) VALUES (?, ?, ?, ?, ?, ?)', user.society_id, name, name, role, role, str(body?.flats, 80)).id;
      return { id: sid };
    },
  },
  {
    method: 'DELETE', path: '/staff/:id', roles: ['watchman', 'secretary'], handle(c) {
      c.db.run('UPDATE staff SET active = 0 WHERE id = ? AND society_id = ?', id(c), c.user.society_id);
      return { ok: true };
    },
  },
  {
    method: 'POST', path: '/staff/:id/attendance', roles: ['watchman'], handle(c) {
      if (!c.db.get('SELECT id FROM staff WHERE id = ? AND society_id = ? AND active = 1', id(c), c.user.society_id)) notFound();
      const open = c.db.get<{ id: number }>('SELECT id FROM staff_attendance WHERE staff_id = ? AND date = ? AND out_time IS NULL ORDER BY id DESC LIMIT 1', id(c), today());
      if (open) c.db.run('UPDATE staff_attendance SET out_time = ? WHERE id = ?', nowHM(), open.id);
      else c.db.run('INSERT INTO staff_attendance (staff_id, date, in_time) VALUES (?, ?, ?)', id(c), today(), nowHM());
      return { in: !open };
    },
  },
  {
    method: 'POST', path: '/sos', async handle({ db, deps, user, body }) {
      const type = SOS_TYPES.includes(body?.type) ? body.type : 'medical';
      const sid = db.run('INSERT INTO sos_alerts (society_id, flat_id, user_id, type, created_at) VALUES (?, ?, ?, ?, ?)', user.society_id, user.flat_id, user.id, type, nowIso()).id;
      await deps.notifier.sosAlert(user.flat_id, type);
      return { id: sid };
    },
  },
  {
    method: 'POST', path: '/sos/:id/resolve', roles: ['watchman', ...ADMIN], handle(c) {
      c.db.run('UPDATE sos_alerts SET resolved_at = ?, resolved_by = ? WHERE id = ? AND society_id = ? AND resolved_at IS NULL', nowIso(), c.user.id, id(c), c.user.society_id);
      return { ok: true };
    },
  },

  // ── Community ────────────────────────────────────────────
  {
    method: 'POST', path: '/complaints', roles: RESIDENTS, upload: 'photo', handle({ db, user, body, file }) {
      const sid = user.society_id, flat = myFlat(user);
      const text = str(body?.text, 1000) || bad('text_required');
      const category = COMPLAINT_CATS.includes(body?.category) ? body.category : 'other';
      const code = db.tx(() => {
        db.run('UPDATE societies SET complaint_seq = complaint_seq + 1 WHERE id = ?', sid);
        const code = `C-${db.value<number>('SELECT complaint_seq FROM societies WHERE id = ?', sid)}`;
        db.run("INSERT INTO complaints (society_id, code, flat_id, category, text_gu, text_en, status, attachment, attachment_name, created_at, created_by) VALUES (?, ?, ?, ?, ?, ?, 'open', ?, ?, ?, ?)",
          sid, code, flat, category, text, text, file?.filename ?? null, file?.originalname ?? null, nowIso(), user.id);
        return code;
      });
      return { code };
    },
  },
  {
    method: 'POST', path: '/complaints/:id/advance', roles: ADMIN, handle(c) {
      c.db.run("UPDATE complaints SET status = CASE status WHEN 'open' THEN 'progress' ELSE 'resolved' END WHERE id = ? AND society_id = ?", id(c), c.user.society_id);
      return { ok: true };
    },
  },
  {
    method: 'POST', path: '/notices', roles: ['secretary'], async handle({ db, deps, user, body }) {
      const title = str(body?.title, 140) || bad('title_required');
      const text = str(body?.body, 2000);
      db.run('INSERT INTO notices (society_id, title_gu, title_en, body_gu, body_en, pinned, created_at, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        user.society_id, title, title, text, text, body?.pinned ? 1 : 0, nowIso(), user.id);
      const flats = db.value<number>('SELECT COUNT(*) FROM flats WHERE society_id = ?', user.society_id);
      await deps.notifier.broadcastNotice(title, flats);
      return { flats };
    },
  },
  {
    method: 'POST', path: '/events', roles: ['secretary'], handle({ db, user, body }) {
      const title = str(body?.title, 100) || bad('title_required');
      const date = str(body?.date, 10);
      if (!isDate(date) || date < today()) bad('date_invalid');
      const when = str(body?.when, 60), place = str(body?.place, 60);
      return { id: db.run('INSERT INTO events (society_id, title_gu, title_en, starts_on, when_gu, when_en, place_gu, place_en) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        user.society_id, title, title, date, when, when, place, place).id };
    },
  },
  {
    method: 'POST', path: '/events/:id/rsvp', handle(c) {
      if (!c.db.get('SELECT id FROM events WHERE id = ? AND society_id = ?', id(c), c.user.society_id)) notFound();
      const r = c.db.run('DELETE FROM event_rsvps WHERE event_id = ? AND user_id = ?', id(c), c.user.id);
      if (!r.changes) c.db.run('INSERT INTO event_rsvps (event_id, user_id) VALUES (?, ?)', id(c), c.user.id);
      return { going: !r.changes };
    },
  },
  {
    method: 'POST', path: '/polls', roles: ['secretary'], handle({ db, user, body }) {
      const q = str(body?.question, 200) || bad('question_required');
      const options = (Array.isArray(body?.options) ? body.options : []).map((o: unknown) => str(o, 80)).filter(Boolean).slice(0, 6);
      if (options.length < 2) bad('options_required');
      const ends = str(body?.endsOn, 10);
      if (!isDate(ends) || ends < today()) bad('date_invalid');
      return db.tx(() => {
        const pid = db.run('INSERT INTO polls (society_id, q_gu, q_en, ends_on) VALUES (?, ?, ?, ?)', user.society_id, q, q, ends).id;
        options.forEach((o: string, i: number) => db.run('INSERT INTO poll_options (poll_id, label_gu, label_en, sort) VALUES (?, ?, ?, ?)', pid, o, o, i));
        return { id: pid };
      });
    },
  },
  {
    method: 'POST', path: '/polls/:id/vote', handle(c) {
      const poll = c.db.get<{ ends_on: string }>('SELECT ends_on FROM polls WHERE id = ? AND society_id = ?', id(c), c.user.society_id) ?? notFound();
      if (poll.ends_on < today()) bad('poll_closed');
      const option = Number(c.body?.optionId);
      if (!c.db.get('SELECT id FROM poll_options WHERE id = ? AND poll_id = ?', option, id(c))) bad('option_invalid');
      if (!c.db.run('INSERT OR IGNORE INTO poll_votes (poll_id, user_id, option_id) VALUES (?, ?, ?)', id(c), c.user.id, option).changes) bad('already_voted');
      return { ok: true };
    },
  },

  // ── Facilities ───────────────────────────────────────────
  {
    method: 'POST', path: '/bookings', roles: RESIDENTS, handle({ db, user, body }) {
      const sid = user.society_id, flat = myFlat(user);
      const a = db.get<{ id: string; fee: number }>('SELECT id, fee FROM amenities WHERE society_id = ? AND id = ?', sid, str(body?.amenity, 20)) ?? bad('amenity_invalid');
      const date = str(body?.date, 10);
      if (!isDate(date) || date < today() || date > addDays(today(), 30)) bad('date_invalid');
      const slot = str(body?.slot, 10);
      if (!SLOTS.includes(slot)) bad('slot_invalid');
      const r = db.run('INSERT OR IGNORE INTO amenity_bookings (society_id, amenity_id, date, slot, flat_id, fee, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)', sid, a.id, date, slot, flat, a.fee, nowIso());
      if (!r.changes) throw new HttpError(409, 'slot_taken');
      if (a.fee > 0) db.run("INSERT INTO bills (society_id, flat_id, kind, icon, title_gu, title_en, amount, due_date, period, created_at) VALUES (?, ?, 'booking', 'IconCalendarCheck', ?, ?, ?, ?, ?, ?)",
        sid, flat, `બુકિંગ ${a.id} · ${date} · ${slot}`, `Booking ${a.id} · ${date} · ${slot}`, a.fee, date, date.slice(0, 7), nowIso());
      return { id: r.id };
    },
  },
  {
    method: 'POST', path: '/guest-parking', roles: RESIDENTS, handle({ db, user }) {
      const sid = user.society_id, flat = myFlat(user);
      const n = db.tx(() => {
        if (guestParkingFree(db, sid) <= 0) throw new HttpError(409, 'parking_full');
        const n = db.value<number>('SELECT COALESCE(MAX(slot_no), 0) + 1 FROM guest_parking WHERE society_id = ? AND date = ?', sid, today());
        db.run('INSERT INTO guest_parking (society_id, date, slot_no, flat_id, created_at) VALUES (?, ?, ?, ?, ?)', sid, today(), n, flat, nowIso());
        return n;
      });
      return { slot: `G-${String(n).padStart(2, '0')}` };
    },
  },
  {
    method: 'POST', path: '/vehicles', roles: RESIDENTS, handle({ db, user, body }) {
      const vehicle = str(body?.vehicle, 20).toUpperCase() || bad('vehicle_required');
      const kind = body?.kind === 'two' ? 'two' : 'car';
      return { id: db.run('INSERT INTO vehicles (society_id, flat_id, slot, vehicle, kind, location) VALUES (?, ?, ?, ?, ?, ?)',
        user.society_id, myFlat(user), str(body?.slot, 12).toUpperCase() || '—', vehicle, kind, str(body?.location, 40)).id };
    },
  },
  {
    method: 'DELETE', path: '/vehicles/:id', roles: RESIDENTS, handle(c) {
      c.db.run('DELETE FROM vehicles WHERE id = ? AND society_id = ? AND flat_id = ?', id(c), c.user.society_id, myFlat(c.user));
      return { ok: true };
    },
  },
  {
    method: 'POST', path: '/contacts', roles: ['secretary'], handle({ db, user, body }) {
      const name = str(body?.name, 60) || bad('name_required');
      const phone = str(body?.phone, 15).replace(/[^\d+]/g, '') || bad('phone_invalid');
      const sub = str(body?.role, 40);
      const ini = name.split(/\s+/).slice(0, 2).map(w => w[0]).join('').toUpperCase();
      return { id: db.run('INSERT INTO contacts (society_id, initials, name_gu, name_en, sub_gu, sub_en, phone, sort) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        user.society_id, ini, name, name, sub ? `${sub} · ${phone}` : phone, sub ? `${sub} · ${phone}` : phone, phone, 50).id };
    },
  },
  {
    method: 'DELETE', path: '/contacts/:id', roles: ['secretary'], handle(c) {
      c.db.run('DELETE FROM contacts WHERE id = ? AND society_id = ?', id(c), c.user.society_id);
      return { ok: true };
    },
  },
  {
    method: 'POST', path: '/documents', roles: ['secretary'], upload: 'file', handle({ db, user, body, file }) {
      if (!file?.filename) bad('file_required');
      const name = str(body?.name, 80) || file!.originalname.replace(/\.[^.]+$/, '');
      const size = file!.size ?? 0;
      const sizeLabel = size >= 1048576 ? `${(size / 1048576).toFixed(1)} MB` : `${Math.max(1, Math.round(size / 1024))} KB`;
      const d = new Date().toLocaleString('en-IN', { month: 'short', year: 'numeric', timeZone: 'Asia/Kolkata' });
      return { id: db.run('INSERT INTO documents (society_id, name_gu, name_en, size_label, date_label, file) VALUES (?, ?, ?, ?, ?, ?)', user.society_id, name, name, sizeLabel, d, file!.filename).id };
    },
  },
  {
    method: 'DELETE', path: '/documents/:id', roles: ['secretary'], handle(c) {
      c.db.run('DELETE FROM documents WHERE id = ? AND society_id = ?', id(c), c.user.society_id);
      return { ok: true };
    },
  },

  // ── Expenses (committee) ─────────────────────────────────
  {
    method: 'POST', path: '/expenses', roles: ADMIN, upload: 'file', handle({ db, user, body, file }) {
      const amount = num(body?.amount);
      if (!(amount > 0)) bad('amount_required');
      const title = str(body?.vendor, 140) || bad('vendor_required');
      const category = EXPENSE_CATS.includes(body?.category) ? body.category : 'repair';
      return { id: db.run("INSERT INTO expenses (society_id, category, title_gu, title_en, amount, status, attachment, attachment_name, submitted_by, submitted_at) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?)",
        user.society_id, category, title, title, amount, file?.filename ?? null, file?.originalname ?? null, user.id, nowIso()).id };
    },
  },
  {
    method: 'POST', path: '/expenses/:id/decision', roles: ['secretary'], handle(c) {
      const sid = c.user.society_id;
      c.db.tx(() => {
        const e = c.db.get<{ amount: number; title_en: string }>("SELECT amount, title_en FROM expenses WHERE id = ? AND society_id = ? AND status = 'pending'", id(c), sid) ?? notFound();
        const approve = !!c.body?.approve;
        c.db.run('UPDATE expenses SET status = ?, decided_by = ?, decided_at = ? WHERE id = ?', approve ? 'approved' : 'rejected', c.user.id, nowIso(), id(c));
        if (approve) c.db.run('INSERT INTO fund_ledger (society_id, amount, reason, ref, created_at) VALUES (?, ?, ?, ?, ?)', sid, -e.amount, `Expense: ${e.title_en}`, `E-${id(c)}`, nowIso());
      });
      return { ok: true };
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

/** Resolves the caller for the route's auth level, checks the role, and runs it. */
export async function runRoute(route: Route, ctx: Omit<RouteCtx, 'account' | 'user'> & { session?: { account: Account; user: User | null } }) {
  const auth = route.auth ?? 'member';
  if (auth !== 'public' && !ctx.session) throw new HttpError(401, 'unauthenticated');
  const user = ctx.session?.user ?? null;
  if (auth === 'member' && !user) throw new HttpError(403, 'no_society');
  if (route.roles && (!user || !route.roles.includes(user.role))) forbidden();
  return route.handle({ ...ctx, account: ctx.session?.account as Account, user: user as User });
}

export { isAdmin, dueFlats };
