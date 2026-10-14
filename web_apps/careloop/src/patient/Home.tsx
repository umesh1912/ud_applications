import { SPECIALTIES, fmtTime, relDay, specialtyOf } from '../data/catalog';
import { REGIONS, money } from '../data/region';
import { lastRead, markJoined, nextFreeLabel, openVideoRoom } from '../lib/care';
import { ratingOf, type DoctorDoc } from '../lib/model';
import { Sparkline } from '../ui/charts';
import { Avatar, Icon, SectionHead, Stars, useNow, type Nav } from '../ui/kit';
import { hasPlus, isUpcoming, useP } from './ctx';

function greeting() {
  const h = new Date().getHours();
  return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
}

export function DoctorRating({ d }: { d: DoctorDoc }) {
  return d.ratingCount ? <Stars rating={ratingOf(d)} count={d.ratingCount} /> : <span className="badge brand">New</span>;
}

export function Home({ nav }: { nav: Nav }) {
  const { me, region, doctors, appts, inbox } = useP();
  const unread = inbox.some((m) => m.t > lastRead(m.apptId));
  const now = useNow(15000);
  const r = REGIONS[region];
  const next = (appts ?? []).filter((a) => isUpcoming(a, now)).sort((a, b) => a.t - b.t)[0];
  const first = me.name.split(' ')[0];
  const top = [...(doctors ?? [])].sort((a, b) => Number(b.online) - Number(a.online) || ratingOf(b) - ratingOf(a)).slice(0, 8);
  const v = me.vitals ?? { bp: [], sugar: [], weight: [] };

  const quick = [
    { icon: 'Zap', label: 'Instant video consult', sub: 'Next available doctor', onClick: () => nav.push('instant'), tone: '' },
    { icon: 'Stethoscope', label: 'Book a clinic visit', sub: 'Pick your doctor', onClick: () => nav.push('search', { mode: 'clinic' }), tone: 'accent' },
    { icon: 'FlaskConical', label: 'Lab tests at home', sub: 'Up to 60% off', onClick: () => nav.push('labs'), tone: 'good' },
    { icon: 'Pill', label: 'Order medicines', sub: 'Delivered to your door', onClick: () => nav.push('pharmacy'), tone: 'neutral' },
  ];

  return (
    <div className="screen has-tabs tab-root">
      <div className="pad" style={{ paddingTop: 14 }}>
        <div className="row between">
          <div className="row gap-12">
            <Avatar name={me.name} hue={200} size={46} />
            <div>
              <div className="t-sm">{greeting()}</div>
              <div className="t-h2">{first}</div>
            </div>
          </div>
          <div className="row gap-8">
            {hasPlus(me) && <span className="badge accent"><Icon name="Crown" size={13} />Plus</span>}
            <button className="icon-btn" onClick={() => nav.push('notifications')} aria-label="Notifications"><Icon name="Bell" size={20} />{(unread || next) && <span className="dot" />}</button>
          </div>
        </div>

        <button className="search tap" style={{ marginTop: 18, width: '100%', border: 0, textAlign: 'left' }} onClick={() => nav.push('search', { focus: true })}>
          <Icon name="Search" size={20} />
          <span style={{ flex: 1, fontSize: 15 }}>Search doctors, symptoms, clinics</span>
          <Icon name="SlidersHorizontal" size={18} />
        </button>

        {next && (() => {
          const mins = Math.round((next.t - now) / 60000);
          const live = next.mode === 'video' && (mins <= 15 || next.status !== 'booked');
          return (
            <div className="hero" style={{ marginTop: 18 }}>
              <div className="row between" style={{ position: 'relative', zIndex: 1 }}>
                <span className="hero-pill"><Icon name={next.mode === 'video' ? 'Video' : 'MapPin'} size={14} />{next.mode === 'video' ? 'Video visit' : 'Clinic visit'}</span>
                <span className="t-xs" style={{ color: '#fff' }}>
                  {next.status === 'in-consult' ? 'Doctor is in the room' : next.status === 'waiting' ? 'You’re in the waiting room' : mins > 0 && mins < 60 ? `Starts in ${mins} min` : `${relDay(next.t)}, ${fmtTime(next.t)}`}
                </span>
              </div>
              <div className="row gap-12" style={{ marginTop: 16, position: 'relative', zIndex: 1 }}>
                <Avatar name={next.doctorName} hue={next.doctorHue} size={52} online={next.status === 'in-consult'} />
                <div className="grow">
                  <div className="t-h3">{next.doctorName}</div>
                  <div className="t-sm">{specialtyOf(next.specialty).name} · for {next.member.split(' ')[0]}</div>
                </div>
              </div>
              <div className="row gap-10" style={{ marginTop: 16, position: 'relative', zIndex: 1 }}>
                {live ? (
                  <button className="btn white grow" onClick={async () => { await markJoined(next); await openVideoRoom(next.room, next.member); }}><Icon name="Video" size={18} />Join visit</button>
                ) : (
                  <button className="btn white grow" onClick={() => nav.push('appt', { id: next.id })}>View details</button>
                )}
                <button className="icon-btn on-dark" style={{ width: 52, height: 52, borderRadius: 16 }} onClick={() => nav.push('appt', { id: next.id })} aria-label="Appointment details"><Icon name="CalendarClock" size={20} /></button>
              </div>
            </div>
          );
        })()}

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 18 }}>
          {quick.map((q) => (
            <button key={q.label} className="card tap stack gap-10" onClick={q.onClick} style={{ border: 0, padding: 16, textAlign: 'left', alignItems: 'flex-start' }}>
              <span className={`tile-icon ${q.tone}`}><Icon name={q.icon} size={22} /></span>
              <div>
                <div style={{ fontWeight: 700, fontSize: 14.5, lineHeight: 1.25 }}>{q.label}</div>
                <div className="t-xs" style={{ marginTop: 3 }}>{q.sub}</div>
              </div>
            </button>
          ))}
        </div>

        <SectionHead title="What’s bothering you?" action="See all" onAction={() => nav.push('search')} />
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
          {SPECIALTIES.map((sp) => (
            <button key={sp.id} className="tap stack center gap-8" onClick={() => nav.push('search', { specialty: sp.id })} style={{ border: 0, background: 'none', padding: '4px 0' }}>
              <span style={{ width: 58, height: 58, borderRadius: 20, display: 'flex', alignItems: 'center', justifyContent: 'center', background: `${sp.tint}1A`, color: sp.tint }}>
                <Icon name={sp.icon} size={24} />
              </span>
              <span style={{ fontSize: 11.5, fontWeight: 700, textAlign: 'center', lineHeight: 1.2 }}>{sp.symptoms.split(',')[0]}</span>
            </button>
          ))}
        </div>

        {!hasPlus(me) && (
          <button className="card tap row gap-12" onClick={() => nav.push('plus')} style={{ marginTop: 24, border: 0, padding: 16, textAlign: 'left', background: 'linear-gradient(120deg, #fff4ec, #ffe7dc)' }}>
            <span className="tile-icon accent" style={{ background: '#fff' }}><Icon name="Crown" size={22} /></span>
            <div className="grow">
              <div className="t-h3">CareLoop Plus for your family</div>
              <div className="t-sm" style={{ color: '#7a4a3a' }}>20% off every consult, no booking fees, free home collection and delivery. {money(region, r.plus.monthly)}/month.</div>
            </div>
            <Icon name="ChevronRight" size={20} className="t-accent" />
          </button>
        )}

        <SectionHead title="Doctors on CareLoop" action={top.length ? 'View all' : undefined} onAction={() => nav.push('search')} />
        {doctors === undefined ? (
          <div className="t-sm">Loading doctors…</div>
        ) : top.length === 0 ? (
          <div className="card p stack gap-6"><div className="t-h3">Doctors are joining in {r.name}</div><div className="t-sm">No verified doctors are taking bookings in your country yet. We’ll notify you as soon as one is available.</div></div>
        ) : (
          <div className="hscroll">
            {top.map((d) => {
              const nf = nextFreeLabel(d);
              return (
                <button key={d.id} className="card tap stack gap-10" onClick={() => nav.push('doctor', { id: d.id })} style={{ width: 172, border: 0, padding: 14, textAlign: 'left' }}>
                  <div className="row between" style={{ alignItems: 'flex-start' }}>
                    <Avatar name={d.name} hue={d.hue} size={54} square online={d.online} />
                    <DoctorRating d={d} />
                  </div>
                  <div>
                    <div className="t-h3 ellipsis">{d.name}</div>
                    <div className="t-sm ellipsis">{specialtyOf(d.specialty).name}</div>
                  </div>
                  <div className="row between">
                    <span className="num" style={{ fontWeight: 800 }}>{money(region, d.feeVideo)}</span>
                    <span className={`badge ${nf.soon ? 'good' : ''}`}>{d.online ? 'Online' : nf.soon ? 'Soon' : 'Book'}</span>
                  </div>
                </button>
              );
            })}
          </div>
        )}

        {(v.bp.length > 1 || v.sugar.length > 1) && (
          <>
            <SectionHead title="Your health" action="Records" onAction={() => nav.setTab('records')} />
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              {[{ label: 'Blood pressure', unit: 'mmHg', data: v.bp }, { label: 'Fasting sugar', unit: 'mg/dL', data: v.sugar }].filter((x) => x.data.length > 1).map((x) => (
                <button key={x.label} className="card tap stack gap-8" onClick={() => nav.setTab('records')} style={{ border: 0, padding: 14, textAlign: 'left' }}>
                  <div className="t-xs">{x.label}</div>
                  <div className="row gap-4" style={{ alignItems: 'baseline' }}><span className="t-h2 num">{x.data[x.data.length - 1]}</span><span className="t-xs">{x.unit}</span></div>
                  <Sparkline values={x.data} width={130} height={36} />
                </button>
              ))}
            </div>
          </>
        )}

        <div className="row gap-10 card flat" style={{ marginTop: 24, padding: 14, background: 'var(--bad-soft)', boxShadow: 'none' }}>
          <Icon name="Siren" size={20} className="t-bad" />
          <div className="t-sm grow" style={{ color: '#8a1c1c' }}>Chest pain, trouble breathing or severe bleeding? Call <b>{r.emergency}</b> now. CareLoop is not for emergencies.</div>
        </div>
      </div>
    </div>
  );
}
