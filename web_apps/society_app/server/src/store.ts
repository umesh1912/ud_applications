// Storage-agnostic types shared by the Node server (node:sqlite) and the offline app build (sql.js).
export type SqlValue = string | number | bigint | null | Uint8Array;
export type Row = Record<string, any>;

export interface Store {
  all<T = Row>(sql: string, ...params: SqlValue[]): T[];
  get<T = Row>(sql: string, ...params: SqlValue[]): T | undefined;
  run(sql: string, ...params: SqlValue[]): { changes: number; id: number };
  value<T = number>(sql: string, ...params: SqlValue[]): T;
  tx<T>(fn: () => T): T;
  setting(key: string): string | undefined;
}

export type Role = 'resident' | 'secretary' | 'treasurer' | 'watchman';
export interface User { id: number; name: string; name_gu: string; phone: string; flat_id: string | null; role: Role }

export class HttpError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

/** n random decimal digits (no leading zero), using Web Crypto so it works in Node and the browser. */
export const randomDigits = (n: number) => {
  const buf = new Uint32Array(n);
  globalThis.crypto.getRandomValues(buf);
  return Array.from(buf, (v, i) => String(i === 0 ? 1 + (v % 9) : v % 10)).join('');
};

export const SCHEMA = `
CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS flats (id TEXT PRIMARY KEY, wing TEXT NOT NULL, owner TEXT NOT NULL, autopay INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY, name TEXT NOT NULL, name_gu TEXT NOT NULL, phone TEXT NOT NULL UNIQUE,
  flat_id TEXT REFERENCES flats(id), role TEXT NOT NULL CHECK (role IN ('resident','secretary','treasurer','watchman'))
);
CREATE TABLE IF NOT EXISTS sessions (token TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS otps (phone TEXT PRIMARY KEY, code TEXT NOT NULL, expires_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS bills (
  id INTEGER PRIMARY KEY, flat_id TEXT NOT NULL REFERENCES flats(id), kind TEXT NOT NULL, icon TEXT NOT NULL,
  title_gu TEXT NOT NULL, title_en TEXT NOT NULL, amount INTEGER NOT NULL, due_date TEXT NOT NULL,
  payment_id INTEGER REFERENCES payments(id)
);
CREATE TABLE IF NOT EXISTS payments (
  id INTEGER PRIMARY KEY, receipt_no TEXT NOT NULL UNIQUE, flat_id TEXT REFERENCES flats(id), amount INTEGER NOT NULL,
  method TEXT NOT NULL CHECK (method IN ('upi','card','net','cash')), title_gu TEXT NOT NULL, title_en TEXT NOT NULL,
  period TEXT NOT NULL, created_at TEXT NOT NULL, recorded_by INTEGER REFERENCES users(id), provider_ref TEXT
);
CREATE TABLE IF NOT EXISTS reminders (id INTEGER PRIMARY KEY, flat_id TEXT NOT NULL, sent_at TEXT NOT NULL, sent_by INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS visitors (
  id INTEGER PRIMARY KEY, name TEXT NOT NULL, flat_id TEXT NOT NULL, purpose TEXT NOT NULL, photo TEXT,
  status TEXT NOT NULL CHECK (status IN ('waiting','inside','out','denied')), in_at TEXT NOT NULL, out_at TEXT,
  logged_by INTEGER, decided_by INTEGER
);
CREATE TABLE IF NOT EXISTS gate_passes (
  id INTEGER PRIMARY KEY, flat_id TEXT NOT NULL, name TEXT NOT NULL, valid_on TEXT NOT NULL,
  window_gu TEXT NOT NULL, window_en TEXT NOT NULL, code TEXT NOT NULL, created_by INTEGER, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS complaints (
  id INTEGER PRIMARY KEY, code TEXT NOT NULL UNIQUE, flat_id TEXT NOT NULL, category TEXT NOT NULL,
  text_gu TEXT NOT NULL, text_en TEXT NOT NULL, status TEXT NOT NULL CHECK (status IN ('open','progress','resolved')),
  attachment TEXT, attachment_name TEXT, created_at TEXT NOT NULL, created_by INTEGER
);
CREATE TABLE IF NOT EXISTS notices (
  id INTEGER PRIMARY KEY, title_gu TEXT NOT NULL, title_en TEXT NOT NULL, body_gu TEXT NOT NULL, body_en TEXT NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, created_by INTEGER
);
CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY, title_gu TEXT NOT NULL, title_en TEXT NOT NULL, starts_on TEXT NOT NULL,
  when_gu TEXT NOT NULL, when_en TEXT NOT NULL, place_gu TEXT NOT NULL, place_en TEXT NOT NULL, base_going INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS event_rsvps (event_id INTEGER NOT NULL, user_id INTEGER NOT NULL, PRIMARY KEY (event_id, user_id));
CREATE TABLE IF NOT EXISTS polls (id INTEGER PRIMARY KEY, q_gu TEXT NOT NULL, q_en TEXT NOT NULL, ends_on TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS poll_options (
  id INTEGER PRIMARY KEY, poll_id INTEGER NOT NULL, label_gu TEXT NOT NULL, label_en TEXT NOT NULL, base_votes INTEGER NOT NULL DEFAULT 0, sort INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS poll_votes (poll_id INTEGER NOT NULL, user_id INTEGER NOT NULL, option_id INTEGER NOT NULL, PRIMARY KEY (poll_id, user_id));
CREATE TABLE IF NOT EXISTS amenities (id TEXT PRIMARY KEY, icon TEXT NOT NULL, name_gu TEXT NOT NULL, name_en TEXT NOT NULL, fee INTEGER NOT NULL, unit TEXT NOT NULL, sort INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS amenity_bookings (
  id INTEGER PRIMARY KEY, amenity_id TEXT NOT NULL, date TEXT NOT NULL, slot TEXT NOT NULL, flat_id TEXT NOT NULL,
  fee INTEGER NOT NULL, created_at TEXT NOT NULL, UNIQUE (amenity_id, date, slot)
);
CREATE TABLE IF NOT EXISTS parking_slots (id TEXT PRIMARY KEY, flat_id TEXT NOT NULL, vehicle TEXT NOT NULL, kind TEXT NOT NULL, location_gu TEXT NOT NULL, location_en TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS guest_parking (id INTEGER PRIMARY KEY, date TEXT NOT NULL, slot_no INTEGER NOT NULL, flat_id TEXT NOT NULL, created_at TEXT NOT NULL, UNIQUE (date, slot_no));
CREATE TABLE IF NOT EXISTS staff (id INTEGER PRIMARY KEY, name_gu TEXT NOT NULL, name_en TEXT NOT NULL, role_gu TEXT NOT NULL, role_en TEXT NOT NULL, flats TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS staff_attendance (id INTEGER PRIMARY KEY, staff_id INTEGER NOT NULL, date TEXT NOT NULL, in_time TEXT NOT NULL, out_time TEXT);
CREATE TABLE IF NOT EXISTS contacts (
  id INTEGER PRIMARY KEY, grp TEXT NOT NULL, initials TEXT NOT NULL, name_gu TEXT NOT NULL, name_en TEXT NOT NULL,
  sub_gu TEXT NOT NULL, sub_en TEXT NOT NULL, phone TEXT NOT NULL, sort INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS documents (id INTEGER PRIMARY KEY, name_gu TEXT NOT NULL, name_en TEXT NOT NULL, size_label TEXT NOT NULL, date_label TEXT NOT NULL, file TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS expenses (
  id INTEGER PRIMARY KEY, category TEXT NOT NULL, title_gu TEXT NOT NULL, title_en TEXT NOT NULL, amount INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending','approved','rejected')), attachment TEXT, attachment_name TEXT,
  submitted_by INTEGER, submitted_at TEXT NOT NULL, decided_by INTEGER, decided_at TEXT
);
CREATE TABLE IF NOT EXISTS fund_ledger (id INTEGER PRIMARY KEY, amount INTEGER NOT NULL, reason TEXT NOT NULL, ref TEXT, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS sos_alerts (
  id INTEGER PRIMARY KEY, flat_id TEXT, user_id INTEGER NOT NULL, type TEXT NOT NULL, created_at TEXT NOT NULL, resolved_at TEXT, resolved_by INTEGER
);
`;
