import { useState } from 'react';
import { Button, Icon, Input, Progress } from '../ds';
import { useApp } from '../ctx';
import { api } from '../lib/api';
import { CAT_ICON, CATS, MONTH_FULL, ROLES, type Role } from '../lib/i18n';
import { dayMon, fmt } from '../lib/format';
import { btnReset, C, Card, Empty, IconBox, Label, Lines, Row, Stack, wide, wideTall } from '../ui';
import { collectionLabel } from './common';

export function Reports() {
  const { st, T, x, L, role, open, toast, run, dl } = useApp();
  const fin = st.finance!;
  const pct = Math.round(fin.collected / fin.target * 100);
  const remindAll = async () => { if (await run(() => api('POST', '/reminders', {}))) toast(x(['બધા બાકીદારોને યાદી મોકલી', 'Reminders sent to all pending flats'])); };
  const remind = async (flat: string) => { if (await run(() => api('POST', '/reminders', { flat }))) toast(x(['WhatsApp અને SMS યાદી મોકલી: ', 'Reminder sent by WhatsApp & SMS: ']) + flat); };
  const split = [['UPI', fin.split.upi], [x(['કાર્ડ / નેટ', 'Card / Net']), fin.split.card], [x(['રોકડ', 'Cash']), fin.split.cash]] as const;

  return (
    <Stack gap={14}>
      <Card style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{ fontSize: 13, color: C.muted }}>{collectionLabel(st.today, L)}</div>
        <div style={{ fontSize: 28, fontWeight: 700, letterSpacing: -0.6 }}>{fmt(fin.collected)}<span style={{ fontSize: 14, color: C.muted, fontWeight: 500 }}> / {fmt(fin.target)}</span></div>
        <Progress value={pct} />
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 8, marginTop: 4 }}>
          {split.map(([label, amt]) => <Stack key={label} gap={2}><span style={{ fontSize: 12, color: C.muted }}>{label}</span><span style={{ fontSize: 14, fontWeight: 600 }}>{fmt(amt)}</span></Stack>)}
        </div>
      </Card>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
        <Button icon="IconBanknote" style={wide} onClick={() => open('cash')}>{T.recordPayment}</Button>
        <Button variant="outline" icon="IconReceipt" style={wide} onClick={() => open('charge')}>{T.raiseBill}</Button>
        <Button variant="outline" icon="IconBellRing" style={wide} onClick={remindAll}>{T.remindAll}</Button>
        <Button variant="outline" icon="IconDownload" style={wide} onClick={() => { const m = MONTH_FULL[Number(st.today.slice(5, 7)) - 1]; dl('/reports/monthly.pdf', 'report.pdf', x([`${m[0]} રિપોર્ટ PDF ડાઉનલોડ થયો`, `${m[1]} report PDF downloaded`])); }}>{T.reportPdf}</Button>
      </div>
      {fin.claims.length > 0 && <>
        <Label>{T.toVerify} ({fin.claims.length})</Label>
        {fin.claims.map(p => (
          <Card key={p.id} accent style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
              <Stack gap={2}><span style={{ fontSize: 14, fontWeight: 600 }}>{p.flat} · {p.by}</span><span style={{ fontSize: 12, color: C.muted }}>UPI · UTR {p.reference} · {dayMon(p.createdAt)}</span></Stack>
              <span style={{ fontSize: 15, fontWeight: 700, whiteSpace: 'nowrap' }}>{fmt(p.amount)}</span>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
              <Button variant="outline" style={wide} onClick={async () => { if (await run(() => api('POST', `/payments/${p.id}/decision`, { approve: false }))) toast(T.rejectedMsg); }}>{T.reject}</Button>
              <Button style={wide} onClick={async () => { if (await run(() => api('POST', `/payments/${p.id}/decision`, { approve: true }))) toast(T.paymentConfirmed); }}>{T.confirm}</Button>
            </div>
          </Card>
        ))}
      </>}
      <Label>{T.defaulters} ({fin.defaulters.length})</Label>
      <Card>
        {fin.defaulters.map(d => (
          <Row key={d.flat}>
            <div style={{ width: 52, fontWeight: 700, fontSize: 14, flex: 'none' }}>{d.flat}</div>
            <Stack gap={1} style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 500 }}>{d.name}</div>
              <div style={{ fontSize: 12, color: C.red, fontWeight: 500 }}>{fmt(d.amount)} · {d.months} {x(['મહિના', 'month' + (d.months > 1 ? 's' : '')])}</div>
            </Stack>
            <Button variant={d.reminded ? 'subtle' : 'outline'} onClick={() => remind(d.flat)}>{d.reminded ? T.reminded : T.remind}</Button>
          </Row>
        ))}
        {!fin.defaulters.length && <Empty>{T.noDefaulters}</Empty>}
      </Card>
    </Stack>
  );
}

export function Expenses() {
  const { st, T, x, role, open, toast, run, dl } = useApp();
  const fin = st.finance!;
  const max = Math.max(1, ...fin.monthByCategory.map(c => c.amount));
  const decide = async (id: number, approve: boolean) => {
    if (await run(() => api('POST', `/expenses/${id}/decision`, { approve })))
      toast(approve ? x(['મંજૂર – ચુકવણી માટે ખજાનચીને મોકલ્યું', 'Approved – sent to treasurer for payment']) : x(['બિલ નામંજૂર', 'Bill rejected']));
  };

  return (
    <Stack gap={14}>
      <Card style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}><span style={{ fontSize: 13, color: C.muted }}>{T.monthExpense}</span><span style={{ fontSize: 22, fontWeight: 700 }}>{fmt(fin.monthExpense)}</span></div>
        {fin.monthByCategory.map(c => (
          <Stack key={c.category} gap={4}>
            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13 }}><span>{x(CATS[c.category] ?? [c.category, c.category])}</span><span style={{ fontWeight: 600 }}>{fmt(c.amount)}</span></div>
            <div style={{ height: 6, borderRadius: 6, background: C.soft }}><div style={{ height: 6, borderRadius: 6, background: C.ink, width: Math.round(c.amount / max * 100) + '%' }} /></div>
          </Stack>
        ))}
      </Card>
      <Button icon="IconUpload" style={wideTall} onClick={() => open('bill')}>{T.submitBill}</Button>
      {fin.pending.length > 0 && <>
        <Label>{T.pendingApproval}</Label>
        {fin.pending.map(p => (
          <Card key={p.id} accent style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
              <Stack gap={2}><span style={{ fontSize: 14, fontWeight: 600 }}>{x([p.titleGu, p.titleEn])}</span><span style={{ fontSize: 12, color: C.muted }}>{x(CATS[p.category])} · {p.by} · {dayMon(p.date)}</span></Stack>
              <span style={{ fontSize: 15, fontWeight: 700, whiteSpace: 'nowrap' }}>{fmt(p.amount)}</span>
            </div>
            <button disabled={!p.hasFile} onClick={() => dl(`/expenses/${p.id}/attachment`, p.fileName ?? 'attachment', p.fileName ?? '')}
              style={{ ...btnReset, background: 'none', padding: 0, display: 'flex', gap: 6, alignItems: 'center', fontSize: 12, color: C.muted, cursor: p.hasFile ? 'pointer' : 'default', textDecoration: p.hasFile ? 'underline' : 'none' }}>
              <Icon name="IconFileImage" size={14} />{p.fileName ?? x(['જોડાણ નથી', 'No attachment'])}
            </button>
            {role === 'secretary' && (
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                <Button variant="outline" style={wide} onClick={() => decide(p.id, false)}>{T.reject}</Button>
                <Button style={wide} onClick={() => decide(p.id, true)}>{T.approve}</Button>
              </div>
            )}
            {role !== 'secretary' && <div style={{ fontSize: 12, fontWeight: 500, padding: '6px 10px', borderRadius: 6, background: C.soft }}>{T.awaitingSec}</div>}
          </Card>
        ))}
      </>}
      <Label>{T.allExpenses}</Label>
      <Card>
        {fin.expenses.map(e => (
          <Row key={e.id} style={{ gap: 12 }}>
            <IconBox name={CAT_ICON[e.category] ?? 'IconWrench'} box={36} size={18} />
            <Lines gap={1} titleWeight={500} title={x([e.titleGu, e.titleEn])} sub={`${dayMon(e.date)} · ${x(CATS[e.category] ?? [e.category, e.category])}`} />
            <div style={{ fontSize: 14, fontWeight: 600 }}>{fmt(e.amount)}</div>
          </Row>
        ))}
      </Card>
    </Stack>
  );
}

const roleName = (T: ReturnType<typeof useApp>['T'], r: Role) => ({ resident: T.resident, secretary: T.secretary, treasurer: T.treasurer, watchman: T.watchman })[r];

function RolePicker({ value, onChange, needsFlat }: { value: Role; onChange: (r: Role) => void; needsFlat: boolean }) {
  const { T } = useApp();
  return (
    <select className="sc-input sc-select" style={{ width: 'auto', padding: '6px 28px 6px 10px', fontSize: 13 }} value={value} onChange={e => onChange(e.target.value as Role)}>
      {ROLES.map(r => r.id).filter(r => r === 'watchman' || needsFlat).map(r => <option key={r} value={r}>{roleName(T, r)}</option>)}
    </select>
  );
}

export function MembersScreen() {
  const { st, T, toast, run } = useApp();
  const m = st.members!;
  const [roles, setRoles] = useState<Record<number, Role>>({});
  const decide = async (id: number, approve: boolean, role: Role) => {
    if (await run(() => api('POST', `/members/${id}/decision`, { approve, role }))) toast(approve ? T.approvedMsg : T.rejectedMsg);
  };
  return (
    <Stack gap={14}>
      <Label>{T.joinRequests} ({m.pending.length})</Label>
      {m.pending.map(p => {
        const role = roles[p.id] ?? p.role;
        return (
          <Card key={p.id} accent style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              <Lines title={p.name} sub={`${p.flat ?? T.asGuard}${p.flat ? ` · ${p.occupancy === 'tenant' ? T.tenant : T.owner}` : ''} · ${p.phone}`} />
              <RolePicker value={role} needsFlat={!!p.flat} onChange={r => setRoles({ ...roles, [p.id]: r })} />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
              <Button variant="outline" style={wide} onClick={() => decide(p.id, false, role)}>{T.reject}</Button>
              <Button style={wide} onClick={() => decide(p.id, true, role)}>{T.approve}</Button>
            </div>
          </Card>
        );
      })}
      {!m.pending.length && <Card><Empty>{T.noRequests}</Empty></Card>}
      <Label>{T.activeMembers} ({m.active.length})</Label>
      <Card>
        {m.active.map(a => (
          <Row key={a.id}>
            <Lines title={a.me ? `${a.name} (${T.you})` : a.name} sub={`${a.flat ?? T.asGuard} · ${a.phone}`} />
            <RolePicker value={a.role} needsFlat={!!a.flat} onChange={r => run(() => api('PUT', `/members/${a.id}`, { role: r })).then(x => x && toast(T.saved))} />
            {!a.me && <button aria-label={T.remove} className="hov" onClick={() => { if (confirm(`${T.remove}: ${a.name}?`)) run(() => api('DELETE', `/members/${a.id}`)).then(x => x && toast(T.deleted)); }}
              style={{ ...btnReset, width: 32, height: 32, borderRadius: 6, background: 'transparent', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none' }}><Icon name="IconX" size={16} /></button>}
          </Row>
        ))}
      </Card>
    </Stack>
  );
}

export function SettingsScreen() {
  const { st, T, x, role, toast, run } = useApp();
  const s = st.society;
  const [f, setF] = useState({ name: s.en, nameGu: s.gu === s.en ? '' : s.gu, city: s.cityEn, address: s.address, maintenance: String(s.maintenance ?? ''), dueDay: String(s.dueDay ?? 10), upiId: s.upiId, guestParking: String(s.guestParking ?? 10) });
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF({ ...f, [k]: e.target.value });
  const canEdit = role === 'secretary';
  const shareText = `${T.shareText}${s.code}`;
  const share = async () => {
    try { if (navigator.share) { await navigator.share({ text: shareText }); return; } } catch { return; }
    window.open(`https://wa.me/?text=${encodeURIComponent(shareText)}`, '_blank');
  };
  return (
    <Stack gap={14}>
      <div style={{ background: C.ink, color: '#fff', borderRadius: 6, padding: 18, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{ fontSize: 13, color: '#cbd5e1' }}>{T.societyCode}</div>
        <div style={{ fontSize: 32, fontWeight: 700, letterSpacing: 6, fontFamily: 'Menlo,ui-monospace,monospace' }}>{s.code}</div>
        <div style={{ fontSize: 12, color: '#cbd5e1' }}>{T.joinSub}</div>
        <button onClick={share} style={{ ...btnReset, height: 42, borderRadius: 6, background: '#fff', fontSize: 14, fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
          <Icon name="IconUsers" size={16} />{T.shareCode}
        </button>
      </div>
      <fieldset disabled={!canEdit} style={{ border: 0, padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <Input label={T.societyName} value={f.name} onChange={set('name')} style={wide} />
        <Input label={T.societyNameGu} value={f.nameGu} onChange={set('nameGu')} style={wide} />
        <Input label={T.city} value={f.city} onChange={set('city')} style={wide} />
        <Input label={T.address} value={f.address} onChange={set('address')} style={wide} />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <Input label={T.maintenanceAmt} inputMode="numeric" value={f.maintenance} onChange={set('maintenance')} style={wide} />
          <Input label={T.dueDay} inputMode="numeric" value={f.dueDay} onChange={set('dueDay')} style={wide} />
        </div>
        <Input label={T.upiId} autoCapitalize="none" placeholder="society@sbi" value={f.upiId} onChange={set('upiId')} style={wide} />
        <div style={{ fontSize: 12, color: C.muted, marginTop: -8 }}>{T.upiIdHint}</div>
        <Input label={T.guestSlots} inputMode="numeric" value={f.guestParking} onChange={set('guestParking')} style={wide} />
        {canEdit && <Button style={wideTall} onClick={() => run(() => api('PUT', '/society', f)).then(r => r && toast(T.saved))}>{T.save}</Button>}
      </fieldset>
      <div style={{ fontSize: 12, color: C.muted, lineHeight: 1.5 }}>{x(['નવો મેન્ટેનન્સ દર આવતા મહિનાના બિલથી લાગુ થશે.', 'A new maintenance amount applies from next month’s bills.'])}</div>
    </Stack>
  );
}
