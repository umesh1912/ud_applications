import type { User } from './store.js';
import type { Store as Db } from './store.js';
import { addDays, nowHM, period, today } from './time.js';

const isAdmin = (u: User) => u.role === 'secretary' || u.role === 'treasurer';

export const fundBalance = (db: Db) => db.value<number>('SELECT COALESCE(SUM(amount), 0) FROM fund_ledger');

export function collection(db: Db, per = period()) {
  const split = { upi: 0, card: 0, cash: 0 };
  for (const r of db.all<{ method: string; total: number }>('SELECT method, SUM(amount) AS total FROM payments WHERE period = ? GROUP BY method', per)) {
    split[r.method === 'upi' ? 'upi' : r.method === 'cash' ? 'cash' : 'card'] += r.total;
  }
  const target = Number(db.setting('total_flats')) * Number(db.setting('maintenance'));
  return { collected: split.upi + split.card + split.cash, target, split };
}

/** Flats with unpaid maintenance, with every unpaid bill counted towards the amount. */
export function defaulters(db: Db) {
  const t = today();
  return db.all<{ flat: string; name: string; amount: number; months: number; reminded: number }>(`
    SELECT b.flat_id AS flat, f.owner AS name, SUM(b.amount) AS amount,
      SUM(b.kind = 'maintenance') AS months,
      EXISTS (SELECT 1 FROM reminders r WHERE r.flat_id = b.flat_id AND substr(r.sent_at, 1, 10) = ?) AS reminded
    FROM bills b JOIN flats f ON f.id = b.flat_id
    WHERE b.payment_id IS NULL
    GROUP BY b.flat_id HAVING months > 0
    ORDER BY months DESC, amount DESC, flat`, t).map(d => ({ ...d, reminded: !!d.reminded }));
}

export const guestParkingFree = (db: Db) =>
  Number(db.setting('guest_parking_total')) - db.value<number>('SELECT COUNT(*) FROM guest_parking WHERE date = ?', today());

/** Everything the signed-in member's app shows, scoped to their role. Polled by the client. */
export function buildState(db: Db, me: User, demo: boolean) {
  const t = today();
  const flat = me.flat_id;
  const admin = isAdmin(me);
  const s = (k: string) => db.setting(k)!;

  const bills = flat ? db.all('SELECT id, icon, title_gu AS titleGu, title_en AS titleEn, amount, due_date AS due, payment_id IS NOT NULL AS paid FROM bills WHERE flat_id = ? ORDER BY paid, due_date, id', flat)
    .map(b => ({ ...b, paid: !!b.paid })) : [];
  const history = flat ? db.all('SELECT id, title_gu AS titleGu, title_en AS titleEn, amount, method, receipt_no AS receiptNo, created_at AS createdAt FROM payments WHERE flat_id = ? ORDER BY created_at DESC LIMIT 30', flat) : [];

  const visitorCols = 'id, name, flat_id AS flat, purpose, status, in_at AS inAt, out_at AS outAt';
  const visitors = me.role === 'resident'
    ? db.all(`SELECT ${visitorCols} FROM visitors WHERE flat_id = ? ORDER BY id DESC LIMIT 30`, flat)
    : db.all(`SELECT ${visitorCols} FROM visitors WHERE status IN ('waiting','inside') OR in_at >= ? ORDER BY id DESC LIMIT 60`, new Date(Date.now() - 2 * 86400e3).toISOString());

  const passCols = 'id, flat_id AS flat, name, valid_on AS validOn, window_gu AS windowGu, window_en AS windowEn, code';
  const passes = me.role === 'resident'
    ? db.all(`SELECT ${passCols} FROM gate_passes WHERE flat_id = ? AND valid_on >= ? ORDER BY id DESC`, flat, t)
    : me.role === 'watchman' ? db.all(`SELECT ${passCols} FROM gate_passes WHERE valid_on >= ? ORDER BY id DESC`, t) : [];

  const complaintCols = 'id, code, flat_id AS flat, category, text_gu AS textGu, text_en AS textEn, status, created_at AS createdAt';
  const complaints = me.role === 'resident'
    ? db.all(`SELECT ${complaintCols} FROM complaints WHERE flat_id = ? ORDER BY id DESC`, flat)
    : admin ? db.all(`SELECT ${complaintCols} FROM complaints ORDER BY id DESC`) : [];

  const notices = db.all('SELECT id, title_gu AS titleGu, title_en AS titleEn, body_gu AS bodyGu, body_en AS bodyEn, pinned, created_at AS createdAt FROM notices ORDER BY id DESC LIMIT 50')
    .map(n => ({ ...n, pinned: !!n.pinned }));
  const events = db.all(`SELECT e.id, title_gu AS titleGu, title_en AS titleEn, starts_on AS startsOn, when_gu AS whenGu, when_en AS whenEn,
      place_gu AS placeGu, place_en AS placeEn, base_going + (SELECT COUNT(*) FROM event_rsvps r WHERE r.event_id = e.id) AS going,
      EXISTS (SELECT 1 FROM event_rsvps r WHERE r.event_id = e.id AND r.user_id = ?) AS me
    FROM events e WHERE starts_on >= ? ORDER BY starts_on`, me.id, addDays(t, -9)).map(e => ({ ...e, me: !!e.me }));
  const polls = db.all('SELECT id, q_gu AS qGu, q_en AS qEn, ends_on AS endsOn FROM polls ORDER BY id').map(p => {
    const options = db.all(`SELECT o.id, label_gu AS labelGu, label_en AS labelEn,
        base_votes + (SELECT COUNT(*) FROM poll_votes v WHERE v.option_id = o.id) AS votes
      FROM poll_options o WHERE poll_id = ? ORDER BY sort`, p.id);
    const mine = db.get<{ option_id: number }>('SELECT option_id FROM poll_votes WHERE poll_id = ? AND user_id = ?', p.id, me.id);
    return { ...p, options, votedOption: mine?.option_id ?? null, closed: p.endsOn < t };
  });

  const amenities = db.all('SELECT id, icon, name_gu AS nameGu, name_en AS nameEn, fee, unit FROM amenities ORDER BY sort');
  const bookedSlots = db.all('SELECT amenity_id AS amenity, date, slot FROM amenity_bookings WHERE date BETWEEN ? AND ?', t, addDays(t, 6));
  const myBookings = flat ? db.all('SELECT id, amenity_id AS amenity, date, slot, fee FROM amenity_bookings WHERE flat_id = ? AND date >= ? ORDER BY date, slot', flat, t) : [];

  const staff = db.all(`SELECT s.id, name_gu AS nameGu, name_en AS nameEn, role_gu AS roleGu, role_en AS roleEn, flats,
      a.in_time AS inTime, a.out_time AS outTime,
      (SELECT COUNT(DISTINCT date) FROM staff_attendance x WHERE x.staff_id = s.id AND substr(x.date, 1, 7) = ?) AS days
    FROM staff s LEFT JOIN staff_attendance a ON a.id = (SELECT MAX(id) FROM staff_attendance y WHERE y.staff_id = s.id AND y.date = ?)
    ORDER BY s.id`, t.slice(0, 7), t);

  const sos = db.get('SELECT id, flat_id AS flat, type, user_id AS userId, created_at AS createdAt FROM sos_alerts WHERE resolved_at IS NULL ORDER BY id DESC LIMIT 1');

  let finance = null;
  if (admin) {
    const c = collection(db);
    finance = {
      fund: fundBalance(db), ...c, defaulters: defaulters(db),
      expenses: db.all("SELECT id, category, title_gu AS titleGu, title_en AS titleEn, amount, submitted_at AS date FROM expenses WHERE status = 'approved' ORDER BY id DESC LIMIT 100"),
      monthExpense: db.value<number>("SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE status = 'approved' AND substr(submitted_at, 1, 7) = ?", t.slice(0, 7)),
      monthByCategory: db.all("SELECT category, SUM(amount) AS amount FROM expenses WHERE status = 'approved' AND substr(submitted_at, 1, 7) = ? GROUP BY category ORDER BY amount DESC", t.slice(0, 7)),
      pending: db.all(`SELECT e.id, category, title_gu AS titleGu, title_en AS titleEn, amount, u.name AS by, submitted_at AS date,
          attachment_name AS fileName, attachment IS NOT NULL AS hasFile
        FROM expenses e LEFT JOIN users u ON u.id = e.submitted_by WHERE status = 'pending' ORDER BY e.id`).map(p => ({ ...p, hasFile: !!p.hasFile })),
    };
  }

  return {
    demo, today: t, now: nowHM(),
    society: { gu: s('society_gu'), en: s('society_en'), cityGu: s('city_gu'), cityEn: s('city_en'), totalFlats: Number(s('total_flats')) },
    me: { id: me.id, name: me.name, nameGu: me.name_gu, role: me.role, flat, phone: me.phone },
    autopay: flat ? !!db.value<number>('SELECT autopay FROM flats WHERE id = ?', flat) : false,
    bills, history, visitors, passes, complaints, notices, events, polls,
    amenities, bookedSlots, myBookings,
    parking: flat ? db.all('SELECT id AS slot, vehicle, kind, location_gu AS locGu, location_en AS locEn FROM parking_slots WHERE flat_id = ? ORDER BY id', flat) : [],
    guestFree: guestParkingFree(db), guestTotal: Number(s('guest_parking_total')),
    staff,
    directory: db.all('SELECT grp, initials, name_gu AS nameGu, name_en AS nameEn, sub_gu AS subGu, sub_en AS subEn, phone FROM contacts ORDER BY sort'),
    documents: db.all('SELECT id, name_gu AS nameGu, name_en AS nameEn, size_label AS size, date_label AS date FROM documents ORDER BY id'),
    sos: sos ? { ...sos, mine: sos.userId === me.id } : null,
    finance,
  };
}
