import { HttpError, randomDigits, type Store } from '../store.js';

/** Sends and checks login codes. Twilio Verify keeps the code itself; the others store it in the otps table. */
export interface OtpSender {
  /** Sends a code; devCode is returned only by the development sender. */
  start(phone: string): Promise<{ devCode?: string }>;
  check(phone: string, code: string): Promise<boolean>;
}

const TTL_MS = 5 * 60 * 1000;
const RESEND_MS = 30 * 1000;
const MAX_ATTEMPTS = 5;

/** One send per number every 30 s; the row also tracks verify attempts. */
function throttle(db: Store, phone: string, code: string) {
  const row = db.get<{ sent_at: number }>('SELECT sent_at FROM otps WHERE phone = ?', phone);
  if (row && Date.now() - row.sent_at < RESEND_MS) throw new HttpError(429, 'otp_wait');
  db.run('INSERT OR REPLACE INTO otps (phone, code, expires_at, attempts, sent_at) VALUES (?, ?, ?, 0, ?)', phone, code, Date.now() + TTL_MS, Date.now());
}

function attempt(db: Store, phone: string) {
  const row = db.get<{ code: string; expires_at: number; attempts: number }>('SELECT code, expires_at, attempts FROM otps WHERE phone = ?', phone);
  if (!row || row.expires_at < Date.now() || row.attempts >= MAX_ATTEMPTS) throw new HttpError(400, 'otp_expired');
  db.run('UPDATE otps SET attempts = attempts + 1 WHERE phone = ?', phone);
  return row;
}

/** Generates codes locally and hands them to `deliver` (SMS gateway, or the console in development). */
export class StoredOtp implements OtpSender {
  constructor(private db: Store, private deliver: (phone: string, code: string) => Promise<void>, private fixedCode?: string, private exposeCode = false) {}
  async start(phone: string) {
    const code = this.fixedCode ?? randomDigits(6);
    throttle(this.db, phone, code);
    await this.deliver(phone, code);
    return { devCode: this.exposeCode ? code : undefined };
  }
  async check(phone: string, code: string) {
    const row = attempt(this.db, phone);
    if (row.code !== code) return false;
    this.db.run('DELETE FROM otps WHERE phone = ?', phone);
    return true;
  }
}

/** MSG91 OTP API (India). Needs a DLT-approved template that contains ##OTP##. */
export const msg91Deliver = (authKey: string, templateId: string) => async (phone: string, code: string) => {
  const url = `https://control.msg91.com/api/v5/otp?template_id=${encodeURIComponent(templateId)}&mobile=91${phone}&otp=${code}`;
  const res = await fetch(url, { method: 'POST', headers: { authkey: authKey, 'Content-Type': 'application/json' }, body: '{}' });
  const body = await res.json().catch(() => ({})) as { type?: string; message?: string };
  if (!res.ok || body.type === 'error') { console.error('[otp] MSG91 failed:', res.status, body.message); throw new HttpError(502, 'sms_failed'); }
};

/** Twilio Verify: Twilio generates, sends (using its own registered templates in India) and checks the code. */
export class TwilioVerifyOtp implements OtpSender {
  constructor(private db: Store, private accountSid: string, private authToken: string, private serviceSid: string) {}
  private async call(path: string, form: Record<string, string>) {
    const res = await fetch(`https://verify.twilio.com/v2/Services/${this.serviceSid}/${path}`, {
      method: 'POST',
      headers: { Authorization: 'Basic ' + btoa(`${this.accountSid}:${this.authToken}`), 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(form).toString(),
    });
    return { status: res.status, body: await res.json().catch(() => ({})) as { status?: string; message?: string } };
  }
  async start(phone: string) {
    throttle(this.db, phone, '');
    const r = await this.call('Verifications', { To: `+91${phone}`, Channel: 'sms' });
    if (r.status >= 300) { console.error('[otp] Twilio Verify failed:', r.status, r.body.message); throw new HttpError(502, 'sms_failed'); }
    return {};
  }
  async check(phone: string, code: string) {
    attempt(this.db, phone);
    const r = await this.call('VerificationCheck', { To: `+91${phone}`, Code: code });
    if (r.status === 404) throw new HttpError(400, 'otp_expired');
    if (r.status >= 300) { console.error('[otp] Twilio check failed:', r.status, r.body.message); throw new HttpError(502, 'sms_failed'); }
    if (r.body.status !== 'approved') return false;
    this.db.run('DELETE FROM otps WHERE phone = ?', phone);
    return true;
  }
}
