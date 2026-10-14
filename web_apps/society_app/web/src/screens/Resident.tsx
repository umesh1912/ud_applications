import { Button, Icon, Progress, Switch } from '../ds';
import { useApp } from '../ctx';
import { api } from '../lib/api';
import { COMP_CATS, DOW, SLOTS } from '../lib/i18n';
import { addDays, dayMon, dayMonLocal, dow, fmt } from '../lib/format';
import { btnReset, C, Card, Empty, IconBox, IconBtn, Label, Lines, pill, ring, Row, Stack, wide, wideTall } from '../ui';
import { COMPLAINT_STATUS, useVisitorText, VisitorBadge } from './common';

const METHOD_LABEL: Record<string, string> = { upi: 'UPI', card: 'Card', net: 'Net banking', cash: 'Cash', cheque: 'Cheque', bank: 'Bank' };

export function Bills() {
  const { st, T, x, ui, set, open, toast, run, dl } = useApp();
  const due = st.bills.filter(b => !b.paid && !b.claimed);
  const selected = due.filter(b => !ui.unselected.includes(b.id));
  const selTotal = selected.reduce((a, b) => a + b.amount, 0);
  const toggle = (id: number) => set(u => ({ unselected: u.unselected.includes(id) ? u.unselected.filter(i => i !== id) : [...u.unselected, id] }));
  const autopay = async (v: boolean) => {
    if (await run(() => api('PUT', '/autopay', { enabled: v }))) toast(v ? x(['ઓટો-પે ચાલુ થયું', 'Auto-pay turned on']) : x(['ઓટો-પે બંધ થયું', 'Auto-pay turned off']));
  };

  return (
    <Stack gap={12}>
      <div style={{ fontSize: 13, color: C.muted }}>{T.selectBills}</div>
      {st.bills.map(b => {
        const open_ = !b.paid && !b.claimed;
        const on = open_ && !ui.unselected.includes(b.id);
        return (
          <button key={b.id} onClick={() => open_ && toggle(b.id)} aria-pressed={on}
            style={{ ...btnReset, background: '#fff', boxShadow: ring(on ? C.ink : C.line), borderRadius: 6, padding: 14, display: 'flex', gap: 12, alignItems: 'center', textAlign: 'left', cursor: open_ ? 'pointer' : 'default' }}>
            <IconBox name={b.icon} />
            <Lines title={x([b.titleGu, b.titleEn])} sub={`${T.dueBy} ${dayMon(b.due)}`} />
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
              <div style={{ fontSize: 15, fontWeight: 700 }}>{fmt(b.amount)}</div>
              <span style={{ fontSize: 11, fontWeight: 600, padding: '2px 8px', borderRadius: 40, background: b.paid ? C.ink : '#fff', color: b.paid ? '#fff' : C.red, boxShadow: ring(b.paid ? C.ink : C.red), ...(b.claimed && !b.paid ? { background: C.soft, color: C.body, boxShadow: 'none' } : {}) }}>{b.paid ? T.paid : b.claimed ? T.verifying : T.unpaid}</span>
            </div>
          </button>
        );
      })}
      {due.length > 0 && <Button style={wideTall} onClick={() => selTotal > 0 ? open(st.onlinePay ? 'pay' : 'upi') : toast(T.selectBills)}>{T.pay} {fmt(selTotal)}</Button>}
      {st.onlinePay && <Card style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 4 }}>
        <Switch label={T.autopay} checked={st.autopay} onChange={autopay} />
        <div style={{ fontSize: 12, color: C.muted, paddingLeft: 52 }}>{T.autopaySub}</div>
      </Card>}
      <Label style={{ marginTop: 8 }}>{T.history}</Label>
      <Card>
        {st.history.map(h => (
          <Row key={h.id}>
            <Lines titleWeight={500} title={x([h.titleGu, h.titleEn])} sub={`${dayMon(h.createdAt)} · ${METHOD_LABEL[h.method] ?? h.method} · ${h.status === 'pending' ? T.verifying : h.receiptNo}`} />
            <div style={{ fontSize: 14, fontWeight: 600 }}>{fmt(h.amount)}</div>
            {h.status === 'confirmed'
              ? <IconBtn name="IconDownload" label={T.receiptPdf} onClick={() => dl(`/payments/${h.id}/receipt.pdf`, `${h.receiptNo}.pdf`, x(['રસીદ ડાઉનલોડ થઈ: ', 'Receipt downloaded: ']) + h.receiptNo)} />
              : <div style={{ width: 32 }} />}
          </Row>
        ))}
      </Card>
    </Stack>
  );
}

export function Gate() {
  const { st, T, x, open } = useApp();
  const vt = useVisitorText();
  const when = (p: (typeof st.passes)[number]) => {
    const day = p.validOn === st.today ? T.today : p.validOn === addDays(st.today, 1) ? T.tomorrow : dayMon(p.validOn);
    const win = x([p.windowGu, p.windowEn]);
    return win ? `${day}, ${win}` : day;
  };
  return (
    <Stack gap={12}>
      <Button icon="IconTicket" style={wideTall} onClick={() => open('pass')}>{T.createPass}</Button>
      <Label style={{ marginTop: 4 }}>{T.activePasses}</Label>
      {st.passes.map(p => (
        <Card key={p.id} style={{ padding: 14, display: 'flex', gap: 14, alignItems: 'center' }}>
          <IconBox name="IconQrCode" box={56} size={32} />
          <Stack gap={2} style={{ flex: 1 }}><div style={{ fontSize: 15, fontWeight: 600 }}>{p.name}</div><div style={{ fontSize: 12, color: C.muted }}>{when(p)}</div></Stack>
          <div style={{ fontFamily: 'Menlo,ui-monospace,monospace', fontWeight: 700, fontSize: 18, letterSpacing: 2 }}>{p.code}</div>
        </Card>
      ))}
      {!st.passes.length && <Card><Empty>{T.noPasses}</Empty></Card>}
      <Label style={{ marginTop: 4 }}>{T.visitorLog}</Label>
      <Card>
        {st.visitors.map(v => (
          <Row key={v.id}><Lines title={v.name} sub={`${vt(v).purpose} · ${vt(v).in}`} /><VisitorBadge status={v.status} /></Row>
        ))}
        {!st.visitors.length && <Empty>{T.noVisitors}</Empty>}
      </Card>
    </Stack>
  );
}

export function Complaints() {
  const { st, T, x, isRes, open } = useApp();
  return (
    <Stack gap={10}>
      {st.me.flat && <Button icon="IconPlus" style={wideTall} onClick={() => open('complaint')}>{T.raiseComplaint}</Button>}
      {st.complaints.map(c => {
        const [bg, fg, step] = COMPLAINT_STATUS[c.status];
        return (
          <Card key={c.id} style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
              <span style={{ fontSize: 12, color: C.muted }}>{isRes ? c.code : `${c.code} · ${c.flat}`} · {x(COMP_CATS.find(k => k[0] === c.category)?.[1] ?? COMP_CATS[5][1])} · {dayMon(c.createdAt)}</span>
              <span style={{ fontSize: 11, fontWeight: 600, padding: '2px 8px', borderRadius: 40, background: bg, color: fg, whiteSpace: 'nowrap' }}>{T[c.status]}</span>
            </div>
            <div style={{ fontSize: 14, fontWeight: 600 }}>{x([c.textGu, c.textEn])}</div>
            <div style={{ display: 'flex', gap: 4 }}>
              {[1, 2, 3].map(n => <div key={n} style={{ flex: 1, height: 4, borderRadius: 4, background: n <= step ? C.ink : C.line }} />)}
            </div>
          </Card>
        );
      })}
      {!st.complaints.length && <Card><Empty>{T.noComplaints}</Empty></Card>}
    </Stack>
  );
}

export function Amenities() {
  const { st, T, x, L, ui, set, toast, run } = useApp();
  const date = ui.date || st.today;
  const cur = st.amenities.find(a => a.id === ui.amenity) ?? st.amenities[0];
  if (!cur) return null;
  const booked = new Set(st.bookedSlots.filter(b => b.amenity === cur.id && b.date === date).map(b => b.slot));
  const dates = [0, 1, 2, 3, 4].map(n => addDays(st.today, n));
  const feeLabel = (fee: number, unit: string) => fee ? fmt(fee) + (unit === 'night' ? x([' / રાત', ' / night']) : x([' / સ્લોટ', ' / slot'])) : x(['મફત', 'Free']);
  const book = async () => {
    if (!ui.slot) return toast(T.pickFirst);
    if (await run(() => api('POST', '/bookings', { amenity: cur.id, date, slot: ui.slot }))) { set({ slot: null }); toast(x(['બુકિંગ કન્ફર્મ થયું', 'Booking confirmed'])); }
  };
  const nameOf = (id: string) => { const a = st.amenities.find(a => a.id === id); return a ? x([a.nameGu, a.nameEn]) : id; };

  return (
    <Stack gap={14}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
        {st.amenities.map(a => (
          <button key={a.id} onClick={() => set({ amenity: a.id, slot: null })} aria-pressed={a.id === cur.id}
            style={{ ...btnReset, borderRadius: 6, padding: 14, display: 'flex', flexDirection: 'column', gap: 8, textAlign: 'left', boxShadow: ring(), ...pill(a.id === cur.id) }}>
            <Icon name={a.icon} size={22} />
            <span style={{ fontSize: 14, fontWeight: 600 }}>{x([a.nameGu, a.nameEn])}</span><span style={{ fontSize: 12, opacity: 0.75 }}>{feeLabel(a.fee, a.unit)}</span>
          </button>
        ))}
      </div>
      <Label>{T.pickDate}</Label>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5,1fr)', gap: 6 }}>
        {dates.map(d => (
          <button key={d} onClick={() => set({ date: d, slot: null })} aria-pressed={d === date}
            style={{ ...btnReset, borderRadius: 6, padding: '8px 0', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, boxShadow: ring(), ...pill(d === date) }}>
            <span style={{ fontSize: 11, fontWeight: 500 }}>{DOW[dow(d)][L]}</span><span style={{ fontSize: 18, fontWeight: 700 }}>{Number(d.slice(8))}</span>
          </button>
        ))}
      </div>
      <Label>{T.pickSlot}</Label>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 6 }}>
        {SLOTS.map(sl => {
          const b = booked.has(sl), on = ui.slot === sl;
          return (
            <button key={sl} disabled={b} onClick={() => set({ slot: sl })} aria-pressed={on}
              style={{ ...btnReset, borderRadius: 6, height: 40, fontSize: 13, fontWeight: 600, boxShadow: ring(), cursor: b ? 'not-allowed' : 'pointer',
                background: on ? C.ink : b ? C.soft : '#fff', color: on ? '#fff' : b ? C.faint : C.ink, textDecoration: b ? 'line-through' : 'none' }}>{sl}</button>
          );
        })}
      </div>
      <Button onClick={book} style={{ ...wideTall, opacity: ui.slot ? 1 : 0.5 }}>{ui.slot ? `${T.book} · ${cur.fee ? fmt(cur.fee) : x(['મફત', 'Free'])}` : T.pickFirst}</Button>
      {st.myBookings.length > 0 && <>
        <Label>{T.myBookings}</Label>
        {st.myBookings.map(b => (
          <Card key={b.id} style={{ padding: '12px 14px', display: 'flex', gap: 10, alignItems: 'center' }}>
            <Icon name="IconCalendarCheck" size={18} style={{ flex: 'none' }} />
            <div style={{ flex: 1, fontSize: 14, fontWeight: 500 }}>{nameOf(b.amenity)} · {dayMonLocal(b.date, L)} · {b.slot}</div>
            <span style={{ fontSize: 13, fontWeight: 600 }}>{b.fee ? fmt(b.fee) : x(['મફત', 'Free'])}</span>
          </Card>
        ))}
      </>}
    </Stack>
  );
}

export function Parking() {
  const { st, T, x, toast, run, open } = useApp();
  const request = async () => {
    if (st.guestFree <= 0) return toast(x(['મહેમાન પાર્કિંગ ભરાઈ ગયું', 'Guest parking is full']));
    const r = await run(() => api<{ slot: string }>('POST', '/guest-parking'));
    if (r) toast(x(['મહેમાન પાર્કિંગ ', 'Guest slot ']) + r.slot + x([' ફાળવ્યું', ' allotted']));
  };
  return (
    <Stack gap={10}>
      {st.parking.map(p => (
        <Card key={p.id} style={{ padding: 14, display: 'flex', gap: 12, alignItems: 'center' }}>
          <div style={{ width: 56, height: 56, borderRadius: 6, background: C.ink, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 13, flex: 'none' }}>{p.slot}</div>
          <Stack gap={2} style={{ flex: 1 }}><div style={{ fontFamily: 'Menlo,ui-monospace,monospace', fontWeight: 700, fontSize: 15 }}>{p.vehicle}</div><div style={{ fontSize: 12, color: C.muted }}>{p.kind === 'car' ? T.car : T.twoWheeler}{p.location ? ` · ${p.location}` : ''}</div></Stack>
          <Icon name={p.kind === 'car' ? 'IconCar' : 'IconZap'} size={22} />
          <IconBtn name="IconX" label={T.remove} onClick={() => run(() => api('DELETE', `/vehicles/${p.id}`)).then(r => r && toast(T.deleted))} />
        </Card>
      ))}
      {!st.parking.length && <Card><Empty>{T.noParking}</Empty></Card>}
      {st.me.flat && <Button variant="outline" icon="IconPlus" style={wide} onClick={() => open('vehicle')}>{T.addVehicle}</Button>}
      <Card style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between' }}><span style={{ fontSize: 14, fontWeight: 600 }}>{T.guestParking}</span><span style={{ fontSize: 14, color: C.muted }}>{st.guestFree} / {st.guestTotal} {T.free}</span></div>
        <Progress value={(st.guestTotal - st.guestFree) / st.guestTotal * 100} />
        {st.me.flat && <Button variant="outline" style={wide} onClick={request}>{T.reqGuestParking}</Button>}
      </Card>
      <div style={{ fontSize: 13, color: C.muted, lineHeight: 1.5 }}>{T.parkRule}</div>
    </Stack>
  );
}
