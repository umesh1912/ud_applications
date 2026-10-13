import { useMemo, useState } from 'react';
import { DAY, SPECIALTIES, dow, fmtDay, fmtTime, relDay, slotsFor, specialtyOf, startOfToday, type Doctor } from '../data/catalog';
import { REGIONS, money } from '../data/region';
import { Avatar, Icon, SectionHead, Segmented, Stars, TopBar, useToast, type Nav } from '../ui/kit';
import { priceFor, useP, type Appt } from './state';

type Mode = 'video' | 'clinic';

// ---------------------------------------------------------------- search

export function Search({ nav, specialty: initialSpec, mode: initialMode, focus }: { nav: Nav; specialty?: string; mode?: Mode; focus?: boolean }) {
  const { s, docs } = useP();
  const [q, setQ] = useState('');
  const [spec, setSpec] = useState<string | undefined>(initialSpec);
  const [mode, setMode] = useState<Mode | undefined>(initialMode);
  const [today, setToday] = useState(false);
  const [sort, setSort] = useState<'relevance' | 'rating' | 'fee'>('relevance');

  const list = useMemo(() => {
    const term = q.trim().toLowerCase();
    let out = docs.filter((d) => {
      const sp = specialtyOf(d.specialty);
      if (spec && d.specialty !== spec) return false;
      if (today && !(d.nextFree.startsWith('in') || d.nextFree.startsWith('Today'))) return false;
      if (mode === 'clinic' && d.area === 'Online only') return false;
      if (!term) return true;
      return [d.name, sp.name, sp.symptoms, d.clinic, d.area, ...d.languages].join(' ').toLowerCase().includes(term);
    });
    if (sort === 'rating') out = [...out].sort((a, b) => b.rating - a.rating);
    if (sort === 'fee') out = [...out].sort((a, b) => (mode === 'clinic' ? a.feeClinic - b.feeClinic : a.feeVideo - b.feeVideo));
    return out;
  }, [docs, q, spec, today, mode, sort]);

  return (
    <div className="screen">
      <div className="topbar">
        <button className="icon-btn" onClick={() => nav.back()} aria-label="Back"><Icon name="ChevronLeft" size={22} /></button>
        <div className="search grow" style={{ height: 44, boxShadow: 'inset 0 0 0 1.5px var(--line)' }}>
          <Icon name="Search" size={18} />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Doctor, symptom or clinic" autoFocus={focus} aria-label="Search" />
          {q && <button className="icon-btn ghost" style={{ width: 28, height: 28 }} onClick={() => setQ('')} aria-label="Clear"><Icon name="X" size={16} /></button>}
        </div>
      </div>
      <div className="pad">
        <div className="hscroll" style={{ paddingTop: 4 }}>
          <button className={`chip${!spec ? ' on' : ''}`} onClick={() => setSpec(undefined)}>All</button>
          {SPECIALTIES.map((sp) => (
            <button key={sp.id} className={`chip${spec === sp.id ? ' on' : ''}`} onClick={() => setSpec(spec === sp.id ? undefined : sp.id)}>
              <Icon name={sp.icon} size={15} />{sp.name}
            </button>
          ))}
        </div>
        <div className="hscroll">
          <button className={`chip${today ? ' on' : ''}`} onClick={() => setToday(!today)}><Icon name="Clock" size={15} />Available today</button>
          <button className={`chip${mode === 'video' ? ' on' : ''}`} onClick={() => setMode(mode === 'video' ? undefined : 'video')}><Icon name="Video" size={15} />Video</button>
          <button className={`chip${mode === 'clinic' ? ' on' : ''}`} onClick={() => setMode(mode === 'clinic' ? undefined : 'clinic')}><Icon name="Building2" size={15} />In clinic</button>
        </div>
        <div className="row between" style={{ margin: '10px 0 12px' }}>
          <div className="t-sm"><b style={{ color: 'var(--ink)' }}>{list.length}</b> doctors{spec ? ` for ${specialtyOf(spec).name.toLowerCase()}` : ''}</div>
          <select value={sort} onChange={(e) => setSort(e.target.value as typeof sort)} aria-label="Sort"
            style={{ border: 0, background: 'none', fontWeight: 700, fontSize: 13, color: 'var(--brand)' }}>
            <option value="relevance">Sort: Relevance</option>
            <option value="rating">Sort: Rating</option>
            <option value="fee">Sort: Lowest fee</option>
          </select>
        </div>
        <div className="stack gap-12" style={{ paddingBottom: 24 }}>
          {list.map((d) => <DoctorCard key={d.id} d={d} mode={mode ?? 'video'} region={s.region} onOpen={() => nav.push('doctor', { id: d.id, mode })} />)}
          {list.length === 0 && (
            <div className="empty stack center gap-8">
              <Icon name="SearchX" size={32} />
              <div className="t-h3" style={{ color: 'var(--ink)' }}>No doctors match</div>
              <div className="t-sm">Try another symptom, or clear the filters.</div>
              <button className="btn sm soft" onClick={() => { setQ(''); setSpec(undefined); setToday(false); setMode(undefined); }}>Clear filters</button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function DoctorCard({ d, mode, region, onOpen }: { d: Doctor; mode: Mode; region: 'IN' | 'US'; onOpen: () => void }) {
  const soon = d.nextFree.startsWith('in');
  return (
    <div className="card tap" onClick={onOpen} style={{ padding: 16 }}>
      <div className="row gap-12" style={{ alignItems: 'flex-start' }}>
        <Avatar name={d.name} hue={d.hue} size={64} square online={soon} />
        <div className="grow stack gap-4">
          <div className="row gap-6"><span className="t-h3 ellipsis">{d.name}</span><Icon name="BadgeCheck" size={16} className="t-brand" /></div>
          <div className="t-sm">{specialtyOf(d.specialty).name} · {d.years} yrs exp</div>
          <div className="row gap-10 wrap" style={{ marginTop: 2 }}>
            <Stars rating={d.rating} count={d.reviews} />
            <span className="t-xs row gap-4"><Icon name="MapPin" size={12} />{d.area === 'Online only' ? 'Online only' : `${d.distanceKm} km`}</span>
          </div>
        </div>
      </div>
      <div className="divider" style={{ margin: '14px 0 12px' }} />
      <div className="row between">
        <div>
          <div className={`t-xs ${soon ? 't-good' : ''}`} style={{ color: soon ? 'var(--good)' : undefined }}>{soon ? `Available ${d.nextFree}` : `Next: ${d.nextFree}`}</div>
          <div className="num" style={{ fontWeight: 800, fontSize: 16, marginTop: 2 }}>{money(region, mode === 'clinic' ? d.feeClinic : d.feeVideo)}<span className="t-xs"> / {mode === 'clinic' ? 'visit' : 'video'}</span></div>
        </div>
        <button className="btn sm" onClick={(e) => { e.stopPropagation(); onOpen(); }}>Book</button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- doctor profile + slot picker

export function DoctorProfile({ nav, id, mode: initialMode }: { nav: Nav; id: string; mode?: Mode }) {
  const { s, doctor } = useP();
  const toast = useToast();
  const d = doctor(id);
  const [saved, setSaved] = useState(false);
  const online = d.area === 'Online only';
  const [mode, setMode] = useState<Mode>(online ? 'video' : initialMode ?? 'video');
  const [day, setDay] = useState(startOfToday());
  const [slot, setSlot] = useState<number | null>(null);
  const days = Array.from({ length: 7 }, (_, i) => startOfToday() + i * DAY);
  const slots = slotsFor(d.id, day);
  const groups = [
    { label: 'Morning', icon: 'Sunrise', list: slots.filter((x) => new Date(x.t).getHours() < 12) },
    { label: 'Afternoon', icon: 'Sun', list: slots.filter((x) => { const h = new Date(x.t).getHours(); return h >= 12 && h < 17; }) },
    { label: 'Evening', icon: 'Sunset', list: slots.filter((x) => new Date(x.t).getHours() >= 17) },
  ];
  const fee = mode === 'clinic' ? d.feeClinic : d.feeVideo;
  const sp = specialtyOf(d.specialty);

  return (
    <div className="screen has-cta">
      <TopBar onBack={() => nav.back()} right={<button className="icon-btn" aria-label="Save doctor" onClick={() => { setSaved(!saved); toast(saved ? 'Removed from saved doctors' : 'Saved to your doctors'); }}><Icon name="Heart" size={20} style={saved ? { color: 'var(--accent)', fill: 'var(--accent)' } : undefined} /></button>} />
      <div className="pad">
        <div className="stack center gap-8" style={{ textAlign: 'center' }}>
          <Avatar name={d.name} hue={d.hue} size={96} square online={d.nextFree.startsWith('in')} />
          <div className="row gap-6" style={{ marginTop: 6 }}><span className="t-h1">{d.name}</span><Icon name="BadgeCheck" size={20} className="t-brand" /></div>
          <div className="t-sm">{d.degrees}</div>
          <div className="row gap-6"><span className="badge brand"><Icon name={sp.icon} size={12} />{sp.name}</span><span className="badge">{d.languages.join(', ')}</span></div>
        </div>
        <div className="card row" style={{ marginTop: 18, padding: '14px 4px' }}>
          {[
            { v: `${(d.patients / 1000).toFixed(1)}k`, l: 'Patients', icon: 'Users' },
            { v: `${d.years} yrs`, l: 'Experience', icon: 'Award' },
            { v: d.rating.toFixed(1), l: `${d.reviews.toLocaleString()} reviews`, icon: 'Star' },
          ].map((x, i) => (
            <div key={x.l} className="grow stack center gap-4" style={{ borderLeft: i ? '1px solid var(--line)' : 0 }}>
              <Icon name={x.icon} size={18} className="t-brand" />
              <div className="t-h3 num">{x.v}</div>
              <div className="t-xs">{x.l}</div>
            </div>
          ))}
        </div>

        {!online && (
          <div style={{ marginTop: 18 }}>
            <Segmented options={[{ id: 'video', label: `Video · ${money(s.region, d.feeVideo)}` }, { id: 'clinic', label: `Clinic · ${money(s.region, d.feeClinic)}` }]} value={mode} onChange={(m) => setMode(m)} />
          </div>
        )}
        <div className="row gap-8 t-sm" style={{ marginTop: 12, color: 'var(--good)', fontWeight: 600 }}><Icon name="Gift" size={16} />{d.perk}</div>

        <SectionHead title="Pick a time" />
        <div className="hscroll">
          {days.map((t) => (
            <button key={t} className={`date-pill${t === day ? ' on' : ''}`} onClick={() => { setDay(t); setSlot(null); }}>
              <span className="dow">{t === startOfToday() ? 'Today' : dow(t)}</span>
              <span className="d num">{new Date(t).getDate()}</span>
            </button>
          ))}
        </div>
        <div className="stack gap-16" style={{ marginTop: 12 }}>
          {groups.map((g) => (
            <div key={g.label}>
              <div className="row gap-6 t-sm" style={{ fontWeight: 700, marginBottom: 8 }}><Icon name={g.icon} size={15} />{g.label} · {g.list.filter((x) => !x.taken).length} open</div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
                {g.list.map((x) => (
                  <button key={x.t} className={`slot num${slot === x.t ? ' on' : ''}`} disabled={x.taken} onClick={() => setSlot(x.t)}>{fmtTime(x.t).replace(' ', '')}</button>
                ))}
              </div>
            </div>
          ))}
        </div>

        <SectionHead title="About" />
        <div className="t-body">{d.about}</div>
        {mode === 'clinic' && (
          <>
            <SectionHead title="Clinic" />
            <div className="card" style={{ overflow: 'hidden' }}>
              <div className="ph" style={{ height: 120, borderRadius: 0 }}>map · {d.area}</div>
              <div className="row gap-12" style={{ padding: 14 }}>
                <span className="tile-icon sm"><Icon name="Building2" size={18} /></span>
                <div className="grow"><div className="t-h3">{d.clinic}</div><div className="t-sm">{d.area} · {d.distanceKm} km away</div></div>
                <button className="icon-btn" aria-label="Directions"><Icon name="Navigation" size={18} /></button>
              </div>
            </div>
          </>
        )}
        <SectionHead title="Patient stories" />
        <div className="stack gap-10" style={{ paddingBottom: 20 }}>
          {d.topReviews.map((r) => (
            <div key={r.name} className="card p stack gap-8">
              <div className="row between"><span className="t-h3">{r.name}</span><span className="t-xs">{r.when}</span></div>
              <div className="row gap-4">{Array.from({ length: 5 }, (_, i) => <Icon key={i} name="Star" size={14} style={{ color: 'var(--star)', fill: i < r.rating ? 'var(--star)' : 'none' }} />)}</div>
              <div className="t-body" style={{ fontSize: 14 }}>{r.text}</div>
            </div>
          ))}
        </div>
      </div>
      <div className="cta-bar solid">
        <div className="grow">
          <div className="t-xs">{slot ? `${relDay(slot)}, ${fmtTime(slot)}` : 'Choose a slot'}</div>
          <div className="t-h2 num">{money(s.region, fee)}</div>
        </div>
        <button className="btn" disabled={!slot} onClick={() => nav.push('book', { doctorId: d.id, mode, t: slot })}>Book appointment</button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- instant consult

const CONCERNS = ['Fever or flu', 'Cough or cold', 'Stomach upset', 'Headache', 'Skin rash', 'Allergy', 'Body pain', 'Something else'];

export function Instant({ nav }: { nav: Nav }) {
  const { s, docs } = useP();
  const [concern, setConcern] = useState<string | null>(null);
  const gp = docs.find((d) => d.specialty === 'gp')!;
  return (
    <div className="screen has-cta">
      <TopBar title="Instant consult" onBack={() => nav.back()} />
      <div className="pad stack gap-16">
        <div className="hero">
          <div className="row gap-8" style={{ position: 'relative' }}><span className="hero-pill"><Icon name="Zap" size={14} />Avg. wait 8 min</span></div>
          <div className="t-h1" style={{ marginTop: 12, position: 'relative' }}>Talk to a doctor now, no appointment</div>
          <div className="t-sm" style={{ marginTop: 6, position: 'relative' }}>A general physician joins by video. Prescription in the app, free follow-up for 7 days.</div>
        </div>
        <div className="t-h3">What do you need help with?</div>
        <div className="row wrap gap-8">
          {CONCERNS.map((c) => <button key={c} className={`chip${concern === c ? ' on' : ''}`} onClick={() => setConcern(c)}>{c}</button>)}
        </div>
        <div className="card row gap-12" style={{ padding: 14 }}>
          <Avatar name={gp.name} hue={gp.hue} size={52} online />
          <div className="grow">
            <div className="t-xs t-good" style={{ color: 'var(--good)' }}>Next available doctor</div>
            <div className="t-h3">{gp.name}</div>
            <Stars rating={gp.rating} count={gp.reviews} />
          </div>
        </div>
        <div className="stack gap-8 t-sm">
          {['Doctors verified with the medical council', 'Consult is private and encrypted', 'Full refund if no doctor joins in 30 minutes'].map((t) => (
            <div key={t} className="row gap-8"><Icon name="Check" size={16} className="t-good" style={{ color: 'var(--good)' }} />{t}</div>
          ))}
        </div>
      </div>
      <div className="cta-bar solid">
        <div className="grow"><div className="t-xs">Consult fee</div><div className="t-h2 num">{money(s.region, gp.feeVideo)}</div></div>
        <button className="btn" disabled={!concern} onClick={() => nav.push('book', { doctorId: gp.id, mode: 'video', t: Date.now() + 2 * 60000, reason: concern, instant: true })}>Continue</button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- checkout

const REASONS = ['Fever', 'Follow-up', 'Second opinion', 'Report review', 'New symptoms'];

export function Book({ nav, doctorId, mode, t, reason: initialReason, instant }: { nav: Nav; doctorId: string; mode: Mode; t: number; reason?: string; instant?: boolean }) {
  const { s, set, doctor } = useP();
  const toast = useToast();
  const d = doctor(doctorId);
  const r = REGIONS[s.region];
  const members = [s.user.name, ...s.family.map((f) => f.name)];
  const [member, setMember] = useState(s.user.name);
  const [reason, setReason] = useState(initialReason ?? '');
  const [pay, setPay] = useState(r.pay[0].id);
  const [paying, setPaying] = useState(false);
  const fee = mode === 'clinic' ? d.feeClinic : d.feeVideo;
  const price = priceFor(s, fee);
  const insurance = pay === 'insurance';
  const copay = s.region === 'US' ? 25 : 0;
  const total = insurance ? copay : price.total;

  const confirm = () => {
    setPaying(true);
    window.setTimeout(() => {
      const id = `a-${Date.now()}`;
      const appt: Appt = { id, doctorId, member, mode, t, reason: reason || 'Consultation', paid: total, status: 'upcoming' };
      set((p) => ({ ...p, appts: [appt, ...p.appts] }));
      nav.replace('booked', { id, instant });
      toast('Payment successful');
    }, 1300);
  };

  return (
    <div className="screen has-cta">
      <TopBar title="Confirm booking" onBack={() => nav.back()} />
      <div className="pad stack gap-16" style={{ paddingBottom: 12 }}>
        <div className="card row gap-12" style={{ padding: 14 }}>
          <Avatar name={d.name} hue={d.hue} size={56} square />
          <div className="grow">
            <div className="t-h3">{d.name}</div>
            <div className="t-sm">{specialtyOf(d.specialty).name}</div>
            <div className="row gap-6" style={{ marginTop: 6 }}>
              <span className="badge brand"><Icon name={mode === 'video' ? 'Video' : 'Building2'} size={12} />{mode === 'video' ? 'Video' : 'Clinic'}</span>
              <span className="badge"><Icon name="Calendar" size={12} />{instant ? 'Now' : `${relDay(t)}, ${fmtTime(t)}`}</span>
            </div>
          </div>
        </div>

        <div>
          <div className="t-h3" style={{ marginBottom: 10 }}>Who is this for?</div>
          <div className="hscroll">
            {members.map((m, i) => (
              <button key={m} className={`chip${member === m ? ' on' : ''}`} onClick={() => setMember(m)} style={{ height: 44 }}>
                {i === 0 ? 'Myself' : `${m.split(' ')[0]} (${s.family[i - 1].relation})`}
              </button>
            ))}
            <button className="chip" onClick={() => nav.push('family')}><Icon name="Plus" size={15} />Add</button>
          </div>
        </div>

        <div className="field">
          <label>Reason for visit</label>
          <textarea className="input" rows={3} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Describe your symptoms, how long you’ve had them, any medicines you’re taking" />
          <div className="row wrap gap-6">{REASONS.map((x) => <button key={x} className="chip" style={{ height: 32, fontSize: 12.5 }} onClick={() => setReason((v) => (v ? `${v}, ${x.toLowerCase()}` : x))}>+ {x}</button>)}</div>
        </div>

        <div>
          <div className="t-h3" style={{ marginBottom: 10 }}>Pay with</div>
          <div className="list">
            {r.pay.map((m) => (
              <div key={m.id} className="list-row" onClick={() => setPay(m.id)}>
                <span className="tile-icon sm neutral"><Icon name={m.icon} size={18} /></span>
                <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>{m.label}</div><div className="t-xs">{m.sub}</div></div>
                <span className={`radio${pay === m.id ? ' on' : ''}`} />
              </div>
            ))}
          </div>
        </div>

        <div className="card p">
          <div className="kv"><span>Consultation fee</span><span className="num">{money(s.region, price.fee)}</span></div>
          {price.discount > 0 && <div className="kv"><span>Plus member discount (20%)</span><span className="num t-good" style={{ color: 'var(--good)' }}>−{money(s.region, price.discount)}</span></div>}
          <div className="kv"><span>Booking fee</span><span className="num">{price.bookingFee ? money(s.region, price.bookingFee) : 'Free'}</span></div>
          {price.tax > 0 && <div className="kv"><span>GST on booking fee</span><span className="num">{money(s.region, price.tax)}</span></div>}
          {insurance && <div className="kv"><span>Billed to insurance</span><span className="num">−{money(s.region, price.total - copay)}</span></div>}
          <div className="divider" />
          <div className="kv total"><span>{insurance ? 'Your copay' : 'To pay'}</span><span className="num">{money(s.region, total)}</span></div>
          {!s.plus && (
            <button className="row gap-8 tap" onClick={() => nav.push('plus')} style={{ marginTop: 10, width: '100%', border: 0, borderRadius: 12, padding: '10px 12px', background: 'var(--accent-soft)', color: '#9a3b1c', fontWeight: 600, fontSize: 13, textAlign: 'left' }}>
              <Icon name="Crown" size={16} /><span className="grow">Save {money(s.region, Math.round(fee * 0.2 + r.bookingFee))} on this visit with Plus</span><Icon name="ChevronRight" size={16} />
            </button>
          )}
        </div>
        <div className="row gap-8 t-xs"><Icon name="RotateCcw" size={14} />Free cancellation up to 2 hours before the visit</div>
      </div>
      <div className="cta-bar solid">
        <button className="btn block" onClick={confirm} disabled={paying}>
          {paying ? <><span className="spinner" />Processing payment…</> : <>Pay {money(s.region, total)} and confirm</>}
        </button>
      </div>
    </div>
  );
}

export function Booked({ nav, id, instant }: { nav: Nav; id: string; instant?: boolean }) {
  const { s, doctor } = useP();
  const toast = useToast();
  const a = s.appts.find((x) => x.id === id)!;
  const d = doctor(a.doctorId);
  return (
    <div className="screen stack" style={{ padding: '40px 24px 24px' }}>
      <div className="stack center gap-16" style={{ flex: 1, textAlign: 'center' }}>
        <div className="success-ring"><Icon name="Check" size={52} stroke={3} /></div>
        <div className="t-display" style={{ marginTop: 16 }}>{instant ? 'Finding your doctor' : 'You’re booked!'}</div>
        <div className="t-body" style={{ maxWidth: 300 }}>
          {instant ? `${d.name} is joining. Keep this screen open; it takes about 2 minutes.` : `${d.name} will see ${a.member === s.user.name ? 'you' : a.member.split(' ')[0]} ${relDay(a.t).toLowerCase()} at ${fmtTime(a.t)}. We’ll remind you 15 minutes before.`}
        </div>
        <div className="card p" style={{ width: '100%', textAlign: 'left', marginTop: 8 }}>
          <div className="kv"><span>Doctor</span><span>{d.name}</span></div>
          <div className="kv"><span>When</span><span>{instant ? 'Now' : `${fmtDay(a.t)}, ${fmtTime(a.t)}`}</span></div>
          <div className="kv"><span>Type</span><span>{a.mode === 'video' ? 'Video visit' : `Clinic · ${d.clinic}`}</span></div>
          <div className="kv"><span>Paid</span><span className="num">{money(s.region, a.paid)}</span></div>
          <div className="kv"><span>Booking ID</span><span className="num">CL{id.slice(-6)}</span></div>
        </div>
      </div>
      <div className="stack gap-10">
        {instant ? (
          <button className="btn block" onClick={() => nav.replace('call', { apptId: id })}><Icon name="Video" size={18} />Join waiting room</button>
        ) : (
          <button className="btn block" onClick={() => { nav.reset(); nav.setTab('visits'); }}>View my visits</button>
        )}
        {!instant && <button className="btn block ghost" onClick={() => toast('Added to your calendar')}><Icon name="CalendarPlus" size={18} />Add to calendar</button>}
        <button className="btn block ghost" style={{ boxShadow: 'none', background: 'none' }} onClick={() => nav.setTab('home')}>Back to home</button>
      </div>
    </div>
  );
}
