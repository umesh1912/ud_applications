import type { Store as Db } from './store.js';
import { addDays, istIso, nowIso, today } from './time.js';

export const SLOTS = ['06–08', '08–10', '10–12', '16–18', '18–20', '20–22'];

/** Sample data for Shivam Residency, transcribed from the design prototype. Runs only on an empty database. */
export function seed(db: Db) {
  if (db.value<number>('SELECT COUNT(*) FROM settings') > 0) return false;
  const t = today();
  const now = nowIso();

  db.tx(() => {
    const settings: Record<string, string> = {
      society_gu: 'શિવમ રેસિડેન્સી', society_en: 'Shivam Residency', city_gu: 'અમદાવાદ', city_en: 'Ahmedabad',
      total_flats: '120', maintenance: '2500', receipt_seq: '1015', complaint_seq: '120', guest_parking_total: '10',
    };
    for (const [k, v] of Object.entries(settings)) db.run('INSERT INTO settings (key, value) VALUES (?, ?)', k, v);

    const owners: Record<string, string> = {
      'A-101': 'Hasmukh Desai', 'A-102': 'Ketan Bhatt', 'A-204': 'Jayesh Mehta', 'A-306': 'Rina Parmar', 'B-102': 'Meena Pandya',
      'B-304': 'Rajesh Patel', 'B-305': 'Alpa Shah', 'B-401': 'Kalpesh Joshi', 'C-108': 'Pooja Trivedi', 'C-202': 'Nilesh Shah',
    };
    for (const wing of ['A', 'B', 'C']) for (let floor = 1; floor <= 4; floor++) for (let u = 1; u <= 10; u++) {
      const id = `${wing}-${floor}${String(u).padStart(2, '0')}`;
      db.run('INSERT INTO flats (id, wing, owner) VALUES (?, ?, ?)', id, wing, owners[id] ?? `Owner ${id}`);
    }

    const users: [string, string, string, string | null, string][] = [
      ['Rajesh Patel', 'રાજેશભાઈ પટેલ', '9825012345', 'B-304', 'resident'],
      ['Hasmukh Desai', 'હસમુખભાઈ દેસાઈ', '9825023456', 'A-101', 'secretary'],
      ['Nilesh Shah', 'નિલેશભાઈ શાહ', '9825034567', 'C-202', 'treasurer'],
      ['Bhikhabhai Rathod', 'ભીખાભાઈ રાઠોડ', '9825041122', null, 'watchman'],
    ];
    for (const u of users) db.run('INSERT INTO users (name, name_gu, phone, flat_id, role) VALUES (?, ?, ?, ?, ?)', ...u);
    const uid = (role: string) => db.value<number>('SELECT id FROM users WHERE role = ?', role);

    // Payments: B-304 history plus this month's collection from the other flats.
    const pay = (no: string, flat: string | null, amt: number, method: string, gu: string, en: string, per: string, at: string) =>
      db.run('INSERT INTO payments (receipt_no, flat_id, amount, method, title_gu, title_en, period, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', no, flat, amt, method, gu, en, per, at).id;
    pay('SR-26-0815', 'B-304', 3050, 'card', 'ઓગસ્ટ મેન્ટેનન્સ', 'August maintenance', '2026-08', istIso('2026-08-05', '10:12'));
    pay('SR-26-0912', 'B-304', 3100, 'upi', 'સપ્ટેમ્બર મેન્ટેનન્સ', 'September maintenance', '2026-09', istIso('2026-09-04', '09:40'));
    const sinking = pay('SR-26-0931', 'B-304', 1000, 'upi', 'સિંકિંગ ફંડ (Q3)', 'Sinking fund (Q3)', '2026-09', istIso('2026-09-28', '19:05'));
    pay('SR-26-1001', null, 184000, 'upi', 'મેન્ટેનન્સ – અન્ય ફ્લેટ', 'Maintenance – other flats', '2026-10', istIso('2026-10-05', '18:00'));
    pay('SR-26-1002', null, 31500, 'card', 'મેન્ટેનન્સ – અન્ય ફ્લેટ', 'Maintenance – other flats', '2026-10', istIso('2026-10-05', '18:00'));
    pay('SR-26-1003', null, 26000, 'cash', 'મેન્ટેનન્સ – અન્ય ફ્લેટ', 'Maintenance – other flats', '2026-10', istIso('2026-10-05', '18:00'));

    const bill = (flat: string, kind: string, icon: string, gu: string, en: string, amt: number, due: string, paymentId: number | null = null) =>
      db.run('INSERT INTO bills (flat_id, kind, icon, title_gu, title_en, amount, due_date, payment_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', flat, kind, icon, gu, en, amt, due, paymentId);
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
    for (const v of visitors) db.run('INSERT INTO visitors (name, flat_id, purpose, status, in_at, out_at) VALUES (?, ?, ?, ?, ?, ?)', ...v);
    db.run('INSERT INTO gate_passes (flat_id, name, valid_on, window_gu, window_en, code, created_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      'B-304', 'Kiran Shah', t, 'સાંજે 7 પછી', 'after 7 pm', '482915', uid('resident'), now);

    // Complaints
    const comp: [string, string, string, string, string, string, string][] = [
      ['C-111', 'B-304', 'lift', 'બી વિંગની લિફ્ટમાં અવાજ આવે છે', 'B wing lift is making noise', 'resolved', '2026-09-28'],
      ['C-118', 'B-304', 'plumb', 'બાથરૂમમાં પાણી લીક થાય છે', 'Water leaking in bathroom', 'progress', '2026-10-06'],
      ['C-120', 'A-102', 'elec', 'ગેટ પાસેની સ્ટ્રીટ લાઇટ બંધ છે', 'Street light near the gate is off', 'open', '2026-10-07'],
    ];
    for (const [code, flat, cat, gu, en, st, d] of comp)
      db.run('INSERT INTO complaints (code, flat_id, category, text_gu, text_en, status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)', code, flat, cat, gu, en, st, istIso(d, '10:00'));

    // Community
    const notices: [string, string, string, string, string, number][] = [
      ['વાર્ષિક સામાન્ય સભા 25 ઓક્ટોબરે', 'Annual general meeting on 25 Oct', 'ક્લબહાઉસમાં સવારે 10 વાગ્યે. ઓડિટ રિપોર્ટ દસ્તાવેજોમાં ઉપલબ્ધ છે.', '10 am at the clubhouse. The audit report is in Documents.', '2026-10-01', 0],
      ['12 ઓક્ટોબરે પાણી પુરવઠો બંધ', 'Water supply off on 12 Oct', 'ટાંકી સફાઈને કારણે સવારે 10 થી બપોરે 2 સુધી પાણી બંધ રહેશે.', 'Water will be off from 10 am to 2 pm for tank cleaning.', '2026-10-05', 0],
      ['નવરાત્રી ગરબા – પાસ વિતરણ', 'Navratri garba – pass distribution', 'ક્લબહાઉસ ઓફિસમાં 9 અને 10 ઓક્ટોબરે સાંજે 6 થી 9 વાગ્યે પાસ મળશે. ફ્લેટ દીઠ 4 પાસ.', 'Collect passes at the clubhouse office on 9–10 Oct, 6–9 pm. Four passes per flat.', '2026-10-07', 1],
    ];
    for (const [tg, te, bg, be, d, pin] of notices)
      db.run('INSERT INTO notices (title_gu, title_en, body_gu, body_en, pinned, created_at, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)', tg, te, bg, be, pin, istIso(d, '09:00'), uid('secretary'));

    const events: [string, string, string, string, string, string, string, number, boolean][] = [
      ['નવરાત્રી ગરબા મહોત્સવ', 'Navratri Garba Mahotsav', '2026-10-11', '11–19 ઓક્ટો, રાત્રે 9 વાગ્યે', '11–19 Oct, 9 pm', 'પાર્ટી લોન', 'Party lawn', 186, false],
      ['વાર્ષિક સામાન્ય સભા', 'Annual general meeting', '2026-10-25', 'રવિવાર, સવારે 10 વાગ્યે', 'Sunday, 10 am', 'ક્લબહાઉસ હોલ', 'Clubhouse hall', 63, true],
      ['દિવાળી સ્નેહ મિલન', 'Diwali Sneh Milan', '2026-11-08', 'રવિવાર, સાંજે 7 વાગ્યે', 'Sunday, 7 pm', 'પાર્ટી લોન', 'Party lawn', 142, false],
      ['રક્તદાન શિબિર', 'Blood donation camp', '2026-11-15', 'સવારે 9 થી 1', '9 am – 1 pm', 'ક્લબહાઉસ હોલ', 'Clubhouse hall', 38, false],
    ];
    for (const [tg, te, d, wg, we, pg, pe, going, me] of events) {
      const id = db.run('INSERT INTO events (title_gu, title_en, starts_on, when_gu, when_en, place_gu, place_en, base_going) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', tg, te, d, wg, we, pg, pe, going).id;
      if (me) db.run('INSERT INTO event_rsvps (event_id, user_id) VALUES (?, ?)', id, uid('resident'));
    }

    const polls: [string, string, string, [string, string, number][]][] = [
      ['પાર્કિંગમાં નવા CCTV કેમેરા લગાવવા? (અંદાજે ₹1,20,000)', 'Install new CCTV cameras in parking? (approx. ₹1,20,000)', '2026-10-15', [['હા', 'Yes', 64], ['ના', 'No', 12], ['AGMમાં ચર્ચા કરીએ', 'Discuss at AGM', 9]]],
      ['ટેરેસ પર સોલાર પેનલ લગાવવી?', 'Install solar panels on the terrace?', '2026-10-30', [['હા, સોસાયટી ફંડમાંથી', 'Yes, from society fund', 41], ['હા, અલગ ફાળાથી', 'Yes, separate contribution', 22], ['હમણાં નહીં', 'Not now', 18]]],
    ];
    for (const [qg, qe, ends, opts] of polls) {
      const id = db.run('INSERT INTO polls (q_gu, q_en, ends_on) VALUES (?, ?, ?)', qg, qe, ends).id;
      opts.forEach(([g, e, n], i) => db.run('INSERT INTO poll_options (poll_id, label_gu, label_en, base_votes, sort) VALUES (?, ?, ?, ?, ?)', id, g, e, n, i));
    }

    // Facilities
    const amenities: [string, string, string, string, number, string][] = [
      ['hall', 'IconBuilding', 'ક્લબહાઉસ હોલ', 'Clubhouse hall', 1500, 'slot'],
      ['gym', 'IconDumbbell', 'જિમ', 'Gym', 0, 'slot'],
      ['lawn', 'IconPartyPopper', 'પાર્ટી લોન', 'Party lawn', 2500, 'slot'],
      ['guest', 'IconKey', 'ગેસ્ટ રૂમ', 'Guest room', 800, 'night'],
    ];
    amenities.forEach((a, i) => db.run('INSERT INTO amenities (id, icon, name_gu, name_en, fee, unit, sort) VALUES (?, ?, ?, ?, ?, ?, ?)', ...a, i));
    // Bookings by other flats, spread the same way as the prototype's pre-booked slots.
    const others = ['A-102', 'C-108', 'A-204', 'B-305'];
    for (let n = 0; n < 14; n++) {
      const date = addDays(t, n); const day = Number(date.slice(8));
      for (const [id, , , , fee] of amenities) SLOTS.forEach((slot, i) => {
        if ((id.length * 7 + day * 3 + i * 5) % 4 === 0)
          db.run('INSERT INTO amenity_bookings (amenity_id, date, slot, flat_id, fee, created_at) VALUES (?, ?, ?, ?, ?, ?)', id, date, slot, others[(day + i) % others.length], fee, now);
      });
    }
    db.run("INSERT INTO parking_slots VALUES ('B-P12', 'B-304', 'GJ 01 KX 4521', 'car', 'કાર · બેઝમેન્ટ 1', 'Car · Basement 1')");
    db.run("INSERT INTO parking_slots VALUES ('B-T07', 'B-304', 'GJ 01 SN 0873', 'two', 'ટુ-વ્હીલર · સ્ટિલ્ટ', 'Two-wheeler · Stilt')");
    ['A-102', 'A-204', 'C-108', 'B-305', 'A-306', 'C-202'].forEach((flat, i) =>
      db.run('INSERT INTO guest_parking (date, slot_no, flat_id, created_at) VALUES (?, ?, ?, ?)', t, i + 1, flat, now));

    // Daily help with attendance earlier this month.
    const staff: [string, string, string, string, string, number, string | null, string | null][] = [
      ['સવિતાબેન', 'Savita ben', 'ઘરકામ', 'Maid', 'B-304, B-305', 7, '08:10', null],
      ['રમેશભાઈ', 'Ramesh bhai', 'દૂધવાળા', 'Milkman', 'B wing', 8, '06:30', '06:52'],
      ['જીગ્નેશ', 'Jignesh', 'કાર સફાઈ', 'Car cleaner', 'B-304, A-204', 6, null, null],
      ['હંસાબેન', 'Hansa ben', 'રસોઈ', 'Cook', 'C-108', 7, '09:05', null],
    ];
    const dayOfMonth = Number(t.slice(8));
    for (const [ng, ne, rg, re, flats, days, tin, tout] of staff) {
      const id = db.run('INSERT INTO staff (name_gu, name_en, role_gu, role_en, flats) VALUES (?, ?, ?, ?, ?)', ng, ne, rg, re, flats).id;
      const past = Math.min(days - (tin ? 1 : 0), dayOfMonth - 1);
      for (let k = 1; k <= past; k++) db.run('INSERT INTO staff_attendance (staff_id, date, in_time, out_time) VALUES (?, ?, ?, ?)', id, addDays(t, -k), '08:00', '10:00');
      if (tin) db.run('INSERT INTO staff_attendance (staff_id, date, in_time, out_time) VALUES (?, ?, ?, ?)', id, t, tin, tout);
    }

    const contacts: [string, string, string, string, string, string, string][] = [
      ['committee', 'HD', 'Hasmukh Desai', 'Hasmukh Desai', 'A-101 · સેક્રેટરી', 'A-101 · Secretary', '9825023456'],
      ['committee', 'NS', 'Nilesh Shah', 'Nilesh Shah', 'C-202 · ખજાનચી', 'C-202 · Treasurer', '9825034567'],
      ['committee', 'MP', 'Meena Pandya', 'Meena Pandya', 'B-102 · પ્રમુખ', 'B-102 · Chairperson', '9825056789'],
      ['resident', 'JM', 'Jayesh Mehta', 'Jayesh Mehta', 'A-204', 'A-204', '9824011111'],
      ['resident', 'RP', 'Rajesh Patel', 'Rajesh Patel', 'B-304', 'B-304', '9825012345'],
      ['resident', 'KJ', 'Kalpesh Joshi', 'Kalpesh Joshi', 'B-401', 'B-401', '9824022222'],
      ['resident', 'PT', 'Pooja Trivedi', 'Pooja Trivedi', 'C-108', 'C-108', '9824033333'],
      ['resident', 'RP', 'Rina Parmar', 'Rina Parmar', 'A-306', 'A-306', '9824044444'],
      ['emergency', 'BR', 'Bhikhabhai Rathod', 'Bhikhabhai Rathod', 'વોચમેન · 98250 41122', 'Watchman · 98250 41122', '9825041122'],
      ['emergency', 'MK', 'Mukesh – plumber', 'Mukesh – plumber', '98790 22314', '98790 22314', '9879022314'],
      ['emergency', 'BE', 'Bharat – electrician', 'Bharat – electrician', '99250 66781', '99250 66781', '9925066781'],
      ['emergency', '108', 'એમ્બ્યુલન્સ', 'Ambulance', '108', '108', '108'],
      ['emergency', '101', 'ફાયર બ્રિગેડ', 'Fire brigade', '101', '101', '101'],
    ];
    contacts.forEach(([g, ini, ng, ne, sg, se, ph], i) =>
      db.run('INSERT INTO contacts (grp, initials, name_gu, name_en, sub_gu, sub_en, phone, sort) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', g, ini, ng, ne, sg, se, ph, i));

    const docs: [string, string, string, string][] = [
      ['સોસાયટી બાય-લૉઝ', 'Society bye-laws', '1.2 MB', '2024'],
      ['ઓડિટ રિપોર્ટ 2025–26', 'Audit report 2025–26', '860 KB', 'Sep 2026'],
      ['AGM મિનિટ્સ 2025', 'AGM minutes 2025', '420 KB', 'Oct 2025'],
      ['NOC અરજી ફોર્મ', 'NOC application form', '95 KB', '2024'],
      ['પાર્કિંગ નિયમો', 'Parking rules', '130 KB', 'Jan 2026'],
      ['ભાડૂઆત નોંધણી ફોર્મ', 'Tenant registration form', '110 KB', '2024'],
    ];
    for (const d of docs) db.run("INSERT INTO documents (name_gu, name_en, size_label, date_label, file) VALUES (?, ?, ?, ?, '')", ...d);

    // Finance
    db.run('INSERT INTO fund_ledger (amount, reason, created_at) VALUES (?, ?, ?)', 842300, 'Opening balance', now);
    const exps: [string, string, string, number, string][] = [
      // Listed newest-id-first in the app, so inserted in reverse display order.
      ['water', 'પાણીના ટેન્કર (3)', 'Water tankers (3)', 3600, '2026-10-04'],
      ['repair', 'લિફ્ટ AMC – ઓટીસ', 'Lift AMC – Otis', 6500, '2026-10-02'],
      ['light', 'ટોરેન્ટ પાવર – કોમન લાઇટ (સપ્ટે)', 'Torrent Power – common light (Sep)', 18450, '2026-10-03'],
      ['clean', 'હાઉસકીપિંગ સ્ટાફ પગાર', 'Housekeeping staff salary', 22000, '2026-10-01'],
      ['event', 'નવરાત્રી ડેકોરેશન અને સાઉન્ડ', 'Navratri decoration & sound', 35000, '2026-10-06'],
      ['security', 'સિક્યુરિટી એજન્સી – ઓક્ટોબર', 'Security agency – October', 48000, '2026-10-01'],
    ];
    for (const [cat, gu, en, amt, d] of exps)
      db.run("INSERT INTO expenses (category, title_gu, title_en, amount, status, submitted_by, submitted_at, decided_by, decided_at) VALUES (?, ?, ?, ?, 'approved', ?, ?, ?, ?)",
        cat, gu, en, amt, uid('treasurer'), istIso(d, '11:00'), uid('secretary'), istIso(d, '12:00'));
    db.run("INSERT INTO expenses (category, title_gu, title_en, amount, status, attachment_name, submitted_by, submitted_at) VALUES ('water', ?, ?, 5500, 'pending', 'invoice_tank.jpg', ?, ?)",
      'પ્લમ્બર – પાણીની ટાંકી સફાઈ', 'Plumber – water tank cleaning', uid('treasurer'), istIso('2026-10-07', '16:00'));
  });
  return true;
}
