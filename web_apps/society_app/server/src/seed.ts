import { createSociety } from './society.js';
import type { SqlValue, Store as Db } from './store.js';
import { addDays, istIso, nowIso, period, today } from './time.js';

export const SLOTS = ['06–08', '08–10', '10–12', '16–18', '18–20', '20–22'];

/** Phones of the four demo members (one per role), used by demo mode's one-tap logins. */
export const DEMO_PHONES = { resident: '9825012345', secretary: '9825023456', treasurer: '9825034567', watchman: '9825041122' } as const;

/**
 * Demo society "Shivam Residency" with the design prototype's sample data. Only used when DEMO_MODE is on,
 * and only on a database with no societies yet. Returns the society id, or null if nothing was seeded.
 */
export function seedDemo(db: Db) {
  if (db.value<number>('SELECT COUNT(*) FROM societies') > 0) return null;
  const t = today();
  const now = nowIso();
  const ins = (table: string, row: Record<string, SqlValue | boolean>) => {
    const keys = Object.keys(row);
    return db.run(`INSERT INTO ${table} (${keys.join(', ')}) VALUES (${keys.map(() => '?').join(', ')})`,
      ...keys.map(k => typeof row[k] === 'boolean' ? (row[k] ? 1 : 0) : row[k] as SqlValue)).id;
  };

  return db.tx(() => {
    const people: [string, string, string, string | null, string][] = [
      ['Rajesh Patel', 'રાજેશભાઈ પટેલ', DEMO_PHONES.resident, 'B-304', 'resident'],
      ['Hasmukh Desai', 'હસમુખભાઈ દેસાઈ', DEMO_PHONES.secretary, 'A-101', 'secretary'],
      ['Nilesh Shah', 'નિલેશભાઈ શાહ', DEMO_PHONES.treasurer, 'C-202', 'treasurer'],
      ['Bhikhabhai Rathod', 'ભીખાભાઈ રાઠોડ', DEMO_PHONES.watchman, null, 'watchman'],
    ];
    const uids: Record<string, number> = {};
    for (const [name, gu, phone] of people) uids[phone] = ins('users', { name, name_gu: gu, phone, created_at: now });
    const uid = (role: keyof typeof DEMO_PHONES) => uids[DEMO_PHONES[role]];

    const sid = createSociety(db, {
      name: 'Shivam Residency', nameGu: 'શિવમ રેસિડેન્સી', city: 'Ahmedabad', cityGu: 'અમદાવાદ', address: 'Satellite, Ahmedabad',
      wings: ['A', 'B', 'C'].map(name => ({ name, floors: 4, perFloor: 10 })), maintenance: 2500, dueDay: 10, upiId: 'shivamresidency@sbi',
      openingBalance: 842300,
    }, uid('secretary'));
    // Sample bills below stand in for this month's run, so the automatic monthly billing is marked done.
    db.run('UPDATE societies SET receipt_seq = 1015, complaint_seq = 120, last_billed_period = ? WHERE id = ?', period(), sid);
    const S = { society_id: sid };

    for (const [name, , phone, flat, role] of people)
      ins('members', { ...S, user_id: uids[phone], flat_id: flat, role, status: 'active', created_at: now });
    const owners: Record<string, string> = {
      'A-101': 'Hasmukh Desai', 'A-102': 'Ketan Bhatt', 'A-204': 'Jayesh Mehta', 'A-306': 'Rina Parmar', 'B-102': 'Meena Pandya',
      'B-304': 'Rajesh Patel', 'B-305': 'Alpa Shah', 'B-401': 'Kalpesh Joshi', 'C-108': 'Pooja Trivedi', 'C-202': 'Nilesh Shah',
    };
    for (const [flat, owner] of Object.entries(owners)) db.run('UPDATE flats SET owner = ? WHERE society_id = ? AND id = ?', owner, sid, flat);

    // Payments: B-304 history plus this month's collection from the other flats.
    const pay = (receipt_no: string, flat_id: string | null, amount: number, method: string, title_gu: string, title_en: string, per: string, at: string) =>
      ins('payments', { ...S, receipt_no, flat_id, amount, method, title_gu, title_en, period: per, created_at: at });
    pay('SR-26-0815', 'B-304', 3050, 'card', 'ઓગસ્ટ મેન્ટેનન્સ', 'August maintenance', '2026-08', istIso('2026-08-05', '10:12'));
    pay('SR-26-0912', 'B-304', 3100, 'upi', 'સપ્ટેમ્બર મેન્ટેનન્સ', 'September maintenance', '2026-09', istIso('2026-09-04', '09:40'));
    const sinking = pay('SR-26-0931', 'B-304', 1000, 'upi', 'સિંકિંગ ફંડ (Q3)', 'Sinking fund (Q3)', '2026-09', istIso('2026-09-28', '19:05'));
    const thisMonth = period();
    pay('SR-26-1001', null, 184000, 'upi', 'મેન્ટેનન્સ – અન્ય ફ્લેટ', 'Maintenance – other flats', thisMonth, istIso(`${thisMonth}-05`, '18:00'));
    pay('SR-26-1002', null, 31500, 'card', 'મેન્ટેનન્સ – અન્ય ફ્લેટ', 'Maintenance – other flats', thisMonth, istIso(`${thisMonth}-05`, '18:00'));
    pay('SR-26-1003', null, 26000, 'cash', 'મેન્ટેનન્સ – અન્ય ફ્લેટ', 'Maintenance – other flats', thisMonth, istIso(`${thisMonth}-05`, '18:00'));

    const bill = (flat_id: string, kind: string, icon: string, title_gu: string, title_en: string, amount: number, due_date: string, payment_id: number | null = null) =>
      ins('bills', { ...S, flat_id, kind, icon, title_gu, title_en, amount, due_date, payment_id, period: due_date.slice(0, 7), created_at: now });
    bill('B-304', 'maintenance', 'IconBuilding2', 'ઓક્ટોબર મેન્ટેનન્સ', 'October maintenance', 2500, '2026-10-10');
    bill('B-304', 'light', 'IconZap', 'કોમન લાઇટ બિલ (હિસ્સો)', 'Common light bill (share)', 420, '2026-10-15');
    bill('B-304', 'water', 'IconDroplet', 'પાણી ચાર્જ', 'Water charges', 180, '2026-10-15');
    bill('B-304', 'sinking', 'IconLandmark', 'સિંકિંગ ફંડ (Q3)', 'Sinking fund (Q3)', 1000, '2026-09-30', sinking);
    const months: [string, string, string][] = [['2026-08', 'ઓગસ્ટ', 'August'], ['2026-09', 'સપ્ટેમ્બર', 'September'], ['2026-10', 'ઓક્ટોબર', 'October']];
    const dues: [string, number][] = [['B-401', 3], ['A-204', 2], ['C-108', 1], ['A-306', 1]];
    for (const [flat, n] of dues) for (const [ym, gu, en] of months.slice(3 - n))
      bill(flat, 'maintenance', 'IconBuilding2', `${gu} મેન્ટેનન્સ`, `${en} maintenance`, 2500, `${ym}-10`);

    // Gate
    const yest = addDays(t, -1);
    const visitors: [string, string, string, string, string, string | null][] = [
      ['Ola – GJ01 TX 2231', 'A-306', 'cab', 'out', istIso(t, '08:05'), istIso(t, '08:09')],
      ['Urban Company – AC', 'B-304', 'service', 'out', istIso(yest, '15:10'), istIso(yest, '17:20')],
      ['Dr. Mehul Vyas', 'C-108', 'guest', 'inside', istIso(t, '09:30'), null],
      ['Amazon – Courier', 'A-204', 'courier', 'inside', istIso(t, '10:15'), null],
      ['Swiggy – Mahesh', 'B-304', 'delivery', 'waiting', istIso(t, '10:42'), null],
    ];
    for (const [name, flat_id, purpose, status, in_at, out_at] of visitors) ins('visitors', { ...S, name, flat_id, purpose, status, in_at, out_at });
    ins('gate_passes', { ...S, flat_id: 'B-304', name: 'Kiran Shah', valid_on: t, window_gu: 'સાંજે 7 પછી', window_en: 'after 7 pm', code: '482915', created_by: uid('resident'), created_at: now });

    // Complaints
    const comp: [string, string, string, string, string, string, string][] = [
      ['C-111', 'B-304', 'lift', 'બી વિંગની લિફ્ટમાં અવાજ આવે છે', 'B wing lift is making noise', 'resolved', '2026-09-28'],
      ['C-118', 'B-304', 'plumb', 'બાથરૂમમાં પાણી લીક થાય છે', 'Water leaking in bathroom', 'progress', '2026-10-06'],
      ['C-120', 'A-102', 'elec', 'ગેટ પાસેની સ્ટ્રીટ લાઇટ બંધ છે', 'Street light near the gate is off', 'open', '2026-10-07'],
    ];
    for (const [code, flat_id, category, text_gu, text_en, status, d] of comp)
      ins('complaints', { ...S, code, flat_id, category, text_gu, text_en, status, created_at: istIso(d, '10:00') });

    // Community
    const notices: [string, string, string, string, string, boolean][] = [
      ['વાર્ષિક સામાન્ય સભા 25 ઓક્ટોબરે', 'Annual general meeting on 25 Oct', 'ક્લબહાઉસમાં સવારે 10 વાગ્યે. ઓડિટ રિપોર્ટ દસ્તાવેજોમાં ઉપલબ્ધ છે.', '10 am at the clubhouse. The audit report is in Documents.', '2026-10-01', false],
      ['12 ઓક્ટોબરે પાણી પુરવઠો બંધ', 'Water supply off on 12 Oct', 'ટાંકી સફાઈને કારણે સવારે 10 થી બપોરે 2 સુધી પાણી બંધ રહેશે.', 'Water will be off from 10 am to 2 pm for tank cleaning.', '2026-10-05', false],
      ['નવરાત્રી ગરબા – પાસ વિતરણ', 'Navratri garba – pass distribution', 'ક્લબહાઉસ ઓફિસમાં 9 અને 10 ઓક્ટોબરે સાંજે 6 થી 9 વાગ્યે પાસ મળશે. ફ્લેટ દીઠ 4 પાસ.', 'Collect passes at the clubhouse office on 9–10 Oct, 6–9 pm. Four passes per flat.', '2026-10-07', true],
    ];
    for (const [title_gu, title_en, body_gu, body_en, d, pinned] of notices)
      ins('notices', { ...S, title_gu, title_en, body_gu, body_en, pinned, created_at: istIso(d, '09:00'), created_by: uid('secretary') });

    const events: [string, string, string, string, string, string, string, number, boolean][] = [
      ['નવરાત્રી ગરબા મહોત્સવ', 'Navratri Garba Mahotsav', '2026-10-11', '11–19 ઓક્ટો, રાત્રે 9 વાગ્યે', '11–19 Oct, 9 pm', 'પાર્ટી લોન', 'Party lawn', 186, false],
      ['વાર્ષિક સામાન્ય સભા', 'Annual general meeting', '2026-10-25', 'રવિવાર, સવારે 10 વાગ્યે', 'Sunday, 10 am', 'ક્લબહાઉસ હોલ', 'Clubhouse hall', 63, true],
      ['દિવાળી સ્નેહ મિલન', 'Diwali Sneh Milan', '2026-11-08', 'રવિવાર, સાંજે 7 વાગ્યે', 'Sunday, 7 pm', 'પાર્ટી લોન', 'Party lawn', 142, false],
      ['રક્તદાન શિબિર', 'Blood donation camp', '2026-11-15', 'સવારે 9 થી 1', '9 am – 1 pm', 'ક્લબહાઉસ હોલ', 'Clubhouse hall', 38, false],
    ];
    for (const [title_gu, title_en, starts_on, when_gu, when_en, place_gu, place_en, base_going, me] of events) {
      const id = ins('events', { ...S, title_gu, title_en, starts_on, when_gu, when_en, place_gu, place_en, base_going });
      if (me) ins('event_rsvps', { event_id: id, user_id: uid('resident') });
    }

    const polls: [string, string, string, [string, string, number][]][] = [
      ['પાર્કિંગમાં નવા CCTV કેમેરા લગાવવા? (અંદાજે ₹1,20,000)', 'Install new CCTV cameras in parking? (approx. ₹1,20,000)', '2026-10-15', [['હા', 'Yes', 64], ['ના', 'No', 12], ['AGMમાં ચર્ચા કરીએ', 'Discuss at AGM', 9]]],
      ['ટેરેસ પર સોલાર પેનલ લગાવવી?', 'Install solar panels on the terrace?', '2026-10-30', [['હા, સોસાયટી ફંડમાંથી', 'Yes, from society fund', 41], ['હા, અલગ ફાળાથી', 'Yes, separate contribution', 22], ['હમણાં નહીં', 'Not now', 18]]],
    ];
    for (const [q_gu, q_en, ends_on, opts] of polls) {
      const id = ins('polls', { ...S, q_gu, q_en, ends_on });
      opts.forEach(([label_gu, label_en, base_votes], sort) => ins('poll_options', { poll_id: id, label_gu, label_en, base_votes, sort }));
    }

    // Facilities: bookings by other flats, spread the same way as the prototype's pre-booked slots.
    const others = ['A-102', 'C-108', 'A-204', 'B-305'];
    const amenities = db.all<{ id: string; fee: number }>('SELECT id, fee FROM amenities WHERE society_id = ?', sid);
    for (let n = 0; n < 14; n++) {
      const date = addDays(t, n); const day = Number(date.slice(8));
      for (const a of amenities) SLOTS.forEach((slot, i) => {
        if ((a.id.length * 7 + day * 3 + i * 5) % 4 === 0)
          ins('amenity_bookings', { ...S, amenity_id: a.id, date, slot, flat_id: others[(day + i) % others.length], fee: a.fee, created_at: now });
      });
    }
    ins('vehicles', { ...S, flat_id: 'B-304', slot: 'B-P12', vehicle: 'GJ 01 KX 4521', kind: 'car', location: 'Basement 1' });
    ins('vehicles', { ...S, flat_id: 'B-304', slot: 'B-T07', vehicle: 'GJ 01 SN 0873', kind: 'two', location: 'Stilt' });
    ['A-102', 'A-204', 'C-108', 'B-305', 'A-306', 'C-202'].forEach((flat_id, i) => ins('guest_parking', { ...S, date: t, slot_no: i + 1, flat_id, created_at: now }));

    // Daily help with attendance earlier this month.
    const staff: [string, string, string, string, string, number, string | null, string | null][] = [
      ['સવિતાબેન', 'Savita ben', 'ઘરકામ', 'Maid', 'B-304, B-305', 7, '08:10', null],
      ['રમેશભાઈ', 'Ramesh bhai', 'દૂધવાળા', 'Milkman', 'B wing', 8, '06:30', '06:52'],
      ['જીગ્નેશ', 'Jignesh', 'કાર સફાઈ', 'Car cleaner', 'B-304, A-204', 6, null, null],
      ['હંસાબેન', 'Hansa ben', 'રસોઈ', 'Cook', 'C-108', 7, '09:05', null],
    ];
    const dayOfMonth = Number(t.slice(8));
    for (const [name_gu, name_en, role_gu, role_en, flats, days, tin, tout] of staff) {
      const id = ins('staff', { ...S, name_gu, name_en, role_gu, role_en, flats });
      const past = Math.min(days - (tin ? 1 : 0), dayOfMonth - 1);
      for (let k = 1; k <= past; k++) ins('staff_attendance', { staff_id: id, date: addDays(t, -k), in_time: '08:00', out_time: '10:00' });
      if (tin) ins('staff_attendance', { staff_id: id, date: t, in_time: tin, out_time: tout });
    }

    const contacts: [string, string, string, string, string][] = [
      ['MK', 'Mukesh – plumber', 'Mukesh – plumber', 'પ્લમ્બર', '9879022314'],
      ['BE', 'Bharat – electrician', 'Bharat – electrician', 'ઇલેક્ટ્રિશિયન', '9925066781'],
    ];
    contacts.forEach(([initials, name_gu, name_en, sub_gu, phone], sort) =>
      ins('contacts', { ...S, initials, name_gu, name_en, sub_gu: `${sub_gu} · ${phone}`, sub_en: phone, phone, sort }));

    const docs: [string, string, string, string][] = [
      ['સોસાયટી બાય-લૉઝ', 'Society bye-laws', '1.2 MB', '2024'],
      ['ઓડિટ રિપોર્ટ 2025–26', 'Audit report 2025–26', '860 KB', 'Sep 2026'],
      ['AGM મિનિટ્સ 2025', 'AGM minutes 2025', '420 KB', 'Oct 2025'],
      ['NOC અરજી ફોર્મ', 'NOC application form', '95 KB', '2024'],
      ['પાર્કિંગ નિયમો', 'Parking rules', '130 KB', 'Jan 2026'],
      ['ભાડૂઆત નોંધણી ફોર્મ', 'Tenant registration form', '110 KB', '2024'],
    ];
    for (const [name_gu, name_en, size_label, date_label] of docs) ins('documents', { ...S, name_gu, name_en, size_label, date_label, file: '' });

    // Finance. Listed newest-id-first in the app, so inserted in reverse display order.
    const exps: [string, string, string, number, string][] = [
      ['water', 'પાણીના ટેન્કર (3)', 'Water tankers (3)', 3600, '2026-10-04'],
      ['repair', 'લિફ્ટ AMC – ઓટીસ', 'Lift AMC – Otis', 6500, '2026-10-02'],
      ['light', 'ટોરેન્ટ પાવર – કોમન લાઇટ (સપ્ટે)', 'Torrent Power – common light (Sep)', 18450, '2026-10-03'],
      ['clean', 'હાઉસકીપિંગ સ્ટાફ પગાર', 'Housekeeping staff salary', 22000, '2026-10-01'],
      ['event', 'નવરાત્રી ડેકોરેશન અને સાઉન્ડ', 'Navratri decoration & sound', 35000, '2026-10-06'],
      ['security', 'સિક્યુરિટી એજન્સી – ઓક્ટોબર', 'Security agency – October', 48000, '2026-10-01'],
    ];
    for (const [category, title_gu, title_en, amount, d] of exps)
      ins('expenses', { ...S, category, title_gu, title_en, amount, status: 'approved', submitted_by: uid('treasurer'), submitted_at: istIso(d, '11:00'), decided_by: uid('secretary'), decided_at: istIso(d, '12:00') });
    ins('expenses', { ...S, category: 'water', title_gu: 'પ્લમ્બર – પાણીની ટાંકી સફાઈ', title_en: 'Plumber – water tank cleaning', amount: 5500, status: 'pending', attachment_name: 'invoice_tank.jpg', submitted_by: uid('treasurer'), submitted_at: istIso('2026-10-07', '16:00') });
    return sid;
  });
}
