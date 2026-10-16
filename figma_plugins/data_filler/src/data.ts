// Reading tables from pasted text or files, and matching layer names to columns.
// Pure functions so they can be unit tested.

export type Row = Record<string, unknown>;

export interface Table {
  columns: string[];
  rows: Row[];
}

// CSV with quotes ("a, b", "say ""hi"""), or TSV as copied from Google Sheets / Excel.
export function parseDelimited(text: string): Table {
  const firstLine = text.split(/\r?\n/, 1)[0] ?? '';
  const delim = firstLine.includes('\t') ? '\t' : firstLine.split(';').length > firstLine.split(',').length ? ';' : ',';
  const records: string[][] = [];
  let field = '';
  let record: string[] = [];
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') {
        field += '"';
        i++;
      } else if (ch === '"') quoted = false;
      else field += ch;
    } else if (ch === '"' && field === '') quoted = true;
    else if (ch === delim) {
      record.push(field);
      field = '';
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      record.push(field);
      records.push(record);
      record = [];
      field = '';
    } else field += ch;
  }
  if (field !== '' || record.length) {
    record.push(field);
    records.push(record);
  }
  const nonEmpty = records.filter((r) => r.some((c) => c.trim() !== ''));
  if (!nonEmpty.length) return { columns: [], rows: [] };
  const columns = uniqueHeaders(nonEmpty[0].map((h) => h.trim()));
  const rows = nonEmpty.slice(1).map((r) => {
    const row: Row = {};
    columns.forEach((c, i) => (row[c] = (r[i] ?? '').trim()));
    return row;
  });
  return { columns, rows };
}

function uniqueHeaders(headers: string[]): string[] {
  const seen = new Map<string, number>();
  return headers.map((h, i) => {
    const base = h || `column ${i + 1}`;
    const n = (seen.get(base) ?? 0) + 1;
    seen.set(base, n);
    return n === 1 ? base : `${base} ${n}`;
  });
}

// A JSON array of objects, or an object holding one (e.g. {"users": [...]} from an API).
export function parseJson(text: string): Table {
  let data: unknown = JSON.parse(text);
  if (!Array.isArray(data) && data && typeof data === 'object') {
    const arr = Object.values(data as object).find(Array.isArray);
    data = arr ?? [data];
  }
  if (!Array.isArray(data)) throw new Error('JSON must be a list of objects.');
  const rows = data.map((d) => (d && typeof d === 'object' ? (d as Row) : { value: d }));
  const columns: string[] = [];
  const addKeys = (obj: Row, prefix: string) => {
    for (const [k, v] of Object.entries(obj)) {
      const key = prefix + k;
      if (v && typeof v === 'object' && !Array.isArray(v)) addKeys(v as Row, `${key}.`);
      else if (!columns.includes(key)) columns.push(key);
    }
  };
  rows.slice(0, 50).forEach((r) => addKeys(r, ''));
  return { columns, rows };
}

export function parseTable(text: string): Table {
  const t = text.trim();
  if (!t) return { columns: [], rows: [] };
  if (t.startsWith('[') || t.startsWith('{')) return parseJson(t);
  return parseDelimited(t);
}

// "First name", "first_name" and "firstName" all match the layer "#firstname".
export const normKey = (s: string) => s.toLowerCase().replace(/[\s_\-]/g, '');

export function lookup(row: Row, field: string): unknown {
  const want = normKey(field);
  for (const [k, v] of Object.entries(row)) if (normKey(k) === want) return v;
  // Dotted paths into nested JSON: "#user.name".
  if (field.includes('.')) {
    let cur: unknown = row;
    for (const part of field.split('.')) {
      if (!cur || typeof cur !== 'object') return undefined;
      const entry = Object.entries(cur as Row).find(([k]) => normKey(k) === normKey(part));
      cur = entry ? entry[1] : undefined;
    }
    return cur;
  }
  return undefined;
}

export function isTruthy(v: unknown): boolean {
  if (v === null || v === undefined || v === false) return false;
  const s = String(v).trim().toLowerCase();
  return !['', '0', 'false', 'no', 'n', 'off', 'hide', 'hidden', 'null'].includes(s);
}

export const isImageUrl = (v: unknown) => typeof v === 'string' && /^https?:\/\/\S+$/i.test(v.trim());
export const isHexColor = (v: unknown) => typeof v === 'string' && /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(v.trim());

// Parses a layer name: "#title" fills, "#badge?" shows/hides, "#price | Card" ignores the note after "|".
export function parseLayerName(name: string): { field: string; toggle: boolean } | null {
  const n = name.trim();
  if (!n.startsWith('#') || n.length < 2) return null;
  let field = n.slice(1).split('|')[0].trim();
  const toggle = field.endsWith('?');
  if (toggle) field = field.slice(0, -1).trim();
  return field ? { field, toggle } : null;
}

// ---- Sample data ----

const FIRST = ['Aarav', 'Diya', 'Kabir', 'Ananya', 'Rohan', 'Isha', 'Vivaan', 'Meera', 'Arjun', 'Sara', 'Liam', 'Emma', 'Noah', 'Olivia', 'Mateo', 'Yuki', 'Amara', 'Lucas', 'Zara', 'Omar'];
const LAST = ['Shah', 'Patel', 'Mehta', 'Iyer', 'Kapoor', 'Desai', 'Rao', 'Singh', 'Joshi', 'Nair', 'Smith', 'Garcia', 'Kim', 'Müller', 'Rossi', 'Tanaka', 'Okafor', 'Silva', 'Haddad', 'Novak'];
const CITY = ['Ahmedabad', 'Mumbai', 'Bengaluru', 'Pune', 'Delhi', 'Surat', 'Jaipur', 'London', 'Berlin', 'Toronto', 'Dubai', 'Singapore'];
const COMPANY = ['Northwind', 'Bluepeak', 'Sunrise Labs', 'Kite & Co', 'Indigo Works', 'Saffron Tech', 'Lumen', 'Orbit Studio'];
const STATUS = ['Active', 'Pending', 'Paid', 'Overdue', 'Shipped', 'Draft'];
const ROLE = ['Designer', 'Engineer', 'Product Manager', 'Founder', 'Marketing Lead', 'Data Analyst'];
const WORDS = 'quick simple bright modern secure fast friendly smart clean fresh easy local daily'.split(' ');
const PRODUCT = ['Wireless Earbuds', 'Cotton Kurta', 'Smart Watch', 'Leather Wallet', 'Desk Lamp', 'Running Shoes', 'Masala Chai Set', 'Backpack'];

// Small seeded generator so the same seed gives the same sample.
function rng(seed: number) {
  let s = seed >>> 0 || 1;
  return () => {
    s ^= s << 13;
    s ^= s >>> 17;
    s ^= s << 5;
    return (s >>> 0) / 4294967296;
  };
}

export function sampleRows(count: number, seed = 7): Table {
  const r = rng(seed);
  const pick = <T,>(a: T[]) => a[Math.floor(r() * a.length)];
  const rows: Row[] = [];
  for (let i = 0; i < count; i++) {
    const first = pick(FIRST);
    const last = pick(LAST);
    const day = new Date(Date.UTC(2026, Math.floor(r() * 12), 1 + Math.floor(r() * 28)));
    rows.push({
      name: `${first} ${last}`,
      first,
      last,
      email: `${first}.${last}`.toLowerCase().normalize('NFD').replace(/[^a-z.]/g, '') + '@example.com',
      phone: `+91 9${Math.floor(r() * 1e9).toString().padStart(9, '0').replace(/(\d{4})(\d{5})/, '$1 $2')}`,
      city: pick(CITY),
      company: pick(COMPANY),
      role: pick(ROLE),
      product: pick(PRODUCT),
      price: `₹${(Math.round(r() * 4900) + 99).toLocaleString('en-IN')}`,
      amount: (Math.round(r() * 99900) / 100 + 1).toFixed(2),
      rating: (3 + r() * 2).toFixed(1),
      date: day.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' }),
      status: pick(STATUS),
      title: `${pick(WORDS)[0].toUpperCase()}${pick(WORDS).slice(1)} ${pick(WORDS)} ${pick(['update', 'launch', 'guide', 'offer', 'release'])}`,
      verified: r() > 0.4 ? 'yes' : 'no',
      avatar: `https://i.pravatar.cc/240?img=${1 + Math.floor(r() * 70)}`,
    });
  }
  return { columns: Object.keys(rows[0] ?? {}), rows };
}

// Order in which rows are used.
export function rowOrder(total: number, needed: number, start: number, shuffle: boolean, seed = Date.now()): number[] {
  if (!total) return [];
  const idx = Array.from({ length: total }, (_, i) => i);
  if (shuffle) {
    const r = rng(seed);
    for (let i = idx.length - 1; i > 0; i--) {
      const j = Math.floor(r() * (i + 1));
      [idx[i], idx[j]] = [idx[j], idx[i]];
    }
  }
  const s = ((start % total) + total) % total;
  return Array.from({ length: needed }, (_, i) => idx[(s + i) % total]);
}
