import { useEffect, useState } from 'react';
import { COMMON_TESTS, DOSES, DURATIONS, MEDICINES, fmtDay, fmtTime } from '../data/catalog';
import { REGIONS, money, type Region } from '../data/region';
import type { RxMed } from '../patient/state';
import { CallScreen } from '../ui/call';
import { Avatar, Icon, Segmented, Sheet, Toggle, TopBar, useNow, useToast, type Nav } from '../ui/kit';
import { commissionOf, seed, todayGross, useD, type QueueItem } from './state';

// ---------------------------------------------------------------- sign in

export function Welcome() {
  const { set } = useD();
  const [region, setRegion] = useState<Region>('IN');
  const [reg, setReg] = useState('KMC 84213');
  const [busy, setBusy] = useState(false);
  return (
    <div className="screen stack" style={{ background: 'linear-gradient(170deg, #0e1330 0%, #1d2468 55%, #3b3fb0 100%)', color: '#fff', padding: '20px 24px 28px' }}>
      <div className="row gap-8" style={{ fontWeight: 800, fontSize: 18 }}>
        <span className="tile-icon sm" style={{ background: '#fff', color: 'var(--brand)' }}><Icon name="Stethoscope" size={20} /></span>CareLoop <span className="badge" style={{ background: 'rgba(255,255,255,.16)', color: '#fff' }}>PRO</span>
      </div>
      <div className="stack gap-12" style={{ flex: 1, justifyContent: 'center' }}>
        <div className="t-display" style={{ fontSize: 34 }}>Your practice, in your pocket</div>
        <div style={{ fontSize: 15.5, lineHeight: 1.5, opacity: 0.8 }}>Video and clinic patients, e-prescriptions, records and payouts in one app. Doctors on CareLoop see 30% more patients in their first 3 months.</div>
        <div className="stack gap-10" style={{ marginTop: 10 }}>
          {['Get paid within 48 hours', 'Prescriptions signed digitally in 30 seconds', 'Set your own fees and hours'].map((t) => (
            <div key={t} className="row gap-10" style={{ fontSize: 14.5, fontWeight: 600 }}><span className="check-circle" style={{ background: 'rgba(255,255,255,.18)' }}><Icon name="Check" size={14} stroke={3} /></span>{t}</div>
          ))}
        </div>
      </div>
      <div className="card stack gap-12" style={{ padding: 18, color: 'var(--ink)' }}>
        <Segmented options={[{ id: 'IN', label: 'India' }, { id: 'US', label: 'United States' }]} value={region} onChange={(r) => { setRegion(r); setReg(r === 'IN' ? 'KMC 84213' : 'CA A-129874'); }} />
        <div className="field">
          <label>{region === 'IN' ? 'Medical council registration no.' : 'State license / NPI'}</label>
          <input className="input" value={reg} onChange={(e) => setReg(e.target.value)} />
        </div>
        <button className="btn block" disabled={!reg.trim() || busy} onClick={() => {
          setBusy(true);
          window.setTimeout(() => set(() => ({ ...seed(region), stage: 'app' })), 900);
        }}>{busy ? <><span className="spinner" />Verifying license…</> : 'Sign in securely'}</button>
        <div className="t-xs row gap-6" style={{ justifyContent: 'center' }}><Icon name="ShieldCheck" size={13} />{REGIONS[region].compliance}</div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- today

const STATUS: Record<QueueItem['status'], { label: string; cls: string }> = {
  done: { label: 'Seen', cls: 'good' },
  waiting: { label: 'Waiting', cls: 'accent' },
  'in-consult': { label: 'In consult', cls: 'brand' },
  upcoming: { label: 'Booked', cls: '' },
  'no-show': { label: 'No-show', cls: 'bad' },
};

export function Today({ nav }: { nav: Nav }) {
  const { s, set, me, patient } = useD();
  const toast = useToast();
  const now = useNow(20000);
  const [request, setRequest] = useState(false);
  const [asked, setAsked] = useState(false);

  // While online, an instant-consult request arrives shortly after opening Today (once per session).
  useEffect(() => {
    if (!s.online || asked) return;
    const id = window.setTimeout(() => { setRequest(true); setAsked(true); }, 7000);
    return () => window.clearTimeout(id);
  }, [s.online, asked]);

  const gross = todayGross(s);
  const net = gross * (1 - commissionOf(s));
  const done = s.queue.filter((q) => q.status === 'done').length;
  const list = [...s.queue].sort((a, b) => a.t - b.t);
  const next = list.find((q) => q.status === 'waiting' || q.status === 'in-consult') ?? list.find((q) => q.status === 'upcoming');
  const first = me.name.split(' ').slice(0, 2).join(' ');
  const r = REGIONS[s.region];
  const reqPatient = s.region === 'IN' ? { name: 'Nisha Patel', age: 29 } : { name: 'Sam Rivera', age: 29 };

  const start = (q: QueueItem) => {
    set((p) => ({ ...p, queue: p.queue.map((x) => (x.id === q.id ? { ...x, status: 'in-consult' } : x)) }));
    nav.push(q.mode === 'video' ? 'consult' : 'prescribe', { id: q.id });
  };

  return (
    <div className="screen has-tabs tab-root" style={{ background: 'var(--bg)' }}>
      <div style={{ background: 'linear-gradient(160deg, #0e1330, #27307a)', color: '#fff', padding: '16px 20px 74px', borderRadius: '0 0 30px 30px' }}>
        <div className="row between">
          <div className="row gap-12">
            <Avatar name={me.name} hue={me.hue} size={46} online={s.online} />
            <div>
              <div style={{ fontSize: 13, opacity: 0.7 }}>{fmtDay(now)}</div>
              <div className="t-h2">Hello, {first}</div>
            </div>
          </div>
          <button className="icon-btn on-dark" onClick={() => toast('3 new reviews this week · avg 4.9')} aria-label="Notifications"><Icon name="Bell" size={20} /><span className="dot" style={{ boxShadow: '0 0 0 2px #1a2160' }} /></button>
        </div>
        <div className="row gap-12" style={{ marginTop: 18, padding: '12px 14px', borderRadius: 16, background: 'rgba(255,255,255,.1)' }}>
          <span style={{ width: 10, height: 10, borderRadius: 5, background: s.online ? '#4ade80' : '#9ca3af', boxShadow: s.online ? '0 0 0 4px rgba(74,222,128,.25)' : 'none' }} />
          <div className="grow">
            <div style={{ fontWeight: 700, fontSize: 14.5 }}>{s.online ? 'Online for instant consults' : 'Offline'}</div>
            <div style={{ fontSize: 12, opacity: 0.7 }}>{s.online ? `Patients can reach you now · ${money(s.region, s.fees.video)} per consult` : 'Only booked appointments'}</div>
          </div>
          <Toggle on={s.online} onChange={(v) => { set((p) => ({ ...p, online: v })); toast(v ? 'You’re online' : 'You’re offline'); }} label="Online" />
        </div>
      </div>

      <div className="pad" style={{ marginTop: -54 }}>
        <div className="card row" style={{ padding: '16px 6px' }}>
          {[
            { v: money(s.region, Math.round(net)), l: 'Earned today', icon: 'Wallet' },
            { v: `${done}/${s.queue.length}`, l: 'Patients seen', icon: 'Users' },
            { v: me.rating.toFixed(1), l: 'Rating', icon: 'Star' },
          ].map((x, i) => (
            <div key={x.l} className="grow stack center gap-4" style={{ borderLeft: i ? '1px solid var(--line)' : 0 }}>
              <div className="t-h2 num">{x.v}</div>
              <div className="t-xs row gap-4"><Icon name={x.icon} size={12} />{x.l}</div>
            </div>
          ))}
        </div>

        {next && (() => {
          const p = patient(next.patientId);
          const mins = Math.round((next.t - now) / 60000);
          return (
            <div className="card" style={{ marginTop: 16, padding: 18, boxShadow: 'inset 0 0 0 2px var(--brand), var(--shadow)' }}>
              <div className="row between">
                <span className="t-label" style={{ color: 'var(--brand)' }}>Up next</span>
                <span className={`badge ${STATUS[next.status].cls}`}>{next.status === 'waiting' ? `${next.mode === 'video' ? 'In waiting room' : 'Checked in'}` : mins > 0 ? `In ${mins} min` : 'Now'}</span>
              </div>
              <div className="row gap-12" style={{ marginTop: 12 }}>
                <Avatar name={p.name} hue={p.hue} size={54} />
                <div className="grow">
                  <div className="t-h3">{p.name}</div>
                  <div className="t-sm">{p.age} y · {p.sex === 'M' ? 'Male' : 'Female'} · {next.mode === 'video' ? 'Video' : 'Clinic'} · {fmtTime(next.t)}</div>
                </div>
              </div>
              <div style={{ marginTop: 12, padding: '10px 12px', borderRadius: 12, background: 'var(--surface-2)', fontSize: 14 }}>
                <b>Reason:</b> {next.reason}
                <div className="row gap-12 t-xs" style={{ marginTop: 6 }}>
                  <span>BP {p.vitals.bp}</span><span>Temp {p.vitals.temp}</span><span>SpO₂ {p.vitals.spo2}</span>
                </div>
                {p.allergies !== 'None' && <div className="row gap-6" style={{ marginTop: 6, color: 'var(--bad)', fontSize: 12.5, fontWeight: 700 }}><Icon name="TriangleAlert" size={13} />Allergic to {p.allergies}</div>}
              </div>
              <div className="row gap-10" style={{ marginTop: 14 }}>
                <button className="btn ghost" onClick={() => nav.push('patient', { id: p.id })}>Chart</button>
                <button className="btn grow" onClick={() => start(next)}><Icon name={next.mode === 'video' ? 'Video' : 'ClipboardPen'} size={18} />{next.mode === 'video' ? 'Start video consult' : 'Start consult'}</button>
              </div>
            </div>
          );
        })()}

        <div className="section-head"><div className="t-h2">Today’s patients</div><span className="t-sm">{s.queue.length - done} left</span></div>
        <div className="stack" style={{ position: 'relative' }}>
          {list.map((q, i) => {
            const p = patient(q.patientId);
            const st = STATUS[q.status];
            return (
              <div key={q.id} className="row gap-12 tap" onClick={() => (q.status === 'done' ? nav.push('patient', { id: p.id }) : start(q))} style={{ padding: '10px 0', alignItems: 'stretch' }}>
                <div className="stack center" style={{ width: 54, flex: 'none' }}>
                  <span className="num" style={{ fontSize: 13, fontWeight: 800, color: q.status === 'done' ? 'var(--muted)' : 'var(--ink)' }}>{fmtTime(q.t).replace(/\s?[AP]M/, '')}</span>
                  <span className="t-xs">{fmtTime(q.t).slice(-2)}</span>
                  {i < list.length - 1 && <span style={{ flex: 1, width: 2, background: 'var(--line)', marginTop: 6, borderRadius: 1 }} />}
                </div>
                <div className="card grow row gap-12" style={{ padding: 12, opacity: q.status === 'done' ? 0.7 : 1 }}>
                  <Avatar name={p.name} hue={p.hue} size={40} />
                  <div className="grow" style={{ minWidth: 0 }}>
                    <div style={{ fontWeight: 700, fontSize: 14.5 }} className="ellipsis">{p.name}{q.instant && <span className="badge accent" style={{ marginLeft: 6 }}>Instant</span>}</div>
                    <div className="t-xs ellipsis">{q.reason}</div>
                  </div>
                  <div className="stack gap-4" style={{ alignItems: 'flex-end' }}>
                    <span className={`badge ${st.cls}`}>{st.label}</span>
                    <Icon name={q.mode === 'video' ? 'Video' : 'Building2'} size={14} style={{ color: 'var(--muted)' }} />
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      <Sheet open={request} onClose={() => setRequest(false)}>
        <div className="stack gap-14">
          <div className="row between"><span className="badge accent"><Icon name="Zap" size={12} />Instant consult request</span><span className="t-xs">Expires in 60 s</span></div>
          <div className="row gap-12">
            <Avatar name={reqPatient.name} hue={120} size={56} />
            <div className="grow"><div className="t-h2">{reqPatient.name}</div><div className="t-sm">{reqPatient.age} y · Female · First visit</div></div>
          </div>
          <div style={{ padding: 12, borderRadius: 14, background: 'var(--surface-2)', fontSize: 14.5 }}><b>Concern:</b> Fever or flu since yesterday, mild sore throat.</div>
          <div className="row between card flat" style={{ padding: 14 }}>
            <span className="t-sm">You earn</span>
            <span className="t-h2 num">{money(s.region, Math.round(s.fees.video * (1 - commissionOf(s))))}</span>
          </div>
          <div className="row gap-10">
            <button className="btn ghost grow" onClick={() => { setRequest(false); toast('Request passed to the next doctor'); }}>Decline</button>
            <button className="btn good grow" onClick={() => {
              const id = `q-${Date.now()}`;
              set((p) => ({
                ...p,
                patients: p.patients.some((x) => x.id === 'p-new') ? p.patients : [...p.patients, { id: 'p-new', name: reqPatient.name, age: reqPatient.age, sex: 'F', hue: 120, conditions: [], allergies: 'None', vitals: { bp: '118/76', temp: '100.8°F', spo2: '98%', weight: '60 kg' }, visits: [] }],
                queue: [...p.queue, { id, patientId: 'p-new', t: Date.now(), mode: 'video', reason: 'Fever or flu since yesterday', fee: p.fees.video, status: 'in-consult', instant: true }],
              }));
              setRequest(false);
              nav.push('consult', { id });
            }}><Icon name="Video" size={18} />Accept</button>
          </div>
          <div className="t-xs" style={{ textAlign: 'center' }}>Instant consults pay {r.name === 'India' ? 'the same fee' : 'your video fee'} and count toward your search ranking</div>
        </div>
      </Sheet>
    </div>
  );
}

// ---------------------------------------------------------------- consult

export function Consult({ nav, id }: { nav: Nav; id: string }) {
  const { s, patient } = useD();
  const q = s.queue.find((x) => x.id === id)!;
  const p = patient(q.patientId);
  const [notes, setNotes] = useState('');
  return (
    <CallScreen
      name={p.name}
      sub={`${p.age} y · ${q.reason}`}
      hue={p.hue}
      selfName="Doctor"
      sideLabel="Notes"
      sidePanel={
        <div className="stack gap-10">
          <div className="row between"><span className="t-h3">{p.name}</span><span className="t-xs">{p.age} y · {p.sex}</span></div>
          <div className="row wrap gap-6">
            <span className="badge">BP {p.vitals.bp}</span><span className="badge">{p.vitals.temp}</span><span className="badge">SpO₂ {p.vitals.spo2}</span>
            {p.conditions.map((c) => <span key={c} className="badge brand">{c}</span>)}
            {p.allergies !== 'None' && <span className="badge bad">Allergy: {p.allergies}</span>}
          </div>
          <textarea className="input" rows={4} value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Consult notes (private to you)" />
        </div>
      }
      onEnd={() => nav.replace('prescribe', { id })}
    />
  );
}

// ---------------------------------------------------------------- prescribe

const DIAGNOSES = ['Viral fever', 'Upper respiratory infection', 'Acute gastritis', 'Migraine', 'Hypertension', 'Type 2 diabetes', 'Allergic rhinitis', 'Muscle strain'];
const ADVICE_TEMPLATES = [
  'Rest, drink 3 litres of fluids a day, steam inhalation twice daily. Return if fever persists beyond 3 days.',
  'Low-salt diet, 30 minutes of brisk walking daily. Check BP every morning and log it in the app.',
  'Avoid oily and spicy food, eat small frequent meals, no lying down within 2 hours of eating.',
];
const FOLLOW = ['3 days', '1 week', '2 weeks', '1 month', 'Not needed'];

export function Prescribe({ nav, id }: { nav: Nav; id: string }) {
  const { s, patient } = useD();
  const toast = useToast();
  const q = s.queue.find((x) => x.id === id)!;
  const p = patient(q.patientId);
  const [diagnosis, setDiagnosis] = useState('');
  const [meds, setMeds] = useState<RxMed[]>([]);
  const [tests, setTests] = useState<string[]>([]);
  const [advice, setAdvice] = useState('');
  const [follow, setFollow] = useState('1 week');
  const [adding, setAdding] = useState(false);
  const [draft, setDraft] = useState<RxMed>({ name: '', dose: '1-0-1', duration: '5 days', note: 'After food' });
  const [query, setQuery] = useState('');
  const pro = s.plan !== 'starter';

  return (
    <div className="screen has-cta">
      <TopBar title="Prescription" onBack={() => nav.back()} surface />
      <div className="pad stack gap-16" style={{ paddingTop: 16, paddingBottom: 12 }}>
        <div className="card row gap-12" style={{ padding: 14 }}>
          <Avatar name={p.name} hue={p.hue} size={46} />
          <div className="grow"><div className="t-h3">{p.name}</div><div className="t-xs">{p.age} y · {p.sex === 'M' ? 'Male' : 'Female'} · {q.reason}</div></div>
          {p.allergies !== 'None' && <span className="badge bad"><Icon name="TriangleAlert" size={12} />{p.allergies}</span>}
        </div>

        <div className="field">
          <label>Diagnosis</label>
          <input className="input" value={diagnosis} onChange={(e) => setDiagnosis(e.target.value)} placeholder="Type or pick below" />
          <div className="hscroll" style={{ paddingTop: 4 }}>{DIAGNOSES.map((d) => <button key={d} className={`chip${diagnosis === d ? ' on' : ''}`} style={{ height: 34, fontSize: 13 }} onClick={() => setDiagnosis(d)}>{d}</button>)}</div>
        </div>

        <div>
          <div className="row between" style={{ marginBottom: 8 }}><span className="t-h3">Medicines</span><span className="t-xs">{meds.length} added</span></div>
          <div className="stack gap-8">
            {meds.map((m, i) => (
              <div key={m.name} className="card row gap-12" style={{ padding: 12 }}>
                <span className="tile-icon sm" style={{ fontWeight: 800, fontSize: 13 }}>{i + 1}</span>
                <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>{m.name}</div><div className="t-xs">{m.dose} · {m.duration}{m.note ? ` · ${m.note}` : ''}</div></div>
                <button className="icon-btn ghost" onClick={() => setMeds(meds.filter((x) => x.name !== m.name))} aria-label="Remove"><Icon name="X" size={18} /></button>
              </div>
            ))}
            <button className="btn block soft" onClick={() => { setAdding(true); setQuery(''); setDraft({ name: '', dose: '1-0-1', duration: '5 days', note: 'After food' }); }}><Icon name="Plus" size={18} />Add medicine</button>
          </div>
        </div>

        <div>
          <div className="t-h3" style={{ marginBottom: 8 }}>Lab tests</div>
          <div className="row wrap gap-6">{COMMON_TESTS.map((t) => <button key={t} className={`chip${tests.includes(t) ? ' on' : ''}`} style={{ height: 34, fontSize: 13 }} onClick={() => setTests(tests.includes(t) ? tests.filter((x) => x !== t) : [...tests, t])}>{t}</button>)}</div>
        </div>

        <div className="field">
          <div className="row between"><label>Advice</label>{!pro && <span className="badge"><Icon name="Lock" size={11} />Templates in Pro</span>}</div>
          <textarea className="input" rows={3} value={advice} onChange={(e) => setAdvice(e.target.value)} placeholder="Diet, rest, warning signs to watch for" />
          <div className="stack gap-6">
            {ADVICE_TEMPLATES.map((a, i) => (
              <button key={i} className="chip" style={{ height: 'auto', padding: '8px 12px', whiteSpace: 'normal', textAlign: 'left', fontSize: 12.5, opacity: pro ? 1 : 0.55 }}
                onClick={() => (pro ? setAdvice(a) : nav.push('plans'))}>
                <Icon name={pro ? 'FileText' : 'Lock'} size={14} />{a.slice(0, 64)}…
              </button>
            ))}
          </div>
        </div>

        <div>
          <div className="t-h3" style={{ marginBottom: 8 }}>Follow-up</div>
          <div className="row wrap gap-6">{FOLLOW.map((f) => <button key={f} className={`chip${follow === f ? ' on' : ''}`} onClick={() => setFollow(f)}>{f === 'Not needed' ? f : `In ${f}`}</button>)}</div>
        </div>
      </div>
      <div className="cta-bar solid">
        <button className="btn block" disabled={!diagnosis.trim() || meds.length === 0} onClick={() => nav.push('rxPreview', {
          id, rx: { diagnosis: diagnosis.trim(), meds, tests, advice: advice.trim() || 'Follow the medicines as advised. Contact me if symptoms get worse.', followUp: follow === 'Not needed' ? undefined : `In ${follow}` },
        })}>
          {meds.length === 0 ? 'Add at least one medicine' : 'Preview and sign'}
        </button>
      </div>

      <Sheet open={adding} onClose={() => setAdding(false)}>
        <div className="stack gap-14">
          <div className="t-h2">Add medicine</div>
          {!draft.name ? (
            <>
              <div className="search" style={{ boxShadow: 'inset 0 0 0 1.5px var(--line)' }}>
                <Icon name="Search" size={18} /><input autoFocus value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search by name or salt" />
              </div>
              <div className="list" style={{ boxShadow: 'inset 0 0 0 1px var(--line)' }}>
                {MEDICINES.filter((m) => m.name.toLowerCase().includes(query.toLowerCase()) && !meds.some((x) => x.name === m.name)).slice(0, 6).map((m) => {
                  const clash = p.allergies !== 'None' && m.name.toLowerCase().includes(p.allergies.toLowerCase().slice(0, 6));
                  return (
                    <div key={m.name} className="list-row" onClick={() => (clash ? toast(`Allergy alert: ${p.name.split(' ')[0]} is allergic to ${p.allergies}`) : setDraft({ ...draft, name: m.name }))}>
                      <span className={`tile-icon sm ${clash ? 'bad' : 'neutral'}`}><Icon name={clash ? 'TriangleAlert' : 'Pill'} size={16} /></span>
                      <div className="grow"><div style={{ fontWeight: 700, fontSize: 14 }}>{m.name}</div><div className="t-xs">{clash ? 'Conflicts with allergy' : m.form}</div></div>
                    </div>
                  );
                })}
              </div>
            </>
          ) : (
            <>
              <div className="card flat row gap-10" style={{ padding: 12 }}><Icon name="Pill" size={18} className="t-brand" /><span className="grow" style={{ fontWeight: 700 }}>{draft.name}</span><button className="btn xs ghost" onClick={() => setDraft({ ...draft, name: '' })}>Change</button></div>
              <div><div className="t-sm" style={{ fontWeight: 700, marginBottom: 6 }}>Dose (morning-noon-night)</div><div className="row wrap gap-6">{DOSES.map((d) => <button key={d} className={`chip${draft.dose === d ? ' on' : ''}`} onClick={() => setDraft({ ...draft, dose: d })}>{d}</button>)}</div></div>
              <div><div className="t-sm" style={{ fontWeight: 700, marginBottom: 6 }}>Duration</div><div className="row wrap gap-6">{DURATIONS.map((d) => <button key={d} className={`chip${draft.duration === d ? ' on' : ''}`} onClick={() => setDraft({ ...draft, duration: d })}>{d}</button>)}</div></div>
              <div><div className="t-sm" style={{ fontWeight: 700, marginBottom: 6 }}>Instructions</div><div className="row wrap gap-6">{['After food', 'Before food', 'At bedtime', 'If needed'].map((d) => <button key={d} className={`chip${draft.note === d ? ' on' : ''}`} onClick={() => setDraft({ ...draft, note: d })}>{d}</button>)}</div></div>
              <button className="btn block" onClick={() => { setMeds([...meds, draft]); setAdding(false); }}>Add to prescription</button>
            </>
          )}
        </div>
      </Sheet>
    </div>
  );
}

export function RxPreview({ nav, id, rx }: { nav: Nav; id: string; rx: NonNullable<QueueItem['rx']> }) {
  const { s, set, me, patient } = useD();
  const toast = useToast();
  const q = s.queue.find((x) => x.id === id)!;
  const p = patient(q.patientId);
  const [signing, setSigning] = useState(false);
  const earn = Math.round(q.fee * (1 - commissionOf(s)) * 100) / 100;
  return (
    <div className="screen has-cta">
      <TopBar title="Review and sign" onBack={() => nav.back()} />
      <div className="pad" style={{ paddingBottom: 12 }}>
        <div className="card" style={{ overflow: 'hidden' }}>
          <div style={{ padding: 18, background: 'linear-gradient(135deg, #0e1330, #27307a)', color: '#fff' }}>
            <div className="t-h3">{me.name}</div>
            <div style={{ fontSize: 12.5, opacity: 0.8 }}>{me.degrees}</div>
            <div style={{ fontSize: 12, opacity: 0.65, marginTop: 2 }}>{me.clinic} · Reg. {s.region === 'IN' ? 'KMC 84213' : 'CA A-129874'}</div>
          </div>
          <div className="stack gap-12" style={{ padding: 18 }}>
            <div className="row between t-sm"><span><b style={{ color: 'var(--ink)' }}>{p.name}</b> · {p.age} y, {p.sex}</span><span>{fmtDay(Date.now())}</span></div>
            <div><div className="t-label">Diagnosis</div><div className="t-h3" style={{ marginTop: 4 }}>{rx.diagnosis}</div></div>
            <div className="stack gap-8">
              <div className="t-label">Rx</div>
              {rx.meds.map((m, i) => <div key={m.name} style={{ fontSize: 14 }}><b>{i + 1}. {m.name}</b><div className="t-sm">{m.dose} · {m.duration}{m.note ? ` · ${m.note}` : ''}</div></div>)}
            </div>
            {rx.tests.length > 0 && <div><div className="t-label">Tests</div><div className="row wrap gap-6" style={{ marginTop: 6 }}>{rx.tests.map((t) => <span key={t} className="badge brand">{t}</span>)}</div></div>}
            <div><div className="t-label">Advice</div><div className="t-body" style={{ fontSize: 14, marginTop: 4 }}>{rx.advice}</div></div>
            {rx.followUp && <div className="t-sm" style={{ fontWeight: 600 }}>Follow-up {rx.followUp.toLowerCase()}</div>}
            <div className="row between" style={{ borderTop: '1px dashed var(--line)', paddingTop: 12 }}>
              <span style={{ fontFamily: 'cursive', fontSize: 22, color: 'var(--brand)' }}>{me.name.replace('Dr. ', '')}</span>
              <Icon name="QrCode" size={34} />
            </div>
          </div>
        </div>
        <div className="row gap-8 t-sm" style={{ marginTop: 14 }}><Icon name="Send" size={15} className="t-brand" />Sent to {p.name.split(' ')[0]}’s CareLoop app, with one-tap medicine ordering and lab booking.</div>
      </div>
      <div className="cta-bar solid">
        <button className="btn block" disabled={signing} onClick={() => {
          setSigning(true);
          window.setTimeout(() => {
            set((st) => ({ ...st, queue: st.queue.map((x) => (x.id === id ? { ...x, status: 'done', rx } : x)), patients: st.patients.map((x) => (x.id === p.id ? { ...x, visits: [{ t: Date.now(), reason: q.reason, diagnosis: rx.diagnosis }, ...x.visits] } : x)) }));
            toast(`Prescription sent · ${money(s.region, earn)} added to earnings`);
            nav.reset();
          }, 900);
        }}>{signing ? <><span className="spinner" />Signing…</> : <><Icon name="PenLine" size={18} />Sign and send</>}</button>
      </div>
    </div>
  );
}
