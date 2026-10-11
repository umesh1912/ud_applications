import { Avatar, Button, Icon, Input, Progress } from '../ds';
import { useApp } from '../ctx';
import { api } from '../lib/api';
import { COMP_CATS, WING_GU } from '../lib/i18n';
import { dayMon, dayMonYear, fmt, monUpper } from '../lib/format';
import { btnReset, C, Card, IconBox, Label, Lines, ring, Stack, wide } from '../ui';
import { collectionLabel, firstName, initials, purposeLabel, useVisitorText, VisitorBadge } from './common';

const tileStyle = { ...btnReset, background: '#fff', boxShadow: ring(), borderRadius: 6 } as const;

export function ResidentHome() {
  const { st, T, x, L, go, set, toast, run } = useApp();
  const vt = useVisitorText();
  const due = st.bills.filter(b => !b.paid);
  const dueTotal = due.reduce((a, b) => a + b.amount, 0);
  const dueBy = due.map(b => b.due).sort()[0];
  const wing = st.me.flat?.[0] ?? '';
  const approval = st.visitors.find(v => v.status === 'waiting');
  const notice = st.notices[0];
  const event = st.events.find(e => e.startsOn >= st.today) ?? st.events[0];
  const community = (commTab: 'notices' | 'events' | 'polls') => set({ screen: 'community', commTab });

  const decide = async (approve: boolean) => {
    if (!approval) return;
    if (await run(() => api('POST', `/visitors/${approval.id}/decision`, { approve })))
      toast(approve ? x(['મંજૂરી આપી – ગેટ પર જાણ કરી', 'Approved – gate notified']) : x(['પ્રવેશ નામંજૂર', 'Entry denied']));
  };

  const tiles: [string, string, () => void][] = [
    ['IconReceipt', T.bills, () => go('bills')], ['IconTicket', T.gatePass, () => go('gate')], ['IconWrench', T.complaints, () => go('complaints')],
    ['IconCalendarDays', x(['બુકિંગ', 'Booking']), () => go('amenities')], ['IconPartyPopper', T.events, () => community('events')],
    ['IconCheckSquare', T.polls, () => community('polls')], ['IconUsers', T.dailyHelp, () => go('help')], ['IconCar', T.parking, () => go('parking')],
  ];

  return (
    <Stack gap={16}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <Avatar initials={initials(st.me.name)} size={44} />
        <Stack gap={2}>
          <div style={{ fontSize: 16, fontWeight: 600 }}>{T.greeting}, {firstName(L ? st.me.name : st.me.nameGu)}</div>
          <div style={{ fontSize: 13, color: C.muted }}>{T.flat} {st.me.flat} · {L ? `${wing} wing` : `${WING_GU[wing] ?? wing} વિંગ`}</div>
        </Stack>
      </div>

      <div style={{ background: C.ink, color: '#fff', borderRadius: 6, padding: 18, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <Stack gap={4}><div style={{ fontSize: 13, color: '#cbd5e1' }}>{T.totalDue}</div><div style={{ fontSize: 32, fontWeight: 700, letterSpacing: -0.8 }}>{fmt(dueTotal)}</div></Stack>
          {dueBy && <div style={{ fontSize: 12, color: '#cbd5e1', textAlign: 'right' }}>{T.dueBy}<br /><span style={{ color: '#fff', fontWeight: 600, fontSize: 14 }}>{dayMonYear(dueBy)}</span></div>}
        </div>
        {dueTotal > 0
          ? <button onClick={() => go('bills')} style={{ ...btnReset, height: 42, borderRadius: 6, background: '#fff', fontSize: 14, fontWeight: 600 }}>{T.payNow}</button>
          : <div style={{ fontSize: 14, display: 'flex', gap: 6, alignItems: 'center' }}><Icon name="IconCheckCircle2" size={16} />{T.allPaid}</div>}
      </div>

      {approval && (
        <Card accent style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
            <IconBox name="IconBellRing" radius={40} />
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
              <div style={{ fontSize: 12, color: C.muted, fontWeight: 500 }}>{T.atGate}</div>
              <div style={{ fontSize: 15, fontWeight: 600 }}>{approval.name}</div>
              <div style={{ fontSize: 13, color: C.muted }}>{x(purposeLabel(approval.purpose))} · {vt(approval).in}</div>
            </div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            <Button variant="outline" style={wide} onClick={() => decide(false)}>{T.deny}</Button>
            <Button style={wide} onClick={() => decide(true)}>{T.approve}</Button>
          </div>
        </Card>
      )}

      <Label>{T.services}</Label>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 8 }}>
        {tiles.map(([icon, label, onClick]) => (
          <button key={icon} className="hov" onClick={onClick} style={{ ...tileStyle, padding: '12px 4px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, minHeight: 80 }}>
            <Icon name={icon} size={22} />
            <span style={{ fontSize: 12, fontWeight: 500, lineHeight: 1.25, textAlign: 'center' }}>{label}</span>
          </button>
        ))}
      </div>

      {notice && (
        <button onClick={() => community('notices')} style={{ ...tileStyle, padding: 14, display: 'flex', flexDirection: 'column', gap: 6, textAlign: 'left' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: C.muted, fontWeight: 500 }}><Icon name="IconMegaphone" size={14} />{T.latestNotice} · {dayMon(notice.createdAt)}</div>
          <div style={{ fontSize: 15, fontWeight: 600 }}>{x([notice.titleGu, notice.titleEn])}</div>
          <div style={{ fontSize: 13, color: C.muted, lineHeight: 1.5 }}>{x([notice.bodyGu, notice.bodyEn])}</div>
        </button>
      )}
      {event && (
        <button onClick={() => community('events')} style={{ ...tileStyle, padding: 14, display: 'flex', gap: 12, alignItems: 'center', textAlign: 'left' }}>
          <DateBox d={event.startsOn} />
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 2 }}>
            <div style={{ fontSize: 12, color: C.muted, fontWeight: 500 }}>{T.upcoming}</div>
            <div style={{ fontSize: 15, fontWeight: 600 }}>{x([event.titleGu, event.titleEn])}</div>
            <div style={{ fontSize: 13, color: C.muted }}>{x([event.placeGu, event.placeEn])} · {event.going} {T.going}</div>
          </div>
          <Icon name="IconChevronRight" size={18} />
        </button>
      )}
    </Stack>
  );
}

export const DateBox = ({ d }: { d: string }) => (
  <div style={{ width: 48, height: 52, borderRadius: 6, background: C.soft, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flex: 'none' }}>
    <span style={{ fontSize: 11, color: C.muted, fontWeight: 600 }}>{monUpper(d)}</span><span style={{ fontSize: 20, fontWeight: 700 }}>{d.slice(8)}</span>
  </div>
);

export function AdminHome() {
  const { st, T, x, L, role, go, set, open, toast, run, dl } = useApp();
  const fin = st.finance!;
  const pct = Math.round(fin.collected / fin.target * 100);
  const roleLabel = role === 'secretary' ? T.secretary : T.treasurer;
  const remindAll = async () => { if (await run(() => api('POST', '/reminders', {}))) toast(x(['બધા બાકીદારોને યાદી મોકલી', 'Reminders sent to all pending flats'])); };
  const report = () => dl('/reports/monthly.pdf', 'report.pdf', x(['રિપોર્ટ PDF ડાઉનલોડ થયો', 'Report PDF downloaded']));
  const actions: [string, string, () => void][] = role === 'treasurer'
    ? [['IconBanknote', T.recordCash, () => open('cash')], ['IconUpload', x(['બિલ જમા કરો', 'Submit a bill']), () => open('bill')], ['IconBellRing', T.remindAll, remindAll], ['IconFileBarChart', T.reportPdf, report]]
    : [['IconCheckSquare', `${T.pendingApproval} (${fin.pending.length})`, () => go('expenses')], ['IconMegaphone', T.postNotice, () => { set({ screen: 'community', commTab: 'notices' }); open('notice'); }],
      ['IconBellRing', T.remindAll, remindAll], ['IconWrench', T.complaints, () => go('complaints')]];
  const openComplaints = st.complaints.filter(c => c.status !== 'resolved');
  const card = { ...tileStyle, padding: 14, display: 'flex', flexDirection: 'column', gap: 4, textAlign: 'left' } as const;

  return (
    <Stack gap={16}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <Avatar initials={initials(st.me.name)} size={44} />
        <Stack gap={2}>
          <div style={{ fontSize: 16, fontWeight: 600 }}>{T.greeting}, {firstName(L ? st.me.name : st.me.nameGu)}</div>
          <div style={{ fontSize: 13, color: C.muted }}>{st.me.flat} · {roleLabel}</div>
        </Stack>
      </div>
      <div style={{ background: C.ink, color: '#fff', borderRadius: 6, padding: 18, display: 'flex', flexDirection: 'column', gap: 4 }}>
        <div style={{ fontSize: 13, color: '#cbd5e1' }}>{T.fundBalance}</div>
        <div style={{ fontSize: 32, fontWeight: 700, letterSpacing: -0.8 }}>{fmt(fin.fund)}</div>
        <div style={{ fontSize: 12, color: '#cbd5e1' }}>{T.asOn} {dayMonYear(st.today)}</div>
      </div>
      <button onClick={() => go('reports')} style={{ ...tileStyle, padding: 16, display: 'flex', flexDirection: 'column', gap: 10, textAlign: 'left' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', width: '100%' }}><span style={{ fontSize: 14, fontWeight: 600 }}>{collectionLabel(st.today, L)}</span><span style={{ fontSize: 14, fontWeight: 600 }}>{pct}%</span></div>
        <Progress value={pct} />
        <div style={{ fontSize: 13, color: C.muted }}>{fmt(fin.collected)} / {fmt(fin.target)} · {fin.defaulters.length} {T.flatsPending}</div>
      </button>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
        <button onClick={() => go('expenses')} style={card}><span style={{ fontSize: 12, color: C.muted }}>{T.monthExpense}</span><span style={{ fontSize: 20, fontWeight: 700 }}>{fmt(fin.monthExpense)}</span></button>
        <button onClick={() => go('expenses')} style={card}><span style={{ fontSize: 12, color: C.muted }}>{T.pendingApproval}</span><span style={{ fontSize: 20, fontWeight: 700 }}>{fin.pending.length}</span></button>
      </div>
      <Label>{T.quickActions}</Label>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
        {actions.map(([icon, label, onClick]) => (
          <button key={icon} className="hov" onClick={onClick} style={{ ...tileStyle, padding: 14, display: 'flex', alignItems: 'center', gap: 10, textAlign: 'left' }}>
            <Icon name={icon} size={20} style={{ flex: 'none' }} /><span style={{ fontSize: 13, fontWeight: 600, lineHeight: 1.3 }}>{label}</span>
          </button>
        ))}
      </div>
      <Label>{T.openComplaints}</Label>
      <Card>
        {openComplaints.map(c => (
          <div key={c.id} style={{ padding: '12px 14px', display: 'flex', gap: 10, alignItems: 'center', borderBottom: `1px solid ${C.soft}` }}>
            <Lines title={x([c.textGu, c.textEn])} sub={`${c.code} · ${c.flat} · ${x(COMP_CATS.find(k => k[0] === c.category)?.[1] ?? COMP_CATS[5][1])}`} />
            <Button variant="outline" onClick={() => run(() => api('POST', `/complaints/${c.id}/advance`))}>{c.status === 'open' ? T.start : T.resolve}</Button>
          </div>
        ))}
        {!openComplaints.length && <div style={{ padding: 16, fontSize: 14, color: C.muted, textAlign: 'center' }}>{x(['કોઈ ખુલ્લી ફરિયાદ નથી', 'No open complaints'])}</div>}
      </Card>
    </Stack>
  );
}

export function GateHome() {
  const { st, T, x, ui, setF, set, open, run } = useApp();
  const vt = useVisitorText();
  const inside = st.visitors.filter(v => v.status !== 'out' && v.status !== 'denied');
  const stats = [
    [st.visitors.filter(v => v.status === 'inside').length, T.visitorsIn],
    [st.passes.length, T.expected],
    [st.staff.filter(h => h.inTime && !h.outTime).length, T.helpIn],
  ] as const;
  const verify = async () => {
    const r = await run(() => api<{ valid: boolean; name?: string; flat?: string }>('POST', '/passes/verify', { code: ui.f.code.trim() }));
    if (r) set({ codeResult: r.valid ? x(['માન્ય પાસ ✓ ', 'Valid pass ✓ ']) + r.name + ' → ' + r.flat : x(['આ કોડ માન્ય નથી', 'This code is not valid']) });
  };
  return (
    <Stack gap={16}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 8 }}>
        {stats.map(([n, label]) => (
          <Card key={label} style={{ padding: 12, display: 'flex', flexDirection: 'column', gap: 2 }}>
            <span style={{ fontSize: 24, fontWeight: 700 }}>{n}</span><span style={{ fontSize: 12, color: C.muted, lineHeight: 1.3 }}>{label}</span>
          </Card>
        ))}
      </div>
      <button onClick={() => open('visitor')} style={{ ...btnReset, height: 64, borderRadius: 6, background: C.ink, color: '#fff', fontSize: 16, fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10 }}>
        <Icon name="IconUserPlus" size={22} />{T.newEntry}
      </button>
      <Card style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{ fontSize: 14, fontWeight: 600, display: 'flex', gap: 8, alignItems: 'center' }}><Icon name="IconQrCode" size={18} />{T.verifyPass}</div>
        <form onSubmit={e => { e.preventDefault(); verify(); }} style={{ display: 'flex', gap: 8, alignItems: 'flex-end' }}>
          <div style={{ flex: 1 }}><Input placeholder="482915" value={ui.f.code} onChange={e => setF('code', e.target.value)} inputMode="numeric" maxLength={6} style={wide} /></div>
          <Button type="submit">{T.check}</Button>
        </form>
        {ui.codeResult && <div style={{ fontSize: 13, padding: 10, borderRadius: 6, background: C.soft, fontWeight: 500 }}>{ui.codeResult}</div>}
      </Card>
      <Label>{T.insideNow}</Label>
      {inside.map(v => (
        <Card key={v.id} style={{ padding: '12px 14px', display: 'flex', gap: 10, alignItems: 'center' }}>
          <Lines title={v.name} sub={`${v.flat} · ${vt(v).purpose} · ${T.inAt} ${vt(v).in}`} />
          <VisitorBadge status={v.status} />
          {v.status === 'inside' && <Button variant="outline" onClick={() => run(() => api('POST', `/visitors/${v.id}/exit`))}>{T.exit}</Button>}
        </Card>
      ))}
    </Stack>
  );
}
