import { useRef, useState } from 'react';
import { Button, Icon, Input, Switch, Textarea } from './ds';
import { useApp, type Sheet } from './ctx';
import { api } from './lib/api';
import { CATS, COMP_CATS, PURPOSES, SOS_TYPES } from './lib/i18n';
import { addDays, dayMonYear, fmt } from './lib/format';
import { btnReset, C, Chip, Chips, FieldLabel, pill, ring, Stack, wide, wideTall } from './ui';

const METHOD_NAME = { upi: 'UPI', card: 'Card', net: 'Net banking' } as const;

export function SheetHost() {
  const { ui, x, T, close } = useApp();
  if (!ui.sheet) return null;
  const titles: Record<Sheet, string> = {
    pay: x(['ચુકવણી', 'Checkout']), receipt: T.success, sos: x(['ઇમરજન્સી SOS', 'Emergency SOS']), pass: T.gatePass, complaint: T.raiseComplaint,
    visitor: T.newEntry, notice: T.postNotice, bill: x(['બિલ જમા કરો', 'Submit a bill']), cash: T.recordPayment, upi: T.payUpi,
    charge: T.raiseBill, event: T.newEvent, poll: T.newPoll, staff: T.addStaff, vehicle: T.addVehicle, contact: T.addContact, doc: T.uploadDoc,
  };
  const Body = {
    pay: PaySheet, receipt: ReceiptSheet, sos: SosSheet, pass: PassSheet, complaint: ComplaintSheet, visitor: VisitorSheet, notice: NoticeSheet, bill: BillSheet,
    cash: RecordPaymentSheet, upi: UpiSheet, charge: ChargeSheet, event: EventSheet, poll: PollSheet, staff: StaffSheet, vehicle: VehicleSheet, contact: ContactSheet, doc: DocSheet,
  }[ui.sheet];
  return (
    <>
      <div onClick={close} style={{ position: 'absolute', inset: 0, background: 'rgba(15,23,42,.45)', zIndex: 40 }} />
      <div role="dialog" aria-modal="true" aria-label={titles[ui.sheet]} className="sheet"
        style={{ position: 'absolute', left: 0, right: 0, bottom: 0, maxHeight: '86%', overflowY: 'auto', background: '#fff', borderRadius: '16px 16px 0 0', padding: '10px 20px 40px', zIndex: 41, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div style={{ width: 40, height: 4, borderRadius: 4, background: C.line, alignSelf: 'center' }} />
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ fontSize: 18, fontWeight: 700 }}>{titles[ui.sheet]}</div>
          <button aria-label="Close" onClick={close} style={{ ...btnReset, width: 32, height: 32, borderRadius: 6, background: C.soft, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="IconX" size={16} /></button>
        </div>
        <Body />
      </div>
    </>
  );
}

/** Dashed attach button backed by a real file input (opens the camera on phones when `capture` is set). */
function Attach({ icon, label, attachedLabel, accept, capture, height = 56 }: { icon: string; label: string; attachedLabel: (name: string) => string; accept: string; capture?: boolean; height?: number }) {
  const { ui, set } = useApp();
  const ref = useRef<HTMLInputElement>(null);
  return (
    <>
      <input ref={ref} type="file" hidden accept={accept} capture={capture ? 'environment' : undefined} onChange={e => set({ file: e.target.files?.[0] ?? null })} />
      <button onClick={() => ref.current?.click()}
        style={{ ...btnReset, height, borderRadius: 6, boxShadow: ring('#cbd5e1'), background: '#f8fafc', color: C.body, fontSize: 13, display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'center', padding: '0 12px' }}>
        <Icon name={icon} size={height > 56 ? 20 : 18} style={{ flex: 'none' }} />
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{ui.file ? attachedLabel(ui.file.name) : label}</span>
      </button>
    </>
  );
}

const form = (fields: Record<string, string | Blob | null | undefined>) => {
  const fd = new FormData();
  for (const [k, v] of Object.entries(fields)) if (v != null) fd.append(k, v);
  return fd;
};

function PaySheet() {
  const { st, T, x, ui, set, run } = useApp();
  const sel = st.bills.filter(b => !b.paid && !b.claimed && !ui.unselected.includes(b.id));
  const total = sel.reduce((a, b) => a + b.amount, 0);
  const methods = [['upi', 'IconSmartphone', 'UPI', 'Google Pay · PhonePe · Paytm · BHIM'], ['card', 'IconCreditCard', x(['ડેબિટ / ક્રેડિટ કાર્ડ', 'Debit / credit card']), 'Visa · Mastercard · RuPay'],
    ['net', 'IconLandmark', x(['નેટ બેંકિંગ', 'Net banking']), 'SBI · HDFC · ICICI · BoB']] as const;
  const pay = async () => {
    if (ui.paying || !sel.length) return;
    set({ paying: true });
    const r = await run(() => api<{ payment: { id: number; receiptNo: string; amount: number; method: keyof typeof METHOD_NAME; createdAt: string; time: string } }>('POST', '/bills/pay', { billIds: sel.map(b => b.id), method: ui.payMethod }));
    set(r ? { paying: false, sheet: 'receipt', unselected: [], receipt: { id: r.payment.id, amt: r.payment.amount, no: r.payment.receiptNo, via: METHOD_NAME[r.payment.method], time: r.payment.time, date: r.payment.createdAt } } : { paying: false });
  };
  return (
    <Stack gap={14}>
      <div style={{ display: 'flex', justifyContent: 'space-between', padding: 14, borderRadius: 6, background: C.soft }}><span style={{ fontSize: 14 }}>{sel.length} {T.billsSel}</span><span style={{ fontSize: 18, fontWeight: 700 }}>{fmt(total)}</span></div>
      <FieldLabel><span style={{ fontSize: 13, fontWeight: 600, color: C.muted }}>{T.payMethod}</span></FieldLabel>
      {methods.map(([id, icon, label, sub]) => {
        const on = ui.payMethod === id;
        return (
          <button key={id} role="radio" aria-checked={on} onClick={() => set({ payMethod: id })}
            style={{ ...btnReset, background: '#fff', boxShadow: ring(on ? C.ink : C.line, on ? '2px' : '1px'), borderRadius: 6, padding: 14, display: 'flex', gap: 12, alignItems: 'center', textAlign: 'left' }}>
            <Icon name={icon} size={20} style={{ flex: 'none' }} />
            <Stack gap={1} style={{ flex: 1 }}><span style={{ fontSize: 14, fontWeight: 600 }}>{label}</span><span style={{ fontSize: 12, color: C.muted }}>{sub}</span></Stack>
            <div style={{ width: 18, height: 18, borderRadius: 18, boxShadow: `inset 0 0 0 ${on ? '5px' : '1.5px'} ${C.ink}`, flex: 'none' }} />
          </button>
        );
      })}
      <Button onClick={pay} loading={ui.paying} style={wideTall}>{ui.paying ? x(['પ્રક્રિયા ચાલુ છે…', 'Processing…']) : `${T.pay} ${fmt(total)}`}</Button>
      <div style={{ fontSize: 12, color: C.muted, textAlign: 'center', display: 'flex', gap: 6, justifyContent: 'center', alignItems: 'center' }}><Icon name="IconLock" size={12} />{T.secure}</div>
    </Stack>
  );
}

function ReceiptSheet() {
  const { st, T, x, ui, close, dl } = useApp();
  const r = ui.receipt;
  if (!r) return null;
  const lines = [[x(['રસીદ નં.', 'Receipt no.']), r.no], [x(['ફ્લેટ', 'Flat']), st.me.flat ?? '—'], [x(['પદ્ધતિ', 'Method']), r.via], [x(['તારીખ', 'Date']), `${dayMonYear(r.date)}, ${r.time}`]];
  return (
    <Stack gap={14} style={{ alignItems: 'center', textAlign: 'center' }}>
      <div style={{ width: 64, height: 64, borderRadius: 64, background: C.ink, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="IconCheck" size={32} /></div>
      <div style={{ fontSize: 28, fontWeight: 700 }}>{fmt(r.amt)}</div>
      <div style={{ width: '100%', borderRadius: 6, boxShadow: ring(), textAlign: 'left' }}>
        {lines.map(([k, v]) => <div key={k} style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 14px', borderBottom: `1px solid ${C.soft}`, fontSize: 13 }}><span style={{ color: C.muted }}>{k}</span><span style={{ fontWeight: 600 }}>{v}</span></div>)}
      </div>
      <div style={{ width: '100%', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
        <Button variant="outline" icon="IconDownload" style={wide} onClick={() => dl(`/payments/${r.id}/receipt.pdf`, `${r.no}.pdf`, x(['રસીદ PDF ડાઉનલોડ થઈ', 'Receipt PDF downloaded']))}>{T.receiptPdf}</Button>
        <Button style={wide} onClick={close}>{T.done}</Button>
      </div>
    </Stack>
  );
}

function SosSheet() {
  const { st, T, x, ui, set, run, toast } = useApp();
  const guard = st.directory.find(d => d.grp === 'emergency' && d.initials === 'BR') ?? st.directory.find(d => d.grp === 'emergency');
  const send = async () => { if (await run(() => api('POST', '/sos', { type: ui.sosType }))) set({ sosSent: true }); };
  if (ui.sosSent) return (
    <Stack gap={12} style={{ alignItems: 'center', textAlign: 'center', padding: '8px 0' }}>
      <div style={{ width: 64, height: 64, borderRadius: 64, background: C.red, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="IconSiren" size={30} /></div>
      <div style={{ fontSize: 16, fontWeight: 700 }}>{T.alertSent}</div>
      <div style={{ fontSize: 13, color: C.muted, lineHeight: 1.5 }}>{T.alertSentSub}</div>
      <a href={guard ? `tel:${guard.phone}` : undefined} onClick={() => toast(x(['કૉલ થઈ રહ્યો છે: ભીખાભાઈ (ગેટ)', 'Calling Bhikhabhai (gate)']))}
        className="sc-btn sc-btn--outline" style={{ ...wide, boxSizing: 'border-box' }}>{T.callGuard}</a>
    </Stack>
  );
  return (
    <Stack gap={14}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
        {SOS_TYPES.map(([id, icon, label]) => {
          const on = ui.sosType === id;
          return (
            <button key={id} aria-pressed={on} onClick={() => set({ sosType: id })}
              style={{ ...btnReset, borderRadius: 6, padding: 14, display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'flex-start', background: on ? C.red : '#fff', color: on ? '#fff' : C.ink, boxShadow: ring() }}>
              <Icon name={icon} size={20} /><span style={{ fontSize: 14, fontWeight: 600 }}>{x(label)}</span>
            </button>
          );
        })}
      </div>
      <button onClick={send} style={{ ...btnReset, height: 56, borderRadius: 6, background: C.red, color: '#fff', fontSize: 16, fontWeight: 700 }}>{T.sendAlert}</button>
      <div style={{ fontSize: 12, color: C.muted, textAlign: 'center' }}>{T.sosNote}</div>
    </Stack>
  );
}

function PassSheet() {
  const { T, x, ui, set, setF, run, toast } = useApp();
  const create = async () => {
    const r = await run(() => api<{ code: string }>('POST', '/passes', { name: ui.f.passName.trim(), when: ui.f.passWhen }));
    if (r) { set(u => ({ sheet: null, f: { ...u.f, passName: '' } })); toast(x(['પાસ બન્યો અને મહેમાનને મોકલ્યો: ', 'Pass created and shared: ']) + r.code); }
  };
  return (
    <Stack gap={14}>
      <Input label={T.guestName} placeholder="Kiran Shah" value={ui.f.passName} onChange={e => setF('passName', e.target.value)} style={wide} />
      <div style={{ display: 'flex', gap: 8 }}>
        {([['today', T.today], ['tomorrow', T.tomorrow]] as const).map(([id, label]) => (
          <button key={id} aria-pressed={ui.f.passWhen === id} onClick={() => setF('passWhen', id)}
            style={{ ...btnReset, flex: 1, height: 40, borderRadius: 6, fontSize: 14, fontWeight: 600, boxShadow: ring(), ...pill(ui.f.passWhen === id) }}>{label}</button>
        ))}
      </div>
      <Button onClick={create} style={wideTall}>{T.generate}</Button>
    </Stack>
  );
}

function ComplaintSheet() {
  const { T, x, ui, set, setF, run, toast } = useApp();
  const submit = async () => {
    if (!ui.f.comp.trim()) return toast(x(['વિગત લખો', 'Add a short description']));
    const r = await run(() => api<{ code: string }>('POST', '/complaints', form({ category: ui.f.compCat, text: ui.f.comp.trim(), photo: ui.file })));
    if (r) { set(u => ({ sheet: null, f: { ...u.f, comp: '' } })); toast(x(['ફરિયાદ નોંધાઈ: ', 'Complaint logged: ']) + r.code); }
  };
  return (
    <Stack gap={14}>
      <FieldLabel>{T.category}</FieldLabel>
      <Chips>{COMP_CATS.map(([id, label]) => <Chip key={id} on={ui.f.compCat === id} onClick={() => setF('compCat', id)}>{x(label)}</Chip>)}</Chips>
      <Textarea label={T.describe} placeholder={T.describePh} value={ui.f.comp} onChange={e => setF('comp', e.target.value)} style={wide} />
      <Attach icon="IconCamera" label={T.photoAdd} accept="image/*" capture attachedLabel={n => x(['ફોટો જોડ્યો: ', 'Photo attached: ']) + n} />
      <Button onClick={submit} style={wideTall}>{T.submit}</Button>
    </Stack>
  );
}

function VisitorSheet() {
  const { T, x, ui, set, setF, run, toast } = useApp();
  const submit = async () => {
    const flat = (ui.f.vFlat.trim() || 'B-304').toUpperCase();
    const name = ui.f.vName.trim() || 'Visitor';
    const r = await run(() => api<{ id: number; autoApprove: boolean }>('POST', '/visitors', form({ name, flat, purpose: ui.f.vP, photo: ui.file })));
    if (!r) return;
    set(u => ({ sheet: null, f: { ...u.f, vName: '', vFlat: '' } }));
    toast(x(['મંજૂરી માટે મોકલ્યું: ', 'Approval request sent to ']) + flat);
    if (r.autoApprove) setTimeout(() => toast(x(['સભ્યે મંજૂરી આપી: ', 'Resident approved: ']) + name), 3200);
  };
  return (
    <Stack gap={14}>
      <Input label={T.visitorName} placeholder="Ramesh Kumar" value={ui.f.vName} onChange={e => setF('vName', e.target.value)} style={wide} />
      <Input label={T.flatNo} placeholder="B-304" value={ui.f.vFlat} onChange={e => setF('vFlat', e.target.value)} autoCapitalize="characters" style={wide} />
      <FieldLabel>{T.purpose}</FieldLabel>
      <Chips>{PURPOSES.map(([id, label]) => <Chip key={id} on={ui.f.vP === id} onClick={() => setF('vP', id)}>{x(label)}</Chip>)}</Chips>
      <Attach icon="IconCamera" label={T.photo} accept="image/*" capture attachedLabel={() => x(['ફોટો લીધો ✓', 'Photo captured ✓'])} />
      <Button onClick={submit} style={wideTall}>{T.sendApproval}</Button>
    </Stack>
  );
}

function NoticeSheet() {
  const { T, x, ui, set, setF, run, toast } = useApp();
  const submit = async () => {
    if (!ui.f.nTitle.trim()) return toast(x(['શીર્ષક લખો', 'Add a title']));
    const r = await run(() => api<{ flats: number }>('POST', '/notices', { title: ui.f.nTitle.trim(), body: ui.f.nBody.trim(), pinned: ui.f.nPin }));
    if (r) { set(u => ({ sheet: null, f: { ...u.f, nTitle: '', nBody: '', nPin: false } })); toast(x([`નોટિસ ${r.flats} ફ્લેટને મોકલાઈ`, `Notice sent to ${r.flats} flats`])); }
  };
  return (
    <Stack gap={14}>
      <Input label={T.titleLbl} value={ui.f.nTitle} onChange={e => setF('nTitle', e.target.value)} style={wide} />
      <Textarea label={T.message} value={ui.f.nBody} onChange={e => setF('nBody', e.target.value)} style={wide} />
      <Switch label={T.markImportant} checked={ui.f.nPin} onChange={v => setF('nPin', v)} />
      <Button onClick={submit} style={wideTall}>{T.publish}</Button>
    </Stack>
  );
}

function BillSheet() {
  const { T, x, ui, set, setF, run, toast } = useApp();
  const submit = async () => {
    const amount = parseInt(ui.f.bAmt.replace(/\D/g, ''), 10);
    if (!amount) return toast(x(['રકમ લખો', 'Enter an amount']));
    const vendor = ui.f.bVendor.trim() || 'Torrent Power – common light';
    const r = await run(() => api('POST', '/expenses', form({ vendor, amount: String(amount), category: ui.f.bCat, file: ui.file })));
    if (r) { set(u => ({ sheet: null, f: { ...u.f, bVendor: '', bAmt: '' } })); toast(x(['બિલ સેક્રેટરીને મંજૂરી માટે મોકલ્યું', 'Bill sent to the secretary for approval'])); }
  };
  return (
    <Stack gap={14}>
      <Input label={T.vendor} placeholder="Torrent Power" value={ui.f.bVendor} onChange={e => setF('bVendor', e.target.value)} style={wide} />
      <Input label={T.amount} placeholder="18450" value={ui.f.bAmt} onChange={e => setF('bAmt', e.target.value)} inputMode="numeric" style={wide} />
      <FieldLabel>{T.category}</FieldLabel>
      <Chips>{Object.keys(CATS).map(k => <Chip key={k} on={ui.f.bCat === k} onClick={() => setF('bCat', k)}>{x(CATS[k])}</Chip>)}</Chips>
      <Attach icon="IconUploadCloud" label={T.attach} accept="image/*,application/pdf" height={64} attachedLabel={n => x(['જોડ્યું: ', 'Attached: ']) + n + ' ✓'} />
      <Button onClick={submit} style={wideTall}>{T.sendForApproval}</Button>
    </Stack>
  );
}

/** Shared submit for the simple create sheets: runs the call, closes the sheet and toasts. */
function useSubmit() {
  const { set, run, toast } = useApp();
  const [busy, setBusy] = useState(false);
  return { busy, submit: async (fn: () => Promise<unknown>, ok: string) => {
    if (busy) return;
    setBusy(true);
    const r = await run(fn);
    setBusy(false);
    if (r !== undefined) { set({ sheet: null }); toast(ok); }
  } };
}

function RecordPaymentSheet() {
  const { st, T, x } = useApp();
  const due = st.finance?.dueFlats ?? [];
  const [flat, setFlat] = useState('');
  const [method, setMethod] = useState<'cash' | 'upi' | 'cheque' | 'bank'>('cash');
  const [reference, setReference] = useState('');
  const { busy, submit } = useSubmit();
  const cur = due.find(d => d.flat === flat);
  if (!due.length) return <div style={{ fontSize: 14, color: C.muted }}>{T.nothingDue}</div>;
  return (
    <Stack gap={14}>
      <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        <span className="sc-field-label">{T.flatNo}</span>
        <select className="sc-input sc-select" value={flat} onChange={e => setFlat(e.target.value)}>
          <option value="">{T.pickFlat}</option>
          {due.map(d => <option key={d.flat} value={d.flat}>{d.flat}{d.name ? ` · ${d.name}` : ''} · {fmt(d.amount)}</option>)}
        </select>
      </label>
      <FieldLabel>{T.method}</FieldLabel>
      <Chips>{([['cash', T.cash], ['upi', 'UPI'], ['cheque', T.cheque], ['bank', T.bank]] as const).map(([m, l]) => <Chip key={m} on={method === m} onClick={() => setMethod(m)}>{l}</Chip>)}</Chips>
      {method !== 'cash' && <Input label={T.reference} value={reference} onChange={e => setReference(e.target.value)} style={wide} />}
      <div style={{ display: 'flex', justifyContent: 'space-between', padding: 14, borderRadius: 6, background: C.soft }}><span style={{ fontSize: 14 }}>{T.amount}</span><span style={{ fontSize: 18, fontWeight: 700 }}>{cur ? fmt(cur.amount) : '—'}</span></div>
      <Button icon="IconBanknote" loading={busy} disabled={!cur} style={{ ...wideTall, opacity: cur ? 1 : 0.5 }}
        onClick={() => cur && submit(() => api('POST', '/payments/record', { flat: cur.flat, method, reference }), x(['ચુકવણી નોંધાઈ, રસીદ બની: ', 'Payment recorded, receipt issued: ']) + cur.flat)}>{T.recordIssue}</Button>
    </Stack>
  );
}

/** Resident pays the society's UPI ID in their own UPI app, then submits the UTR for the treasurer to confirm. */
function UpiSheet() {
  const { st, T, x, ui, set } = useApp();
  const sel = st.bills.filter(b => !b.paid && !b.claimed && !ui.unselected.includes(b.id));
  const total = sel.reduce((a, b) => a + b.amount, 0);
  const [utr, setUtr] = useState('');
  const { busy, submit } = useSubmit();
  if (!st.society.upiId) return <div style={{ fontSize: 14, color: C.body, lineHeight: 1.6 }}>{T.noUpi}</div>;
  const note = `${st.me.flat} ${sel.length === 1 ? sel[0].titleEn : 'maintenance'}`.slice(0, 50);
  const link = `upi://pay?pa=${encodeURIComponent(st.society.upiId)}&pn=${encodeURIComponent(st.society.en)}&am=${total.toFixed(2)}&cu=INR&tn=${encodeURIComponent(note)}`;
  return (
    <Stack gap={14}>
      <div style={{ display: 'flex', justifyContent: 'space-between', padding: 14, borderRadius: 6, background: C.soft }}><span style={{ fontSize: 14 }}>{sel.length} {T.billsSel}</span><span style={{ fontSize: 18, fontWeight: 700 }}>{fmt(total)}</span></div>
      <FieldLabel>{T.upiStep1}</FieldLabel>
      <div style={{ fontSize: 14, display: 'flex', justifyContent: 'space-between', gap: 8 }}><span style={{ color: C.muted }}>UPI ID</span><b style={{ fontFamily: 'Menlo,ui-monospace,monospace' }}>{st.society.upiId}</b></div>
      <a href={link} className="sc-btn" style={{ ...wideTall, boxSizing: 'border-box' }}><Icon name="IconSmartphone" size={16} />{T.openUpi} · {fmt(total)}</a>
      <FieldLabel>{T.upiStep2}</FieldLabel>
      <Input label={T.utr} inputMode="text" autoCapitalize="characters" placeholder="412345678901" value={utr} onChange={e => setUtr(e.target.value.replace(/\s/g, ''))} style={wide} />
      <Button loading={busy} disabled={!sel.length} style={wideTall}
        onClick={() => submit(async () => { const r = await api('POST', '/bills/claim', { billIds: sel.map(b => b.id), reference: utr }); set({ unselected: [] }); return r; }, T.claimSent)}>{T.iPaid}</Button>
      <div style={{ fontSize: 12, color: C.muted, textAlign: 'center' }}>{x(['ખજાનચી બેંકમાં ચકાસીને પુષ્ટિ કરશે, પછી રસીદ મળશે.', 'The treasurer checks the bank statement and confirms; you then get a receipt.'])}</div>
    </Stack>
  );
}

function ChargeSheet() {
  const { st, T } = useApp();
  const [f, setF] = useState({ title: '', amount: '', dueDate: addDays(st.today, 15), target: 'all', flat: '' });
  const { busy, submit } = useSubmit();
  const flats = (st.finance?.dueFlats ?? []).map(d => d.flat);
  return (
    <Stack gap={14}>
      <Input label={T.titleLbl} placeholder="Water tanker share" value={f.title} onChange={e => setF({ ...f, title: e.target.value })} style={wide} />
      <Input label={T.amount} inputMode="numeric" value={f.amount} onChange={e => setF({ ...f, amount: e.target.value })} style={wide} />
      <Input label={T.dueDate} type="date" min={st.today} value={f.dueDate} onChange={e => setF({ ...f, dueDate: e.target.value })} style={wide} />
      <Chips>
        <Chip on={f.target === 'all'} onClick={() => setF({ ...f, target: 'all' })}>{T.allFlats} ({st.society.totalFlats})</Chip>
        <Chip on={f.target === 'one'} onClick={() => setF({ ...f, target: 'one' })}>{T.oneFlat}</Chip>
      </Chips>
      {f.target === 'one' && <Input label={T.flatNo} placeholder={flats[0] ?? 'A-101'} autoCapitalize="characters" value={f.flat} onChange={e => setF({ ...f, flat: e.target.value.toUpperCase() })} style={wide} />}
      <Button loading={busy} style={wideTall} onClick={() => submit(async () => {
        const r = await api<{ count: number }>('POST', '/bills', { title: f.title, amount: f.amount, dueDate: f.dueDate, flat: f.target === 'one' ? f.flat : 'all' });
        return r;
      }, `${T.billRaised}${f.target === 'one' ? f.flat : st.society.totalFlats}`)}>{T.raiseBill}</Button>
    </Stack>
  );
}

function EventSheet() {
  const { st, T } = useApp();
  const [f, setF] = useState({ title: '', date: addDays(st.today, 7), when: '', place: '' });
  const { busy, submit } = useSubmit();
  return (
    <Stack gap={14}>
      <Input label={T.eventTitle} value={f.title} onChange={e => setF({ ...f, title: e.target.value })} style={wide} />
      <Input label={T.eventDate} type="date" min={st.today} value={f.date} onChange={e => setF({ ...f, date: e.target.value })} style={wide} />
      <Input label={T.eventTime} placeholder="7 pm" value={f.when} onChange={e => setF({ ...f, when: e.target.value })} style={wide} />
      <Input label={T.eventPlace} placeholder="Clubhouse" value={f.place} onChange={e => setF({ ...f, place: e.target.value })} style={wide} />
      <Button loading={busy} style={wideTall} onClick={() => submit(() => api('POST', '/events', f), T.added)}>{T.publish}</Button>
    </Stack>
  );
}

function PollSheet() {
  const { st, T } = useApp();
  const [q, setQ] = useState('');
  const [opts, setOpts] = useState(['', '']);
  const [ends, setEnds] = useState(addDays(st.today, 7));
  const { busy, submit } = useSubmit();
  return (
    <Stack gap={14}>
      <Textarea label={T.question} value={q} onChange={e => setQ(e.target.value)} style={wide} />
      {opts.map((o, i) => <Input key={i} label={`${T.option} ${i + 1}`} value={o} onChange={e => setOpts(opts.map((v, j) => j === i ? e.target.value : v))} style={wide} />)}
      {opts.length < 6 && <Button variant="outline" icon="IconPlus" style={wide} onClick={() => setOpts([...opts, ''])}>{T.addOption}</Button>}
      <Input label={T.pollEnds} type="date" min={st.today} value={ends} onChange={e => setEnds(e.target.value)} style={wide} />
      <Button loading={busy} style={wideTall} onClick={() => submit(() => api('POST', '/polls', { question: q, options: opts, endsOn: ends }), T.added)}>{T.publish}</Button>
    </Stack>
  );
}

function StaffSheet() {
  const { T } = useApp();
  const [f, setF] = useState({ name: '', role: '', flats: '' });
  const { busy, submit } = useSubmit();
  return (
    <Stack gap={14}>
      <Input label={T.nameLbl} value={f.name} onChange={e => setF({ ...f, name: e.target.value })} style={wide} />
      <Input label={T.staffRole} value={f.role} onChange={e => setF({ ...f, role: e.target.value })} style={wide} />
      <Input label={T.staffFlats} placeholder="B-304, B-305" value={f.flats} onChange={e => setF({ ...f, flats: e.target.value })} style={wide} />
      <Button loading={busy} style={wideTall} onClick={() => submit(() => api('POST', '/staff', f), T.added)}>{T.addStaff}</Button>
    </Stack>
  );
}

function VehicleSheet() {
  const { T } = useApp();
  const [f, setF] = useState({ vehicle: '', slot: '', kind: 'car', location: '' });
  const { busy, submit } = useSubmit();
  return (
    <Stack gap={14}>
      <Input label={T.vehicleNo} placeholder="GJ 01 AB 1234" autoCapitalize="characters" value={f.vehicle} onChange={e => setF({ ...f, vehicle: e.target.value })} style={wide} />
      <Chips>
        <Chip on={f.kind === 'car'} onClick={() => setF({ ...f, kind: 'car' })}>{T.car}</Chip>
        <Chip on={f.kind === 'two'} onClick={() => setF({ ...f, kind: 'two' })}>{T.twoWheeler}</Chip>
      </Chips>
      <Input label={T.parkingSlot} placeholder="B-P12" autoCapitalize="characters" value={f.slot} onChange={e => setF({ ...f, slot: e.target.value })} style={wide} />
      <Input label={T.location} placeholder="Basement 1" value={f.location} onChange={e => setF({ ...f, location: e.target.value })} style={wide} />
      <Button loading={busy} style={wideTall} onClick={() => submit(() => api('POST', '/vehicles', f), T.added)}>{T.addVehicle}</Button>
    </Stack>
  );
}

function ContactSheet() {
  const { T } = useApp();
  const [f, setF] = useState({ name: '', phone: '', role: '' });
  const { busy, submit } = useSubmit();
  return (
    <Stack gap={14}>
      <Input label={T.nameLbl} value={f.name} onChange={e => setF({ ...f, name: e.target.value })} style={wide} />
      <Input label={T.phoneLbl} type="tel" inputMode="tel" value={f.phone} onChange={e => setF({ ...f, phone: e.target.value })} style={wide} />
      <Input label={T.contactRole} value={f.role} onChange={e => setF({ ...f, role: e.target.value })} style={wide} />
      <Button loading={busy} style={wideTall} onClick={() => submit(() => api('POST', '/contacts', f), T.added)}>{T.addContact}</Button>
    </Stack>
  );
}

function DocSheet() {
  const { T, ui, set } = useApp();
  const [name, setName] = useState('');
  const { busy, submit } = useSubmit();
  return (
    <Stack gap={14}>
      <Input label={T.docName} value={name} onChange={e => setName(e.target.value)} style={wide} />
      <Attach icon="IconUploadCloud" label={T.chooseFile} accept="application/pdf,image/*" height={64} attachedLabel={n => n + ' ✓'} />
      <Button loading={busy} style={wideTall} onClick={() => submit(async () => { const r = await api('POST', '/documents', form({ name, file: ui.file })); set({ file: null }); return r; }, T.added)}>{T.uploadDoc}</Button>
    </Stack>
  );
}
