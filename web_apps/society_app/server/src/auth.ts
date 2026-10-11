import crypto from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';
import type { Db } from './db.js';
import { HttpError, type Role, type User } from './store.js';
import { nowIso } from './time.js';

export { HttpError, type Role, type User };

declare global {
  namespace Express { interface Request { user?: User } }
}

const OTP_TTL_MS = 5 * 60 * 1000;
const MAX_ATTEMPTS = 5;

/** Normalises Indian mobile numbers to their 10-digit form. */
export const normalizePhone = (raw: unknown) => {
  const digits = String(raw ?? '').replace(/\D/g, '');
  const ten = digits.length === 12 && digits.startsWith('91') ? digits.slice(2) : digits;
  return /^[6-9]\d{9}$/.test(ten) ? ten : null;
};

export function createSession(db: Db, userId: number) {
  const token = crypto.randomBytes(24).toString('base64url');
  db.run('INSERT INTO sessions (token, user_id, created_at) VALUES (?, ?, ?)', token, userId, nowIso());
  return token;
}

/** Stores a fresh OTP for a registered member. Returns null when the number is not registered. */
export function issueOtp(db: Db, phone: string, fixedCode?: string) {
  if (!db.get('SELECT id FROM users WHERE phone = ?', phone)) return null;
  const code = fixedCode ?? String(crypto.randomInt(100000, 1000000));
  db.run('INSERT OR REPLACE INTO otps (phone, code, expires_at, attempts) VALUES (?, ?, ?, 0)', phone, code, Date.now() + OTP_TTL_MS);
  return code;
}

export function verifyOtp(db: Db, phone: string, code: string) {
  const row = db.get<{ code: string; expires_at: number; attempts: number }>('SELECT code, expires_at, attempts FROM otps WHERE phone = ?', phone);
  if (!row || row.expires_at < Date.now() || row.attempts >= MAX_ATTEMPTS) throw new HttpError(400, 'otp_expired');
  const ok = row.code.length === code.length && crypto.timingSafeEqual(Buffer.from(row.code), Buffer.from(code));
  if (!ok) { db.run('UPDATE otps SET attempts = attempts + 1 WHERE phone = ?', phone); throw new HttpError(400, 'otp_invalid'); }
  db.run('DELETE FROM otps WHERE phone = ?', phone);
  const user = db.get<User>('SELECT * FROM users WHERE phone = ?', phone)!;
  return createSession(db, user.id);
}

export const authenticate = (db: Db) => (req: Request, _res: Response, next: NextFunction) => {
  const header = req.headers.authorization ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : undefined;
  if (!token) throw new HttpError(401, 'unauthenticated');
  const user = db.get<User>('SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?', token);
  if (!user) throw new HttpError(401, 'unauthenticated');
  req.user = user;
  next();
};

export const requireRole = (...roles: Role[]) => (req: Request, _res: Response, next: NextFunction) => {
  if (!req.user || !roles.includes(req.user.role)) throw new HttpError(403, 'forbidden');
  next();
};
