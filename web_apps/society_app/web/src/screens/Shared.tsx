import { Avatar, Button, Icon, Input } from '../ds';
import { useApp, type CommTab } from '../ctx';
import { api } from '../lib/api';
import { ROLES } from '../lib/i18n';
import { dayMon } from '../lib/format';
import { btnReset, C, Card, Empty, IconBox, IconBtn, Label, Lines, Row, Stack, wide, wideTall } from '../ui';
import { initials, useVisitorText, VisitorBadge } from './common';
import { DateBox } from './Home';

export function Community() {
  const { st, T, x, ui, set, role, open, run } = useApp();
  const tabs: [CommTab, string][] = [['notices', T.notices], ['events', T.events], ['polls', T.polls]];
  return (
    <Stack gap={12}>
      <div role="tablist" style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 4, padding: 4, background: C.soft, borderRadius: 6 }}>
        {tabs.map(([id, label]) => (
          <button key={id} role="tab" aria-selected={ui.commTab === id} onClick={() => set({ commTab: id })}
            style={{ ...btnReset, height: 34, borderRadius: 3, fontSize: 13, fontWeight: 600, background: ui.commTab === id ? '#fff' : 'transparent', color: ui.commTab === id ? C.ink : C.muted }}>{label}</button>
        ))}
      </div>

      {ui.commTab === 'notices' && <Stack gap={10}>
        {role === 'secretary' && <Button variant="outline" icon="IconPlus" style={wide} onClick={() => open('notice')}>{T.postNotice}</Button>}
        {!st.notices.length && <Card><Empty>{T.noNotices}</Empty></Card>}
        {st.notices.map(n => (
          <Card key={n.id} style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 6 }}>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center', fontSize: 12, color: C.muted }}>
              <span>{dayMon(n.createdAt)}</span>
              {n.pinned && <span style={{ fontWeight: 600, color: C.ink, padding: '1px 6px', borderRadius: 40, background: C.soft }}>{T.important}</span>}
            </div>
            <div style={{ fontSize: 15, fontWeight: 600 }}>{x([n.titleGu, n.titleEn])}</div>
            <div style={{ fontSize: 13, color: C.body, lineHeight: 1.55, whiteSpace: 'pre-line' }}>{x([n.bodyGu, n.bodyEn])}</div>
          </Card>
        ))}
      </Stack>}

      {ui.commTab === 'events' && <Stack gap={10}>
        {role === 'secretary' && <Button variant="outline" icon="IconPlus" style={wide} onClick={() => open('event')}>{T.newEvent}</Button>}
        {!st.events.length && <Card><Empty>{T.noEvents}</Empty></Card>}
        {st.events.map(e => (
          <Card key={e.id} style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div style={{ display: 'flex', gap: 12 }}>
              <DateBox d={e.startsOn} />
              <Stack gap={2} style={{ flex: 1 }}>
                <div style={{ fontSize: 15, fontWeight: 600 }}>{x([e.titleGu, e.titleEn])}</div>
                <div style={{ fontSize: 13, color: C.muted }}>{x([e.whenGu, e.whenEn])}</div>
                <div style={{ fontSize: 13, color: C.muted }}>{x([e.placeGu, e.placeEn])}</div>
              </Stack>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 13, color: C.muted, display: 'flex', gap: 6, alignItems: 'center' }}><Icon name="IconUsers" size={14} />{e.going} {T.going}</span>
              <Button variant={e.me ? 'default' : 'outline'} onClick={() => run(() => api('POST', `/events/${e.id}/rsvp`))}>{e.me ? T.youGoing : T.imGoing}</Button>
            </div>
          </Card>
        ))}
      </Stack>}

      {ui.commTab === 'polls' && <Stack gap={10}>
        {role === 'secretary' && <Button variant="outline" icon="IconPlus" style={wide} onClick={() => open('poll')}>{T.newPoll}</Button>}
        {!st.polls.length && <Card><Empty>{T.noPolls}</Empty></Card>}
        {st.polls.map(p => {
          const tot = p.options.reduce((a, o) => a + o.votes, 0);
          const shown = p.votedOption !== null || p.closed;
          return (
            <Card key={p.id} style={{ padding: 14, display: 'flex', flexDirection: 'column', gap: 10 }}>
              <div style={{ fontSize: 15, fontWeight: 600, lineHeight: 1.4 }}>{x([p.qGu, p.qEn])}</div>
              <div style={{ fontSize: 12, color: C.muted }}>{tot} {T.votes} · {p.closed ? x(['મતદાન બંધ', 'Voting closed']) : `${T.endsOn} ${dayMon(p.endsOn)}`}</div>
              {p.options.map(o => {
                const pct = tot ? Math.round(o.votes / tot * 100) : 0, mine = p.votedOption === o.id;
                return (
                  <button key={o.id} disabled={shown} onClick={() => run(() => api('POST', `/polls/${p.id}/vote`, { optionId: o.id }))}
                    style={{ ...btnReset, position: 'relative', overflow: 'hidden', height: 42, borderRadius: 6, boxShadow: `inset 0 0 0 1px ${mine ? C.ink : C.line}`, background: '#fff', textAlign: 'left', padding: '0 12px', cursor: shown ? 'default' : 'pointer' }}>
                    <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: shown ? pct + '%' : '0%', background: C.soft, transition: 'width .4s' }} />
                    <div style={{ position: 'relative', display: 'flex', justifyContent: 'space-between', fontSize: 14, fontWeight: mine ? 700 : 500 }}><span>{x([o.labelGu, o.labelEn])}</span><span>{shown ? pct + '%' : ''}</span></div>
                  </button>
                );
              })}
            </Card>
          );
        })}
      </Stack>}
    </Stack>
  );
}

export function Directory() {
  const { st, T, x, ui, setF, toast, role, open } = useApp();
  const q = ui.f.q.trim().toLowerCase();
  const groups = ([['committee', T.committee], ['resident', T.residents], ['emergency', T.emergency]] as const).map(([g, label]) => ({
    label,
    items: st.directory.filter(d => d.grp === g).filter(d => !q || (d.nameEn + d.nameGu + d.subEn).toLowerCase().includes(q)),
  })).filter(g => g.items.length);
  return (
    <Stack gap={12}>
      <Input type="search" placeholder={T.searchPh} value={ui.f.q} onChange={e => setF('q', e.target.value)} style={wide} />
      {role === 'secretary' && <Button variant="outline" icon="IconPlus" style={wide} onClick={() => open('contact')}>{T.addContact}</Button>}
      {groups.map(g => (
        <Stack key={g.label} gap={6}>
          <Label>{g.label}</Label>
          <Card>
            {g.items.map((p, i) => (
              <div key={i} style={{ padding: '10px 14px', display: 'flex', gap: 12, alignItems: 'center', borderBottom: `1px solid ${C.soft}` }}>
                <Avatar initials={p.initials} size={36} />
                <Lines gap={1} title={x([p.nameGu, p.nameEn])} sub={x([p.subGu, p.subEn])} />
                <a href={`tel:${p.phone}`} aria-label={x([p.nameGu, p.nameEn])} onClick={() => toast(x(['કૉલ થઈ રહ્યો છે: ', 'Calling ']) + x([p.nameGu, p.nameEn]))}
                  style={{ width: 36, height: 36, borderRadius: 36, background: C.soft, color: C.ink, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none' }}>
                  <Icon name="IconPhone" size={16} />
                </a>
              </div>
            ))}
          </Card>
        </Stack>
      ))}
    </Stack>
  );
}

export function Docs() {
  const { st, T, x, dl, role, open, run, toast } = useApp();
  return (
    <Stack gap={12}>
    {role === 'secretary' && <Button icon="IconUpload" style={wideTall} onClick={() => open('doc')}>{T.uploadDoc}</Button>}
    {!st.documents.length && <Card><Empty>{T.noDocs}</Empty></Card>}
    <Card>
      {st.documents.map(d => (
        <Row key={d.id} style={{ gap: 12 }}>
          <IconBox name="IconFileText" box={36} size={18} />
          <Lines gap={1} title={x([d.nameGu, d.nameEn])} sub={`${d.size} · ${d.date}`} />
          <IconBtn name="IconDownload" size={18} box={36} label={x([d.nameGu, d.nameEn])}
            onClick={() => dl(`/documents/${d.id}/download`, `${d.nameEn}.pdf`, x(['ડાઉનલોડ થયું: ', 'Downloaded: ']) + x([d.nameGu, d.nameEn]))} />
          {role === 'secretary' && <IconBtn name="IconX" size={16} label={T.remove}
            onClick={() => { if (confirm(`${T.remove}: ${x([d.nameGu, d.nameEn])}?`)) run(() => api('DELETE', `/documents/${d.id}`)).then(r => r && toast(T.deleted)); }} />}
        </Row>
      ))}
    </Card>
    </Stack>
  );
}

export function Help() {
  const { st, T, x, isW, role, run, open, toast } = useApp();
  const canManage = isW || role === 'secretary';
  return (
    <Stack gap={10}>
      {canManage && <Button variant="outline" icon="IconPlus" style={wide} onClick={() => open('staff')}>{T.addStaff}</Button>}
      {!st.staff.length && <Card><Empty>{T.noStaff}</Empty></Card>}
      {st.staff.map(h => {
        const isIn = !!h.inTime && !h.outTime;
        const status = isIn ? `${T.present} ${h.inTime}` : h.outTime ? `${T.left} ${h.outTime}` : T.absent;
        return (
          <Card key={h.id} style={{ padding: '12px 14px', display: 'flex', gap: 12, alignItems: 'center' }}>
            <Avatar initials={Array.from(x([h.nameGu, h.nameEn])).slice(0, 2).join('')} size={40} />
            <Stack gap={2} style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 600 }}>{x([h.nameGu, h.nameEn])}</div>
              <div style={{ fontSize: 12, color: C.muted }}>{x([h.roleGu, h.roleEn])} · {h.flats}</div>
              <div style={{ fontSize: 12, color: C.ink, fontWeight: 500 }}>{status}</div>
            </Stack>
            {isW
              ? <Button variant={isIn ? 'outline' : 'default'} onClick={() => run(() => api('POST', `/staff/${h.id}/attendance`))}>{isIn ? T.markOut : T.markIn}</Button>
              : <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end' }}><span style={{ fontSize: 16, fontWeight: 700 }}>{h.days}</span><span style={{ fontSize: 11, color: C.muted }}>{T.daysMonth}</span></div>}
            {canManage && <IconBtn name="IconX" label={T.remove} onClick={() => { if (confirm(`${T.remove}: ${x([h.nameGu, h.nameEn])}?`)) run(() => api('DELETE', `/staff/${h.id}`)).then(r => r && toast(T.deleted)); }} />}
          </Card>
        );
      })}
    </Stack>
  );
}

export function VisitorLog() {
  const { st, T, open } = useApp();
  const vt = useVisitorText();
  return (
    <Stack gap={10}>
      <Button icon="IconUserPlus" style={wideTall} onClick={() => open('visitor')}>{T.newEntry}</Button>
      <Card>
        {st.visitors.map(v => (
          <Row key={v.id}><Lines title={v.name} sub={`${v.flat} · ${vt(v).purpose} · ${vt(v).in}${vt(v).outTxt}`} /><VisitorBadge status={v.status} /></Row>
        ))}
        {!st.visitors.length && <Empty>{T.noVisitors}</Empty>}
      </Card>
    </Stack>
  );
}

export function More() {
  const { st, T, x, L, role, isRes, isAdmin, go, switchRole, logout, memberships, switchSociety, addSociety } = useApp();
  const roleLocal = { resident: T.resident, secretary: T.secretary, treasurer: T.treasurer, watchman: T.watchman };
  const booking = x(['બુકિંગ', 'Booking']);
  const t = (id: string, icon: string, label: string) => ({ id, icon, label });
  const tiles = isRes
    ? [t('complaints', 'IconWrench', T.complaints), t('amenities', 'IconCalendarDays', booking), t('parking', 'IconCar', T.parking), t('help', 'IconUsers', T.dailyHelp), t('directory', 'IconUser', T.directory), t('docs', 'IconFolder', T.docs), t('bills', 'IconReceipt', T.bills), t('gate', 'IconTicket', T.gatePass), t('community', 'IconMegaphone', T.community)]
    : isAdmin
      ? [...(role === 'secretary' ? [t('members', 'IconUserPlus', `${T.members}${st.members?.pending.length ? ` (${st.members.pending.length})` : ''}`)] : []), t('settings', 'IconClipboardCheck', T.settings),
        t('reports', 'IconIndianRupee', T.reports), t('expenses', 'IconPieChart', T.expenses), t('complaints', 'IconWrench', T.complaints), t('directory', 'IconUser', T.directory), t('docs', 'IconFolder', T.docs),
        t('community', 'IconMegaphone', T.community), t('help', 'IconUsers', T.dailyHelp),
        ...(st.me.flat ? [t('bills', 'IconReceipt', T.bills), t('gate', 'IconTicket', T.gatePass), t('amenities', 'IconCalendarDays', booking), t('parking', 'IconCar', T.parking)] : [])]
      : [t('log', 'IconClipboardList', T.visitors), t('help', 'IconUsers', T.dailyHelp), t('directory', 'IconUser', T.directory), t('parking', 'IconCar', T.parking), t('community', 'IconMegaphone', T.community)];
  const society = x([st.society.gu, st.society.en]);
  const sub = role === 'resident' ? `${T.flat} ${st.me.flat} · ${T.resident}` : role === 'watchman' ? `${T.watchman} · ${society}` : `${st.me.flat ? `${st.me.flat} · ` : ''}${roleLocal[role]}`;
  const others = memberships.filter(m => m.status === 'active' && m.id !== st.me.memberId);
  const rowStyle = { ...btnReset, width: '100%', background: 'transparent', padding: '12px 14px', display: 'flex', gap: 12, alignItems: 'center', borderBottom: `1px solid ${C.soft}`, textAlign: 'left' } as const;

  return (
    <Stack gap={16}>
      <Card style={{ padding: 14, display: 'flex', gap: 12, alignItems: 'center' }}>
        <Avatar initials={initials(st.me.name)} size={48} />
        <Stack gap={2}><div style={{ fontSize: 16, fontWeight: 600 }}>{st.me.name}</div><div style={{ fontSize: 13, color: C.muted }}>{sub}</div></Stack>
      </Card>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 8 }}>
        {tiles.map(tile => (
          <button key={tile.id} className="hov" onClick={() => go(tile.id)} style={{ ...btnReset, background: '#fff', boxShadow: `inset 0 0 0 1px ${C.line}`, borderRadius: 6, padding: '14px 4px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, minHeight: 84 }}>
            <Icon name={tile.icon} size={22} />
            <span style={{ fontSize: 12, fontWeight: 500, lineHeight: 1.25, textAlign: 'center' }}>{tile.label}</span>
          </button>
        ))}
      </div>
      {st.demo && <>
        <Label>{T.switchRole}</Label>
        <Card>
          {ROLES.map(r => (
            <button key={r.id} className="hov2" onClick={() => switchRole(r.id)} style={rowStyle}>
              <Icon name={r.icon} size={18} />
              <span style={{ flex: 1, fontSize: 14, fontWeight: 500 }}>{roleLocal[r.id]}</span>
              {r.id === role && <Icon name="IconCheck" size={16} />}
            </button>
          ))}
        </Card>
      </>}
      <Label>{T.switchSociety}</Label>
      <Card>
        <div style={{ ...rowStyle, cursor: 'default' }}>
          <Icon name="IconBuilding2" size={18} /><span style={{ flex: 1, fontSize: 14, fontWeight: 600 }}>{society}</span><Icon name="IconCheck" size={16} />
        </div>
        {others.map(m => (
          <button key={m.id} className="hov2" onClick={() => switchSociety(m.id)} style={rowStyle}>
            <Icon name="IconBuilding" size={18} /><span style={{ flex: 1, fontSize: 14, fontWeight: 500 }}>{L ? m.society : m.societyGu || m.society}</span>
          </button>
        ))}
        <button className="hov2" onClick={addSociety} style={rowStyle}>
          <Icon name="IconPlus" size={18} /><span style={{ flex: 1, fontSize: 14, fontWeight: 500 }}>{T.addSociety}</span>
        </button>
        <button className="hov2" onClick={logout} style={{ ...rowStyle, borderBottom: 0 }}>
          <Icon name="IconLogOut" size={18} /><span style={{ flex: 1, fontSize: 14, fontWeight: 500 }}>{T.logout}</span>
        </button>
      </Card>
    </Stack>
  );
}
