import { useMemo, useState } from 'react';
import { addDoc, collection, doc, updateDoc } from 'firebase/firestore';
import { DAY, SPECIALTIES, dow, fmtDay, fmtTime, relDay, specialtyOf, startOfToday } from '../data/catalog';
import { REGIONS, money, type Region } from '../data/region';
import { SlotTakenError, bookAppointment, cancelAppointment, markJoined, nextFreeLabel, openVideoRoom, slotsFor } from '../lib/care';
import { errorText, useDoc, useQuery, where } from '../lib/db';
import { db } from '../lib/firebase';
import type { ApptDoc, DoctorDoc, InstantRequest, SlotDoc } from '../lib/model';
import { usePay } from '../lib/pay';
import { Avatar, Icon, SectionHead, Segmented, TopBar, useToast, type Nav } from '../ui/kit';
import { INSTANT_FEE, patientInfo, priceFor, useP } from './ctx';
import { DoctorRating } from './Home';

type Mode = 'video' | 'clinic';

// ---------------------------------------------------------------- search

export function Search({ nav, specialty: initialSpec, mode: initialMode, focus }: { nav: Nav; specialty?: string; mode?: Mode; focus?: boolean }) {
  const { region, doctors } = useP();
  const [q, setQ] = useState('');
  const [spec, setSpec] = useState<string | undefined>(initialSpec);
  const [mode, setMode] = useState<Mode | undefined>(initialMode);
  const [online, setOnline] = useState(false);
  const [sort, setSort] = useState<'relevance' | 'rating' | 'fee'>('relevance');

  const list = useMemo(() => {
    const term = q.trim().toLowerCase();
    let out = (doctors ?? []).filter((d) => {
      const sp = specialtyOf(d.specialty);
      if (spec && d.specialty !== spec) return false;
      if (online && !d.online) return false;
      if (mode === 'clinic' && !d.clinic) return false;
      if (!term) return true;
      return [d.name, sp.name, sp.symptoms, d.clinic, d.area, ...d.languages].join(' ').toLowerCase().includes(term);
    });
    if (sort === 'rating') out = [...out].sort((a, b) => (b.ratingCount ? b.ratingSum / b.ratingCount : 0) - (a.ratingCount ? a.ratingSum / a.ratingCount : 0));
    else if (sort === 'fee') out = [...out].sort((a, b) => (mode === 'clinic' ? a.feeClinic - b.feeClinic : a.feeVideo - b.feeVideo));
    else out = [...out].sort((a, b) => Number(b.online) - Number(a.online));
    return out;
  }, [doctors, q, spec, online, mode, sort]);

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
            <button key={sp.id} className={`chip${spec === sp.id ? ' on' : ''}`} onClick={() => setSpec(spec === sp.id ? undefined : sp.id)}><Icon name={sp.icon} size={15} />{sp.name}</button>
          ))}
        </div>
        <div className="hscroll">
          <button className={`chip${online ? ' on' : ''}`} onClick={() => setOnline(!online)}><Icon name="Radio" size={15} />Online now</button>
          <button className={`chip${mode === 'video' ? ' on' : ''}`} onClick={() => setMode(mode === 'video' ? undefined : 'video')}><Icon name="Video" size={15} />Video</button>
          <button className={`chip${mode === 'clinic' ? ' on' : ''}`} onClick={() => setMode(mode === 'clinic' ? undefined : 'clinic')}><Icon name="Building2" size={15} />In clinic</button>
        </div>
        <div className="row between" style={{ margin: '10px 0 12px' }}>
          <div className="t-sm"><b style={{ color: 'var(--ink)' }}>{list.length}</b> doctors{spec ? ` for ${specialtyOf(spec).name.toLowerCase()}` : ''}</div>
          <select value={sort} onChange={(e) => setSort(e.target.value as typeof sort)} aria-label="Sort" style={{ border: 0, background: 'none', fontWeight: 700, fontSize: 13, color: 'var(--brand)' }}>
            <option value="relevance">Sort: Online first</option>
            <option value="rating">Sort: Rating</option>
            <option value="fee">Sort: Lowest fee</option>
          </select>
        </div>
        <div className="stack gap-12" style={{ paddingBottom: 24 }}>
          {doctors === undefined && <div className="t-sm">Loading doctors…</div>}
          {list.map((d) => <DoctorCard key={d.id} d={d} mode={mode ?? 'video'} region={region} onOpen={() => nav.push('doctor', { id: d.id, mode })} />)}
          {doctors && list.length === 0 && (
            <div className="empty stack center gap-8">
              <Icon name="SearchX" size={32} />
              <div className="t-h3" style={{ color: 'var(--ink)' }}>No doctors match</div>
              <div className="t-sm">{doctors.length ? 'Try another symptom, or clear the filters.' : `No verified doctors in ${REGIONS[region].name} yet.`}</div>
              {doctors.length > 0 && <button className="btn sm soft" onClick={() => { setQ(''); setSpec(undefined); setOnline(false); setMode(undefined); }}>Clear filters</button>}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function DoctorCard({ d, mode, region, onOpen }: { d: DoctorDoc; mode: Mode; region: Region; onOpen: () => void }) {
  const nf = nextFreeLabel(d);
  return (
    <div className="card tap" onClick={onOpen} style={{ padding: 16 }}>
      <div className="row gap-12" style={{ alignItems: 'flex-start' }}>
        <Avatar name={d.name} hue={d.hue} size={64} square online={d.online} />
        <div className="grow stack gap-4" style={{ minWidth: 0 }}>
          <div className="row gap-6"><span className="t-h3 ellipsis">{d.name}</span><Icon name="BadgeCheck" size={16} className="t-brand" /></div>
          <div className="t-sm">{specialtyOf(d.specialty).name} · {d.years} yrs exp</div>
          <div className="row gap-10 wrap" style={{ marginTop: 2 }}>
            <DoctorRating d={d} />
            <span className="t-xs row gap-4"><Icon name="MapPin" size={12} />{d.area || 'Online'}</span>
          </div>
        </div>
      </div>
      <div className="divider" style={{ margin: '14px 0 12px' }} />
      <div className="row between">
        <div>
          <div className="t-xs" style={{ color: nf.soon ? 'var(--good)' : undefined }}>{nf.label}</div>
          <div className="num" style={{ fontWeight: 800, fontSize: 16, marginTop: 2 }}>{money(region, mode === 'clinic' ? d.feeClinic : d.feeVideo)}<span className="t-xs"> / {mode === 'clinic' ? 'visit' : 'video'}</span></div>
        </div>
        <button className="btn sm" onClick={(e) => { e.stopPropagation(); onOpen(); }}>Book</button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- doctor profile + slot picker

export function DoctorProfile({ nav, id, mode: initialMode, rescheduleOf }: { nav: Nav; id: string; mode?: Mode; rescheduleOf?: string }) {
  const { region, doctor } = useP();
  const d = doctor(id);
  const [mode, setMode] = useState<Mode>(initialMode ?? 'video');
  const [day, setDay] = useState(startOfToday());
  const [slot, setSlot] = useState<number | null>(null);
  const taken = useQuery<SlotDoc>(`slots-${id}-${day}`, 'slots', where('doctorId', '==', id), where('day', '==', day));
  const reviews = useQuery<{ name: string; rating: number; text: string; t: number }>(`reviews-${id}`, 'reviews', where('doctorId', '==', id));
  if (!d) return <div className="screen"><TopBar onBack={() => nav.back()} /><div className="empty">This doctor isn’t available right now.</div></div>;

  const hasClinic = !!d.clinic;
  const days = Array.from({ length: 7 }, (_, i) => startOfToday() + i * DAY);
  const slots = slotsFor(d, day, taken ?? []);
  const groups = [
    { label: 'Morning', icon: 'Sunrise', list: slots.filter((x) => x.session === 'morning') },
    { label: 'Afternoon', icon: 'Sun', list: slots.filter((x) => x.session === 'afternoon') },
    { label: 'Evening', icon: 'Sunset', list: slots.filter((x) => x.session === 'evening') },
  ].filter((g) => g.list.length);
  const fee = mode === 'clinic' ? d.feeClinic : d.feeVideo;
  const sp = specialtyOf(d.specialty);

  return (
    <div className="screen has-cta">
      <TopBar onBack={() => nav.back()} />
      <div className="pad">
        <div className="stack center gap-8" style={{ textAlign: 'center' }}>
          <Avatar name={d.name} hue={d.hue} size={96} square online={d.online} />
          <div className="row gap-6" style={{ marginTop: 6 }}><span className="t-h1">{d.name}</span><Icon name="BadgeCheck" size={20} className="t-brand" /></div>
          <div className="t-sm">{d.degrees}</div>
          <div className="row gap-6 wrap center"><span className="badge brand"><Icon name={sp.icon} size={12} />{sp.name}</span><span className="badge">{d.languages.join(', ')}</span></div>
        </div>
        <div className="card row" style={{ marginTop: 18, padding: '14px 4px' }}>
          {[
            { v: `${d.years} yrs`, l: 'Experience', icon: 'Award' },
            { v: d.ratingCount ? (d.ratingSum / d.ratingCount).toFixed(1) : 'New', l: `${d.ratingCount} review${d.ratingCount === 1 ? "" : "s"}`, icon: 'Star' },
            { v: d.online ? 'Online' : 'Offline', l: 'Right now', icon: 'Radio' },
          ].map((x, i) => (
            <div key={x.l} className="grow stack center gap-4" style={{ borderLeft: i ? '1px solid var(--line)' : 0 }}>
              <Icon name={x.icon} size={18} className="t-brand" />
              <div className="t-h3 num">{x.v}</div>
              <div className="t-xs">{x.l}</div>
            </div>
          ))}
        </div>

        {hasClinic && (
          <div style={{ marginTop: 18 }}>
            <Segmented options={[{ id: 'video', label: `Video · ${money(region, d.feeVideo)}` }, { id: 'clinic', label: `Clinic · ${money(region, d.feeClinic)}` }]} value={mode} onChange={(m) => setMode(m)} />
          </div>
        )}
        <div className="row gap-8 t-sm" style={{ marginTop: 12, color: 'var(--good)', fontWeight: 600 }}><Icon name="Gift" size={16} />Free follow-up chat for 7 days after your visit</div>

        <SectionHead title="Pick a time" />
        <div className="hscroll">
          {days.map((t) => (
            <button key={t} className={`date-pill${t === day ? ' on' : ''}`} onClick={() => { setDay(t); setSlot(null); }} style={!d.availability.days[new Date(t).getDay()] || d.timeOff?.includes(t) ? { opacity: 0.45 } : undefined}>
              <span className="dow">{t === startOfToday() ? 'Today' : dow(t)}</span>
              <span className="d num">{new Date(t).getDate()}</span>
            </button>
          ))}
        </div>
        <div className="stack gap-16" style={{ marginTop: 12 }}>
          {taken === undefined && <div className="t-sm">Checking availability…</div>}
          {taken && groups.length === 0 && <div className="card flat p t-sm">No times left on {fmtDay(day)}. Try another day.</div>}
          {taken && groups.map((g) => (
            <div key={g.label}>
              <div className="row gap-6 t-sm" style={{ fontWeight: 700, marginBottom: 8 }}><Icon name={g.icon} size={15} />{g.label} · {g.list.filter((x) => !x.taken).length} open</div>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
                {g.list.map((x) => <button key={x.t} className={`slot num${slot === x.t ? ' on' : ''}`} disabled={x.taken} onClick={() => setSlot(x.t)}>{fmtTime(x.t).replace(' ', '')}</button>)}
              </div>
            </div>
          ))}
        </div>

        {d.about && <><SectionHead title="About" /><div className="t-body">{d.about}</div></>}
        {mode === 'clinic' && hasClinic && (
          <>
            <SectionHead title="Clinic" />
            <div className="card row gap-12" style={{ padding: 14 }}>
              <span className="tile-icon sm"><Icon name="Building2" size={18} /></span>
              <div className="grow"><div className="t-h3">{d.clinic}</div><div className="t-sm">{d.area}</div></div>
              <a className="icon-btn" aria-label="Directions" href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${d.clinic} ${d.area}`)}`} target="_blank" rel="noreferrer"><Icon name="Navigation" size={18} /></a>
            </div>
          </>
        )}
        <SectionHead title="Patient reviews" />
        <div className="stack gap-10" style={{ paddingBottom: 20 }}>
          {reviews && reviews.length === 0 && <div className="t-sm">No reviews yet. Reviews come only from patients who had a visit.</div>}
          {(reviews ?? []).sort((a, b) => b.t - a.t).slice(0, 10).map((r) => (
            <div key={r.id} className="card p stack gap-8">
              <div className="row between"><span className="t-h3">{r.name}</span><span className="t-xs">{fmtDay(r.t)}</span></div>
              <div className="row gap-4">{Array.from({ length: 5 }, (_, i) => <Icon key={i} name="Star" size={14} style={{ color: 'var(--star)', fill: i < r.rating ? 'var(--star)' : 'none' }} />)}</div>
              {r.text && <div className="t-body" style={{ fontSize: 14 }}>{r.text}</div>}
            </div>
          ))}
        </div>
      </div>
      <div className="cta-bar solid">
        <div className="grow">
          <div className="t-xs">{slot ? `${relDay(slot)}, ${fmtTime(slot)}` : 'Choose a time'}</div>
          <div className="t-h2 num">{money(region, fee)}</div>
        </div>
        <button className="btn" disabled={!slot} onClick={() => nav.push('book', { doctorId: d.id, mode, t: slot, rescheduleOf })}>{rescheduleOf ? 'Move my visit here' : 'Book appointment'}</button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- checkout

const REASONS = ['Fever', 'Follow-up', 'Second opinion', 'Report review', 'New symptoms'];

export function Book({ nav, doctorId, mode, t, rescheduleOf }: { nav: Nav; doctorId: string; mode: Mode; t: number; rescheduleOf?: string }) {
  const { uid, me, region, doctor, appts } = useP();
  const old = appts?.find((x) => x.id === rescheduleOf);
  const pay = usePay();
  const toast = useToast();
  const d = doctor(doctorId)!;
  const members = [me.name, ...(me.family ?? []).map((f) => f.name)];
  const [member, setMember] = useState(me.name);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const fee = mode === 'clinic' ? d.feeClinic : d.feeVideo;
  const price = priceFor(me, region, fee);

  const confirm = async () => {
    setErr(null);
    // Rescheduling keeps the original payment; a new booking pays now.
    const payment = old ? old.payment : await pay({ region, amount: price.total, title: `${mode === 'video' ? 'Video' : 'Clinic'} visit with ${d.name}`, copay: region === 'US' ? 25 : undefined, prefill: { name: me.name, email: me.email, phone: me.phone } });
    if (!payment) return;
    setBusy(true);
    try {
      const id = await bookAppointment({
        patientId: uid, patientName: me.name, member, patientInfo: patientInfo(me, member),
        doctorId: d.id, doctorName: d.name, doctorHue: d.hue, specialty: d.specialty, region, mode, t,
        reason: reason.trim() || old?.reason || 'Consultation', fee, payment,
      });
      if (old) await cancelAppointment({ ...old, payment: { ...old.payment, status: 'paid' } }, 'doctor');
      toast(old ? 'Visit moved to the new time' : 'Payment successful · booking confirmed');
      nav.replace('booked', { id });
    } catch (e) {
      setBusy(false);
      setErr(e instanceof SlotTakenError ? `${e.message} Your payment will be refunded.` : errorText(e));
    }
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
              <span className="badge"><Icon name="Calendar" size={12} />{relDay(t)}, {fmtTime(t)}</span>
            </div>
          </div>
        </div>

        <div>
          <div className="t-h3" style={{ marginBottom: 10 }}>Who is this for?</div>
          <div className="hscroll">
            {members.map((m, i) => (
              <button key={m} className={`chip${member === m ? ' on' : ''}`} onClick={() => setMember(m)} style={{ height: 44 }}>
                {i === 0 ? 'Myself' : `${m.split(' ')[0]} (${me.family![i - 1].relation})`}
              </button>
            ))}
            <button className="chip" onClick={() => nav.push('family')}><Icon name="Plus" size={15} />Add</button>
          </div>
        </div>

        <div className="field">
          <label htmlFor="reason">Reason for visit</label>
          <textarea id="reason" className="input" rows={3} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Describe your symptoms, how long you’ve had them, any medicines you’re taking" />
          <div className="row wrap gap-6">{REASONS.map((x) => <button key={x} className="chip" style={{ height: 32, fontSize: 12.5 }} onClick={() => setReason((v) => (v ? `${v}, ${x.toLowerCase()}` : x))}>+ {x}</button>)}</div>
        </div>

        <div className="card p">
          <div className="kv"><span>Consultation fee</span><span className="num">{money(region, price.fee)}</span></div>
          {price.discount > 0 && <div className="kv"><span>Plus member discount (20%)</span><span className="num" style={{ color: 'var(--good)' }}>−{money(region, price.discount)}</span></div>}
          <div className="kv"><span>Booking fee</span><span className="num">{price.bookingFee ? money(region, price.bookingFee) : 'Free'}</span></div>
          {price.tax > 0 && <div className="kv"><span>GST on booking fee</span><span className="num">{money(region, price.tax)}</span></div>}
          <div className="divider" />
          <div className="kv total"><span>To pay</span><span className="num">{money(region, price.total)}</span></div>
          {region === 'US' && <div className="t-xs" style={{ marginTop: 4 }}>Paying with insurance? Choose it at checkout to pay only your copay.</div>}
          {!price.plus && (
            <button className="row gap-8 tap" onClick={() => nav.push('plus')} style={{ marginTop: 10, width: '100%', border: 0, borderRadius: 12, padding: '10px 12px', background: 'var(--accent-soft)', color: '#9a3b1c', fontWeight: 600, fontSize: 13, textAlign: 'left' }}>
              <Icon name="Crown" size={16} /><span className="grow">Save {money(region, Math.round(fee * 0.2 + REGIONS[region].bookingFee))} on this visit with Plus</span><Icon name="ChevronRight" size={16} />
            </button>
          )}
        </div>
        {err && <div className="row gap-8" role="alert" style={{ padding: '10px 12px', borderRadius: 12, background: 'var(--bad-soft)', color: 'var(--bad)', fontSize: 13.5, fontWeight: 600 }}><Icon name="CircleAlert" size={16} />{err}</div>}
        <div className="row gap-8 t-xs"><Icon name="RotateCcw" size={14} />Free cancellation up to 2 hours before the visit</div>
      </div>
      <div className="cta-bar solid">
        <button className="btn block" onClick={confirm} disabled={busy}>{busy ? <><span className="spinner" />Confirming…</> : old ? 'Confirm new time' : <>Continue to pay {money(region, price.total)}</>}</button>
      </div>
    </div>
  );
}

export function Booked({ nav, id }: { nav: Nav; id: string }) {
  const { region, appts } = useP();
  const toast = useToast();
  const a = appts?.find((x) => x.id === id);
  if (!a) return <div className="screen stack center"><span className="spinner" style={{ borderColor: 'var(--line)', borderTopColor: 'var(--brand)' }} /></div>;
  const calUrl = `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${encodeURIComponent(`CareLoop: ${a.doctorName}`)}&dates=${new Date(a.t).toISOString().replace(/[-:]|\.\d{3}/g, '')}/${new Date(a.t + 30 * 60000).toISOString().replace(/[-:]|\.\d{3}/g, '')}&details=${encodeURIComponent(a.mode === 'video' ? 'Video visit: open CareLoop and tap Join visit.' : 'Clinic visit')}`;
  return (
    <div className="screen stack" style={{ padding: '40px 24px 24px' }}>
      <div className="stack center gap-16" style={{ flex: 1, textAlign: 'center' }}>
        <div className="success-ring"><Icon name="Check" size={52} stroke={3} /></div>
        <div className="t-display" style={{ marginTop: 16 }}>You’re booked!</div>
        <div className="t-body" style={{ maxWidth: 300 }}>{a.doctorName} will see {a.member.split(' ')[0]} {relDay(a.t).toLowerCase()} at {fmtTime(a.t)}. {a.mode === 'video' ? 'Join from the app when it’s time.' : 'Arrive 10 minutes early.'}</div>
        <div className="card p" style={{ width: '100%', textAlign: 'left', marginTop: 8 }}>
          <div className="kv"><span>Doctor</span><span>{a.doctorName}</span></div>
          <div className="kv"><span>When</span><span>{fmtDay(a.t)}, {fmtTime(a.t)}</span></div>
          <div className="kv"><span>Type</span><span>{a.mode === 'video' ? 'Video visit' : 'Clinic visit'}</span></div>
          <div className="kv"><span>Paid</span><span className="num">{money(region, a.payment.amount)}</span></div>
          <div className="kv"><span>Booking ID</span><span className="num">{a.id.slice(0, 8).toUpperCase()}</span></div>
        </div>
      </div>
      <div className="stack gap-10">
        <button className="btn block" onClick={() => nav.setTab('visits')}>View my visits</button>
        <a className="btn block ghost" href={calUrl} target="_blank" rel="noreferrer" onClick={() => toast('Opening your calendar')}><Icon name="CalendarPlus" size={18} />Add to calendar</a>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- instant consult

const CONCERNS = ['Fever or flu', 'Cough or cold', 'Stomach upset', 'Headache', 'Skin rash', 'Allergy', 'Body pain', 'Something else'];

export function Instant({ nav }: { nav: Nav }) {
  const { uid, me, region, doctors } = useP();
  const pay = usePay();
  const [concern, setConcern] = useState<string | null>(null);
  const [details, setDetails] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const online = (doctors ?? []).filter((d) => d.online).length;
  const fee = INSTANT_FEE[region];

  const start = async () => {
    setErr(null);
    const payment = await pay({ region, amount: fee, title: 'Instant video consult', copay: region === 'US' ? 25 : undefined, prefill: { name: me.name, email: me.email, phone: me.phone } });
    if (!payment) return;
    setBusy(true);
    try {
      const ref = await addDoc(collection(db, 'instantRequests'), {
        patientId: uid, patientName: me.name, patientInfo: patientInfo(me, me.name), concern: details.trim() ? `${concern}: ${details.trim()}` : concern,
        region, fee, payment, status: 'open', createdAt: Date.now(),
      });
      nav.replace('instantWait', { id: ref.id });
    } catch (e) { setErr(errorText(e)); setBusy(false); }
  };

  return (
    <div className="screen has-cta">
      <TopBar title="Instant consult" onBack={() => nav.back()} />
      <div className="pad stack gap-16">
        <div className="hero">
          <div className="row gap-8" style={{ position: 'relative' }}><span className="hero-pill"><Icon name="Radio" size={14} />{online ? `${online} doctor${online > 1 ? 's' : ''} online now` : 'Doctors notified when online'}</span></div>
          <div className="t-h1" style={{ marginTop: 12, position: 'relative' }}>Talk to a doctor now, no appointment</div>
          <div className="t-sm" style={{ marginTop: 6, position: 'relative' }}>The first available doctor accepts and joins by video. Prescription in the app, free follow-up chat for 7 days.</div>
        </div>
        <div className="t-h3">What do you need help with?</div>
        <div className="row wrap gap-8">{CONCERNS.map((c) => <button key={c} className={`chip${concern === c ? ' on' : ''}`} onClick={() => setConcern(c)}>{c}</button>)}</div>
        <textarea className="input" rows={2} value={details} onChange={(e) => setDetails(e.target.value)} placeholder="Anything else the doctor should know? (optional)" />
        <div className="stack gap-8 t-sm">
          {['Only license-verified doctors', 'Private, encrypted video', 'Full refund if no doctor accepts in 30 minutes'].map((x) => (
            <div key={x} className="row gap-8"><Icon name="Check" size={16} style={{ color: 'var(--good)' }} />{x}</div>
          ))}
        </div>
        {err && <div className="t-sm t-bad" role="alert">{err}</div>}
      </div>
      <div className="cta-bar solid">
        <div className="grow"><div className="t-xs">Consult fee</div><div className="t-h2 num">{money(region, fee)}</div></div>
        <button className="btn" disabled={!concern || busy} onClick={start}>{busy ? <span className="spinner" /> : 'Pay and find a doctor'}</button>
      </div>
    </div>
  );
}

/** Live wait for a doctor to accept; then shows the doctor and opens the video room. */
export function InstantWait({ nav, id }: { nav: Nav; id: string }) {
  const { me } = useP();
  const toast = useToast();
  const req = useDoc<InstantRequest>(`instantRequests/${id}`);
  const appt = useDoc<ApptDoc>(req?.apptId ? `appointments/${req.apptId}` : null);
  const waited = req ? Math.floor((Date.now() - req.createdAt) / 60000) : 0;

  if (req?.status === 'accepted' && appt) {
    return (
      <div className="screen stack" style={{ padding: '40px 24px 24px' }}>
        <div className="stack center gap-14" style={{ flex: 1, textAlign: 'center' }}>
          <div className="pulse" style={{ borderRadius: '50%' }}><Avatar name={appt.doctorName} hue={appt.doctorHue} size={110} /></div>
          <div className="t-h1" style={{ marginTop: 10 }}>{appt.doctorName} accepted</div>
          <div className="t-body">{specialtyOf(appt.specialty).name} · Join the video room now. The doctor is waiting.</div>
        </div>
        <div className="stack gap-10">
          <button className="btn block" onClick={async () => { await markJoined(appt); await openVideoRoom(appt.room, me.name); }}><Icon name="Video" size={18} />Join video visit</button>
          <button className="btn block ghost" onClick={() => nav.replace('appt', { id: appt.id })}>Visit details</button>
        </div>
      </div>
    );
  }

  return (
    <div className="screen stack" style={{ padding: '40px 24px 24px' }}>
      <div className="stack center gap-16" style={{ flex: 1, textAlign: 'center' }}>
        <div style={{ position: 'relative', width: 160, height: 160, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {[160, 120].map((s, i) => <div key={s} className="pulse" style={{ position: 'absolute', width: s, height: s, borderRadius: '50%', background: 'var(--brand)', opacity: 0.08 + i * 0.06 }} />)}
          <span className="tile-icon" style={{ width: 76, height: 76, borderRadius: 26, background: 'var(--brand)', color: '#fff' }}><Icon name="Stethoscope" size={34} /></span>
        </div>
        <div className="t-h1">{req?.status === 'cancelled' ? 'Request cancelled' : 'Finding your doctor…'}</div>
        <div className="t-body" style={{ maxWidth: 300 }}>
          {req?.status === 'cancelled' ? 'Your refund has been started.' : `We’ve alerted online doctors. Keep this screen open; most requests are accepted within a few minutes.${waited ? ` Waiting ${waited} min.` : ''}`}
        </div>
      </div>
      {req?.status === 'open' && (
        <button className="btn block ghost" onClick={async () => {
          await updateDoc(doc(db, 'instantRequests', id), { status: 'cancelled', updatedAt: Date.now() });
          toast('Request cancelled · refund started');
          nav.back();
        }}>Cancel request</button>
      )}
      {req?.status === 'cancelled' && <button className="btn block" onClick={() => nav.back()}>Done</button>}
    </div>
  );
}
