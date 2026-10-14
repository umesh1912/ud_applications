import { useEffect, useRef, useState } from 'react';
import { orderBy } from 'firebase/firestore';
import { fmtDay, fmtTime, relDay, specialtyOf } from '../data/catalog';
import { money } from '../data/region';
import { cancelAppointment, markJoined, markRead, openVideoRoom, rateVisit, sendMessage } from '../lib/care';
import { errorText, useQuery } from '../lib/db';
import type { ApptDoc, MessageDoc } from '../lib/model';
import { Avatar, Empty, Icon, Segmented, Sheet, TopBar, useNow, useToast, type Nav } from '../ui/kit';
import { isUpcoming, statusOf, useP } from './ctx';

const STATUS: Record<string, { label: string; cls: string }> = {
  booked: { label: 'Upcoming', cls: 'brand' },
  waiting: { label: 'In waiting room', cls: 'accent' },
  'in-consult': { label: 'In consult', cls: 'good' },
  completed: { label: 'Completed', cls: 'good' },
  cancelled: { label: 'Cancelled', cls: 'bad' },
  missed: { label: 'Missed', cls: 'warn' },
};

const canJoin = (a: ApptDoc, now: number) => a.mode === 'video' && isUpcoming(a, now) && (a.t - now < 15 * 60000 || a.status !== 'booked');

async function join(a: ApptDoc) {
  await markJoined(a);
  await openVideoRoom(a.room, a.member);
}

export function Visits({ nav }: { nav: Nav }) {
  const { appts } = useP();
  const now = useNow();
  const [tab, setTab] = useState<'upcoming' | 'past'>('upcoming');
  const list = (appts ?? [])
    .filter((a) => (tab === 'upcoming' ? isUpcoming(a, now) : !isUpcoming(a, now)))
    .sort((a, b) => (tab === 'upcoming' ? a.t - b.t : b.t - a.t));
  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="My visits" left right={<button className="icon-btn" onClick={() => nav.push('search')} aria-label="Book a visit"><Icon name="Plus" size={20} /></button>} />
      <div className="pad stack gap-16">
        <Segmented options={[{ id: 'upcoming', label: 'Upcoming' }, { id: 'past', label: 'Past' }]} value={tab} onChange={setTab} />
        {appts === undefined && <div className="t-sm">Loading…</div>}
        {appts && list.length === 0 && (
          <Empty icon="CalendarHeart" title={tab === 'upcoming' ? 'No upcoming visits' : 'No past visits yet'} body="Book a video or clinic visit with a verified doctor in under a minute."
            action={<button className="btn sm" onClick={() => nav.push('search')}>Find a doctor</button>} />
        )}
        {list.map((a) => {
          const st = STATUS[statusOf(a, now)];
          return (
            <div key={a.id} className="card tap" style={{ padding: 16 }} onClick={() => nav.push('appt', { id: a.id })}>
              <div className="row between">
                <span className={`badge ${st.cls}`}>{st.label}</span>
                <span className="t-xs row gap-4"><Icon name={a.mode === 'video' ? 'Video' : 'Building2'} size={13} />{a.mode === 'video' ? 'Video' : 'Clinic'}</span>
              </div>
              <div className="row gap-12" style={{ marginTop: 12 }}>
                <Avatar name={a.doctorName} hue={a.doctorHue} size={50} square />
                <div className="grow">
                  <div className="t-h3">{a.doctorName}</div>
                  <div className="t-sm">{specialtyOf(a.specialty).name} · {a.member.split(' ')[0]}</div>
                </div>
              </div>
              <div className="row between" style={{ marginTop: 14, padding: '10px 12px', borderRadius: 12, background: 'var(--surface-2)' }}>
                <span className="row gap-6" style={{ fontWeight: 700, fontSize: 14 }}><Icon name="Calendar" size={15} />{relDay(a.t)}</span>
                <span className="row gap-6 num" style={{ fontWeight: 700, fontSize: 14 }}><Icon name="Clock" size={15} />{fmtTime(a.t)}</span>
              </div>
              {canJoin(a, now) && <button className="btn block" style={{ marginTop: 12 }} onClick={(e) => { e.stopPropagation(); join(a); }}><Icon name="Video" size={18} />Join visit</button>}
              {a.rx && <button className="btn block soft" style={{ marginTop: 12 }} onClick={(e) => { e.stopPropagation(); nav.push('rx', { id: a.id }); }}><Icon name="FileText" size={18} />View prescription</button>}
            </div>
          );
        })}
      </div>
    </div>
  );
}

export function ApptDetail({ nav, id }: { nav: Nav; id: string }) {
  const { appts } = useP();
  const toast = useToast();
  const now = useNow(15000);
  const [cancel, setCancel] = useState(false);
  const [busy, setBusy] = useState(false);
  const a = appts?.find((x) => x.id === id);
  if (!a) return <div className="screen"><TopBar onBack={() => nav.back()} /></div>;
  const status = statusOf(a, now);
  const st = STATUS[status];
  const upcoming = isUpcoming(a, now);
  const lateCancel = a.t - now < 2 * 3600000;

  return (
    <div className="screen">
      <TopBar title="Visit details" onBack={() => nav.back()} />
      <div className="pad stack gap-16" style={{ paddingBottom: 30 }}>
        <div className="card p-lg stack center gap-8" style={{ textAlign: 'center' }}>
          <Avatar name={a.doctorName} hue={a.doctorHue} size={72} square />
          <div className="t-h2" style={{ marginTop: 6 }}>{a.doctorName}</div>
          <div className="t-sm">{specialtyOf(a.specialty).name}</div>
          <span className={`badge ${st.cls}`} style={{ marginTop: 4 }}>{st.label}</span>
        </div>
        <div className="card p">
          <div className="kv"><span>Date</span><span>{fmtDay(a.t)}</span></div>
          <div className="kv"><span>Time</span><span className="num">{fmtTime(a.t)}</span></div>
          <div className="kv"><span>Type</span><span>{a.mode === 'video' ? 'Video visit' : 'In clinic'}{a.instant ? ' · instant' : ''}</span></div>
          <div className="kv"><span>Patient</span><span>{a.member}</span></div>
          <div className="kv"><span>Reason</span><span style={{ maxWidth: 190 }}>{a.reason}</span></div>
          <div className="kv"><span>Paid</span><span className="num">{money(a.region, a.payment.amount)}{a.payment.status === 'refund-pending' ? ' · refunding' : ''}</span></div>
        </div>

        {upcoming && a.mode === 'video' && (
          <button className="btn block" disabled={!canJoin(a, now)} onClick={() => join(a)}>
            <Icon name="Video" size={18} />{canJoin(a, now) ? 'Join visit' : 'Join opens 15 min before'}
          </button>
        )}
        {upcoming && a.mode === 'video' && <div className="t-xs row gap-6" style={{ marginTop: -8, justifyContent: 'center' }}><Icon name="Info" size={13} />The visit opens in a secure Jitsi Meet room. Allow camera and microphone.</div>}
        {upcoming && !a.instant && (
          <div className="row gap-10">
            <button className="btn ghost grow" onClick={() => nav.push('doctor', { id: a.doctorId, mode: a.mode, rescheduleOf: a.id })}><Icon name="CalendarClock" size={18} />Reschedule</button>
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
        {(status === 'completed' || upcoming) && (
          <button className="list-row card" style={{ border: 0, borderRadius: 18 }} onClick={() => nav.push('chat', { id: a.id })}>
            <span className="tile-icon good"><Icon name="MessageCircle" size={20} /></span>
            <div className="grow" style={{ textAlign: 'left' }}><div className="t-h3">Message {a.doctorName.split(' ').slice(0, 2).join(' ')}</div><div className="t-sm">{status === 'completed' ? 'Free follow-up for 7 days' : 'Share reports or ask before the visit'}</div></div>
            <Icon name="ChevronRight" size={18} className="chev" />
          </button>
        )}
        {status === 'completed' && !a.rating && <button className="btn block soft" onClick={() => nav.push('rate', { id: a.id })}><Icon name="Star" size={18} />Rate this visit</button>}
        {a.rating && <div className="row gap-6 t-sm center">You rated this visit {a.rating}<Icon name="Star" size={14} style={{ color: 'var(--star)', fill: 'var(--star)' }} /></div>}
        <div className="t-xs" style={{ textAlign: 'center' }}>Payment ref {a.payment.ref}</div>
      </div>
      <Sheet open={cancel} onClose={() => setCancel(false)}>
        <div className="stack gap-12">
          <div className="t-h2">Cancel this visit?</div>
          <div className="t-body">{lateCancel ? 'This visit is less than 2 hours away, so the booking fee isn’t refunded. ' : ''}The consultation fee goes back to your original payment method within 3–5 days.</div>
          <button className="btn block danger" disabled={busy} onClick={async () => {
            setBusy(true);
            try { await cancelAppointment(a, 'patient'); toast('Visit cancelled · refund started'); setCancel(false); }
            catch (e) { toast(errorText(e)); }
            setBusy(false);
          }}>{busy ? <span className="spinner" /> : 'Yes, cancel visit'}</button>
          <button className="btn block ghost" onClick={() => setCancel(false)}>Keep it</button>
        </div>
      </Sheet>
    </div>
  );
}

const TAGS = ['Listened well', 'Clear explanation', 'On time', 'Thorough', 'Friendly'];

export function RateVisit({ nav, id }: { nav: Nav; id: string }) {
  const { appts } = useP();
  const toast = useToast();
  const a = appts?.find((x) => x.id === id);
  const [stars, setStars] = useState(5);
  const [tags, setTags] = useState<string[]>([]);
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  if (!a) return null;
  return (
    <div className="screen stack" style={{ padding: '36px 24px 24px' }}>
      <div className="stack center gap-12" style={{ flex: 1, textAlign: 'center' }}>
        <Avatar name={a.doctorName} hue={a.doctorHue} size={84} square />
        <div className="t-h1" style={{ marginTop: 8 }}>How was your visit?</div>
        <div className="t-body">Your review helps other patients choose {a.doctorName}.</div>
        <div className="row gap-8" style={{ marginTop: 8 }}>
          {[1, 2, 3, 4, 5].map((n) => (
            <button key={n} onClick={() => setStars(n)} className="tap" style={{ border: 0, background: 'none', padding: 2 }} aria-label={`${n} stars`}>
              <Icon name="Star" size={36} style={{ color: 'var(--star)', fill: n <= stars ? 'var(--star)' : 'none' }} />
            </button>
          ))}
        </div>
        <div className="row wrap gap-8 center">{TAGS.map((t) => <button key={t} className={`chip${tags.includes(t) ? ' on' : ''}`} onClick={() => setTags(tags.includes(t) ? tags.filter((x) => x !== t) : [...tags, t])}>{t}</button>)}</div>
        <textarea className="input" rows={3} value={text} onChange={(e) => setText(e.target.value)} placeholder="Tell others about your visit (optional)" />
      </div>
      <button className="btn block" disabled={busy} onClick={async () => {
        setBusy(true);
        try { await rateVisit(a, stars, [tags.join(', '), text.trim()].filter(Boolean).join('. ')); toast('Thanks for your review'); nav.back(); }
        catch (e) { toast(errorText(e)); setBusy(false); }
      }}>{busy ? <span className="spinner" /> : 'Submit review'}</button>
    </div>
  );
}

export function RxView({ nav, id }: { nav: Nav; id: string }) {
  const { me, appts } = useP();
  const toast = useToast();
  const a = appts?.find((x) => x.id === id);
  if (!a?.rx) return null;
  const rx = a.rx;
  const share = async () => {
    const text = `Prescription from ${a.doctorName} (${fmtDay(rx.signedAt)})\nPatient: ${a.member}\nDiagnosis: ${rx.diagnosis}\n${rx.meds.map((m, i) => `${i + 1}. ${m.name} ${m.dose} for ${m.duration}${m.note ? ` (${m.note})` : ''}`).join('\n')}${rx.tests.length ? `\nTests: ${rx.tests.join(', ')}` : ''}\nAdvice: ${rx.advice}`;
    try {
      if (navigator.share) await navigator.share({ title: 'Prescription', text });
      else { await navigator.clipboard.writeText(text); toast('Prescription copied'); }
    } catch { /* share sheet closed */ }
  };
  return (
    <div className="screen has-cta">
      <TopBar title="Prescription" onBack={() => nav.back()} right={<button className="icon-btn" onClick={share} aria-label="Share"><Icon name="Share2" size={19} /></button>} />
      <div className="pad" style={{ paddingBottom: 12 }}>
        <div className="card" style={{ overflow: 'hidden' }}>
          <div style={{ padding: 18, background: 'linear-gradient(135deg, var(--hero-a), var(--hero-b))', color: '#fff' }}>
            <div className="row between">
              <div><div className="t-h3">{a.doctorName}</div><div style={{ fontSize: 12.5, opacity: 0.85 }}>{specialtyOf(a.specialty).name}</div></div>
              <Icon name="HeartPulse" size={28} />
            </div>
          </div>
          <div style={{ padding: 18 }} className="stack gap-14">
            <div className="row between t-sm">
              <span><b style={{ color: 'var(--ink)' }}>{a.member}</b>{a.member === me.name && me.age ? ` · ${me.age} y, ${me.sex}` : ''}</span>
              <span>{fmtDay(rx.signedAt)}</span>
            </div>
            <div><div className="t-label">Diagnosis</div><div className="t-h3" style={{ marginTop: 4 }}>{rx.diagnosis}</div></div>
            <div>
              <div className="t-label" style={{ marginBottom: 8 }}>Rx · Medicines</div>
              <div className="stack gap-10">
                {rx.meds.map((m, i) => (
                  <div key={m.name} className="row gap-12" style={{ alignItems: 'flex-start' }}>
                    <span className="tile-icon sm" style={{ fontWeight: 800, fontSize: 13 }}>{i + 1}</span>
                    <div className="grow"><div style={{ fontWeight: 700 }}>{m.name}</div><div className="t-sm">{m.dose} · {m.duration}{m.note ? ` · ${m.note}` : ''}</div></div>
                  </div>
                ))}
              </div>
            </div>
            {rx.tests.length > 0 && <div><div className="t-label" style={{ marginBottom: 8 }}>Tests</div><div className="row wrap gap-6">{rx.tests.map((t) => <span key={t} className="badge brand">{t}</span>)}</div></div>}
            <div><div className="t-label">Advice</div><div className="t-body" style={{ marginTop: 4, fontSize: 14 }}>{rx.advice}</div></div>
            {rx.followUp && <div className="row gap-8 t-sm" style={{ fontWeight: 600 }}><Icon name="CalendarClock" size={16} className="t-brand" />Follow-up {rx.followUp.toLowerCase()}</div>}
            <div className="row between" style={{ borderTop: '1px dashed var(--line)', paddingTop: 12 }}>
              <span className="t-xs">Digitally signed {fmtDay(rx.signedAt)}, {fmtTime(rx.signedAt)} · ID {a.id.slice(0, 8).toUpperCase()}</span>
              <Icon name="QrCode" size={34} />
            </div>
          </div>
        </div>
        {!a.rating && <button className="btn block soft" style={{ marginTop: 14 }} onClick={() => nav.push('rate', { id: a.id })}><Icon name="Star" size={18} />Rate your visit</button>}
      </div>
      <div className="cta-bar solid">
        {rx.tests.length > 0 && <button className="btn ghost" onClick={() => nav.push('labs', { tests: rx.tests })}><Icon name="FlaskConical" size={18} />Book tests</button>}
        <button className="btn grow" onClick={() => nav.push('pharmacy', { apptId: a.id })}><Icon name="ShoppingBag" size={18} />Order medicines</button>
      </div>
    </div>
  );
}

/** Real-time chat between the patient and the doctor on one visit. */
export function Chat({ nav, id }: { nav: Nav; id: string }) {
  const { uid, appts } = useP();
  const a = appts?.find((x) => x.id === id);
  const msgs = useQuery<MessageDoc>(`msgs-${id}`, `appointments/${id}/messages`, orderBy('t'));
  const [text, setText] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const end = useRef<HTMLDivElement>(null);
  useEffect(() => { end.current?.scrollIntoView({ behavior: 'smooth' }); markRead(id); }, [msgs, id]);
  if (!a) return null;
  const send = async (t: string) => {
    if (!t.trim()) return;
    setText(''); setErr(null);
    try { await sendMessage(a, uid, t); } catch (e) { setErr(errorText(e)); setText(t); }
  };
  return (
    <div className="app">
      <div className="topbar on-surface">
        <button className="icon-btn" onClick={() => nav.back()} aria-label="Back"><Icon name="ChevronLeft" size={22} /></button>
        <Avatar name={a.doctorName} hue={a.doctorHue} size={40} />
        <div className="grow"><div className="t-h3">{a.doctorName}</div><div className="t-xs">{specialtyOf(a.specialty).name} · usually replies within a few hours</div></div>
      </div>
      <div className="screen" style={{ padding: '16px 16px 8px' }}>
        <div className="t-xs" style={{ textAlign: 'center', margin: '0 0 12px' }}>Messages are private to you and your doctor. For emergencies, call your local emergency number.</div>
        <div className="stack gap-8">
          {msgs === undefined && <div className="t-sm center">Loading…</div>}
          {msgs?.length === 0 && <div className="t-sm" style={{ textAlign: 'center' }}>No messages yet. Say hello or share an update.</div>}
          {(msgs ?? []).map((m) => {
            const mine = m.from === uid;
            return (
              <div key={m.id} style={{ alignSelf: mine ? 'flex-end' : 'flex-start', maxWidth: '80%', padding: '10px 14px', borderRadius: 18, fontSize: 14.5, lineHeight: 1.45,
                background: mine ? 'var(--brand)' : 'var(--surface)', color: mine ? '#fff' : 'var(--ink)',
                borderBottomRightRadius: mine ? 6 : 18, borderBottomLeftRadius: mine ? 18 : 6, boxShadow: mine ? 'none' : 'var(--shadow)', whiteSpace: 'pre-wrap' }}>
                {m.text}
                <div style={{ fontSize: 10.5, opacity: 0.65, marginTop: 4, textAlign: 'right' }}>{relDay(m.t) === 'Today' ? '' : `${relDay(m.t)}, `}{fmtTime(m.t)}</div>
              </div>
            );
          })}
          <div ref={end} />
        </div>
      </div>
      {err && <div className="t-sm t-bad" style={{ padding: '0 16px' }}>{err}</div>}
      <form className="row gap-8" style={{ padding: '8px 12px 14px', background: 'var(--surface)', borderTop: '1px solid var(--line)' }} onSubmit={(e) => { e.preventDefault(); send(text); }}>
        <input className="input" style={{ height: 46 }} value={text} onChange={(e) => setText(e.target.value)} placeholder="Message" aria-label="Message" />
        <button type="submit" className="icon-btn" style={{ background: 'var(--brand)', color: '#fff', boxShadow: 'none' }} aria-label="Send"><Icon name="SendHorizontal" size={19} /></button>
      </form>
    </div>
  );
}
