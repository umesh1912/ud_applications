// Storage-agnostic types shared by the Node server (node:sqlite) and the offline app build (sql.js).
export type SqlValue = string | number | bigint | null | Uint8Array;
export type Row = Record<string, any>;

export interface Store {
  all<T = Row>(sql: string, ...params: SqlValue[]): T[];
  get<T = Row>(sql: string, ...params: SqlValue[]): T | undefined;
  run(sql: string, ...params: SqlValue[]): { changes: number; id: number };
  value<T = number>(sql: string, ...params: SqlValue[]): T;
  tx<T>(fn: () => T): T;
}

export type Role = 'resident' | 'secretary' | 'treasurer' | 'watchman';
export const ROLES: Role[] = ['resident', 'secretary', 'treasurer', 'watchman'];

/** A signed-in person (a row in users). */
export interface Account { id: number; name: string; name_gu: string; phone: string }

/** The signed-in person acting inside one society, through an active membership. */
export interface User extends Account { member_id: number; society_id: number; flat_id: string | null; role: Role }

export interface Society {
  id: number; name: string; name_gu: string; city: string; city_gu: string; address: string; code: string;
  maintenance: number; due_day: number; upi_id: string; guest_parking_total: number; receipt_seq: number; complaint_seq: number;
  last_billed_period: string | null; created_at: string;
}

export class HttpError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

/** n random decimal digits (no leading zero), using Web Crypto so it works in Node and the browser. */
export const randomDigits = (n: number) => {
  const buf = new Uint32Array(n);
  globalThis.crypto.getRandomValues(buf);
  return Array.from(buf, (v, i) => String(i === 0 ? 1 + (v % 9) : v % 10)).join('');
};

/** Society join code: 6 characters without look-alikes (0/O, 1/I/L). */
export const randomCode = () => {
  const abc = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  const buf = new Uint32Array(6);
  globalThis.crypto.getRandomValues(buf);
  return Array.from(buf, v => abc[v % abc.length]).join('');
};

export const randomToken = () => {
  const buf = new Uint8Array(24);
  globalThis.crypto.getRandomValues(buf);
  return Array.from(buf, b => b.toString(16).padStart(2, '0')).join('');
};

export const SCHEMA_VERSION = 2;

export const SCHEMA = `
CREATE TABLE IF NOT EXISTS societies (
  id INTEGER PRIMARY KEY, name TEXT NOT NULL, name_gu TEXT NOT NULL DEFAULT '', city TEXT NOT NULL DEFAULT '', city_gu TEXT NOT NULL DEFAULT '',
  address TEXT NOT NULL DEFAULT '', code TEXT NOT NULL UNIQUE, maintenance INTEGER NOT NULL DEFAULT 0, due_day INTEGER NOT NULL DEFAULT 10,
  upi_id TEXT NOT NULL DEFAULT '', guest_parking_total INTEGER NOT NULL DEFAULT 10, receipt_seq INTEGER NOT NULL DEFAULT 0,
  complaint_seq INTEGER NOT NULL DEFAULT 100, last_billed_period TEXT, created_at TEXT NOT NULL, created_by INTEGER
);
CREATE TABLE IF NOT EXISTS flats (
  society_id INTEGER NOT NULL, id TEXT NOT NULL, wing TEXT NOT NULL, owner TEXT NOT NULL DEFAULT '', autopay INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (society_id, id)
);
CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT NOT NULL DEFAULT '', name_gu TEXT NOT NULL DEFAULT '', phone TEXT NOT NULL UNIQUE, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS members (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, user_id INTEGER NOT NULL, flat_id TEXT,
  role TEXT NOT NULL CHECK (role IN ('resident','secretary','treasurer','watchman')),
  status TEXT NOT NULL CHECK (status IN ('pending','active','rejected','removed')),
  occupancy TEXT NOT NULL DEFAULT 'owner', created_at TEXT NOT NULL, decided_by INTEGER, UNIQUE (society_id, user_id)
);
CREATE TABLE IF NOT EXISTS sessions (token TEXT PRIMARY KEY, user_id INTEGER NOT NULL, member_id INTEGER, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS otps (phone TEXT PRIMARY KEY, code TEXT NOT NULL, expires_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, sent_at INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS bills (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, flat_id TEXT NOT NULL, kind TEXT NOT NULL, icon TEXT NOT NULL,
  title_gu TEXT NOT NULL, title_en TEXT NOT NULL, amount INTEGER NOT NULL, due_date TEXT NOT NULL, period TEXT,
  payment_id INTEGER, created_at TEXT
);
CREATE TABLE IF NOT EXISTS payments (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, receipt_no TEXT, flat_id TEXT, amount INTEGER NOT NULL,
  method TEXT NOT NULL CHECK (method IN ('upi','card','net','cash','cheque','bank')), title_gu TEXT NOT NULL, title_en TEXT NOT NULL,
  period TEXT NOT NULL, created_at TEXT NOT NULL, recorded_by INTEGER, provider_ref TEXT,
  status TEXT NOT NULL DEFAULT 'confirmed' CHECK (status IN ('pending','confirmed','rejected')), bill_ids TEXT, reference TEXT
);
CREATE TABLE IF NOT EXISTS reminders (id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, flat_id TEXT NOT NULL, sent_at TEXT NOT NULL, sent_by INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS visitors (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, name TEXT NOT NULL, flat_id TEXT NOT NULL, purpose TEXT NOT NULL, photo TEXT,
  status TEXT NOT NULL CHECK (status IN ('waiting','inside','out','denied')), in_at TEXT NOT NULL, out_at TEXT,
  logged_by INTEGER, decided_by INTEGER
);
CREATE TABLE IF NOT EXISTS gate_passes (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, flat_id TEXT NOT NULL, name TEXT NOT NULL, valid_on TEXT NOT NULL,
  window_gu TEXT NOT NULL, window_en TEXT NOT NULL, code TEXT NOT NULL, created_by INTEGER, created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS complaints (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, code TEXT NOT NULL, flat_id TEXT NOT NULL, category TEXT NOT NULL,
  text_gu TEXT NOT NULL, text_en TEXT NOT NULL, status TEXT NOT NULL CHECK (status IN ('open','progress','resolved')),
  attachment TEXT, attachment_name TEXT, created_at TEXT NOT NULL, created_by INTEGER, UNIQUE (society_id, code)
);
CREATE TABLE IF NOT EXISTS notices (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, title_gu TEXT NOT NULL, title_en TEXT NOT NULL, body_gu TEXT NOT NULL, body_en TEXT NOT NULL,
  pinned INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, created_by INTEGER
);
CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, title_gu TEXT NOT NULL, title_en TEXT NOT NULL, starts_on TEXT NOT NULL,
  when_gu TEXT NOT NULL, when_en TEXT NOT NULL, place_gu TEXT NOT NULL, place_en TEXT NOT NULL, base_going INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS event_rsvps (event_id INTEGER NOT NULL, user_id INTEGER NOT NULL, PRIMARY KEY (event_id, user_id));
CREATE TABLE IF NOT EXISTS polls (id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, q_gu TEXT NOT NULL, q_en TEXT NOT NULL, ends_on TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS poll_options (
  id INTEGER PRIMARY KEY, poll_id INTEGER NOT NULL, label_gu TEXT NOT NULL, label_en TEXT NOT NULL, base_votes INTEGER NOT NULL DEFAULT 0, sort INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS poll_votes (poll_id INTEGER NOT NULL, user_id INTEGER NOT NULL, option_id INTEGER NOT NULL, PRIMARY KEY (poll_id, user_id));
CREATE TABLE IF NOT EXISTS amenities (
  society_id INTEGER NOT NULL, id TEXT NOT NULL, icon TEXT NOT NULL, name_gu TEXT NOT NULL, name_en TEXT NOT NULL, fee INTEGER NOT NULL, unit TEXT NOT NULL, sort INTEGER NOT NULL,
  PRIMARY KEY (society_id, id)
);
CREATE TABLE IF NOT EXISTS amenity_bookings (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, amenity_id TEXT NOT NULL, date TEXT NOT NULL, slot TEXT NOT NULL, flat_id TEXT NOT NULL,
  fee INTEGER NOT NULL, created_at TEXT NOT NULL, UNIQUE (society_id, amenity_id, date, slot)
);
CREATE TABLE IF NOT EXISTS vehicles (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, flat_id TEXT NOT NULL, slot TEXT NOT NULL, vehicle TEXT NOT NULL, kind TEXT NOT NULL, location TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS guest_parking (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, date TEXT NOT NULL, slot_no INTEGER NOT NULL, flat_id TEXT NOT NULL, created_at TEXT NOT NULL,
  UNIQUE (society_id, date, slot_no)
);
CREATE TABLE IF NOT EXISTS staff (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, name_gu TEXT NOT NULL, name_en TEXT NOT NULL, role_gu TEXT NOT NULL, role_en TEXT NOT NULL,
  flats TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS staff_attendance (id INTEGER PRIMARY KEY, staff_id INTEGER NOT NULL, date TEXT NOT NULL, in_time TEXT NOT NULL, out_time TEXT);
CREATE TABLE IF NOT EXISTS contacts (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, initials TEXT NOT NULL, name_gu TEXT NOT NULL, name_en TEXT NOT NULL,
  sub_gu TEXT NOT NULL, sub_en TEXT NOT NULL, phone TEXT NOT NULL, sort INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS documents (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, name_gu TEXT NOT NULL, name_en TEXT NOT NULL, size_label TEXT NOT NULL, date_label TEXT NOT NULL, file TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS expenses (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, category TEXT NOT NULL, title_gu TEXT NOT NULL, title_en TEXT NOT NULL, amount INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending','approved','rejected')), attachment TEXT, attachment_name TEXT,
  submitted_by INTEGER, submitted_at TEXT NOT NULL, decided_by INTEGER, decided_at TEXT
);
CREATE TABLE IF NOT EXISTS fund_ledger (id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, amount INTEGER NOT NULL, reason TEXT NOT NULL, ref TEXT, created_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS sos_alerts (
  id INTEGER PRIMARY KEY, society_id INTEGER NOT NULL, flat_id TEXT, user_id INTEGER NOT NULL, type TEXT NOT NULL, created_at TEXT NOT NULL, resolved_at TEXT, resolved_by INTEGER
);
CREATE INDEX IF NOT EXISTS bills_by_flat ON bills (society_id, flat_id, payment_id);
CREATE INDEX IF NOT EXISTS payments_by_period ON payments (society_id, period, status);
CREATE INDEX IF NOT EXISTS visitors_by_society ON visitors (society_id, status, in_at);
CREATE INDEX IF NOT EXISTS members_by_user ON members (user_id, status);
`;

/** Creates the schema; refuses to open a database from the single-society version (no migration path). */
export function prepareSchema(db: Store) {
  const legacy = db.get("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'settings'");
  if (legacy) throw new Error('This database is from the single-society version. Delete it (or run `npm run seed -- --reset`) to start fresh.');
  db.run(`PRAGMA user_version = ${SCHEMA_VERSION}`);
  for (const stmt of SCHEMA.split(';').map(s => s.trim()).filter(Boolean)) db.run(stmt);
}
