import { useEffect, useRef, useState } from 'react';
import { addDoc, collection, orderBy } from 'firebase/firestore';
import { DAY, fmtDay, fmtTime, relDay, specialtyOf, startOfToday } from '../data/catalog';
import { REGIONS, money } from '../data/region';
import { logOut, resetPassword } from '../lib/auth';
import { markRead, sendMessage } from '../lib/care';
import { errorText, useQuery } from '../lib/db';
import { db } from '../lib/firebase';
import type { MessageDoc } from '../lib/model';
import { usePay } from '../lib/pay';
import { BarChart } from '../ui/charts';
import { Avatar, Empty, Icon, SectionHead, Sheet, Stars, Toggle, TopBar, useToast, type Nav } from '../ui/kit';
import { commissionOf, earnings, patientsOf, updateDoctor, useD } from './ctx';
import { PracticeFields, formOf, practiceOf, practiceValid } from './Onboarding';

const hueOf = (id: string) => (id.charCodeAt(0) * 7) % 360;

// ---------------------------------------------------------------- schedule

export function Schedule({ nav }: { nav: Nav }) {
  const { uid, doc: d, appts } = useD();
  const toast = useToast();
  const [day, setDay] = useState(startOfToday());
  const [feeSheet, setFeeSheet] = useState(false);
  const [offSheet, setOffSheet] = useState(false);
  const [fees, setFees] = useState({ video: d.feeVideo, clinic: d.feeClinic });
  const days = Array.from({ length: 14 }, (_, i) => startOfToday() + i * DAY);
  const dayList = (appts ?? []).filter((a) => a.day === day && a.status !== 'cancelled').sort((a, b) => a.t - b.t);
  const av = d.availability;
  const off = d.timeOff?.includes(day);
  const working = av.days[new Date(day).getDay()];
  const setAv = (patch: Partial<typeof av>) => updateDoctor(uid, { availability: { ...av, ...patch } });
  const toggleOff = (t: number) => updateDoctor(uid, { timeOff: d.timeOff?.includes(t) ? d.timeOff.filter((x) => x !== t) : [...(d.timeOff ?? []), t] });

  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="Schedule" left right={<button className="icon-btn" onClick={() => setOffSheet(true)} aria-label="Block days off"><Icon name="CalendarOff" size={19} /></button>} />
      <div className="pad stack gap-16">
        <div className="hscroll">
          {days.map((t) => {
            const n = (appts ?? []).filter((a) => a.day === t && a.status !== 'cancelled').length;
            return (
              <button key={t} className={`date-pill${t === day ? ' on' : ''}`} onClick={() => setDay(t)} style={!av.days[new Date(t).getDay()] || d.timeOff?.includes(t) ? { opacity: 0.45 } : undefined}>
                <span className="dow">{t === startOfToday() ? 'Today' : new Date(t).toLocaleDateString('en', { weekday: 'short' })}</span>
                <span className="d num">{new Date(t).getDate()}</span>
                {n > 0 && <span style={{ width: 6, height: 6, borderRadius: 3, background: t === day ? '#fff' : 'var(--brand)' }} />}
              </button>
            );
          })}
        </div>
        <div className="row between"><span className="t-h2">{fmtDay(day)}</span><span className="t-sm">{off ? 'Day off' : !working ? 'Not a working day' : `${dayList.length} booked`}</span></div>
        {off ? (
          <Empty icon="TreePalm" title="You’re off this day" body="Patients can’t book new visits. Existing bookings stay unless you cancel them." action={<button className="btn sm soft" onClick={() => toggleOff(day)}>Open this day again</button>} />
        ) : dayList.length === 0 ? (
          <div className="card flat p t-sm">{working ? 'No bookings yet. Open slots are visible to patients.' : 'Turn this weekday on below to take bookings.'}</div>
        ) : (
          <div className="list">
            {dayList.map((a) => (
              <div key={a.id} className="list-row" onClick={() => nav.push('consult', { id: a.id })}>
                <div className="stack" style={{ width: 62 }}><span className="num" style={{ fontWeight: 800, fontSize: 14 }}>{fmtTime(a.t)}</span><span className="t-xs">{av.slot} min</span></div>
                <div className="grow" style={{ minWidth: 0 }}><div style={{ fontWeight: 700, fontSize: 14.5 }} className="ellipsis">{a.member}</div><div className="t-xs ellipsis">{a.reason}</div></div>
                <span className={`badge ${a.mode === 'video' ? 'brand' : ''}`}><Icon name={a.mode === 'video' ? 'Video' : 'Building2'} size={12} />{a.status === 'completed' ? 'Seen' : a.mode === 'video' ? 'Video' : 'Clinic'}</span>
              </div>
            ))}
          </div>
        )}

        <SectionHead title="Availability" />
        <div className="card p stack gap-14">
          <div>
            <div className="t-sm" style={{ fontWeight: 700, marginBottom: 8 }}>Working days</div>
            <div className="row gap-6">
              {['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((x, i) => (
                <button key={i} onClick={() => setAv({ days: av.days.map((y, j) => (j === i ? !y : y)) })} aria-pressed={av.days[i]} aria-label={['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][i]}
                  style={{ flex: 1, height: 40, borderRadius: 12, border: 0, cursor: 'pointer', fontWeight: 800, background: av.days[i] ? 'var(--brand)' : 'var(--surface-2)', color: av.days[i] ? '#fff' : 'var(--muted)' }}>{x}</button>
              ))}
            </div>
          </div>
          {([['morning', 'Morning', '9 AM – 1 PM', 'Sunrise'], ['afternoon', 'Afternoon', '2 PM – 5 PM', 'Sun'], ['evening', 'Evening', '5 PM – 8 PM', 'Sunset']] as const).map(([k, label, hours, icon]) => (
            <div key={k} className="row gap-12">
              <span className="tile-icon sm neutral"><Icon name={icon} size={17} /></span>
              <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>{label}</div><div className="t-xs">{hours}</div></div>
              <Toggle on={av[k]} onChange={(v) => setAv({ [k]: v })} label={label} />
            </div>
          ))}
          <div>
            <div className="t-sm" style={{ fontWeight: 700, marginBottom: 8 }}>Visit length</div>
            <div className="segmented">{([15, 20, 30] as const).map((m) => <button key={m} className={av.slot === m ? 'on' : ''} onClick={() => setAv({ slot: m })}>{m} min</button>)}</div>
          </div>
        </div>

        <button className="card tap row gap-12" onClick={() => { setFees({ video: d.feeVideo, clinic: d.feeClinic }); setFeeSheet(true); }} style={{ border: 0, padding: 16, textAlign: 'left' }}>
          <span className="tile-icon accent"><Icon name={d.region === 'IN' ? 'IndianRupee' : 'DollarSign'} size={20} /></span>
          <div className="grow"><div className="t-h3">Consultation fees</div><div className="t-sm">Video {money(d.region, d.feeVideo)} · Clinic {money(d.region, d.feeClinic)}</div></div>
          <Icon name="ChevronRight" size={18} className="chev" />
        </button>
      </div>

      <Sheet open={feeSheet} onClose={() => setFeeSheet(false)}>
        <div className="stack gap-14">
          <div className="t-h2">Consultation fees</div>
          {(['video', 'clinic'] as const).map((k) => {
            const step = d.region === 'IN' ? 50 : 5;
            return (
              <div key={k} className="row gap-12">
                <div className="grow"><div style={{ fontWeight: 700 }}>{k === 'video' ? 'Video consult' : 'Clinic visit'}</div><div className="t-xs">Applies to new bookings</div></div>
                <div className="row gap-6" style={{ background: 'var(--surface-2)', borderRadius: 14, padding: 4 }}>
                  <button className="icon-btn ghost" style={{ width: 36, height: 36 }} onClick={() => setFees({ ...fees, [k]: Math.max(step, fees[k] - step) })} aria-label="Lower"><Icon name="Minus" size={16} /></button>
                  <span className="num" style={{ fontWeight: 800, minWidth: 64, textAlign: 'center' }}>{money(d.region, fees[k])}</span>
                  <button className="icon-btn ghost" style={{ width: 36, height: 36 }} onClick={() => setFees({ ...fees, [k]: fees[k] + step })} aria-label="Raise"><Icon name="Plus" size={16} /></button>
                </div>
              </div>
            );
          })}
          <div className="t-xs">You keep {Math.round((1 - commissionOf(d)) * 100)}% on the {REGIONS[d.region].doctorPlans.find((p) => p.id === d.plan)!.name} plan.</div>
          <button className="btn block" onClick={async () => { await updateDoctor(uid, { feeVideo: fees.video, feeClinic: fees.clinic }); setFeeSheet(false); toast('Fees updated for new bookings'); }}>Save fees</button>
        </div>
      </Sheet>

      <Sheet open={offSheet} onClose={() => setOffSheet(false)}>
        <div className="stack gap-12">
          <div className="t-h2">Days off</div>
          <div className="t-sm">Patients can’t book you on days you block.</div>
          <div className="list" style={{ boxShadow: 'inset 0 0 0 1px var(--line)' }}>
            {days.slice(0, 10).map((t) => (
              <div key={t} className="list-row" onClick={() => toggleOff(t)}>
                <div className="grow" style={{ fontWeight: 700 }}>{fmtDay(t)}</div>
                <span className={`toggle${d.timeOff?.includes(t) ? ' on' : ''}`} aria-hidden />
              </div>
            ))}
          </div>
          <button className="btn block" onClick={() => setOffSheet(false)}>Done</button>
        </div>
      </Sheet>
    </div>
  );
}

// ---------------------------------------------------------------- patients

export function Patients({ nav }: { nav: Nav }) {
  const { appts } = useD();
  const [q, setQ] = useState('');
  const all = patientsOf(appts ?? []);
  const list = all.filter((p) => [p.name, ...(p.latest.patientInfo?.conditions ?? [])].join(' ').toLowerCase().includes(q.toLowerCase()));
  const returning = all.filter((p) => p.visits.length > 1).length;
  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="Patients" left />
      <div className="pad stack gap-14">
        <div className="search"><Icon name="Search" size={18} /><input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search by name or condition" aria-label="Search patients" /></div>
        <div className="row gap-10">
          {[{ v: all.length, l: 'Patients' }, { v: (appts ?? []).filter((a) => a.status === 'completed').length, l: 'Consults' }, { v: all.length ? `${Math.round((returning / all.length) * 100)}%` : '—', l: 'Returning' }].map((x) => (
            <div key={x.l} className="card grow stack center" style={{ padding: 12 }}><div className="t-h2 num">{x.v}</div><div className="t-xs">{x.l}</div></div>
          ))}
        </div>
        {appts && all.length === 0 && <Empty icon="Users" title="No patients yet" body="Patients appear here after they book you or you accept an instant consult." />}
        {list.length > 0 && (
          <div className="list">
            {list.map((p) => (
              <div key={p.key} className="list-row" onClick={() => nav.push('patient', { pkey: p.key })}>
                <Avatar name={p.name} hue={hueOf(p.patientId)} size={44} />
                <div className="grow" style={{ minWidth: 0 }}>
                  <div style={{ fontWeight: 700, fontSize: 14.5 }}>{p.name}</div>
                  <div className="t-xs ellipsis">{[p.latest.patientInfo?.age && `${p.latest.patientInfo.age} y`, `${p.visits.length} visit${p.visits.length > 1 ? 's' : ''}`, `last ${relDay(p.latest.t).toLowerCase()}`].filter(Boolean).join(' · ')}</div>
                </div>
                {p.latest.patientInfo?.conditions?.[0] && <span className="badge brand">{p.latest.patientInfo.conditions[0]}</span>}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export function PatientChart({ nav, pkey }: { nav: Nav; pkey: string }) {
  const { appts } = useD();
  const p = patientsOf(appts ?? []).find((x) => x.key === pkey);
  if (!p) return <div className="screen"><TopBar onBack={() => nav.back()} /></div>;
  const info = p.latest.patientInfo ?? {};
  const open = p.visits.find((a) => ['booked', 'waiting', 'in-consult'].includes(a.status));
  return (
    <div className="screen has-cta">
      <TopBar title="Patient chart" onBack={() => nav.back()} />
      <div className="pad stack gap-16" style={{ paddingBottom: 12 }}>
        <div className="card p-lg row gap-14">
          <Avatar name={p.name} hue={hueOf(p.patientId)} size={64} />
          <div className="grow">
            <div className="t-h2">{p.name}</div>
            <div className="t-sm">{[info.age && `${info.age} years`, info.sex].filter(Boolean).join(' · ')}</div>
            <div className="row wrap gap-6" style={{ marginTop: 8 }}>
              {(info.conditions ?? []).map((c) => <span key={c} className="badge brand">{c}</span>)}
              {info.allergies && info.allergies !== 'None' && <span className="badge bad"><Icon name="TriangleAlert" size={11} />{info.allergies}</span>}
            </div>
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10 }}>
          {[['BP', info.bp, 'mmHg'], ['Sugar', info.sugar, 'mg/dL'], ['Weight', info.weight, 'kg']].map(([l, v, u]) => (
            <div key={l as string} className="card stack gap-4" style={{ padding: 12 }}><div className="t-xs">{l}</div><div className="t-h2 num">{v ?? '—'}</div><div className="t-xs">{v ? u : 'not logged'}</div></div>
          ))}
        </div>
        <SectionHead title="Visits with you" />
        <div className="stack gap-10">
          {p.visits.map((v) => (
            <div key={v.id} className="card tap" style={{ padding: 12 }} onClick={() => nav.push('consult', { id: v.id })}>
              <div className="row between"><span style={{ fontWeight: 700, fontSize: 14 }}>{v.rx?.diagnosis ?? v.reason}</span><span className="t-xs">{fmtDay(v.t)}</span></div>
              <div className="t-xs">{v.rx ? v.rx.meds.map((m) => m.name).join(', ') : v.status === 'cancelled' ? 'Cancelled' : 'No prescription yet'}</div>
            </div>
          ))}
        </div>
      </div>
      <div className="cta-bar solid">
        {open
          ? <button className="btn block" onClick={() => nav.push('consult', { id: open.id })}><Icon name="Video" size={18} />Open {relDay(open.t).toLowerCase()}’s consult</button>
          : <button className="btn block soft" onClick={() => nav.push('chat', { id: p.latest.id })}><Icon name="MessageCircle" size={18} />Message {p.name.split(' ')[0]}</button>}
      </div>
    </div>
  );
}

export function VisitChat({ nav, id }: { nav: Nav; id: string }) {
  const { uid, appts } = useD();
  const a = appts?.find((x) => x.id === id);
  const msgs = useQuery<MessageDoc>(`msgs-${id}`, `appointments/${id}/messages`, orderBy('t'));
  const [text, setText] = useState('');
  const end = useRef<HTMLDivElement>(null);
  useEffect(() => { end.current?.scrollIntoView({ behavior: 'smooth' }); markRead(id); }, [msgs, id]);
  if (!a) return null;
  return (
    <div className="app">
      <div className="topbar on-surface">
        <button className="icon-btn" onClick={() => nav.back()} aria-label="Back"><Icon name="ChevronLeft" size={22} /></button>
        <Avatar name={a.member} hue={hueOf(a.patientId)} size={40} />
        <div className="grow"><div className="t-h3">{a.member}</div><div className="t-xs">{a.rx?.diagnosis ?? a.reason}</div></div>
      </div>
      <div className="screen" style={{ padding: '16px 16px 8px' }}>
        <div className="stack gap-8">
          {msgs?.length === 0 && <div className="t-sm" style={{ textAlign: 'center' }}>No messages yet.</div>}
          {(msgs ?? []).map((m) => {
            const mine = m.from === uid;
            return (
              <div key={m.id} style={{ alignSelf: mine ? 'flex-end' : 'flex-start', maxWidth: '80%', padding: '10px 14px', borderRadius: 18, fontSize: 14.5, lineHeight: 1.45, background: mine ? 'var(--brand)' : 'var(--surface)', color: mine ? '#fff' : 'var(--ink)', boxShadow: mine ? 'none' : 'var(--shadow)', whiteSpace: 'pre-wrap' }}>
                {m.text}<div style={{ fontSize: 10.5, opacity: 0.65, marginTop: 4, textAlign: 'right' }}>{fmtTime(m.t)}</div>
              </div>
            );
          })}
          <div ref={end} />
        </div>
      </div>
      <form className="row gap-8" style={{ padding: '8px 12px 14px', background: 'var(--surface)', borderTop: '1px solid var(--line)' }} onSubmit={async (e) => { e.preventDefault(); if (!text.trim()) return; const t = text; setText(''); await sendMessage(a, uid, t); }}>
        <input className="input" style={{ height: 46 }} value={text} onChange={(e) => setText(e.target.value)} placeholder="Message" aria-label="Message" />
        <button type="submit" className="icon-btn" style={{ background: 'var(--brand)', color: '#fff', boxShadow: 'none' }} aria-label="Send"><Icon name="SendHorizontal" size={19} /></button>
      </form>
    </div>
  );
}

// ---------------------------------------------------------------- earnings

export function Earnings({ nav }: { nav: Nav }) {
  const { uid, doc: d, appts, payouts } = useD();
  const toast = useToast();
  const [busy, setBusy] = useState(false);
  const e = earnings(d, appts ?? [], payouts ?? []);
  const days = Array.from({ length: 7 }, (_, i) => startOfToday() - (6 - i) * DAY);
  const data = days.map((t, i) => ({ label: i === 6 ? 'Today' : new Date(t).toLocaleDateString('en', { weekday: 'short' }), value: e.done.filter((a) => a.day === t).reduce((s, a) => s + a.fee, 0) }));
  const week = data.reduce((s, x) => s + x.value, 0);
  const pro = REGIONS[d.region].doctorPlans.find((p) => p.id === 'pro')!;
  const monthly = (e.done.filter((a) => a.t > Date.now() - 30 * DAY).reduce((s, a) => s + a.fee, 0));
  const proSaving = monthly * (e.rate - pro.commission) - pro.price;
  const minPayout = d.region === 'IN' ? 500 : 20;

  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="Earnings" left />
      <div className="pad stack gap-16">
        <div className="hero">
          <div style={{ position: 'relative' }}>
            <div className="t-sm">Available to withdraw</div>
            <div className="t-display num" style={{ fontSize: 36, marginTop: 4 }}>{money(d.region, e.available)}</div>
            <div className="row gap-10" style={{ marginTop: 14 }}>
              <button className="btn white sm" disabled={busy || e.available < minPayout} onClick={async () => {
                setBusy(true);
                try { await addDoc(collection(db, 'payouts'), { doctorId: uid, amount: e.available, t: Date.now(), status: 'requested' }); toast(`Payout of ${money(d.region, e.available)} requested`); }
                catch (x) { toast(errorText(x)); }
                setBusy(false);
              }}><Icon name="ArrowDownToLine" size={16} />Withdraw</button>
              <span className="t-xs" style={{ color: 'rgba(255,255,255,.8)' }}>{e.available < minPayout ? `Minimum ${money(d.region, minPayout)}` : 'Arrives in 1–2 business days'}</span>
            </div>
          </div>
        </div>
        <div className="card p">
          <div className="row between" style={{ marginBottom: 8 }}>
            <div><div className="t-h3">Consult revenue</div><div className="t-xs">Last 7 days · tap a bar</div></div>
            <div style={{ textAlign: 'right' }}><div className="t-h2 num">{money(d.region, week)}</div><div className="t-xs">{e.done.filter((a) => a.t > Date.now() - 7 * DAY).length} consults</div></div>
          </div>
          <BarChart data={data} format={(v) => money(d.region, v)} />
        </div>
        <div className="card p">
          <div className="kv"><span>All-time consults</span><span className="num">{money(d.region, e.gross)}</span></div>
          <div className="kv"><span>Platform fee ({Math.round(e.rate * 100)}%)</span><span className="num">−{money(d.region, e.fee)}</span></div>
          <div className="kv"><span>Paid out or requested</span><span className="num">−{money(d.region, Math.round((e.net - e.available) * 100) / 100)}</span></div>
          <div className="divider" />
          <div className="kv total"><span>Your earnings</span><span className="num">{money(d.region, e.net)}</span></div>
        </div>
        {d.plan === 'starter' && proSaving > 0 && (
          <button className="card tap row gap-12" onClick={() => nav.push('plans')} style={{ border: 0, padding: 16, textAlign: 'left', background: 'linear-gradient(120deg, #fff7e6, #ffefc7)' }}>
            <span className="tile-icon accent" style={{ background: '#fff' }}><Icon name="Rocket" size={20} /></span>
            <div className="grow"><div className="t-h3">Keep {money(d.region, Math.round(proSaving))} more a month</div><div className="t-sm" style={{ color: '#7a5a14' }}>Pro halves your platform fee to {Math.round(pro.commission * 100)}%.</div></div>
            <Icon name="ChevronRight" size={18} style={{ color: '#9a6b00' }} />
          </button>
        )}
        <SectionHead title="Payouts" />
        {(payouts ?? []).length === 0 ? <div className="t-sm" style={{ paddingBottom: 16 }}>No payouts yet.</div> : (
          <div className="list">
            {[...payouts!].sort((a, b) => b.t - a.t).map((p) => (
              <div key={p.id} className="list-row no-tap">
                <span className="tile-icon sm good"><Icon name="Landmark" size={17} /></span>
                <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>Bank transfer</div><div className="t-xs">{fmtDay(p.t)}</div></div>
                <div style={{ textAlign: 'right' }}><div className="num" style={{ fontWeight: 800 }}>{money(d.region, p.amount)}</div><span className={`badge ${p.status === 'paid' ? 'good' : 'warn'}`}>{p.status === 'paid' ? 'Paid' : 'Processing'}</span></div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- profile and plans

export function DoctorProfile({ nav }: { nav: Nav }) {
  const { me, doc: d } = useD();
  const toast = useToast();
  const [confirmOut, setConfirmOut] = useState(false);
  const plan = REGIONS[d.region].doctorPlans.find((p) => p.id === d.plan)!;
  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="Profile" left />
      <div className="pad stack gap-16">
        <div className="card p-lg stack center gap-8" style={{ textAlign: 'center' }}>
          <Avatar name={d.name} hue={d.hue} size={84} square />
          <div className="row gap-6" style={{ marginTop: 6 }}><span className="t-h2">{d.name}</span><Icon name="BadgeCheck" size={20} className="t-brand" /></div>
          <div className="t-sm">{specialtyOf(d.specialty).name} · {d.years} yrs{d.clinic ? ` · ${d.clinic}` : ''}</div>
          <div className="row gap-12" style={{ marginTop: 4 }}>{d.ratingCount ? <Stars rating={d.ratingSum / d.ratingCount} count={d.ratingCount} /> : <span className="badge">No reviews yet</span>}<span className="badge good"><Icon name="ShieldCheck" size={12} />License verified</span></div>
        </div>
        <button className="hero tap" onClick={() => nav.push('plans')} style={{ border: 0, textAlign: 'left' }}>
          <div className="row gap-12" style={{ position: 'relative' }}>
            <span className="tile-icon" style={{ background: 'rgba(255,255,255,.16)', color: '#fff' }}><Icon name="Gem" size={22} /></span>
            <div className="grow"><div className="t-h3">{plan.name} plan</div><div className="t-sm">{Math.round(plan.commission * 100)}% platform fee · {plan.price ? `${money(d.region, plan.price)}/month` : 'Free'}</div></div>
            <span className="btn xs white">{d.plan === 'starter' ? 'Upgrade' : 'Manage'}</span>
          </div>
        </button>
        <div className="list">
          {[
            { icon: 'Building2', label: 'Practice details', sub: [d.degrees, d.clinic, d.area].filter(Boolean).join(' · '), go: () => nav.push('editPractice') },
            { icon: 'KeyRound', label: 'Change password', sub: me.email ?? 'Phone login', go: async () => { if (!me.email) return; try { await resetPassword(me.email); toast(`Reset link sent to ${me.email}`); } catch (x) { toast(errorText(x)); } } },
          ].map((r) => (
            <div key={r.label} className="list-row" onClick={r.go}>
              <span className="tile-icon sm neutral"><Icon name={r.icon} size={17} /></span>
              <div className="grow" style={{ minWidth: 0 }}><div style={{ fontWeight: 700, fontSize: 14.5 }}>{r.label}</div><div className="t-xs ellipsis">{r.sub}</div></div>
              <Icon name="ChevronRight" size={18} className="chev" />
            </div>
          ))}
        </div>
        <button className="btn block danger" onClick={() => setConfirmOut(true)}><Icon name="LogOut" size={18} />Log out</button>
        <div className="t-xs" style={{ textAlign: 'center', paddingBottom: 8 }}>CareLoop Pro 2.0 · {REGIONS[d.region].compliance}</div>
      </div>
      <Sheet open={confirmOut} onClose={() => setConfirmOut(false)}>
        <div className="stack gap-12">
          <div className="t-h2">Log out?</div>
          <div className="t-body">You’ll stop receiving instant consult requests on this phone.</div>
          <button className="btn block danger" onClick={async () => { await updateDoctor(d.id, { online: false }); await logOut(); }}>Log out</button>
          <button className="btn block ghost" onClick={() => setConfirmOut(false)}>Stay logged in</button>
        </div>
      </Sheet>
    </div>
  );
}

export function EditPractice({ nav }: { nav: Nav }) {
  const { uid, doc: d } = useD();
  const toast = useToast();
  const [f, setF] = useState(formOf(d, d.region));
  const [busy, setBusy] = useState(false);
  return (
    <form className="screen has-cta" onSubmit={async (e) => {
      e.preventDefault(); setBusy(true);
      try { await updateDoctor(uid, practiceOf(f)); toast('Practice details saved'); nav.back(); } catch (x) { toast(errorText(x)); setBusy(false); }
    }}>
      <TopBar title="Practice details" onBack={() => nav.back()} />
      <div className="pad stack gap-14" style={{ paddingBottom: 12 }}><PracticeFields f={f} set={(p) => setF({ ...f, ...p })} region={d.region} /></div>
      <div className="cta-bar solid"><button className="btn block" type="submit" disabled={!practiceValid(f) || busy}>Save</button></div>
    </form>
  );
}

export function Plans({ nav }: { nav: Nav }) {
  const { uid, me, doc: d, appts } = useD();
  const pay = usePay();
  const toast = useToast();
  const [busy, setBusy] = useState<string | null>(null);
  const r = REGIONS[d.region];
  const monthly = (appts ?? []).filter((a) => a.status === 'completed' && a.t > Date.now() - 30 * DAY).reduce((s, a) => s + a.fee, 0);
  return (
    <div className="screen">
      <TopBar title="Plans" onBack={() => nav.back()} />
      <div className="pad stack gap-14" style={{ paddingBottom: 24 }}>
        <div className="t-body">Pay less commission as your practice grows.{monthly ? ' Based on your last 30 days, here’s what you’d keep:' : ''}</div>
        {r.doctorPlans.map((p) => {
          const current = d.plan === p.id;
          return (
            <div key={p.id} className="card" style={{ padding: 18, boxShadow: current ? 'inset 0 0 0 2px var(--brand), var(--shadow)' : p.id === 'pro' ? 'inset 0 0 0 2px var(--accent), var(--shadow)' : 'var(--shadow)' }}>
              <div className="row between">
                <div className="row gap-8"><span className="t-h2">{p.name}</span>{p.id === 'pro' && <span className="badge accent">Most popular</span>}</div>
                <div style={{ textAlign: 'right' }}><span className="t-h2 num">{p.price ? money(d.region, p.price) : 'Free'}</span>{p.price > 0 && <span className="t-xs">/mo</span>}</div>
              </div>
              <div className="t-sm" style={{ marginTop: 4 }}>{Math.round(p.commission * 100)}% platform fee per consult</div>
              <div className="stack gap-8" style={{ margin: '14px 0' }}>{p.perks.map((x) => <div key={x} className="row gap-8" style={{ fontSize: 14 }}><Icon name="Check" size={16} style={{ color: 'var(--good)' }} />{x}</div>)}</div>
              {monthly > 0 && <div className="row between" style={{ padding: '10px 12px', borderRadius: 12, background: 'var(--surface-2)' }}><span className="t-sm">You’d keep each month</span><span className="num" style={{ fontWeight: 800 }}>{money(d.region, Math.round(monthly * (1 - p.commission) - p.price))}</span></div>}
              <button className={`btn block ${current ? 'ghost' : p.id === 'pro' ? 'accent' : ''}`} style={{ marginTop: 12 }} disabled={current || busy !== null} onClick={async () => {
                if (p.price > 0) {
                  const payment = await pay({ region: d.region, amount: p.price, title: `CareLoop Pro · ${p.name} plan (1 month)`, prefill: { name: me.name, email: me.email, phone: me.phone } });
                  if (!payment) return;
                }
                setBusy(p.id);
                try { await updateDoctor(uid, { plan: p.id }); toast(`You’re on ${p.name}`); nav.back(); } catch (x) { toast(errorText(x)); setBusy(null); }
              }}>{busy === p.id ? <span className="spinner" /> : current ? 'Current plan' : `Switch to ${p.name}`}</button>
            </div>
          );
        })}
      </div>
    </div>
  );
}
