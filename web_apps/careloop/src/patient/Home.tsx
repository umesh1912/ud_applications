import { SPECIALTIES, fmtTime, relDay, specialtyOf } from '../data/catalog';
import { REGIONS, money } from '../data/region';
import { Sparkline } from '../ui/charts';
import { Avatar, Icon, SectionHead, Stars, useNow, type Nav } from '../ui/kit';
import { statusOf, useP } from './state';

function greeting() {
  const h = new Date().getHours();
  return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
}

export function Home({ nav }: { nav: Nav }) {
  const { s, docs, doctor } = useP();
  const now = useNow(15000);
  const r = REGIONS[s.region];
  const next = s.appts
    .filter((a) => statusOf(a, now) === 'upcoming')
    .sort((a, b) => a.t - b.t)[0];
  const first = s.user.name.split(' ')[0];

  const quick = [
    { icon: 'Zap', label: 'Instant video consult', sub: 'Doctor in ~10 min', onClick: () => nav.push('instant'), tone: '' },
    { icon: 'Stethoscope', label: 'Book a clinic visit', sub: 'Near you', onClick: () => nav.push('search', { mode: 'clinic' }), tone: 'accent' },
    { icon: 'FlaskConical', label: 'Lab tests at home', sub: 'Up to 60% off', onClick: () => nav.push('labs'), tone: 'good' },
    { icon: 'Pill', label: 'Order medicines', sub: 'Delivered today', onClick: () => nav.push('pharmacy'), tone: 'neutral' },
  ];

  return (
    <div className="screen has-tabs tab-root">
      <div className="pad" style={{ paddingTop: 14 }}>
        <div className="row between">
          <div className="row gap-12">
            <Avatar name={s.user.name} hue={200} size={46} />
            <div>
              <div className="t-sm">{greeting()}</div>
              <div className="t-h2">{first}</div>
            </div>
          </div>
          <div className="row gap-8">
            {s.plus && <span className="badge accent"><Icon name="Crown" size={13} />Plus</span>}
            <button className="icon-btn" onClick={() => nav.push('notifications')} aria-label="Notifications"><Icon name="Bell" size={20} /><span className="dot" /></button>
          </div>
        </div>

        <button className="search tap" style={{ marginTop: 18, width: '100%', border: 0, textAlign: 'left' }} onClick={() => nav.push('search', { focus: true })}>
          <Icon name="Search" size={20} />
          <span style={{ flex: 1, fontSize: 15 }}>Search doctors, symptoms, tests</span>
          <Icon name="SlidersHorizontal" size={18} />
        </button>

        {next && (() => {
          const d = doctor(next.doctorId);
          const mins = Math.round((next.t - now) / 60000);
          const live = next.mode === 'video' && mins <= 15;
          return (
            <div className="hero" style={{ marginTop: 18 }}>
              <div className="row between" style={{ position: 'relative', zIndex: 1 }}>
                <span className="hero-pill"><Icon name={next.mode === 'video' ? 'Video' : 'MapPin'} size={14} />{next.mode === 'video' ? 'Video visit' : 'Clinic visit'}</span>
                <span className="t-xs" style={{ color: '#fff' }}>{mins > 0 && mins < 60 ? `Starts in ${mins} min` : `${relDay(next.t)}, ${fmtTime(next.t)}`}</span>
              </div>
              <div className="row gap-12" style={{ marginTop: 16, position: 'relative', zIndex: 1 }}>
                <Avatar name={d.name} hue={d.hue} size={52} online={live} />
                <div className="grow">
                  <div className="t-h3">{d.name}</div>
                  <div className="t-sm">{specialtyOf(d.specialty).name} · for {next.member.split(' ')[0]}</div>
                </div>
              </div>
              <div className="row gap-10" style={{ marginTop: 16, position: 'relative', zIndex: 1 }}>
                {live ? (
                  <button className="btn white grow" onClick={() => nav.push('call', { apptId: next.id })}><Icon name="Video" size={18} />Join visit</button>
                ) : (
                  <button className="btn white grow" onClick={() => nav.push('appt', { id: next.id })}>View details</button>
                )}
                <button className="icon-btn on-dark" style={{ width: 52, height: 52, borderRadius: 16 }} onClick={() => nav.push('appt', { id: next.id })} aria-label="Appointment options"><Icon name="CalendarClock" size={20} /></button>
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

        {!s.plus && (
          <button className="card tap row gap-12" onClick={() => nav.push('plus')} style={{ marginTop: 24, border: 0, padding: 16, textAlign: 'left', background: 'linear-gradient(120deg, #fff4ec, #ffe7dc)' }}>
            <span className="tile-icon accent" style={{ background: '#fff' }}><Icon name="Crown" size={22} /></span>
            <div className="grow">
              <div className="t-h3">CareLoop Plus for your family</div>
              <div className="t-sm" style={{ color: '#7a4a3a' }}>20% off every consult, free home collection and delivery. {money(s.region, r.plus.monthly)}/month.</div>
            </div>
            <Icon name="ChevronRight" size={20} className="t-accent" />
          </button>
        )}

        <SectionHead title="Top doctors near you" action="View all" onAction={() => nav.push('search')} />
        <div className="hscroll">
          {docs.slice(0, 6).map((d) => (
            <button key={d.id} className="card tap stack gap-10" onClick={() => nav.push('doctor', { id: d.id })} style={{ width: 168, border: 0, padding: 14, textAlign: 'left' }}>
              <div className="row between" style={{ alignItems: 'flex-start' }}>
                <Avatar name={d.name} hue={d.hue} size={54} square online={d.nextFree.startsWith('in')} />
                <Stars rating={d.rating} />
              </div>
              <div>
                <div className="t-h3 ellipsis">{d.name}</div>
                <div className="t-sm ellipsis">{specialtyOf(d.specialty).name}</div>
              </div>
              <div className="row between">
                <span className="num" style={{ fontWeight: 800 }}>{money(s.region, d.feeVideo)}</span>
                <span className="badge good">{d.nextFree.startsWith('in') ? 'Available' : 'Today'}</span>
              </div>
            </button>
          ))}
        </div>

        <SectionHead title="Your health" action="Records" onAction={() => nav.setTab('records')} />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          {[
            { label: 'Blood pressure', v: `${s.vitals.bp.at(-1)}/${78}`, unit: 'mmHg', data: s.vitals.bp, note: 'Improving' },
            { label: 'Fasting sugar', v: String(s.vitals.sugar.at(-1)), unit: 'mg/dL', data: s.vitals.sugar, note: 'In range' },
          ].map((v) => (
            <button key={v.label} className="card tap stack gap-8" onClick={() => nav.setTab('records')} style={{ border: 0, padding: 14, textAlign: 'left' }}>
              <div className="t-xs">{v.label}</div>
              <div className="row gap-4" style={{ alignItems: 'baseline' }}><span className="t-h2 num">{v.v}</span><span className="t-xs">{v.unit}</span></div>
              <Sparkline values={v.data} width={130} height={36} />
              <span className="badge good" style={{ alignSelf: 'flex-start' }}><Icon name="TrendingDown" size={12} />{v.note}</span>
            </button>
          ))}
        </div>

        <div className="row gap-10 card flat" style={{ marginTop: 24, padding: 14, background: 'var(--bad-soft)', boxShadow: 'none' }}>
          <Icon name="Siren" size={20} className="t-bad" />
          <div className="t-sm grow" style={{ color: '#8a1c1c' }}>Chest pain, trouble breathing or severe bleeding? Call <b>{r.emergency}</b> now. CareLoop is not for emergencies.</div>
        </div>
      </div>
    </div>
  );
}
