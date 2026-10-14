import type { Account, Role, Store, User } from './store.js';
import { HttpError, randomToken } from './store.js';
import { nowIso } from './time.js';

/** Normalises Indian mobile numbers to their 10-digit form. */
export const normalizePhone = (raw: unknown) => {
  const digits = String(raw ?? '').replace(/\D/g, '');
  const ten = digits.length === 12 && digits.startsWith('91') ? digits.slice(2) : digits.length === 11 && digits.startsWith('0') ? digits.slice(1) : digits;
  return /^[6-9]\d{9}$/.test(ten) ? ten : null;
};

export function createSession(db: Store, userId: number) {
  const token = randomToken();
  db.run('INSERT INTO sessions (token, user_id, created_at) VALUES (?, ?, ?)', token, userId, nowIso());
  return token;
}

/** Finds or creates the account for a verified phone number. */
export function upsertUser(db: Store, phone: string) {
  const existing = db.get<{ id: number }>('SELECT id FROM users WHERE phone = ?', phone);
  if (existing) return { id: existing.id, isNew: false };
  return { id: db.run('INSERT INTO users (phone, created_at) VALUES (?, ?)', phone, nowIso()).id, isNew: true };
}

const memberSql = `SELECT u.id, u.name, u.name_gu, u.phone, m.id AS member_id, m.society_id, m.flat_id, m.role
  FROM members m JOIN users u ON u.id = m.user_id WHERE m.status = 'active'`;

/** Resolves a bearer token to the account and, when it has one, the active membership it is acting through. */
export function resolveSession(db: Store, token: string | undefined): { account: Account; user: User | null; token: string } {
  if (!token) throw new HttpError(401, 'unauthenticated');
  const s = db.get<{ user_id: number; member_id: number | null }>('SELECT user_id, member_id FROM sessions WHERE token = ?', token);
  if (!s) throw new HttpError(401, 'unauthenticated');
  const account = db.get<Account>('SELECT id, name, name_gu, phone FROM users WHERE id = ?', s.user_id);
  if (!account) throw new HttpError(401, 'unauthenticated');
  let user = s.member_id ? db.get<User>(`${memberSql} AND m.id = ? AND m.user_id = ?`, s.member_id, s.user_id) : undefined;
  if (!user) {
    // Session has no (or a no-longer-active) membership: fall back to the first active one.
    user = db.get<User>(`${memberSql} AND m.user_id = ? ORDER BY m.id LIMIT 1`, s.user_id);
    db.run('UPDATE sessions SET member_id = ? WHERE token = ?', user?.member_id ?? null, token);
  }
  return { account, user: user ?? null, token };
}

export const roleIn = (u: { role: Role }, roles: Role[]) => roles.includes(u.role);
