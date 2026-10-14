import { HttpError, randomCode, type Society, type Store } from './store.js';
import { nowIso, period } from './time.js';

export interface WingSpec { name: string; floors: number; perFloor: number }
export interface NewSociety {
  name: string; nameGu?: string; city: string; cityGu?: string; address?: string;
  wings: WingSpec[]; maintenance: number; dueDay: number; upiId?: string; openingBalance?: number;
}

export const MONTHS: [string, string][] = [['જાન્યુઆરી', 'January'], ['ફેબ્રુઆરી', 'February'], ['માર્ચ', 'March'], ['એપ્રિલ', 'April'], ['મે', 'May'], ['જૂન', 'June'],
  ['જુલાઈ', 'July'], ['ઓગસ્ટ', 'August'], ['સપ્ટેમ્બર', 'September'], ['ઓક્ટોબર', 'October'], ['નવેમ્બર', 'November'], ['ડિસેમ્બર', 'December']];
export const MAX_FLATS = 3000;

/** Flat numbers for a wing: floor + two-digit unit, e.g. A-101 … A-410. */
export const wingFlats = (w: WingSpec) => {
  const out: string[] = [];
  for (let f = 1; f <= w.floors; f++) for (let u = 1; u <= w.perFloor; u++) out.push(`${w.name}-${f}${String(u).padStart(2, '0')}`);
  return out;
};

export const getSociety = (db: Store, id: number) => db.get<Society>('SELECT * FROM societies WHERE id = ?', id) ?? (() => { throw new HttpError(404, 'society_not_found'); })();

/** Creates a society with its flats, default amenities and emergency contacts. Returns the new society id. */
export function createSociety(db: Store, s: NewSociety, createdBy: number | null) {
  const wings = s.wings.map(w => ({ name: w.name.trim().toUpperCase().slice(0, 6), floors: Math.floor(w.floors), perFloor: Math.floor(w.perFloor) }));
  if (!wings.length || wings.some(w => !/^[A-Z0-9]{1,6}$/.test(w.name) || !(w.floors >= 1 && w.floors <= 60) || !(w.perFloor >= 1 && w.perFloor <= 50)))
    throw new HttpError(400, 'wings_invalid');
  if (new Set(wings.map(w => w.name)).size !== wings.length) throw new HttpError(400, 'wings_invalid');
  const flats = wings.flatMap(w => wingFlats(w).map(id => [id, w.name] as const));
  if (flats.length > MAX_FLATS) throw new HttpError(400, 'too_many_flats');

  let code: string;
  do code = randomCode(); while (db.get('SELECT id FROM societies WHERE code = ?', code));
  const sid = db.run(`INSERT INTO societies (name, name_gu, city, city_gu, address, code, maintenance, due_day, upi_id, created_at, created_by)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  s.name, s.nameGu || s.name, s.city, s.cityGu || s.city, s.address ?? '', code, Math.max(0, Math.round(s.maintenance)),
  Math.min(28, Math.max(1, Math.round(s.dueDay))), s.upiId ?? '', nowIso(), createdBy).id;

  for (const [id, wing] of flats) db.run('INSERT INTO flats (society_id, id, wing) VALUES (?, ?, ?)', sid, id, wing);
  const amenities: [string, string, string, string, number, string][] = [
    ['hall', 'IconBuilding', 'ક્લબહાઉસ હોલ', 'Clubhouse hall', 1500, 'slot'], ['gym', 'IconDumbbell', 'જિમ', 'Gym', 0, 'slot'],
    ['lawn', 'IconPartyPopper', 'પાર્ટી લોન', 'Party lawn', 2500, 'slot'], ['guest', 'IconKey', 'ગેસ્ટ રૂમ', 'Guest room', 800, 'night'],
  ];
  amenities.forEach((a, i) => db.run('INSERT INTO amenities (society_id, id, icon, name_gu, name_en, fee, unit, sort) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', sid, ...a, i));
  const contacts: [string, string, string, string][] = [['108', 'એમ્બ્યુલન્સ', 'Ambulance', '108'], ['101', 'ફાયર બ્રિગેડ', 'Fire brigade', '101'], ['100', 'પોલીસ', 'Police', '100']];
  contacts.forEach(([ini, gu, en, phone], i) =>
    db.run('INSERT INTO contacts (society_id, initials, name_gu, name_en, sub_gu, sub_en, phone, sort) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', sid, ini, gu, en, phone, phone, phone, 100 + i));
  if (s.openingBalance) db.run('INSERT INTO fund_ledger (society_id, amount, reason, created_at) VALUES (?, ?, ?, ?)', sid, Math.round(s.openingBalance), 'Opening balance', nowIso());
  return sid;
}

/** Raises this month's maintenance bill for every flat, once per month. Safe to call on every request. */
export function ensureMonthlyBills(db: Store, sid: number) {
  const per = period();
  const s = getSociety(db, sid);
  if (s.last_billed_period === per) return 0;
  return db.tx(() => {
    const fresh = getSociety(db, sid);
    if (fresh.last_billed_period === per) return 0;
    let n = 0;
    if (fresh.maintenance > 0) {
      const [gu, en] = MONTHS[Number(per.slice(5, 7)) - 1];
      const due = `${per}-${String(fresh.due_day).padStart(2, '0')}`;
      n = db.run(`INSERT INTO bills (society_id, flat_id, kind, icon, title_gu, title_en, amount, due_date, period, created_at)
        SELECT ?, f.id, 'maintenance', 'IconBuilding2', ?, ?, ?, ?, ?, ? FROM flats f
        WHERE f.society_id = ? AND NOT EXISTS (SELECT 1 FROM bills b WHERE b.society_id = f.society_id AND b.flat_id = f.id AND b.kind = 'maintenance' AND b.period = ?)`,
      sid, `${gu} મેન્ટેનન્સ`, `${en} maintenance`, fresh.maintenance, due, per, nowIso(), sid, per).changes;
    }
    db.run('UPDATE societies SET last_billed_period = ? WHERE id = ?', per, sid);
    return n;
  });
}

export function nextReceiptNo(db: Store, sid: number) {
  db.run('UPDATE societies SET receipt_seq = receipt_seq + 1 WHERE id = ?', sid);
  const seq = db.value<number>('SELECT receipt_seq FROM societies WHERE id = ?', sid);
  return `R-${period().slice(2, 4)}-${String(seq).padStart(4, '0')}`;
}
