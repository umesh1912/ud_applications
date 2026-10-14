import path from 'node:path';
import { createApp } from './app.js';
import { DATA_DIR, Db } from './db.js';
import { seedDemo } from './seed.js';
import { ConsoleNotifier } from './services/notifier.js';
import { msg91Deliver, StoredOtp, TwilioVerifyOtp, type OtpSender } from './services/otp.js';
import { StubPaymentProvider } from './services/payments.js';

const env = process.env;
const production = env.NODE_ENV === 'production';
// Demo mode lets anyone sign in as the sample members, so it is off in production unless DEMO_MODE=true.
const demo = (env.DEMO_MODE ?? (production ? 'false' : 'true')) === 'true';
const db = new Db(env.DB_FILE ?? path.join(DATA_DIR, 'society.db'));
if (demo && seedDemo(db)) console.log('Seeded the demo society (Shivam Residency)');

const notifier = new ConsoleNotifier();

function otpSender(): OtpSender {
  const provider = env.OTP_PROVIDER ?? (env.TWILIO_VERIFY_SERVICE_SID ? 'twilio' : env.MSG91_AUTH_KEY ? 'msg91' : 'console');
  if (provider === 'twilio') {
    const { TWILIO_ACCOUNT_SID: sid, TWILIO_AUTH_TOKEN: token, TWILIO_VERIFY_SERVICE_SID: service } = env;
    if (!sid || !token || !service) throw new Error('OTP_PROVIDER=twilio needs TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN and TWILIO_VERIFY_SERVICE_SID');
    console.log('OTP: Twilio Verify');
    return new TwilioVerifyOtp(db, sid, token, service);
  }
  if (provider === 'msg91') {
    if (!env.MSG91_AUTH_KEY || !env.MSG91_TEMPLATE_ID) throw new Error('OTP_PROVIDER=msg91 needs MSG91_AUTH_KEY and MSG91_TEMPLATE_ID');
    console.log('OTP: MSG91');
    return new StoredOtp(db, msg91Deliver(env.MSG91_AUTH_KEY, env.MSG91_TEMPLATE_ID));
  }
  // No SMS provider: codes are printed to the server log. In development the fixed code is also shown in the app.
  const fixed = env.OTP_DEV_CODE ?? (production ? undefined : '123456');
  if (production) console.warn('WARNING: no SMS provider configured — login codes are only written to this log. Set the Twilio variables.');
  return new StoredOtp(db, (phone, code) => notifier.sendOtp(phone, code), fixed, !production || demo);
}

const app = createApp({
  db, demo, notifier, otp: otpSender(),
  // Simulated card/UPI checkout only in demo; real societies pay to their UPI ID and the treasurer confirms.
  payments: (env.ONLINE_PAYMENTS ?? (demo ? 'stub' : 'off')) === 'stub' ? new StubPaymentProvider() : undefined,
  webDist: env.WEB_DIST ?? path.resolve(import.meta.dirname, '../../web/dist'),
});

const port = Number(env.PORT ?? 8787);
app.listen(port, () => console.log(`Society app on http://localhost:${port} (demo mode ${demo ? 'on' : 'off'})`));
