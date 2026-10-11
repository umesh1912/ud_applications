import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import express, { type NextFunction, type Request, type Response } from 'express';
import multer from 'multer';
import { authenticate, createSession, HttpError, issueOtp, normalizePhone, requireRole, verifyOtp, type User } from './auth.js';
import { UPLOAD_DIR, type Db } from './db.js';
import { bad, notFound, routes, runRoute, str, type Deps } from './routes.js';
import { placeholderDocPdf, receiptPdf, reportPdf } from './services/pdf.js';
import { collection, defaulters, fundBalance } from './state.js';
import { period } from './time.js';

export interface AppOptions extends Deps {
  db: Db;
  /** Fixed OTP for development. Leave undefined in production so codes are random. */
  otpDevCode?: string;
  webDist?: string;
}

export function createApp(o: AppOptions) {
  const { db } = o;
  const deps: Deps = { payments: o.payments, notifier: o.notifier, demo: o.demo };
  const app = express();
  app.use(express.json({ limit: '100kb' }));

  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  const upload = multer({
    storage: multer.diskStorage({
      destination: UPLOAD_DIR,
      filename: (_req, file, cb) => cb(null, crypto.randomBytes(12).toString('hex') + path.extname(file.originalname).toLowerCase().slice(0, 6)),
    }),
    limits: { fileSize: 8 * 1024 * 1024 },
    fileFilter: (_req, file, cb) => cb(null, /^(image\/|application\/pdf$)/.test(file.mimetype)),
  });
  const sendPdf = (res: Response, name: string, buf: Buffer) => {
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${name.replace(/[^\w.\- ]+/g, '_')}"`);
    res.send(buf);
  };
  const society = () => db.setting('society_en')!;

  // ── Public ────────────────────────────────────────────────
  app.get('/api/config', (_req, res) => { res.json({ demo: o.demo }); });

  app.post('/api/auth/otp', async (req, res) => {
    const phone = normalizePhone(req.body?.phone) ?? bad('phone_invalid');
    const code = issueOtp(db, phone, o.otpDevCode);
    if (!code) throw new HttpError(404, 'phone_unknown');
    await o.notifier.sendOtp(phone, code);
    res.json({ sent: true, devCode: o.otpDevCode && o.demo ? o.otpDevCode : undefined });
  });

  app.post('/api/auth/verify', (req, res) => {
    const phone = normalizePhone(req.body?.phone) ?? bad('phone_invalid');
    res.json({ token: verifyOtp(db, phone, str(req.body?.code, 6)) });
  });

  app.post('/api/auth/demo', (req, res) => {
    if (!o.demo) throw new HttpError(403, 'demo_disabled');
    const user = db.get<User>('SELECT * FROM users WHERE role = ? ORDER BY id LIMIT 1', str(req.body?.role, 20)) ?? notFound();
    res.json({ token: createSession(db, user.id) });
  });

  // ── Signed in ─────────────────────────────────────────────
  app.use('/api', authenticate(db));

  app.post('/api/auth/logout', (req, res) => {
    db.run('DELETE FROM sessions WHERE token = ?', (req.headers.authorization ?? '').slice(7));
    res.json({ ok: true });
  });

  for (const route of routes) {
    const handlers = route.upload ? [upload.single(route.upload)] : [];
    app[route.method.toLowerCase() as 'get' | 'post' | 'put']('/api' + route.path, ...handlers, async (req: Request, res: Response) => {
      res.json(await runRoute(route, { db, deps, user: req.user!, params: req.params as Record<string, string>, body: req.body, file: req.file }));
    });
  }

  // Files (server only)
  app.get('/api/payments/:id/receipt.pdf', async (req, res) => {
    const p = db.get<any>('SELECT * FROM payments WHERE id = ?', Number(req.params.id)) ?? notFound();
    const u = req.user!;
    if (p.flat_id !== u.flat_id && u.role !== 'secretary' && u.role !== 'treasurer') throw new HttpError(403, 'forbidden');
    sendPdf(res, `${p.receipt_no}.pdf`, await receiptPdf(society(), p));
  });

  app.get('/api/documents/:id/download', async (req, res) => {
    const d = db.get<{ name_en: string; file: string }>('SELECT name_en, file FROM documents WHERE id = ?', Number(req.params.id)) ?? notFound();
    if (d.file) return res.download(path.join(UPLOAD_DIR, path.basename(d.file)), `${d.name_en}.pdf`);
    sendPdf(res, `${d.name_en}.pdf`, await placeholderDocPdf(society(), d.name_en));
  });

  app.get('/api/expenses/:id/attachment', requireRole('secretary', 'treasurer'), (req, res) => {
    const e = db.get<{ attachment: string | null; attachment_name: string | null }>('SELECT attachment, attachment_name FROM expenses WHERE id = ?', Number(req.params.id));
    if (!e?.attachment) notFound();
    res.download(path.join(UPLOAD_DIR, path.basename(e!.attachment!)), e!.attachment_name ?? 'attachment');
  });

  app.get('/api/reports/monthly.pdf', requireRole('secretary', 'treasurer'), async (_req, res) => {
    const per = period();
    const label = new Date(per + '-01T00:00:00Z').toLocaleString('en-IN', { month: 'long', year: 'numeric', timeZone: 'UTC' });
    const expenses = db.all<any>("SELECT title_en, category, amount FROM expenses WHERE status = 'approved' AND substr(submitted_at, 1, 7) = ? ORDER BY id DESC", per);
    sendPdf(res, `report-${per}.pdf`, await reportPdf(society(), { periodLabel: label, ...collection(db, per), fund: fundBalance(db), expenses, defaulters: defaulters(db) }));
  });

  app.use('/api', (_req, _res, next) => next(new HttpError(404, 'not_found')));

  // Built web app (production)
  if (o.webDist && fs.existsSync(o.webDist)) {
    app.use(express.static(o.webDist, { index: false, maxAge: '1h' }));
    app.get(/^(?!\/api\/).*/, (_req, res) => res.sendFile(path.join(o.webDist!, 'index.html')));
  }

  app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
    const status = err instanceof HttpError ? err.status : err?.code === 'LIMIT_FILE_SIZE' ? 413 : 500;
    if (status === 500) console.error(err);
    res.status(status).json({ error: status === 500 ? 'server_error' : err.message });
  });

  return app;
}
