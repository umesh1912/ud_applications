import { useMemo, useState } from 'react';
import { Button, Icon, Input } from './ds';
import { api } from './lib/api';
import { errorText } from './lib/errors';
import { strings } from './lib/i18n';
import type { Me } from './lib/types';
import { ErrorBox, Screen } from './Screen';
import { btnReset, C, Card, Chip, Chips, FieldLabel, Label, Lines, ring, Row, Stack, wide, wideTall } from './ui';

interface Props { lang: 'gu' | 'en'; setLang: (l: 'gu' | 'en') => void; framed: boolean; me: Me; reload: () => Promise<void>; logout: () => void; onBack?: () => void }

const useT = (lang: 'gu' | 'en') => { const L = lang === 'gu' ? 0 : 1; return { L, T: useMemo(() => strings(L), [L]) } as const; };

/** Runs an async action with busy and localized-error state. */
function useAction(L: 0 | 1) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const run = async (fn: () => Promise<void>) => {
    setBusy(true); setError(null);
    try { await fn(); } catch (e) { setError(errorText(e, L)); } finally { setBusy(false); }
  };
  return { busy, error, run, setError };
}

export function Profile({ lang, setLang, framed, me, reload }: Props) {
  const { L, T } = useT(lang);
  const [name, setName] = useState(me.account.name);
  const [nameGu, setNameGu] = useState(me.account.nameGu);
  const a = useAction(L);
  return (
    <Screen sub={me.account.phone} title={T.profileTitle} lang={lang} setLang={setLang} framed={framed}>
      <form onSubmit={e => { e.preventDefault(); a.run(async () => { await api('PUT', '/me', { name, nameGu }); await reload(); }); }} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div style={{ fontSize: 14, color: C.muted, lineHeight: 1.5 }}>{T.profileSub}</div>
        <Input label={T.nameLbl} autoComplete="name" placeholder="Rajesh Patel" value={name} onChange={e => setName(e.target.value)} autoFocus style={wide} />
        <Input label={T.nameGuLbl} placeholder="રાજેશભાઈ પટેલ" value={nameGu} onChange={e => setNameGu(e.target.value)} style={wide} />
        {a.error && <ErrorBox>{a.error}</ErrorBox>}
        <Button type="submit" loading={a.busy} style={wideTall}>{T.continue}</Button>
      </form>
    </Screen>
  );
}

export function Welcome(p: Props & { onRegister: () => void; onJoin: () => void; onSwitch: (memberId: number) => void }) {
  const { L, T } = useT(p.lang);
  const a = useAction(L);
  const pending = p.me.memberships.filter(m => m.status === 'pending');
  const active = p.me.memberships.filter(m => m.status === 'active');
  const card = (icon: string, title: string, sub: string, onClick: () => void) => (
    <button className="hov" onClick={onClick} style={{ ...btnReset, background: '#fff', boxShadow: ring(), borderRadius: 6, padding: 16, display: 'flex', gap: 14, alignItems: 'center', textAlign: 'left' }}>
      <div style={{ width: 44, height: 44, borderRadius: 6, background: C.ink, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none' }}><Icon name={icon} size={22} /></div>
      <Stack gap={2} style={{ flex: 1 }}><span style={{ fontSize: 15, fontWeight: 600 }}>{title}</span><span style={{ fontSize: 13, color: C.muted }}>{sub}</span></Stack>
      <Icon name="IconChevronRight" size={18} />
    </button>
  );
  return (
    <Screen sub={p.me.account.name} title={T.welcome} lang={p.lang} setLang={p.setLang} framed={p.framed} onBack={p.onBack}>
      <Stack gap={14}>
        <div style={{ fontSize: 14, color: C.muted, lineHeight: 1.5 }}>{T.welcomeSub}</div>
        {card('IconBuilding2', T.registerSociety, T.registerSub, p.onRegister)}
        {card('IconUserPlus', T.joinSociety, T.joinSub, p.onJoin)}
        {active.length > 0 && <>
          <Label style={{ marginTop: 8 }}>{T.switchSociety}</Label>
          <Card>
            {active.map(m => (
              <button key={m.id} className="hov2" onClick={() => p.onSwitch(m.id)} style={{ ...btnReset, width: '100%', background: 'transparent', padding: '12px 14px', display: 'flex', gap: 10, alignItems: 'center', borderBottom: `1px solid ${C.soft}`, textAlign: 'left' }}>
                <Lines title={L ? m.society : m.societyGu || m.society} sub={`${m.flat ?? ''} · ${m.city}`} />
                <Icon name="IconChevronRight" size={16} />
              </button>
            ))}
          </Card>
        </>}
        {pending.length > 0 && <>
          <Label style={{ marginTop: 8 }}>{T.pendingRequests}</Label>
          <Card>
            {pending.map(m => (
              <Row key={m.id}>
                <Lines title={L ? m.society : m.societyGu || m.society} sub={`${m.flat ?? T.asGuard} · ${T.waitingApproval}`} />
                <Button variant="outline" onClick={() => a.run(async () => { await api('DELETE', `/memberships/${m.id}`); await p.reload(); })}>{T.cancelRequest}</Button>
              </Row>
            ))}
          </Card>
          <Button variant="outline" icon="IconRefreshCw" loading={a.busy} style={wide} onClick={() => a.run(p.reload)}>{T.refresh}</Button>
        </>}
        {a.error && <ErrorBox>{a.error}</ErrorBox>}
        <button onClick={p.logout} style={{ ...btnReset, background: 'none', fontSize: 14, fontWeight: 500, textDecoration: 'underline', alignSelf: 'center', marginTop: 8 }}>{T.logout}</button>
      </Stack>
    </Screen>
  );
}

interface Wing { name: string; floors: string; perFloor: string }

export function RegisterSociety(p: Props & { onDone: () => void }) {
  const { L, T } = useT(p.lang);
  const a = useAction(L);
  const [f, setF] = useState({ name: '', nameGu: '', city: '', address: '', maintenance: '', dueDay: '10', upiId: '', flat: '' });
  const [wings, setWings] = useState<Wing[]>([{ name: 'A', floors: '4', perFloor: '4' }]);
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF(v => ({ ...v, [k]: e.target.value }));
  const setWing = (i: number, k: keyof Wing, v: string) => setWings(ws => ws.map((w, j) => j === i ? { ...w, [k]: k === 'name' ? v.toUpperCase() : v.replace(/\D/g, '') } : w));
  const flats = wings.flatMap(w => {
    const out: string[] = [];
    for (let fl = 1; fl <= Math.min(60, Number(w.floors) || 0); fl++) for (let u = 1; u <= Math.min(50, Number(w.perFloor) || 0); u++) out.push(`${w.name}-${fl}${String(u).padStart(2, '0')}`);
    return out;
  });
  const submit = () => a.run(async () => {
    await api('POST', '/societies', { ...f, wings: wings.map(w => ({ name: w.name, floors: Number(w.floors), perFloor: Number(w.perFloor) })) });
    await p.reload();
    p.onDone();
  });
  const small = { width: '100%' } as const;

  return (
    <Screen sub={T.welcome} title={T.registerSociety} lang={p.lang} setLang={p.setLang} framed={p.framed} onBack={p.onBack}>
      <form onSubmit={e => { e.preventDefault(); submit(); }} style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <Input label={T.societyName} placeholder="Shivam Residency" value={f.name} onChange={set('name')} style={wide} />
        <Input label={T.societyNameGu} placeholder="શિવમ રેસિડેન્સી" value={f.nameGu} onChange={set('nameGu')} style={wide} />
        <Input label={T.city} placeholder="Ahmedabad" value={f.city} onChange={set('city')} style={wide} />
        <Input label={T.address} value={f.address} onChange={set('address')} style={wide} />

        <FieldLabel>{T.wings}</FieldLabel>
        {wings.map((w, i) => (
          <div key={i} style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 36px', gap: 8, alignItems: 'end' }}>
            <Input label={T.wingName} value={w.name} maxLength={6} onChange={e => setWing(i, 'name', e.target.value)} style={small} />
            <Input label={T.floors} inputMode="numeric" value={w.floors} onChange={e => setWing(i, 'floors', e.target.value)} style={small} />
            <Input label={T.perFloor} inputMode="numeric" value={w.perFloor} onChange={e => setWing(i, 'perFloor', e.target.value)} style={small} />
            <button type="button" aria-label={T.remove} disabled={wings.length === 1} onClick={() => setWings(ws => ws.filter((_, j) => j !== i))}
              style={{ ...btnReset, width: 36, height: 40, borderRadius: 6, background: C.soft, display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: wings.length === 1 ? 0.4 : 1 }}>
              <Icon name="IconX" size={16} />
            </button>
          </div>
        ))}
        <Button type="button" variant="outline" icon="IconPlus" style={wide}
          onClick={() => setWings(ws => [...ws, { name: String.fromCharCode(65 + ws.length), floors: ws[ws.length - 1]?.floors ?? '4', perFloor: ws[ws.length - 1]?.perFloor ?? '4' }])}>{T.addWing}</Button>
        <div style={{ fontSize: 13, color: C.muted }}>{T.flatsPreview}: <b style={{ color: C.ink }}>{flats.length}</b>{flats.length ? ` (${flats[0]} … ${flats[flats.length - 1]})` : ''}</div>

        <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <span className="sc-field-label">{T.yourFlat}</span>
          <select value={f.flat} onChange={set('flat')} className="sc-input sc-select">
            <option value="">{T.noFlatOption}</option>
            {flats.map(id => <option key={id} value={id}>{id}</option>)}
          </select>
        </label>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <Input label={T.maintenanceAmt} inputMode="numeric" placeholder="2500" value={f.maintenance} onChange={set('maintenance')} style={small} />
          <Input label={T.dueDay} inputMode="numeric" value={f.dueDay} onChange={set('dueDay')} style={small} />
        </div>
        <Input label={T.upiId} placeholder="society@sbi" autoCapitalize="none" value={f.upiId} onChange={set('upiId')} style={wide} />
        <div style={{ fontSize: 12, color: C.muted, marginTop: -8 }}>{T.upiIdHint}</div>
        {a.error && <ErrorBox>{a.error}</ErrorBox>}
        <Button type="submit" loading={a.busy} style={wideTall}>{T.create}</Button>
      </form>
    </Screen>
  );
}

export function JoinSociety(p: Props & { onDone: () => void }) {
  const { L, T } = useT(p.lang);
  const a = useAction(L);
  const [code, setCode] = useState('');
  const [found, setFound] = useState<{ name: string; nameGu: string; city: string; flats: string[] } | null>(null);
  const [role, setRole] = useState<'resident' | 'watchman'>('resident');
  const [flat, setFlat] = useState('');
  const [occupancy, setOccupancy] = useState<'owner' | 'tenant'>('owner');

  const find = () => a.run(async () => {
    setFound(await api('GET', `/societies/lookup?code=${encodeURIComponent(code.trim().toUpperCase())}`));
    setFlat('');
  });
  const join = () => a.run(async () => {
    await api('POST', '/societies/join', { code: code.trim().toUpperCase(), role, flat, occupancy });
    await p.reload();
    p.onDone();
  });

  return (
    <Screen sub={T.welcome} title={T.joinSociety} lang={p.lang} setLang={p.setLang} framed={p.framed} onBack={p.onBack}>
      <Stack gap={14}>
        <form onSubmit={e => { e.preventDefault(); find(); }} style={{ display: 'flex', gap: 8, alignItems: 'flex-end' }}>
          <div style={{ flex: 1 }}><Input label={T.societyCode} placeholder="AB12CD" autoCapitalize="characters" maxLength={8} value={code}
            onChange={e => { setCode(e.target.value.toUpperCase()); setFound(null); }} style={{ ...wide, letterSpacing: 2 }} /></div>
          <Button type="submit" loading={a.busy && !found}>{T.findSociety}</Button>
        </form>
        {found && <>
          <Card style={{ padding: 14, display: 'flex', gap: 12, alignItems: 'center' }}>
            <div style={{ width: 40, height: 40, borderRadius: 6, background: C.ink, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none' }}><Icon name="IconBuilding2" size={20} /></div>
            <Lines title={L ? found.name : found.nameGu || found.name} sub={`${found.city} · ${found.flats.length} ${L ? 'flats' : 'ફ્લેટ'}`} />
          </Card>
          <FieldLabel>{T.joinAs}</FieldLabel>
          <Chips>
            <Chip on={role === 'resident'} onClick={() => setRole('resident')}>{T.asResident}</Chip>
            <Chip on={role === 'watchman'} onClick={() => setRole('watchman')}>{T.asGuard}</Chip>
          </Chips>
          {role === 'resident' && <>
            <label style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              <span className="sc-field-label">{T.yourFlat}</span>
              <select value={flat} onChange={e => setFlat(e.target.value)} className="sc-input sc-select">
                <option value="">{T.pickFlat}</option>
                {found.flats.map(id => <option key={id} value={id}>{id}</option>)}
              </select>
            </label>
            <Chips>
              <Chip on={occupancy === 'owner'} onClick={() => setOccupancy('owner')}>{T.owner}</Chip>
              <Chip on={occupancy === 'tenant'} onClick={() => setOccupancy('tenant')}>{T.tenant}</Chip>
            </Chips>
          </>}
          <Button loading={a.busy} disabled={role === 'resident' && !flat} style={{ ...wideTall, opacity: role === 'resident' && !flat ? 0.5 : 1 }} onClick={join}>{T.sendRequest}</Button>
        </>}
        {a.error && <ErrorBox>{a.error}</ErrorBox>}
      </Stack>
    </Screen>
  );
}
