import { useState } from 'react';
import { DAY, fmtDay, fmtTime, specialtyOf, startOfToday } from '../data/catalog';
import { REGIONS, money } from '../data/region';
import { BarChart } from '../ui/charts';
import { Avatar, Empty, Icon, SectionHead, Sheet, Stars, Toggle, TopBar, useToast, type Nav } from '../ui/kit';
import { commissionOf, seed, todayGross, useD } from './state';

// ---------------------------------------------------------------- schedule

export function Schedule({ nav }: { nav: Nav }) {
  const { s, set, patient } = useD();
  const toast = useToast();
  const [day, setDay] = useState(startOfToday());
  const [feeSheet, setFeeSheet] = useState(false);
  const [offSheet, setOffSheet] = useState(false);
  const [fees, setFees] = useState(s.fees);
  const days = Array.from({ length: 7 }, (_, i) => startOfToday() + i * DAY);
  const isToday = day === startOfToday();
  // Future days: a deterministic set of bookings from the patient list.
  const dayList = isToday
    ? [...s.queue].sort((a, b) => a.t - b.t)
    : s.patients.slice(0, 3 + (new Date(day).getDate() % 4)).map((p, i) => ({ id: `${day}-${i}`, patientId: p.id, t: day + (9.5 + i * 1.25) * 3600000, mode: (i % 2 ? 'clinic' : 'video') as 'video' | 'clinic', reason: p.visits[0]?.reason ?? 'Consultation', status: 'upcoming' as const }));
  const av = s.availability;
  const off = s.timeOff.includes(String(day));
  const setAv = (patch: Partial<typeof av>) => set((p) => ({ ...p, availability: { ...p.availability, ...patch } }));

  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="Schedule" left right={<button className="icon-btn" onClick={() => setOffSheet(true)} aria-label="Block time off"><Icon name="CalendarOff" size={19} /></button>} />
      <div className="pad stack gap-16">
        <div className="hscroll">
          {days.map((t) => (
            <button key={t} className={`date-pill${t === day ? ' on' : ''}`} onClick={() => setDay(t)} style={s.timeOff.includes(String(t)) ? { opacity: 0.5 } : undefined}>
              <span className="dow">{t === startOfToday() ? 'Today' : new Date(t).toLocaleDateString('en', { weekday: 'short' })}</span>
              <span className="d num">{new Date(t).getDate()}</span>
            </button>
          ))}
        </div>
        <div className="row between"><span className="t-h2">{fmtDay(day)}</span><span className="t-sm">{off ? 'Day off' : `${dayList.length} appointments`}</span></div>
        {off ? (
          <Empty icon="TreePalm" title="You’re off this day" body="Patients can’t book you. Existing bookings were moved with their consent."
            action={<button className="btn sm soft" onClick={() => set((p) => ({ ...p, timeOff: p.timeOff.filter((x) => x !== String(day)) }))}>Open this day again</button>} />
        ) : (
          <div className="list">
            {dayList.map((q) => {
              const p = patient(q.patientId);
              return (
                <div key={q.id} className="list-row" onClick={() => nav.push('patient', { id: p.id })}>
                  <div className="stack" style={{ width: 58 }}><span className="num" style={{ fontWeight: 800, fontSize: 14 }}>{fmtTime(q.t)}</span><span className="t-xs">{s.availability.slot} min</span></div>
                  <div className="grow" style={{ minWidth: 0 }}><div style={{ fontWeight: 700, fontSize: 14.5 }} className="ellipsis">{p.name}</div><div className="t-xs ellipsis">{q.reason}</div></div>
                  <span className={`badge ${q.mode === 'video' ? 'brand' : ''}`}><Icon name={q.mode === 'video' ? 'Video' : 'Building2'} size={12} />{q.mode === 'video' ? 'Video' : 'Clinic'}</span>
                </div>
              );
            })}
          </div>
        )}

        <SectionHead title="Availability" />
        <div className="card p stack gap-14">
          <div>
            <div className="t-sm" style={{ fontWeight: 700, marginBottom: 8 }}>Working days</div>
            <div className="row gap-6">
              {['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d, i) => (
                <button key={i} onClick={() => setAv({ days: av.days.map((x, j) => (j === i ? !x : x)) })}
                  style={{ flex: 1, height: 40, borderRadius: 12, border: 0, cursor: 'pointer', fontWeight: 800, background: av.days[i] ? 'var(--brand)' : 'var(--surface-2)', color: av.days[i] ? '#fff' : 'var(--muted)' }}>{d}</button>
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
            <div className="t-sm" style={{ fontWeight: 700, marginBottom: 8 }}>Slot length</div>
            <div className="segmented">{([15, 20, 30] as const).map((m) => <button key={m} className={av.slot === m ? 'on' : ''} onClick={() => setAv({ slot: m })}>{m} min</button>)}</div>
          </div>
        </div>

        <button className="card tap row gap-12" onClick={() => { setFees(s.fees); setFeeSheet(true); }} style={{ border: 0, padding: 16, textAlign: 'left' }}>
          <span className="tile-icon accent"><Icon name={s.region === 'IN' ? 'IndianRupee' : 'DollarSign'} size={20} /></span>
          <div className="grow"><div className="t-h3">Consultation fees</div><div className="t-sm">Video {money(s.region, s.fees.video)} · Clinic {money(s.region, s.fees.clinic)}</div></div>
          <Icon name="ChevronRight" size={18} className="chev" />
        </button>
      </div>

      <Sheet open={feeSheet} onClose={() => setFeeSheet(false)}>
        <div className="stack gap-14">
          <div className="t-h2">Consultation fees</div>
          {(['video', 'clinic'] as const).map((k) => {
            const step = s.region === 'IN' ? 50 : 5;
            return (
              <div key={k} className="row gap-12">
                <div className="grow"><div style={{ fontWeight: 700 }}>{k === 'video' ? 'Video consult' : 'Clinic visit'}</div><div className="t-xs">Similar doctors charge {money(s.region, k === 'video' ? (s.region === 'IN' ? 550 : 69) : (s.region === 'IN' ? 750 : 99))}</div></div>
                <div className="row gap-6" style={{ background: 'var(--surface-2)', borderRadius: 14, padding: 4 }}>
                  <button className="icon-btn ghost" style={{ width: 36, height: 36 }} onClick={() => setFees({ ...fees, [k]: Math.max(step, fees[k] - step) })} aria-label="Lower"><Icon name="Minus" size={16} /></button>
                  <span className="num" style={{ fontWeight: 800, minWidth: 64, textAlign: 'center' }}>{money(s.region, fees[k])}</span>
                  <button className="icon-btn ghost" style={{ width: 36, height: 36 }} onClick={() => setFees({ ...fees, [k]: fees[k] + step })} aria-label="Raise"><Icon name="Plus" size={16} /></button>
                </div>
              </div>
            );
          })}
          <div className="t-xs">You keep {Math.round((1 - commissionOf(s)) * 100)}% on your {REGIONS[s.region].doctorPlans.find((p) => p.id === s.plan)!.name} plan.</div>
          <button className="btn block" onClick={() => { set((p) => ({ ...p, fees })); setFeeSheet(false); toast('Fees updated for new bookings'); }}>Save fees</button>
        </div>
      </Sheet>

      <Sheet open={offSheet} onClose={() => setOffSheet(false)}>
        <div className="stack gap-12">
          <div className="t-h2">Block time off</div>
          <div className="t-sm">Patients with bookings are offered another doctor or a new slot.</div>
          <div className="list" style={{ boxShadow: 'inset 0 0 0 1px var(--line)' }}>
            {days.slice(1).map((t) => {
              const on = s.timeOff.includes(String(t));
              return (
                <div key={t} className="list-row" onClick={() => set((p) => ({ ...p, timeOff: on ? p.timeOff.filter((x) => x !== String(t)) : [...p.timeOff, String(t)] }))}>
                  <div className="grow" style={{ fontWeight: 700 }}>{fmtDay(t)}</div>
                  <Toggle on={on} onChange={() => undefined} label={fmtDay(t)} />
                </div>
              );
            })}
          </div>
          <button className="btn block" onClick={() => { setOffSheet(false); toast('Calendar updated'); }}>Done</button>
        </div>
      </Sheet>
    </div>
  );
}

// ---------------------------------------------------------------- patients

export function Patients({ nav }: { nav: Nav }) {
  const { s } = useD();
  const [q, setQ] = useState('');
  const list = s.patients.filter((p) => [p.name, ...p.conditions].join(' ').toLowerCase().includes(q.toLowerCase()));
  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="Patients" left />
      <div className="pad stack gap-14">
        <div className="search"><Icon name="Search" size={18} /><input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search by name or condition" /></div>
        <div className="row gap-10">
          {[{ v: s.patients.length, l: 'Patients' }, { v: s.patients.filter((p) => p.conditions.length).length, l: 'Chronic care' }, { v: '92%', l: 'Return rate' }].map((x) => (
            <div key={x.l} className="card grow stack center" style={{ padding: 12 }}><div className="t-h2 num">{x.v}</div><div className="t-xs">{x.l}</div></div>
          ))}
        </div>
        <div className="list">
          {list.map((p) => (
            <div key={p.id} className="list-row" onClick={() => nav.push('patient', { id: p.id })}>
              <Avatar name={p.name} hue={p.hue} size={44} />
              <div className="grow" style={{ minWidth: 0 }}>
                <div style={{ fontWeight: 700, fontSize: 14.5 }}>{p.name}</div>
                <div className="t-xs ellipsis">{p.age} y · {p.sex} · Last: {p.visits[0] ? p.visits[0].diagnosis : 'New patient'}</div>
              </div>
              {p.conditions[0] && <span className="badge brand">{p.conditions[0]}</span>}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export function PatientChart({ nav, id }: { nav: Nav; id: string }) {
  const { s, patient } = useD();
  const toast = useToast();
  const p = patient(id);
  const pending = s.queue.find((q) => q.patientId === id && q.status !== 'done');
  return (
    <div className="screen has-cta">
      <TopBar title="Patient chart" onBack={() => nav.back()} right={<button className="icon-btn" onClick={() => toast('Secure message sent')} aria-label="Message"><Icon name="MessageCircle" size={19} /></button>} />
      <div className="pad stack gap-16" style={{ paddingBottom: 12 }}>
        <div className="card p-lg row gap-14">
          <Avatar name={p.name} hue={p.hue} size={64} />
          <div className="grow">
            <div className="t-h2">{p.name}</div>
            <div className="t-sm">{p.age} years · {p.sex === 'M' ? 'Male' : 'Female'}</div>
            <div className="row wrap gap-6" style={{ marginTop: 8 }}>
              {p.conditions.map((c) => <span key={c} className="badge brand">{c}</span>)}
              {p.allergies !== 'None' && <span className="badge bad"><Icon name="TriangleAlert" size={11} />{p.allergies}</span>}
            </div>
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {[['Blood pressure', p.vitals.bp, 'HeartPulse'], ['Temperature', p.vitals.temp, 'Thermometer'], ['SpO₂', p.vitals.spo2, 'Wind'], ['Weight', p.vitals.weight, 'Scale']].map(([l, v, icon]) => (
            <div key={l} className="card stack gap-6" style={{ padding: 14 }}>
              <div className="row gap-6 t-xs"><Icon name={icon} size={13} />{l}</div>
              <div className="t-h2 num">{v}</div>
            </div>
          ))}
        </div>
        <SectionHead title="Visit history" />
        <div className="stack gap-10">
          {p.visits.length === 0 && <div className="t-sm">First visit with you.</div>}
          {p.visits.map((v, i) => (
            <div key={i} className="row gap-12" style={{ alignItems: 'flex-start' }}>
              <span className="tile-icon sm" style={{ marginTop: 2 }}><Icon name="FileText" size={16} /></span>
              <div className="grow card" style={{ padding: 12 }}>
                <div className="row between"><span style={{ fontWeight: 700, fontSize: 14 }}>{v.diagnosis}</span><span className="t-xs">{fmtDay(v.t)}</span></div>
                <div className="t-sm">{v.reason}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
      <div className="cta-bar solid">
        {pending ? (
          <button className="btn block" onClick={() => nav.push(pending.mode === 'video' ? 'consult' : 'prescribe', { id: pending.id })}><Icon name="Video" size={18} />Start today’s consult</button>
        ) : (
          <button className="btn block soft" onClick={() => toast(`Follow-up reminder sent to ${p.name.split(' ')[0]}`)}><Icon name="CalendarPlus" size={18} />Send follow-up reminder</button>
        )}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- earnings

export function Earnings({ nav }: { nav: Nav }) {
  const { s } = useD();
  const toast = useToast();
  const r = REGIONS[s.region];
  const rate = commissionOf(s);
  const today = todayGross(s);
  const days = Array.from({ length: 7 }, (_, i) => startOfToday() - (6 - i) * DAY);
  const data = days.map((t, i) => ({ label: i === 6 ? 'Today' : new Date(t).toLocaleDateString('en', { weekday: 'short' }), value: i === 6 ? today : s.week[i] }));
  const gross = data.reduce((a, d) => a + d.value, 0);
  const fee = gross * rate;
  const net = gross - fee;
  const consults = Math.round(gross / s.fees.video);
  const pro = r.doctorPlans.find((p) => p.id === 'pro')!;
  const proSaving = gross * (rate - pro.commission) * 4.3 - pro.price;

  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="Earnings" left right={<button className="icon-btn" onClick={() => toast('Statement emailed (PDF + CSV)')} aria-label="Download statement"><Icon name="Download" size={19} /></button>} />
      <div className="pad stack gap-16">
        <div className="hero">
          <div style={{ position: 'relative' }}>
            <div className="t-sm">Available to withdraw</div>
            <div className="t-display num" style={{ fontSize: 36, marginTop: 4 }}>{money(s.region, Math.round(net * 0.62))}</div>
            <div className="row gap-10" style={{ marginTop: 14 }}>
              <button className="btn white sm" onClick={() => toast(`Payout started · arrives in ${s.region === 'IN' ? '24 hours via IMPS' : '1–2 business days'}`)}><Icon name="ArrowDownToLine" size={16} />Withdraw</button>
              <span className="t-xs" style={{ color: 'rgba(255,255,255,.8)' }}>Auto-payout every Monday</span>
            </div>
          </div>
        </div>

        <div className="card p">
          <div className="row between" style={{ marginBottom: 8 }}>
            <div><div className="t-h3">Gross consult revenue</div><div className="t-xs">Last 7 days · tap a bar</div></div>
            <div style={{ textAlign: 'right' }}><div className="t-h2 num">{money(s.region, gross)}</div><div className="t-xs">{consults} consults</div></div>
          </div>
          <BarChart data={data} format={(v) => money(s.region, v)} />
        </div>

        <div className="card p">
          <div className="kv"><span>Consultations</span><span className="num">{money(s.region, gross)}</span></div>
          <div className="kv"><span>Platform fee ({Math.round(rate * 100)}%)</span><span className="num">−{money(s.region, Math.round(fee))}</span></div>
          <div className="divider" />
          <div className="kv total"><span>Your earnings</span><span className="num">{money(s.region, Math.round(net))}</span></div>
        </div>

        {s.plan === 'starter' && proSaving > 0 && (
          <button className="card tap row gap-12" onClick={() => nav.push('plans')} style={{ border: 0, padding: 16, textAlign: 'left', background: 'linear-gradient(120deg, #fff7e6, #ffefc7)' }}>
            <span className="tile-icon accent" style={{ background: '#fff' }}><Icon name="Rocket" size={20} /></span>
            <div className="grow"><div className="t-h3">Keep {money(s.region, Math.round(proSaving))} more a month</div><div className="t-sm" style={{ color: '#7a5a14' }}>Pro halves your platform fee to {Math.round(pro.commission * 100)}% for {money(s.region, pro.price)}/month.</div></div>
            <Icon name="ChevronRight" size={18} style={{ color: '#9a6b00' }} />
          </button>
        )}

        <SectionHead title="Payouts" />
        <div className="list">
          {s.payouts.map((p) => (
            <div key={p.t} className="list-row no-tap">
              <span className="tile-icon sm good"><Icon name="Landmark" size={17} /></span>
              <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>{s.region === 'IN' ? 'HDFC Bank ••4821' : 'Chase ••7710'}</div><div className="t-xs">{fmtDay(p.t)}</div></div>
              <div style={{ textAlign: 'right' }}><div className="num" style={{ fontWeight: 800 }}>{money(s.region, p.amount)}</div><span className="badge good">{p.status}</span></div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- profile and plans

export function DoctorProfile({ nav }: { nav: Nav }) {
  const { s, set, me } = useD();
  const toast = useToast();
  const plan = REGIONS[s.region].doctorPlans.find((p) => p.id === s.plan)!;
  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="Profile" left />
      <div className="pad stack gap-16">
        <div className="card p-lg stack center gap-8" style={{ textAlign: 'center' }}>
          <Avatar name={me.name} hue={me.hue} size={84} square />
          <div className="row gap-6" style={{ marginTop: 6 }}><span className="t-h2">{me.name}</span><Icon name="BadgeCheck" size={20} className="t-brand" /></div>
          <div className="t-sm">{specialtyOf(me.specialty).name} · {me.years} yrs · {me.clinic}</div>
          <div className="row gap-12" style={{ marginTop: 4 }}><Stars rating={me.rating} count={me.reviews} /><span className="badge good"><Icon name="ShieldCheck" size={12} />License verified</span></div>
        </div>

        <button className="hero tap" onClick={() => nav.push('plans')} style={{ border: 0, textAlign: 'left' }}>
          <div className="row gap-12" style={{ position: 'relative' }}>
            <span className="tile-icon" style={{ background: 'rgba(255,255,255,.16)', color: '#fff' }}><Icon name="Gem" size={22} /></span>
            <div className="grow"><div className="t-h3">{plan.name} plan</div><div className="t-sm">{Math.round(plan.commission * 100)}% platform fee · {plan.price ? `${money(s.region, plan.price)}/month` : 'Free'}</div></div>
            <span className="btn xs white">{s.plan === 'starter' ? 'Upgrade' : 'Manage'}</span>
          </div>
        </button>

        <div className="list">
          {[
            { icon: 'Building2', label: 'Clinic details', sub: `${me.clinic}, ${me.area}` },
            { icon: 'Languages', label: 'Languages', sub: me.languages.join(', ') },
            { icon: 'Signature', label: 'Prescription letterhead and signature', sub: 'Digital signature on file' },
            { icon: 'Landmark', label: 'Bank account for payouts', sub: s.region === 'IN' ? 'HDFC Bank ••4821' : 'Chase ••7710' },
            { icon: 'MessageSquareHeart', label: 'Reviews', sub: `${me.reviews.toLocaleString()} reviews · 97% recommend` },
          ].map((r) => (
            <div key={r.label} className="list-row" onClick={() => toast(`${r.label} saved`)}>
              <span className="tile-icon sm neutral"><Icon name={r.icon} size={17} /></span>
              <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>{r.label}</div><div className="t-xs ellipsis">{r.sub}</div></div>
              <Icon name="ChevronRight" size={18} className="chev" />
            </div>
          ))}
        </div>
        <button className="btn block danger" onClick={() => set((p) => ({ ...seed(p.region), stage: 'welcome' }))}><Icon name="LogOut" size={18} />Sign out</button>
        <div className="t-xs" style={{ textAlign: 'center', paddingBottom: 8 }}>CareLoop Pro 1.0 · Demo data, nothing leaves this phone</div>
      </div>
    </div>
  );
}

export function Plans({ nav }: { nav: Nav }) {
  const { s, set } = useD();
  const toast = useToast();
  const r = REGIONS[s.region];
  const gross = s.week.reduce((a, b) => a + b, 0) * 4.3;
  return (
    <div className="screen">
      <TopBar title="Plans" onBack={() => nav.back()} />
      <div className="pad stack gap-14" style={{ paddingBottom: 24 }}>
        <div className="t-body">Pay less commission as your practice grows. Based on your last month, here’s what you’d keep:</div>
        {r.doctorPlans.map((p) => {
          const keep = gross * (1 - p.commission) - p.price;
          const current = s.plan === p.id;
          return (
            <div key={p.id} className="card" style={{ padding: 18, boxShadow: current ? 'inset 0 0 0 2px var(--brand), var(--shadow)' : p.id === 'pro' ? 'inset 0 0 0 2px var(--accent), var(--shadow)' : 'var(--shadow)' }}>
              <div className="row between">
                <div className="row gap-8"><span className="t-h2">{p.name}</span>{p.id === 'pro' && <span className="badge accent">Most popular</span>}</div>
                <div style={{ textAlign: 'right' }}><span className="t-h2 num">{p.price ? money(s.region, p.price) : 'Free'}</span>{p.price > 0 && <span className="t-xs">/mo</span>}</div>
              </div>
              <div className="t-sm" style={{ marginTop: 4 }}>{Math.round(p.commission * 100)}% platform fee per consult</div>
              <div className="stack gap-8" style={{ margin: '14px 0' }}>
                {p.perks.map((x) => <div key={x} className="row gap-8" style={{ fontSize: 14 }}><Icon name="Check" size={16} style={{ color: 'var(--good)' }} />{x}</div>)}
              </div>
              <div className="row between" style={{ padding: '10px 12px', borderRadius: 12, background: 'var(--surface-2)' }}>
                <span className="t-sm">You keep each month</span><span className="num" style={{ fontWeight: 800 }}>{money(s.region, Math.round(keep))}</span>
              </div>
              <button className={`btn block ${current ? 'ghost' : p.id === 'pro' ? 'accent' : ''}`} style={{ marginTop: 12 }} disabled={current}
                onClick={() => { set((st) => ({ ...st, plan: p.id })); toast(`You’re on ${p.name}`); nav.back(); }}>
                {current ? 'Current plan' : `Switch to ${p.name}`}
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}
