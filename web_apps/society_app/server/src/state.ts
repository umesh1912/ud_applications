import { ensureMonthlyBills, getSociety } from './society.js';
import type { Store as Db, User } from './store.js';
import { addDays, nowHM, period, today } from './time.js';

export const isAdmin = (u: { role: string }) => u.role === 'secretary' || u.role === 'treasurer';

export const fundBalance = (db: Db, sid: number) => db.value<number>('SELECT COALESCE(SUM(amount), 0) FROM fund_ledger WHERE society_id = ?', sid);

export function collection(db: Db, sid: number, per = period()) {
  const split = { upi: 0, card: 0, cash: 0 };
  for (const r of db.all<{ method: string; total: number }>("SELECT method, SUM(amount) AS total FROM payments WHERE society_id = ? AND period = ? AND status = 'confirmed' GROUP BY method", sid, per))
    split[r.method === 'upi' ? 'upi' : r.method === 'cash' ? 'cash' : 'card'] += r.total;
  const s = getSociety(db, sid);
  const target = db.value<number>('SELECT COUNT(*) FROM flats WHERE society_id = ?', sid) * s.maintenance;
  return { collected: split.upi + split.card + split.cash, target, split };
}

/** Every flat with unpaid bills: amount due, overdue maintenance months, and whether it was reminded today. */
export function dueFlats(db: Db, sid: number) {
  const t = today();
  return db.all<{ flat: string; name: string; amount: number; months: number; overdue: number; reminded: number }>(`
    SELECT b.flat_id AS flat, COALESCE(NULLIF(f.owner, ''), (
        SELECT u.name FROM members m JOIN users u ON u.id = m.user_id
        WHERE m.society_id = b.society_id AND m.flat_id = b.flat_id AND m.status = 'active' ORDER BY m.id LIMIT 1), '') AS name,
      SUM(b.amount) AS amount, SUM(b.kind = 'maintenance' AND b.due_date < ?) AS months, SUM(b.due_date < ?) AS overdue,
      EXISTS (SELECT 1 FROM reminders r WHERE r.society_id = b.society_id AND r.flat_id = b.flat_id AND substr(r.sent_at, 1, 10) = ?) AS reminded
    FROM bills b JOIN flats f ON f.society_id = b.society_id AND f.id = b.flat_id
    WHERE b.society_id = ? AND b.payment_id IS NULL
    GROUP BY b.flat_id ORDER BY months DESC, amount DESC, flat`, t, t, t, sid).map(d => ({ ...d, reminded: !!d.reminded }));
}

/** Flats with overdue bills (shown as "Pending dues"). */
export const defaulters = (db: Db, sid: number) => dueFlats(db, sid).filter(d => d.overdue > 0);

export const guestParkingFree = (db: Db, sid: number) =>
  getSociety(db, sid).guest_parking_total - db.value<number>('SELECT COUNT(*) FROM guest_parking WHERE society_id = ? AND date = ?', sid, today());

export interface StateOptions { demo: boolean; onlinePay: boolean }

/** Everything the signed-in member's app shows, scoped to their society and role. Polled by the client. */
export function buildState(db: Db, me: User, o: StateOptions) {
  const sid = me.society_id;
  ensureMonthlyBills(db, sid);
  const t = today();
  const flat = me.flat_id;
  const admin = isAdmin(me);
  const soc = getSociety(db, sid);

  const bills = flat ? db.all(`SELECT id, icon, title_gu AS titleGu, title_en AS titleEn, amount, due_date AS due, payment_id IS NOT NULL AS paid,
      EXISTS (SELECT 1 FROM payments p WHERE p.society_id = b.society_id AND p.status = 'pending' AND (',' || p.bill_ids || ',') LIKE ('%,' || b.id || ',%')) AS claimed
    FROM bills b WHERE society_id = ? AND flat_id = ? AND (payment_id IS NULL OR due_date >= ?) ORDER BY paid, due_date, id`, sid, flat, addDays(t, -120))
    .map(b => ({ ...b, paid: !!b.paid, claimed: !!b.claimed })) : [];
  const history = flat ? db.all(`SELECT id, title_gu AS titleGu, title_en AS titleEn, amount, method, receipt_no AS receiptNo, created_at AS createdAt, status
    FROM payments WHERE society_id = ? AND flat_id = ? AND status <> 'rejected' ORDER BY created_at DESC LIMIT 30`, sid, flat) : [];

  const visitorCols = 'id, name, flat_id AS flat, purpose, status, in_at AS inAt, out_at AS outAt';
  const visitors = me.role === 'resident'
    ? db.all(`SELECT ${visitorCols} FROM visitors WHERE society_id = ? AND flat_id = ? ORDER BY id DESC LIMIT 30`, sid, flat)
    : db.all(`SELECT ${visitorCols} FROM visitors WHERE society_id = ? AND (status IN ('waiting','inside') OR in_at >= ?) ORDER BY id DESC LIMIT 60`, sid, new Date(Date.now() - 2 * 86400e3).toISOString());
  const myWaiting = flat ? db.all(`SELECT ${visitorCols} FROM visitors WHERE society_id = ? AND flat_id = ? AND status = 'waiting' ORDER BY id`, sid, flat) : [];

  const passCols = 'id, flat_id AS flat, name, valid_on AS validOn, window_gu AS windowGu, window_en AS windowEn, code';
  const passes = me.role === 'watchman'
    ? db.all(`SELECT ${passCols} FROM gate_passes WHERE society_id = ? AND valid_on >= ? ORDER BY id DESC`, sid, t)
    : flat ? db.all(`SELECT ${passCols} FROM gate_passes WHERE society_id = ? AND flat_id = ? AND valid_on >= ? ORDER BY id DESC`, sid, flat, t) : [];

  const complaintCols = 'id, code, flat_id AS flat, category, text_gu AS textGu, text_en AS textEn, status, created_at AS createdAt';
  const complaints = admin
    ? db.all(`SELECT ${complaintCols} FROM complaints WHERE society_id = ? ORDER BY id DESC LIMIT 200`, sid)
    : flat ? db.all(`SELECT ${complaintCols} FROM complaints WHERE society_id = ? AND flat_id = ? ORDER BY id DESC`, sid, flat) : [];

  const notices = db.all('SELECT id, title_gu AS titleGu, title_en AS titleEn, body_gu AS bodyGu, body_en AS bodyEn, pinned, created_at AS createdAt FROM notices WHERE society_id = ? ORDER BY id DESC LIMIT 50', sid)
    .map(n => ({ ...n, pinned: !!n.pinned }));
  const events = db.all(`SELECT e.id, title_gu AS titleGu, title_en AS titleEn, starts_on AS startsOn, when_gu AS whenGu, when_en AS whenEn,
      place_gu AS placeGu, place_en AS placeEn, base_going + (SELECT COUNT(*) FROM event_rsvps r WHERE r.event_id = e.id) AS going,
      EXISTS (SELECT 1 FROM event_rsvps r WHERE r.event_id = e.id AND r.user_id = ?) AS me
    FROM events e WHERE society_id = ? AND starts_on >= ? ORDER BY starts_on`, me.id, sid, addDays(t, -9)).map(e => ({ ...e, me: !!e.me }));
  const polls = db.all('SELECT id, q_gu AS qGu, q_en AS qEn, ends_on AS endsOn FROM polls WHERE society_id = ? AND ends_on >= ? ORDER BY id DESC', sid, addDays(t, -30)).map(p => {
    const options = db.all(`SELECT o.id, label_gu AS labelGu, label_en AS labelEn,
        base_votes + (SELECT COUNT(*) FROM poll_votes v WHERE v.option_id = o.id) AS votes
      FROM poll_options o WHERE poll_id = ? ORDER BY sort`, p.id);
    const mine = db.get<{ option_id: number }>('SELECT option_id FROM poll_votes WHERE poll_id = ? AND user_id = ?', p.id, me.id);
    return { ...p, options, votedOption: mine?.option_id ?? null, closed: p.endsOn < t };
  });

  const amenities = db.all('SELECT id, icon, name_gu AS nameGu, name_en AS nameEn, fee, unit FROM amenities WHERE society_id = ? ORDER BY sort', sid);
  const bookedSlots = db.all('SELECT amenity_id AS amenity, date, slot FROM amenity_bookings WHERE society_id = ? AND date BETWEEN ? AND ?', sid, t, addDays(t, 6));
  const myBookings = flat ? db.all('SELECT id, amenity_id AS amenity, date, slot, fee FROM amenity_bookings WHERE society_id = ? AND flat_id = ? AND date >= ? ORDER BY date, slot', sid, flat, t) : [];

  const staff = db.all(`SELECT s.id, name_gu AS nameGu, name_en AS nameEn, role_gu AS roleGu, role_en AS roleEn, flats,
      a.in_time AS inTime, a.out_time AS outTime,
      (SELECT COUNT(DISTINCT date) FROM staff_attendance x WHERE x.staff_id = s.id AND substr(x.date, 1, 7) = ?) AS days
    FROM staff s LEFT JOIN staff_attendance a ON a.id = (SELECT MAX(id) FROM staff_attendance y WHERE y.staff_id = s.id AND y.date = ?)
    WHERE s.society_id = ? AND s.active = 1 ORDER BY s.id`, t.slice(0, 7), t, sid);

  const sos = db.get('SELECT id, flat_id AS flat, type, user_id AS userId, created_at AS createdAt FROM sos_alerts WHERE society_id = ? AND resolved_at IS NULL ORDER BY id DESC LIMIT 1', sid);

  // Directory: committee and residents come from active members; emergency numbers from contacts and guards.
  const active = db.all<{ id: number; name: string; name_gu: string; phone: string; flat_id: string | null; role: string }>(`
    SELECT m.id, u.name, u.name_gu, u.phone, m.flat_id, m.role FROM members m JOIN users u ON u.id = m.user_id
    WHERE m.society_id = ? AND m.status = 'active' ORDER BY m.flat_id, u.name`, sid);
  const ini = (n: string) => n.split(/\s+/).filter(Boolean).slice(0, 2).map(w => w[0]).join('').toUpperCase() || '?';
  const ROLE_GU: Record<string, string> = { secretary: 'સેક્રેટરી', treasurer: 'ખજાનચી', watchman: 'વોચમેન' };
  const ROLE_EN: Record<string, string> = { secretary: 'Secretary', treasurer: 'Treasurer', watchman: 'Watchman' };
  const directory = [
    ...active.filter(m => isAdmin(m)).map(m => ({ grp: 'committee', initials: ini(m.name), nameGu: m.name_gu || m.name, nameEn: m.name, subGu: `${m.flat_id ?? ''} · ${ROLE_GU[m.role]}`, subEn: `${m.flat_id ?? ''} · ${ROLE_EN[m.role]}`, phone: m.phone })),
    ...active.filter(m => m.role === 'resident').map(m => ({ grp: 'resident', initials: ini(m.name), nameGu: m.name_gu || m.name, nameEn: m.name, subGu: m.flat_id ?? '', subEn: m.flat_id ?? '', phone: m.phone })),
    ...active.filter(m => m.role === 'watchman').map(m => ({ grp: 'emergency', initials: ini(m.name), nameGu: m.name_gu || m.name, nameEn: m.name, subGu: `વોચમેન · ${m.phone}`, subEn: `Watchman · ${m.phone}`, phone: m.phone })),
    ...db.all('SELECT id, initials, name_gu AS nameGu, name_en AS nameEn, sub_gu AS subGu, sub_en AS subEn, phone FROM contacts WHERE society_id = ? ORDER BY sort', sid)
      .map(c => ({ ...c, grp: 'emergency' })),
  ];

  let finance = null, members = null;
  if (admin) {
    const due = dueFlats(db, sid);
    const ym = t.slice(0, 7);
    finance = {
      fund: fundBalance(db, sid), ...collection(db, sid), defaulters: due.filter(d => d.overdue > 0), dueFlats: due,
      expenses: db.all("SELECT id, category, title_gu AS titleGu, title_en AS titleEn, amount, submitted_at AS date FROM expenses WHERE society_id = ? AND status = 'approved' ORDER BY id DESC LIMIT 100", sid),
      monthExpense: db.value<number>("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE society_id = ? AND status = 'approved' AND substr(submitted_at, 1, 7) = ?", sid, ym),
      monthByCategory: db.all("SELECT category, SUM(amount) AS amount FROM expenses WHERE society_id = ? AND status = 'approved' AND substr(submitted_at, 1, 7) = ? GROUP BY category ORDER BY amount DESC", sid, ym),
      pending: db.all(`SELECT e.id, category, title_gu AS titleGu, title_en AS titleEn, amount, u.name AS by, submitted_at AS date,
          attachment_name AS fileName, attachment IS NOT NULL AS hasFile
        FROM expenses e LEFT JOIN users u ON u.id = e.submitted_by WHERE e.society_id = ? AND status = 'pending' ORDER BY e.id`, sid).map(p => ({ ...p, hasFile: !!p.hasFile })),
      claims: db.all(`SELECT p.id, p.flat_id AS flat, p.amount, p.method, p.reference, p.created_at AS createdAt, u.name AS by
        FROM payments p LEFT JOIN users u ON u.id = p.recorded_by WHERE p.society_id = ? AND p.status = 'pending' ORDER BY p.id`, sid),
    };
    members = {
      pending: db.all(`SELECT m.id, u.name, u.phone, m.flat_id AS flat, m.role, m.occupancy, m.created_at AS createdAt
        FROM members m JOIN users u ON u.id = m.user_id WHERE m.society_id = ? AND m.status = 'pending' ORDER BY m.id`, sid),
      active: active.map(m => ({ id: m.id, name: m.name, phone: m.phone, flat: m.flat_id, role: m.role, me: m.id === me.member_id })),
    };
  }

  return {
    demo: o.demo, onlinePay: o.onlinePay, today: t, now: nowHM(),
    society: {
      id: sid, gu: soc.name_gu || soc.name, en: soc.name, cityGu: soc.city_gu || soc.city, cityEn: soc.city, address: soc.address,
      totalFlats: db.value<number>('SELECT COUNT(*) FROM flats WHERE society_id = ?', sid), upiId: soc.upi_id,
      ...(admin ? { code: soc.code, maintenance: soc.maintenance, dueDay: soc.due_day, guestParking: soc.guest_parking_total } : {}),
    },
    me: { id: me.id, memberId: me.member_id, name: me.name, nameGu: me.name_gu, role: me.role, flat, phone: me.phone },
    autopay: flat ? !!db.value<number>('SELECT autopay FROM flats WHERE society_id = ? AND id = ?', sid, flat) : false,
    bills, history, visitors, myWaiting, passes, complaints, notices, events, polls,
    amenities, bookedSlots, myBookings,
    parking: flat ? db.all('SELECT id, slot, vehicle, kind, location FROM vehicles WHERE society_id = ? AND flat_id = ? ORDER BY id', sid, flat) : [],
    guestFree: guestParkingFree(db, sid), guestTotal: soc.guest_parking_total,
    staff, directory,
    documents: db.all('SELECT id, name_gu AS nameGu, name_en AS nameEn, size_label AS size, date_label AS date FROM documents WHERE society_id = ? ORDER BY id DESC', sid),
    sos: sos ? { ...sos, mine: sos.userId === me.id } : null,
    finance, members,
  };
}
