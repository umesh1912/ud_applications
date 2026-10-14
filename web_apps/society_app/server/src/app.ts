import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import express, { type NextFunction, type Request, type Response } from 'express';
import multer from 'multer';
import { resolveSession } from './auth.js';
import { UPLOAD_DIR, type Db } from './db.js';
import { notFound, routes, runRoute, type Deps } from './routes.js';
import { placeholderDocPdf, receiptPdf, reportPdf } from './services/pdf.js';
import { getSociety } from './society.js';
import { collection, defaulters, fundBalance, isAdmin } from './state.js';
import { HttpError } from './store.js';
import { period } from './time.js';

export interface AppOptions extends Deps {
  db: Db;
  webDist?: string;
}

const bearer = (req: Request) => {
  const h = req.headers.authorization ?? '';
  return h.startsWith('Bearer ') ? h.slice(7) : undefined;
};

export function createApp(o: AppOptions) {
  const { db } = o;
  const deps: Deps = { payments: o.payments, notifier: o.notifier, otp: o.otp, demo: o.demo };
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use(express.json({ limit: '100kb' }));

  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  const upload = multer({
    storage: multer.diskStorage({
      destination: UPLOAD_DIR,
      filename: (_req, file, cb) => cb(null, crypto.randomBytes(12).toString('hex') + path.extname(file.originalname).toLowerCase().replace(/[^.a-z0-9]/g, '').slice(0, 6)),
    }),
    limits: { fileSize: 10 * 1024 * 1024 },
    fileFilter: (_req, file, cb) => cb(null, /^(image\/|application\/pdf$)/.test(file.mimetype)),
  });
  const sendPdf = (res: Response, name: string, buf: Buffer) => {
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${name.replace(/[^\w.\- ]+/g, '_')}"`);
    res.send(buf);
  };
  const member = (req: Request) => resolveSession(db, bearer(req)).user ?? (() => { throw new HttpError(403, 'no_society'); })();

  app.get('/healthz', (_req, res) => { db.value('SELECT 1'); res.json({ ok: true }); });

  for (const route of routes) {
    const handlers = route.upload ? [upload.single(route.upload)] : [];
    app[route.method.toLowerCase() as 'get' | 'post' | 'put' | 'delete']('/api' + route.path, ...handlers, async (req: Request, res: Response) => {
      const token = bearer(req);
      const session = route.auth === 'public' ? undefined : resolveSession(db, token);
      const body = route.method === 'GET' ? req.query : req.body;
      res.json(await runRoute(route, { db, deps, session, token, params: req.params as Record<string, string>, body, file: req.file }));
    });
  }

  // Files (server only)
  app.get('/api/payments/:id/receipt.pdf', async (req, res) => {
    const u = member(req);
    const p = db.get<any>("SELECT * FROM payments WHERE id = ? AND society_id = ? AND status = 'confirmed'", Number(req.params.id), u.society_id) ?? notFound();
    if (p.flat_id !== u.flat_id && !isAdmin(u)) throw new HttpError(403, 'forbidden');
    sendPdf(res, `${p.receipt_no}.pdf`, await receiptPdf(getSociety(db, u.society_id).name, p));
  });

  app.get('/api/documents/:id/download', async (req, res) => {
    const u = member(req);
    const d = db.get<{ name_en: string; file: string }>('SELECT name_en, file FROM documents WHERE id = ? AND society_id = ?', Number(req.params.id), u.society_id) ?? notFound();
    if (d.file) return res.download(path.join(UPLOAD_DIR, path.basename(d.file)), `${d.name_en}${path.extname(d.file) || '.pdf'}`);
    sendPdf(res, `${d.name_en}.pdf`, await placeholderDocPdf(getSociety(db, u.society_id).name, d.name_en));
  });

  app.get('/api/expenses/:id/attachment', (req, res) => {
    const u = member(req);
    if (!isAdmin(u)) throw new HttpError(403, 'forbidden');
    const e = db.get<{ attachment: string | null; attachment_name: string | null }>('SELECT attachment, attachment_name FROM expenses WHERE id = ? AND society_id = ?', Number(req.params.id), u.society_id);
    if (!e?.attachment) notFound();
    res.download(path.join(UPLOAD_DIR, path.basename(e!.attachment!)), e!.attachment_name ?? 'attachment');
  });

  app.get('/api/reports/monthly.pdf', async (req, res) => {
    const u = member(req);
    if (!isAdmin(u)) throw new HttpError(403, 'forbidden');
    const sid = u.society_id, per = period();
    const label = new Date(per + '-01T00:00:00Z').toLocaleString('en-IN', { month: 'long', year: 'numeric', timeZone: 'UTC' });
    const expenses = db.all<any>("SELECT title_en, category, amount FROM expenses WHERE society_id = ? AND status = 'approved' AND substr(submitted_at, 1, 7) = ? ORDER BY id DESC", sid, per);
    const dues = defaulters(db, sid).map(d => ({ flat: d.flat, name: d.name, amount: d.amount }));
    sendPdf(res, `report-${per}.pdf`, await reportPdf(getSociety(db, sid).name, { periodLabel: label, ...collection(db, sid, per), fund: fundBalance(db, sid), expenses, defaulters: dues }));
  });

  app.use('/api', (_req, _res, next) => next(new HttpError(404, 'not_found')));

  // Built web app (production)
  if (o.webDist && fs.existsSync(o.webDist)) {
    app.use(express.static(o.webDist, { index: false, maxAge: '1h' }));
    app.get(/^(?!\/api\/).*/, (_req, res) => { res.setHeader('Cache-Control', 'no-cache'); res.sendFile(path.join(o.webDist!, 'index.html')); });
  }

  app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
    const status = err instanceof HttpError ? err.status : err?.code === 'LIMIT_FILE_SIZE' ? 413 : 500;
    if (status === 500) console.error(err);
    res.status(status).json({ error: status === 500 ? 'server_error' : err.message });
  });

  return app;
}
