import { useEffect, useRef, useState } from 'react';
import { fmtDay, fmtTime, relDay, specialtyOf } from '../data/catalog';
import { money } from '../data/region';
import { CallScreen } from '../ui/call';
import { Avatar, Empty, Icon, Segmented, Sheet, TopBar, useNow, useToast, type Nav } from '../ui/kit';
import { VIRAL_RX, statusOf, useP, type Appt } from './state';

const STATUS: Record<string, { label: string; cls: string }> = {
  upcoming: { label: 'Upcoming', cls: 'brand' },
  completed: { label: 'Completed', cls: 'good' },
  cancelled: { label: 'Cancelled', cls: 'bad' },
  missed: { label: 'Missed', cls: 'warn' },
};

export function Visits({ nav }: { nav: Nav }) {
  const { s, doctor } = useP();
  const now = useNow();
  const [tab, setTab] = useState<'upcoming' | 'past'>('upcoming');
  const list = s.appts
    .filter((a) => (tab === 'upcoming' ? statusOf(a, now) === 'upcoming' : statusOf(a, now) !== 'upcoming'))
    .sort((a, b) => (tab === 'upcoming' ? a.t - b.t : b.t - a.t));
  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="My visits" left right={<button className="icon-btn" onClick={() => nav.push('search')} aria-label="Book a visit"><Icon name="Plus" size={20} /></button>} />
      <div className="pad stack gap-16">
        <Segmented options={[{ id: 'upcoming', label: 'Upcoming' }, { id: 'past', label: 'Past' }]} value={tab} onChange={setTab} />
        {list.length === 0 && (
          <Empty icon="CalendarHeart" title={tab === 'upcoming' ? 'No upcoming visits' : 'No past visits yet'} body="Book a video or clinic visit with a verified doctor in under a minute."
            action={<button className="btn sm" onClick={() => nav.push('search')}>Find a doctor</button>} />
        )}
        {list.map((a) => {
          const d = doctor(a.doctorId);
          const st = STATUS[statusOf(a, now)];
          const soon = statusOf(a, now) === 'upcoming' && a.mode === 'video' && a.t - now < 15 * 60000;
          return (
            <div key={a.id} className="card tap" style={{ padding: 16 }} onClick={() => nav.push('appt', { id: a.id })}>
              <div className="row between">
                <span className={`badge ${st.cls}`}>{st.label}</span>
                <span className="t-xs row gap-4"><Icon name={a.mode === 'video' ? 'Video' : 'Building2'} size={13} />{a.mode === 'video' ? 'Video' : 'Clinic'}</span>
              </div>
              <div className="row gap-12" style={{ marginTop: 12 }}>
                <Avatar name={d.name} hue={d.hue} size={50} square />
                <div className="grow">
                  <div className="t-h3">{d.name}</div>
                  <div className="t-sm">{specialtyOf(d.specialty).name} · {a.member.split(' ')[0]}</div>
                </div>
              </div>
              <div className="row between" style={{ marginTop: 14, padding: '10px 12px', borderRadius: 12, background: 'var(--surface-2)' }}>
                <span className="row gap-6" style={{ fontWeight: 700, fontSize: 14 }}><Icon name="Calendar" size={15} />{relDay(a.t)}</span>
                <span className="row gap-6 num" style={{ fontWeight: 700, fontSize: 14 }}><Icon name="Clock" size={15} />{fmtTime(a.t)}</span>
              </div>
              {soon && <button className="btn block" style={{ marginTop: 12 }} onClick={(e) => { e.stopPropagation(); nav.push('call', { apptId: a.id }); }}><Icon name="Video" size={18} />Join visit</button>}
              {a.rx && <button className="btn block soft" style={{ marginTop: 12 }} onClick={(e) => { e.stopPropagation(); nav.push('rx', { id: a.id }); }}><Icon name="FileText" size={18} />View prescription</button>}
            </div>
          );
        })}
      </div>
    </div>
  );
}

export function ApptDetail({ nav, id }: { nav: Nav; id: string }) {
  const { s, set, doctor } = useP();
  const toast = useToast();
  const now = useNow();
  const [cancel, setCancel] = useState(false);
  const a = s.appts.find((x) => x.id === id);
  if (!a) return null;
  const d = doctor(a.doctorId);
  const status = statusOf(a, now);
  const st = STATUS[status];
  const upcoming = status === 'upcoming';
  const update = (patch: Partial<Appt>) => set((p) => ({ ...p, appts: p.appts.map((x) => (x.id === id ? { ...x, ...patch } : x)) }));

  return (
    <div className="screen">
      <TopBar title="Visit details" onBack={() => nav.back()} />
      <div className="pad stack gap-16" style={{ paddingBottom: 30 }}>
        <div className="card p-lg stack center gap-8" style={{ textAlign: 'center' }}>
          <Avatar name={d.name} hue={d.hue} size={72} square />
          <div className="t-h2" style={{ marginTop: 6 }}>{d.name}</div>
          <div className="t-sm">{specialtyOf(d.specialty).name} · {d.clinic}</div>
          <span className={`badge ${st.cls}`} style={{ marginTop: 4 }}>{st.label}</span>
        </div>
        <div className="card p">
          <div className="kv"><span>Date</span><span>{fmtDay(a.t)}</span></div>
          <div className="kv"><span>Time</span><span className="num">{fmtTime(a.t)}</span></div>
          <div className="kv"><span>Type</span><span>{a.mode === 'video' ? 'Video visit' : 'In clinic'}</span></div>
          <div className="kv"><span>Patient</span><span>{a.member}</span></div>
          <div className="kv"><span>Reason</span><span style={{ maxWidth: 190 }}>{a.reason}</span></div>
          <div className="kv"><span>Paid</span><span className="num">{money(s.region, a.paid)}</span></div>
        </div>

        {upcoming && a.mode === 'video' && (
          <button className="btn block" disabled={a.t - now > 15 * 60000} onClick={() => nav.push('call', { apptId: a.id })}>
            <Icon name="Video" size={18} />{a.t - now > 15 * 60000 ? 'Join opens 15 min before' : 'Join visit'}
          </button>
        )}
        {upcoming && a.mode === 'clinic' && (
          <div className="card row gap-12" style={{ padding: 14 }}>
            <span className="tile-icon accent"><Icon name="Ticket" size={20} /></span>
            <div className="grow"><div className="t-h3">Token #{7 + (a.t % 5)}</div><div className="t-sm">Show at reception · arrive 10 min early</div></div>
            <button className="icon-btn" aria-label="Directions" onClick={() => toast('Opening directions')}><Icon name="Navigation" size={18} /></button>
          </div>
        )}
        {upcoming && (
          <div className="row gap-10">
            <button className="btn ghost grow" onClick={() => nav.push('doctor', { id: d.id, mode: a.mode })}><Icon name="CalendarClock" size={18} />Reschedule</button>
            <button className="btn danger grow" onClick={() => setCancel(true)}>Cancel</button>
          </div>
        )}
        {a.rx && (
          <button className="list-row card" style={{ border: 0, borderRadius: 18 }} onClick={() => nav.push('rx', { id: a.id })}>
            <span className="tile-icon"><Icon name="FileText" size={20} /></span>
            <div className="grow" style={{ textAlign: 'left' }}><div className="t-h3">Prescription</div><div className="t-sm">{a.rx.meds.length} medicines · {a.rx.tests.length} tests</div></div>
            <Icon name="ChevronRight" size={18} className="chev" />
          </button>
        )}
        {status === 'completed' && (
          <button className="list-row card" style={{ border: 0, borderRadius: 18 }} onClick={() => nav.push('chat', { doctorId: d.id })}>
            <span className="tile-icon good"><Icon name="MessageCircle" size={20} /></span>
            <div className="grow" style={{ textAlign: 'left' }}><div className="t-h3">Message {d.name.split(' ').slice(0, 2).join(' ')}</div><div className="t-sm">Free follow-up for 7 days</div></div>
            <Icon name="ChevronRight" size={18} className="chev" />
          </button>
        )}
        {status === 'completed' && !a.rated && (
          <div className="card p stack gap-10">
            <div className="t-h3">How was your visit?</div>
            <div className="row gap-8">{[1, 2, 3, 4, 5].map((n) => (
              <button key={n} className="icon-btn" onClick={() => { update({ rated: n }); toast('Thanks for your feedback'); }} aria-label={`${n} stars`}><Icon name="Star" size={20} style={{ color: 'var(--star)' }} /></button>
            ))}</div>
          </div>
        )}
        <button className="row gap-8 t-sm tap" onClick={() => toast('Invoice sent to your email')} style={{ border: 0, background: 'none', justifyContent: 'center', fontWeight: 600 }}><Icon name="Receipt" size={16} />Download invoice</button>
      </div>
      <Sheet open={cancel} onClose={() => setCancel(false)}>
        <div className="stack gap-12">
          <div className="t-h2">Cancel this visit?</div>
          <div className="t-body">You’ll get a full refund of {money(s.region, a.paid)} to your original payment method within 3–5 days.</div>
          <button className="btn block danger" onClick={() => { update({ status: 'cancelled' }); setCancel(false); toast('Visit cancelled · refund started'); }}>Yes, cancel visit</button>
          <button className="btn block ghost" onClick={() => setCancel(false)}>Keep it</button>
        </div>
      </Sheet>
    </div>
  );
}

/** Live video visit; ending it completes the appointment and delivers the prescription. */
export function PatientCall({ nav, apptId }: { nav: Nav; apptId: string }) {
  const { s, set, doctor } = useP();
  const a = s.appts.find((x) => x.id === apptId)!;
  const d = doctor(a.doctorId);
  return (
    <CallScreen
      name={d.name}
      sub={`${specialtyOf(d.specialty).name} · Video visit`}
      hue={d.hue}
      selfName={a.member}
      onEnd={() => {
        set((p) => ({ ...p, appts: p.appts.map((x) => (x.id === apptId ? { ...x, status: 'completed', t: Math.min(x.t, Date.now()), rx: x.rx ?? VIRAL_RX } : x)) }));
        nav.replace('rate', { id: apptId });
      }}
    />
  );
}

const TAGS = ['Listened well', 'Clear explanation', 'On time', 'Thorough', 'Friendly'];

export function RateVisit({ nav, id }: { nav: Nav; id: string }) {
  const { s, set, doctor } = useP();
  const toast = useToast();
  const a = s.appts.find((x) => x.id === id)!;
  const d = doctor(a.doctorId);
  const [stars, setStars] = useState(5);
  const [tags, setTags] = useState<string[]>(['Listened well']);
  return (
    <div className="screen stack" style={{ padding: '36px 24px 24px' }}>
      <div className="stack center gap-12" style={{ flex: 1, textAlign: 'center' }}>
        <Avatar name={d.name} hue={d.hue} size={84} square />
        <div className="t-h1" style={{ marginTop: 8 }}>Visit complete</div>
        <div className="t-body">Your prescription from {d.name} is ready. How was the visit?</div>
        <div className="row gap-8" style={{ marginTop: 8 }}>
          {[1, 2, 3, 4, 5].map((n) => (
            <button key={n} onClick={() => setStars(n)} className="tap" style={{ border: 0, background: 'none', padding: 2 }} aria-label={`${n} stars`}>
              <Icon name="Star" size={36} style={{ color: 'var(--star)', fill: n <= stars ? 'var(--star)' : 'none' }} />
            </button>
          ))}
        </div>
        <div className="row wrap gap-8 center" style={{ marginTop: 8 }}>
          {TAGS.map((t) => <button key={t} className={`chip${tags.includes(t) ? ' on' : ''}`} onClick={() => setTags(tags.includes(t) ? tags.filter((x) => x !== t) : [...tags, t])}>{t}</button>)}
        </div>
      </div>
      <div className="stack gap-10">
        <button className="btn block" onClick={() => { set((p) => ({ ...p, appts: p.appts.map((x) => (x.id === id ? { ...x, rated: stars } : x)) })); toast('Thanks! Your review helps others'); nav.replace('rx', { id }); }}>Submit and view prescription</button>
        <button className="btn block ghost" style={{ background: 'none', boxShadow: 'none' }} onClick={() => nav.replace('rx', { id })}>Skip</button>
      </div>
    </div>
  );
}

export function RxView({ nav, id }: { nav: Nav; id: string }) {
  const { s, doctor } = useP();
  const toast = useToast();
  const a = s.appts.find((x) => x.id === id)!;
  const d = doctor(a.doctorId);
  const rx = a.rx!;
  return (
    <div className="screen has-cta">
      <TopBar title="Prescription" onBack={() => nav.back()} right={<button className="icon-btn" onClick={() => toast('Prescription PDF shared')} aria-label="Share"><Icon name="Share2" size={19} /></button>} />
      <div className="pad" style={{ paddingBottom: 12 }}>
        <div className="card" style={{ overflow: 'hidden' }}>
          <div style={{ padding: 18, background: 'linear-gradient(135deg, var(--hero-a), var(--hero-b))', color: '#fff' }}>
            <div className="row between">
              <div>
                <div className="t-h3">{d.name}</div>
                <div style={{ fontSize: 12.5, opacity: 0.85 }}>{d.degrees}</div>
                <div style={{ fontSize: 12, opacity: 0.75, marginTop: 2 }}>Reg. no. {s.region === 'IN' ? 'KMC 84213' : 'CA A-129874'} · {d.clinic}</div>
              </div>
              <Icon name="HeartPulse" size={28} />
            </div>
          </div>
          <div style={{ padding: 18 }} className="stack gap-14">
            <div className="row between t-sm">
              <span><b style={{ color: 'var(--ink)' }}>{a.member}</b> · {a.member === s.user.name ? `${s.user.age} y, ${s.user.sex}` : 'Family'}</span>
              <span>{fmtDay(a.t)}</span>
            </div>
            <div>
              <div className="t-label">Diagnosis</div>
              <div className="t-h3" style={{ marginTop: 4 }}>{rx.diagnosis}</div>
            </div>
            <div>
              <div className="t-label" style={{ marginBottom: 8 }}>Rx · Medicines</div>
              <div className="stack gap-10">
                {rx.meds.map((m, i) => (
                  <div key={m.name} className="row gap-12" style={{ alignItems: 'flex-start' }}>
                    <span className="tile-icon sm" style={{ fontWeight: 800, fontSize: 13 }}>{i + 1}</span>
                    <div className="grow">
                      <div style={{ fontWeight: 700 }}>{m.name}</div>
                      <div className="t-sm">{m.dose} · {m.duration}{m.note ? ` · ${m.note}` : ''}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
            {rx.tests.length > 0 && (
              <div>
                <div className="t-label" style={{ marginBottom: 8 }}>Tests</div>
                <div className="row wrap gap-6">{rx.tests.map((t) => <span key={t} className="badge brand">{t}</span>)}</div>
              </div>
            )}
            <div>
              <div className="t-label">Advice</div>
              <div className="t-body" style={{ marginTop: 4, fontSize: 14 }}>{rx.advice}</div>
            </div>
            {rx.followUp && <div className="row gap-8 t-sm" style={{ fontWeight: 600 }}><Icon name="CalendarClock" size={16} className="t-brand" />Follow-up {rx.followUp.toLowerCase()}</div>}
            <div className="row between" style={{ borderTop: '1px dashed var(--line)', paddingTop: 12 }}>
              <span className="t-xs">Digitally signed · verifiable QR</span>
              <Icon name="QrCode" size={34} />
            </div>
          </div>
        </div>
      </div>
      <div className="cta-bar solid">
        {rx.tests.length > 0 && <button className="btn ghost" onClick={() => nav.push('labs', { tests: rx.tests })}><Icon name="FlaskConical" size={18} />Book tests</button>}
        <button className="btn grow" onClick={() => nav.push('pharmacy', { apptId: a.id })}><Icon name="ShoppingBag" size={18} />Order medicines</button>
      </div>
    </div>
  );
}

interface Msg { from: 'me' | 'doc'; text: string; t: number }

export function Chat({ nav, doctorId }: { nav: Nav; doctorId: string }) {
  const { doctor, s } = useP();
  const d = doctor(doctorId);
  const [msgs, setMsgs] = useState<Msg[]>([
    { from: 'doc', text: `Hi ${s.user.name.split(' ')[0]}, how are you feeling today? Is the fever down?`, t: Date.now() - 3600000 },
  ]);
  const [text, setText] = useState('');
  const [typing, setTyping] = useState(false);
  const end = useRef<HTMLDivElement>(null);
  useEffect(() => end.current?.scrollIntoView({ behavior: 'smooth' }), [msgs, typing]);

  const send = (t: string) => {
    if (!t.trim()) return;
    setMsgs((m) => [...m, { from: 'me', text: t.trim(), t: Date.now() }]);
    setText('');
    setTyping(true);
    window.setTimeout(() => {
      setTyping(false);
      setMsgs((m) => [...m, { from: 'doc', text: 'Thanks for the update. Continue the medicines for 2 more days and keep drinking fluids. If the fever comes back above 101°F, book a quick follow-up.', t: Date.now() }]);
    }, 2200);
  };

  return (
    <div className="app">
      <div className="topbar on-surface">
        <button className="icon-btn" onClick={() => nav.back()} aria-label="Back"><Icon name="ChevronLeft" size={22} /></button>
        <Avatar name={d.name} hue={d.hue} size={40} online />
        <div className="grow"><div className="t-h3">{d.name}</div><div className="t-xs t-good" style={{ color: 'var(--good)' }}>{typing ? 'typing…' : 'Online · replies in ~10 min'}</div></div>
        <button className="icon-btn" aria-label="Video call" onClick={() => nav.push('search', { specialty: d.specialty })}><Icon name="Video" size={19} /></button>
      </div>
      <div className="screen" style={{ padding: '16px 16px 8px' }}>
        <div className="t-xs" style={{ textAlign: 'center', margin: '0 0 12px' }}>Follow-up chat is free for 7 days after your visit</div>
        <div className="stack gap-8">
          {msgs.map((m, i) => (
            <div key={i} style={{ alignSelf: m.from === 'me' ? 'flex-end' : 'flex-start', maxWidth: '80%', padding: '10px 14px', borderRadius: 18, fontSize: 14.5, lineHeight: 1.45,
              background: m.from === 'me' ? 'var(--brand)' : 'var(--surface)', color: m.from === 'me' ? '#fff' : 'var(--ink)',
              borderBottomRightRadius: m.from === 'me' ? 6 : 18, borderBottomLeftRadius: m.from === 'me' ? 18 : 6, boxShadow: m.from === 'me' ? 'none' : 'var(--shadow)' }}>
              {m.text}
              <div style={{ fontSize: 10.5, opacity: 0.65, marginTop: 4, textAlign: 'right' }}>{fmtTime(m.t)}</div>
            </div>
          ))}
          {typing && <div className="card" style={{ alignSelf: 'flex-start', padding: '10px 16px', borderRadius: 18 }}>•••</div>}
          <div ref={end} />
        </div>
      </div>
      <div className="row gap-6 hscroll" style={{ margin: 0, padding: '6px 12px' }}>
        {['Fever is down', 'Still coughing', 'Can I stop the medicine?', 'Side effects'].map((q) => <button key={q} className="chip" style={{ height: 32, fontSize: 12.5 }} onClick={() => send(q)}>{q}</button>)}
      </div>
      <div className="row gap-8" style={{ padding: '8px 12px 14px', background: 'var(--surface)', borderTop: '1px solid var(--line)' }}>
        <button className="icon-btn ghost" aria-label="Attach"><Icon name="Paperclip" size={20} /></button>
        <input className="input" style={{ height: 46 }} value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && send(text)} placeholder="Message" />
        <button className="icon-btn" style={{ background: 'var(--brand)', color: '#fff', boxShadow: 'none' }} onClick={() => send(text)} aria-label="Send"><Icon name="SendHorizontal" size={19} /></button>
      </div>
    </div>
  );
}
