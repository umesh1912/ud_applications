import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, test } from 'node:test';

process.env.DATA_DIR = path.join(os.tmpdir(), 'shivam-test-' + process.pid);
const { createApp } = await import('./app.js');
const { Db } = await import('./db.js');
const { seed } = await import('./seed.js');

const sent: string[] = [];
const notifier = {
  sendOtp: async (p: string, c: string) => { sent.push(`otp ${p} ${c}`); },
  sendDuesReminder: async (f: string) => { sent.push(`remind ${f}`); },
  broadcastNotice: async () => {}, sosAlert: async () => {}, visitorAtGate: async () => {},
};

let base = '';
let server: ReturnType<ReturnType<typeof createApp>['listen']>;
before(async () => {
  const db = new Db(':memory:');
  seed(db);
  const app = createApp({ db, demo: true, notifier, otpDevCode: undefined, payments: { charge: async () => ({ ok: true, providerRef: 't' }) } });
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
const login = async (role: string) => (await call('POST', '/api/auth/demo', undefined, { role })).body.token as string;
const state = async (token: string) => (await call('GET', '/api/state', token)).body;

describe('auth', () => {
  test('rejects unauthenticated requests', async () => {
    assert.equal((await call('GET', '/api/state')).status, 401);
  });
  test('phone OTP login for a registered member', async () => {
    assert.equal((await call('POST', '/api/auth/otp', undefined, { phone: '9999999999' })).status, 404);
    assert.equal((await call('POST', '/api/auth/otp', undefined, { phone: '+91 98250 12345' })).status, 200);
    const code = sent.findLast(s => s.startsWith('otp 9825012345'))!.split(' ')[2];
    assert.equal((await call('POST', '/api/auth/verify', undefined, { phone: '9825012345', code: '000000' === code ? '111111' : '000000' })).status, 400);
    const { body } = await call('POST', '/api/auth/verify', undefined, { phone: '9825012345', code });
    assert.equal((await state(body.token)).me.role, 'resident');
  });
});

describe('cross-role flows', () => {
  test('watchman logs a visitor, resident approves, watchman marks exit', async () => {
    const [w, r] = [await login('watchman'), await login('resident')];
    const { body } = await call('POST', '/api/visitors', w, { name: 'Test Guest', flat: 'b-304', purpose: 'guest' });
    const waiting = (await state(r)).visitors.find((v: any) => v.id === body.id);
    assert.equal(waiting.status, 'waiting');
    assert.equal((await call('POST', `/api/visitors/${body.id}/decision`, await login('treasurer'), { approve: true })).status, 403);
    assert.equal((await call('POST', `/api/visitors/${body.id}/decision`, r, { approve: true })).status, 200);
    assert.equal((await call('POST', `/api/visitors/${body.id}/exit`, w)).status, 200);
    assert.equal((await state(w)).visitors.find((v: any) => v.id === body.id).status, 'out');
  });

  test('treasurer submits a bill, secretary approves it and the fund drops', async () => {
    const [t, s] = [await login('treasurer'), await login('secretary')];
    const before = (await state(s)).finance.fund;
    assert.equal((await call('POST', '/api/expenses', s, { vendor: 'x', amount: 1 })).status, 403);
    const { body } = await call('POST', '/api/expenses', t, { vendor: 'Torrent Power', amount: '18,450', category: 'light' });
    assert.equal((await call('POST', `/api/expenses/${body.id}/decision`, t, { approve: true })).status, 403);
    await call('POST', `/api/expenses/${body.id}/decision`, s, { approve: true });
    const after = (await state(s)).finance;
    assert.equal(after.fund, before - 18450);
    assert.ok(!after.pending.some((p: any) => p.id === body.id));
  });

  test('resident pays selected bills; collection and receipt follow', async () => {
    const [r, s] = [await login('resident'), await login('secretary')];
    const due = (await state(r)).bills.filter((b: any) => !b.paid);
    const collected = (await state(s)).finance.collected;
    const { body } = await call('POST', '/api/bills/pay', r, { billIds: due.map((b: any) => b.id), method: 'upi' });
    assert.equal(body.payment.amount, 3100);
    assert.match(body.payment.receiptNo, /^SR-26-\d{4}$/);
    assert.equal((await call('POST', '/api/bills/pay', r, { billIds: [due[0].id], method: 'upi' })).status, 400);
    assert.equal((await state(s)).finance.collected, collected + 3100);
    const pdf = await fetch(`${base}/api/payments/${body.payment.id}/receipt.pdf`, { headers: { Authorization: `Bearer ${r}` } });
    assert.equal(pdf.headers.get('content-type'), 'application/pdf');
  });

  test('cash recording clears a defaulter', async () => {
    const t = await login('treasurer');
    const { body } = await call('POST', '/api/cash', t, { flat: 'B-401' });
    assert.equal(body.payment.amount, 7500);
    assert.ok(!(await state(t)).finance.defaulters.some((d: any) => d.flat === 'B-401'));
  });

  test('SOS from a resident reaches the gate until resolved', async () => {
    const [r, w] = [await login('resident'), await login('watchman')];
    const { body } = await call('POST', '/api/sos', r, { type: 'fire' });
    assert.equal((await state(w)).sos.type, 'fire');
    assert.equal((await call('POST', `/api/sos/${body.id}/resolve`, r)).status, 403);
    await call('POST', `/api/sos/${body.id}/resolve`, w);
    assert.equal((await state(w)).sos, null);
  });

  test('gate pass verification, booking conflicts, one vote per poll', async () => {
    const [r, w] = [await login('resident'), await login('watchman')];
    const { body } = await call('POST', '/api/passes', r, { name: 'Kiran', when: 'today' });
    assert.deepEqual((await call('POST', '/api/passes/verify', w, { code: body.code })).body, { valid: true, name: 'Kiran', flat: 'B-304' });
    assert.equal((await call('POST', '/api/passes/verify', w, { code: '000001' })).body.valid, false);

    const st = await state(r);
    const free = ['06–08', '08–10', '10–12', '16–18', '18–20', '20–22'].find(sl => !st.bookedSlots.some((b: any) => b.amenity === 'hall' && b.date === st.today && b.slot === sl))!;
    assert.equal((await call('POST', '/api/bookings', r, { amenity: 'hall', date: st.today, slot: free })).status, 200);
    assert.equal((await call('POST', '/api/bookings', r, { amenity: 'hall', date: st.today, slot: free })).status, 409);

    const poll = st.polls.find((p: any) => !p.closed);
    if (poll) {
      assert.equal((await call('POST', `/api/polls/${poll.id}/vote`, r, { optionId: poll.options[0].id })).status, 200);
      assert.equal((await call('POST', `/api/polls/${poll.id}/vote`, r, { optionId: poll.options[1].id })).status, 400);
    }
  });

  test('reminders go to every flat with pending dues', async () => {
    const s = await login('secretary');
    const { body } = await call('POST', '/api/reminders', s, {});
    assert.equal(body.sent, (await state(s)).finance.defaulters.length);
    assert.ok((await state(s)).finance.defaulters.every((d: any) => d.reminded));
  });
});
