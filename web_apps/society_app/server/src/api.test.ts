import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, test } from 'node:test';

process.env.DATA_DIR = path.join(os.tmpdir(), 'society-test-' + process.pid);
const { createApp } = await import('./app.js');
const { Db } = await import('./db.js');
const { seedDemo } = await import('./seed.js');
const { StoredOtp } = await import('./services/otp.js');

const sent: string[] = [];
const notifier = {
  sendOtp: async (p: string, c: string) => { sent.push(`otp ${p} ${c}`); },
  sendDuesReminder: async (f: string) => { sent.push(`remind ${f}`); },
  broadcastNotice: async () => {}, sosAlert: async () => {}, visitorAtGate: async () => {}, joinRequest: async () => {},
};

let base = '';
let server: ReturnType<ReturnType<typeof createApp>['listen']>;
let db: InstanceType<typeof Db>;
before(async () => {
  db = new Db(':memory:');
  seedDemo(db);
  const otp = new StoredOtp(db, (p, c) => notifier.sendOtp(p, c));
  const app = createApp({ db, demo: true, notifier, otp, payments: { charge: async () => ({ ok: true, providerRef: 't' }) } });
  server = app.listen(0);
  await new Promise(r => server.once('listening', r));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});
after(() => server.close());

const call = async (method: string, url: string, token?: string, body?: unknown) => {
  const res = await fetch(base + url, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: res.status, body: res.headers.get('content-type')?.includes('json') ? await res.json() : null };
};
const demo = async (role: string) => (await call('POST', '/api/auth/demo', undefined, { role })).body.token as string;
const state = async (token: string) => (await call('GET', '/api/state', token)).body;
/** Signs in by OTP, reading the code the notifier "sent". */
async function signIn(phone: string) {
  db.run('DELETE FROM otps WHERE phone = ?', phone); // skip the 30 s resend wait between tests
  assert.equal((await call('POST', '/api/auth/otp', undefined, { phone })).status, 200);
  const code = sent.findLast(s => s.startsWith(`otp ${phone}`))!.split(' ')[2];
  const r = await call('POST', '/api/auth/verify', undefined, { phone, code });
  assert.equal(r.status, 200);
  return r.body as { token: string; isNew: boolean };
}

describe('signup and society onboarding', () => {
  let secretary = '', resident = '', guard = '', code = '';

  test('OTP rejects a wrong code and throttles resends', async () => {
    await call('POST', '/api/auth/otp', undefined, { phone: '9000000001' });
    assert.equal((await call('POST', '/api/auth/otp', undefined, { phone: '9000000001' })).status, 429);
    assert.equal((await call('POST', '/api/auth/verify', undefined, { phone: '9000000001', code: '000000' })).status, 400);
    assert.equal((await call('POST', '/api/auth/otp', undefined, { phone: '12345' })).status, 400);
  });

  test('a new user signs up, names themself and registers a society', async () => {
    const s = await signIn('9000000001');
    assert.equal(s.isNew, true);
    secretary = s.token;
    assert.equal((await call('GET', '/api/state', secretary)).status, 403);
    assert.equal((await call('POST', '/api/societies', secretary, { name: 'Green Park', city: 'Surat', wings: [{ name: 'A', floors: 2, perFloor: 2 }] })).body.error, 'name_required');
    await call('PUT', '/api/me', secretary, { name: 'Asha Mehta' });
    const r = await call('POST', '/api/societies', secretary, {
      name: 'Green Park', city: 'Surat', wings: [{ name: 'A', floors: 2, perFloor: 2 }, { name: 'B', floors: 1, perFloor: 3 }],
      maintenance: 1800, dueDay: 10, upiId: 'greenpark@okaxis', flat: 'A-101',
    });
    assert.equal(r.status, 200);
    code = r.body.code;
    const st = await state(secretary);
    assert.equal(st.me.role, 'secretary');
    assert.equal(st.society.totalFlats, 7);
    assert.equal(st.society.code, code);
    // This month's maintenance was raised for every flat.
    assert.equal(st.bills.length, 1);
    assert.equal(st.bills[0].amount, 1800);
    assert.equal(st.finance.dueFlats.length, 7);
  });

  test('residents and a guard join with the code; the secretary approves them', async () => {
    resident = (await signIn('9000000002')).token;
    await call('PUT', '/api/me', resident, { name: 'Ravi Shah' });
    const look = await call('GET', `/api/societies/lookup?code=${code.toLowerCase()}`, resident);
    assert.deepEqual(look.body.flats, ['A-101', 'A-102', 'A-201', 'A-202', 'B-101', 'B-102', 'B-103']);
    assert.equal((await call('POST', '/api/societies/join', resident, { code, flat: 'Z-999' })).body.error, 'flat_unknown');
    assert.equal((await call('POST', '/api/societies/join', resident, { code, flat: 'b-102', occupancy: 'tenant' })).status, 200);
    assert.equal((await call('GET', '/api/state', resident)).status, 403);
    assert.equal((await call('GET', '/api/me', resident)).body.memberships[0].status, 'pending');

    guard = (await signIn('9000000003')).token;
    await call('PUT', '/api/me', guard, { name: 'Ramu' });
    await call('POST', '/api/societies/join', guard, { code, role: 'watchman' });

    const pending = (await state(secretary)).members.pending;
    assert.equal(pending.length, 2);
    assert.equal((await call('POST', `/api/members/${pending[0].id}/decision`, resident, { approve: true })).status, 401 === 0 ? 0 : 403);
    for (const m of pending) await call('POST', `/api/members/${m.id}/decision`, secretary, { approve: true, role: m.flat ? 'resident' : 'watchman' });
    const st = await state(resident);
    assert.equal(st.me.flat, 'B-102');
    assert.equal(st.bills[0].amount, 1800);
    assert.equal((await state(guard)).me.role, 'watchman');
  });

  test('UPI payment claim is confirmed by the committee and settles the bills', async () => {
    const st = await state(resident);
    const ids = st.bills.filter((b: any) => !b.paid).map((b: any) => b.id);
    assert.equal((await call('POST', '/api/bills/claim', resident, { billIds: ids, reference: 'x' })).body.error, 'reference_invalid');
    const claim = await call('POST', '/api/bills/claim', resident, { billIds: ids, reference: '412345678901' });
    assert.equal(claim.status, 200);
    assert.equal((await state(resident)).bills[0].claimed, true);
    const fin = (await state(secretary)).finance;
    assert.equal(fin.claims.length, 1);
    const fundBefore = fin.fund;
    assert.equal((await call('POST', `/api/payments/${claim.body.id}/decision`, resident, { approve: true })).status, 403);
    assert.equal((await call('POST', `/api/payments/${claim.body.id}/decision`, secretary, { approve: true })).status, 200);
    const after = await state(resident);
    assert.equal(after.bills[0].paid, true);
    assert.match(after.history[0].receiptNo, /^R-\d\d-0001$/);
    assert.equal((await state(secretary)).finance.fund, fundBefore + 1800);
  });

  test('committee raises a charge, records cash, and manages roles', async () => {
    assert.equal((await call('POST', '/api/bills', secretary, { title: 'Lift repair share', amount: 500, dueDate: '2099-01-31' })).body.count, 7);
    assert.equal((await state(resident)).bills.filter((b: any) => !b.paid).length, 1);
    const rec = await call('POST', '/api/payments/record', secretary, { flat: 'B-102', method: 'cheque', reference: '001234' });
    assert.equal(rec.body.payment.amount, 500);
    const residentMember = (await state(secretary)).members.active.find((m: any) => m.flat === 'B-102');
    await call('PUT', `/api/members/${residentMember.id}`, secretary, { role: 'treasurer' });
    assert.equal((await state(resident)).me.role, 'treasurer');
    const me = (await state(secretary)).members.active.find((m: any) => m.me);
    assert.equal((await call('PUT', `/api/members/${me.id}`, secretary, { role: 'resident' })).body.error, 'last_secretary');
  });

  test('societies cannot see each other', async () => {
    const demoSecretary = await demo('secretary');
    const other = await state(demoSecretary);
    assert.equal(other.society.en, 'Shivam Residency');
    assert.ok(!other.members.active.some((m: any) => m.name === 'Ravi Shah'));
    const mine = await state(secretary);
    assert.ok(!mine.notices.length);
    const claim = (await state(demoSecretary)).finance.claims;
    assert.equal(claim.length, 0);
    // A demo visitor id from another society cannot be decided here.
    const foreign = db.value<number>("SELECT id FROM visitors WHERE status = 'waiting' LIMIT 1");
    assert.equal((await call('POST', `/api/visitors/${foreign}/decision`, resident, { approve: true })).status, 404);
  });

  test('events, polls, staff, vehicles and contacts can be created', async () => {
    assert.equal((await call('POST', '/api/events', secretary, { title: 'Holi', date: '2099-03-01', when: '10 am', place: 'Garden' })).status, 200);
    const poll = await call('POST', '/api/polls', secretary, { question: 'Paint the gate?', options: ['Yes', 'No'], endsOn: '2099-01-01' });
    assert.equal(poll.status, 200);
    assert.equal((await call('POST', '/api/staff', guard, { name: 'Geeta', role: 'Maid', flats: 'A-101' })).status, 200);
    assert.equal((await call('POST', '/api/vehicles', resident, { vehicle: 'gj05ab1234', slot: 'P1', kind: 'car' })).status, 200);
    assert.equal((await call('POST', '/api/contacts', secretary, { name: 'Plumber Mukesh', phone: '98790 22314', role: 'Plumber' })).status, 200);
    const st = await state(resident);
    assert.equal(st.events[0].titleEn, 'Holi');
    assert.equal(st.polls[0].options.length, 2);
    assert.equal(st.staff[0].nameEn, 'Geeta');
    assert.equal(st.parking[0].vehicle, 'GJ05AB1234');
    assert.ok(st.directory.some((d: any) => d.nameEn === 'Plumber Mukesh'));
  });
});

describe('demo society cross-role flows', () => {
  test('watchman logs a visitor, resident approves, watchman marks exit', async () => {
    const [w, r] = [await demo('watchman'), await demo('resident')];
    const { body } = await call('POST', '/api/visitors', w, { name: 'Test Guest', flat: 'b-304', purpose: 'guest' });
    assert.equal((await state(r)).myWaiting.some((v: any) => v.id === body.id), true);
    assert.equal((await call('POST', `/api/visitors/${body.id}/decision`, await demo('treasurer'), { approve: true })).status, 403);
    assert.equal((await call('POST', `/api/visitors/${body.id}/decision`, r, { approve: true })).status, 200);
    assert.equal((await call('POST', `/api/visitors/${body.id}/exit`, w)).status, 200);
  });

  test('treasurer submits a bill, secretary approves it and the fund drops', async () => {
    const [t, s] = [await demo('treasurer'), await demo('secretary')];
    const before = (await state(s)).finance.fund;
    const { body } = await call('POST', '/api/expenses', t, { vendor: 'Torrent Power', amount: '18,450', category: 'light' });
    assert.equal((await call('POST', `/api/expenses/${body.id}/decision`, t, { approve: true })).status, 403);
    await call('POST', `/api/expenses/${body.id}/decision`, s, { approve: true });
    assert.equal((await state(s)).finance.fund, before - 18450);
  });

  test('online checkout (demo gateway) pays bills and issues a receipt PDF', async () => {
    const r = await demo('resident');
    const due = (await state(r)).bills.filter((b: any) => !b.paid);
    const { body } = await call('POST', '/api/bills/pay', r, { billIds: due.map((b: any) => b.id), method: 'upi' });
    assert.equal(body.payment.amount, 3100);
    assert.equal((await call('POST', '/api/bills/pay', r, { billIds: [due[0].id], method: 'upi' })).status, 400);
    const pdf = await fetch(`${base}/api/payments/${body.payment.id}/receipt.pdf`, { headers: { Authorization: `Bearer ${r}` } });
    assert.equal(pdf.headers.get('content-type'), 'application/pdf');
  });

  test('SOS reaches the gate until resolved; reminders go to overdue flats', async () => {
    const [r, w, s] = [await demo('resident'), await demo('watchman'), await demo('secretary')];
    const { body } = await call('POST', '/api/sos', r, { type: 'fire' });
    assert.equal((await state(w)).sos.type, 'fire');
    assert.equal((await call('POST', `/api/sos/${body.id}/resolve`, r)).status, 403);
    await call('POST', `/api/sos/${body.id}/resolve`, w);
    assert.equal((await state(w)).sos, null);
    const sentN = (await call('POST', '/api/reminders', s, {})).body.sent;
    assert.equal(sentN, (await state(s)).finance.defaulters.length);
  });
});
