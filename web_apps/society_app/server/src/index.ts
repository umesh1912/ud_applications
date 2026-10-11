import path from 'node:path';
import { createApp } from './app.js';
import { DATA_DIR, Db } from './db.js';
import { seed } from './seed.js';
import { ConsoleNotifier } from './services/notifier.js';
import { StubPaymentProvider } from './services/payments.js';

const production = process.env.NODE_ENV === 'production';
// Demo mode lets anyone sign in as any role, so it is off in production unless DEMO_MODE=true.
const demo = (process.env.DEMO_MODE ?? (production ? 'false' : 'true')) === 'true';
const db = new Db(process.env.DB_FILE ?? path.join(DATA_DIR, 'society.db'));
if (seed(db)) console.log('Seeded sample data for Shivam Residency');

const app = createApp({
  db, demo,
  payments: new StubPaymentProvider(),
  notifier: new ConsoleNotifier(),
  otpDevCode: process.env.OTP_DEV_CODE ?? (production ? undefined : '123456'),
  webDist: process.env.WEB_DIST ?? path.resolve(import.meta.dirname, '../../web/dist'),
});

const port = Number(process.env.PORT ?? 8787);
app.listen(port, () => console.log(`API on http://localhost:${port} (demo mode ${demo ? 'on' : 'off'})`));
