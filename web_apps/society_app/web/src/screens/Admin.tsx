import { Button, Icon, Progress } from '../ds';
import { useApp } from '../ctx';
import { api } from '../lib/api';
import { CAT_ICON, CATS, MONTH_FULL } from '../lib/i18n';
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
        {role === 'treasurer' && <Button icon="IconBanknote" style={wide} onClick={() => open('cash')}>{T.recordCash}</Button>}
        <Button variant="outline" icon="IconBellRing" style={wide} onClick={remindAll}>{T.remindAll}</Button>
        <Button variant="outline" icon="IconDownload" style={wide} onClick={() => { const m = MONTH_FULL[Number(st.today.slice(5, 7)) - 1]; dl('/reports/monthly.pdf', 'report.pdf', x([`${m[0]} રિપોર્ટ PDF ડાઉનલોડ થયો`, `${m[1]} report PDF downloaded`])); }}>{T.reportPdf}</Button>
      </div>
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
      {role === 'treasurer' && <Button icon="IconUpload" style={wideTall} onClick={() => open('bill')}>{T.submitBill}</Button>}
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
            {role === 'treasurer' && <div style={{ fontSize: 12, fontWeight: 500, padding: '6px 10px', borderRadius: 6, background: C.soft }}>{T.awaitingSec}</div>}
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
