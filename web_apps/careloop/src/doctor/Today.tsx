import { useState } from 'react';
import { collection, doc, runTransaction, updateDoc } from 'firebase/firestore';
import { COMMON_TESTS, DOSES, DURATIONS, MEDICINES, allergyConflict, fmtDay, fmtTime, startOfToday, specialtyOf } from '../data/catalog';
import { money } from '../data/region';
import { lastRead, openVideoRoom } from '../lib/care';
import { errorText, randomId } from '../lib/db';
import { db } from '../lib/firebase';
import type { ApptDoc, InstantRequest, Rx, RxMed } from '../lib/model';
import { Avatar, Empty, Icon, Sheet, Toggle, TopBar, useNow, useToast, type Nav } from '../ui/kit';
import { commissionOf, updateDoctor, useD } from './ctx';

const STATUS: Record<ApptDoc['status'], { label: string; cls: string }> = {
  completed: { label: 'Seen', cls: 'good' },
  waiting: { label: 'Waiting', cls: 'accent' },
  'in-consult': { label: 'In consult', cls: 'brand' },
  booked: { label: 'Booked', cls: '' },
  cancelled: { label: 'Cancelled', cls: 'bad' },
};

function Info({ a }: { a: ApptDoc }) {
  const p = a.patientInfo ?? {};
  return (
    <div style={{ padding: '10px 12px', borderRadius: 12, background: 'var(--surface-2)', fontSize: 14 }}>
      <b>Reason:</b> {a.reason}
      <div className="row gap-12 wrap t-xs" style={{ marginTop: 6 }}>
        {p.bp && <span>BP {p.bp}</span>}{p.sugar && <span>Sugar {p.sugar}</span>}{p.weight && <span>{p.weight} kg</span>}
        {p.conditions?.length ? <span>{p.conditions.join(', ')}</span> : null}
      </div>
      {p.allergies && p.allergies !== 'None' && <div className="row gap-6" style={{ marginTop: 6, color: 'var(--bad)', fontSize: 12.5, fontWeight: 700 }}><Icon name="TriangleAlert" size={13} />Allergic to {p.allergies}</div>}
    </div>
  );
}

/** First doctor to accept wins: the transaction re-reads the request and fails if someone else took it. */
async function acceptRequest(req: InstantRequest, d: { uid: string; name: string; hue: number; specialty: string }) {
  const apptRef = doc(collection(db, 'appointments'));
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(doc(db, 'instantRequests', req.id));
    if (!snap.exists() || snap.data().status !== 'open') throw new Error('Another doctor already accepted this request.');
    const now = Date.now();
    const appt: Omit<ApptDoc, 'id'> = {
      patientId: req.patientId, patientName: req.patientName, member: req.patientName, patientInfo: req.patientInfo,
      doctorId: d.uid, doctorName: d.name, doctorHue: d.hue, specialty: d.specialty, region: req.region, mode: 'video',
      t: now, day: new Date(now).setHours(0, 0, 0, 0), reason: req.concern, fee: req.fee, payment: req.payment,
      status: 'booked', room: `careloop-${randomId(12)}`, instant: true, createdAt: now,
    };
    tx.set(apptRef, appt);
    tx.update(doc(db, 'instantRequests', req.id), { status: 'accepted', doctorId: d.uid, doctorName: d.name, apptId: apptRef.id, updatedAt: now });
  });
  return apptRef.id;
}

export function Today({ nav }: { nav: Nav }) {
  const { uid, doc: d, appts, requests, inbox } = useD();
  const toast = useToast();
  const now = useNow(20000);
  const unread = inbox.filter((m, i) => m.t > lastRead(m.apptId) && inbox.findIndex((x) => x.apptId === m.apptId) === i);
  const [accepting, setAccepting] = useState<string | null>(null);
  const today = startOfToday();
  const list = (appts ?? []).filter((a) => a.day === today && a.status !== 'cancelled').sort((a, b) => a.t - b.t);
  const doneToday = list.filter((a) => a.status === 'completed');
  const net = doneToday.reduce((s, a) => s + a.fee, 0) * (1 - commissionOf(d));
  const active = (appts ?? []).filter((a) => a.status === 'waiting' || a.status === 'in-consult').sort((a, b) => a.t - b.t);
  const next = active[0] ?? list.find((a) => a.status === 'booked' && a.t > now - 45 * 60000);
  const first = d.name.split(' ').slice(0, 2).join(' ');

  const accept = async (r: InstantRequest) => {
    setAccepting(r.id);
    try {
      const id = await acceptRequest(r, { uid, name: d.name, hue: d.hue, specialty: d.specialty });
      nav.push('consult', { id });
    } catch (e) { toast(errorText(e)); }
    setAccepting(null);
  };

  return (
    <div className="screen has-tabs tab-root" style={{ background: 'var(--bg)' }}>
      <div style={{ background: 'linear-gradient(160deg, #0e1330, #27307a)', color: '#fff', padding: '16px 20px 74px', borderRadius: '0 0 30px 30px' }}>
        <div className="row between">
          <div className="row gap-12">
            <Avatar name={d.name} hue={d.hue} size={46} online={d.online} />
            <div><div style={{ fontSize: 13, opacity: 0.7 }}>{fmtDay(now)}</div><div className="t-h2">Hello, {first}</div></div>
          </div>
        </div>
        <div className="row gap-12" style={{ marginTop: 18, padding: '12px 14px', borderRadius: 16, background: 'rgba(255,255,255,.1)' }}>
          <span style={{ width: 10, height: 10, borderRadius: 5, background: d.online ? '#4ade80' : '#9ca3af', boxShadow: d.online ? '0 0 0 4px rgba(74,222,128,.25)' : 'none' }} />
          <div className="grow">
            <div style={{ fontWeight: 700, fontSize: 14.5 }}>{d.online ? 'Online for instant consults' : 'Offline for instant consults'}</div>
            <div style={{ fontSize: 12, opacity: 0.72 }}>{d.online ? 'Patients nearby can request you now' : 'Booked appointments still come in'}</div>
          </div>
          <Toggle on={d.online} onChange={(v) => { updateDoctor(uid, { online: v }); toast(v ? 'You’re online' : 'You’re offline'); }} label="Online" />
        </div>
      </div>

      <div className="pad" style={{ marginTop: -54 }}>
        <div className="card row" style={{ padding: '16px 6px' }}>
          {[
            { v: money(d.region, Math.round(net)), l: 'Earned today', icon: 'Wallet' },
            { v: `${doneToday.length}/${list.length}`, l: 'Seen today', icon: 'Users' },
            { v: d.ratingCount ? (d.ratingSum / d.ratingCount).toFixed(1) : '—', l: `${d.ratingCount} review${d.ratingCount === 1 ? "" : "s"}`, icon: 'Star' },
          ].map((x, i) => (
            <div key={x.l} className="grow stack center gap-4" style={{ borderLeft: i ? '1px solid var(--line)' : 0 }}>
              <div className="t-h2 num">{x.v}</div>
              <div className="t-xs row gap-4"><Icon name={x.icon} size={12} />{x.l}</div>
            </div>
          ))}
        </div>

        {d.online && requests.map((r) => (
          <div key={r.id} className="card" style={{ marginTop: 16, padding: 16, boxShadow: 'inset 0 0 0 2px var(--accent), var(--shadow)' }}>
            <div className="row between"><span className="badge accent"><Icon name="Zap" size={12} />Instant consult request</span><span className="t-xs">{Math.max(0, Math.round((now - r.createdAt) / 60000))} min ago</span></div>
            <div className="row gap-12" style={{ marginTop: 10 }}>
              <Avatar name={r.patientName} hue={120} size={46} />
              <div className="grow"><div className="t-h3">{r.patientName}</div><div className="t-xs">{[r.patientInfo.age && `${r.patientInfo.age} y`, r.patientInfo.sex].filter(Boolean).join(' · ')}</div></div>
              <div style={{ textAlign: 'right' }}><div className="t-xs">You earn</div><div className="t-h3 num">{money(r.region, Math.round(r.fee * (1 - commissionOf(d))))}</div></div>
            </div>
            <div style={{ marginTop: 10, padding: 10, borderRadius: 12, background: 'var(--surface-2)', fontSize: 14 }}>{r.concern}</div>
            <button className="btn good block" style={{ marginTop: 12 }} disabled={accepting === r.id} onClick={() => accept(r)}>{accepting === r.id ? <span className="spinner" /> : <><Icon name="Video" size={18} />Accept and start</>}</button>
          </div>
        ))}

        {unread.length > 0 && (
          <div className="list" style={{ marginTop: 16 }}>
            {unread.map((m) => (
              <div key={m.id} className="list-row" onClick={() => nav.push('chat', { id: m.apptId })}>
                <span className="tile-icon sm accent"><Icon name="MessageCircle" size={18} /></span>
                <div className="grow" style={{ minWidth: 0 }}><div style={{ fontWeight: 700, fontSize: 14.5 }}>{m.fromName}</div><div className="t-xs ellipsis">{m.text}</div></div>
                <span className="badge accent">New</span>
              </div>
            ))}
          </div>
        )}

        {next && (
          <div className="card" style={{ marginTop: 16, padding: 18, boxShadow: 'inset 0 0 0 2px var(--brand), var(--shadow)' }}>
            <div className="row between">
              <span className="t-label" style={{ color: 'var(--brand)' }}>Up next</span>
              <span className={`badge ${STATUS[next.status].cls}`}>
                {next.status === 'waiting' ? (next.mode === 'video' ? 'In waiting room' : 'Checked in') : next.status === 'in-consult' ? 'In consult' : `${fmtTime(next.t)}`}
              </span>
            </div>
            <div className="row gap-12" style={{ marginTop: 12 }}>
              <Avatar name={next.member} hue={(next.patientId.charCodeAt(0) * 7) % 360} size={54} />
              <div className="grow">
                <div className="t-h3">{next.member}</div>
                <div className="t-sm">{[next.patientInfo?.age && `${next.patientInfo.age} y`, next.patientInfo?.sex, next.mode === 'video' ? 'Video' : 'Clinic'].filter(Boolean).join(' · ')}</div>
              </div>
            </div>
            <div style={{ marginTop: 12 }}><Info a={next} /></div>
            <button className="btn block" style={{ marginTop: 14 }} onClick={() => nav.push('consult', { id: next.id })}>
              <Icon name={next.mode === 'video' ? 'Video' : 'ClipboardPen'} size={18} />{next.status === 'in-consult' ? 'Back to consult' : 'Open consult room'}
            </button>
          </div>
        )}

        <div className="section-head"><div className="t-h2">Today’s patients</div><span className="t-sm">{list.length - doneToday.length} left</span></div>
        {appts === undefined && <div className="t-sm">Loading…</div>}
        {appts && list.length === 0 && <Empty icon="CalendarCheck" title="No appointments today" body={d.online ? 'You’re online, so instant consult requests will appear above.' : 'Go online to take instant consults, or check your schedule.'} />}
        <div className="stack">
          {list.map((a, i) => (
            <div key={a.id} className="row gap-12 tap" onClick={() => nav.push('consult', { id: a.id })} style={{ padding: '10px 0', alignItems: 'stretch' }}>
              <div className="stack center" style={{ width: 54, flex: 'none' }}>
                <span className="num" style={{ fontSize: 13, fontWeight: 800, color: a.status === 'completed' ? 'var(--muted)' : 'var(--ink)' }}>{fmtTime(a.t).replace(/\s?[AP]M/, '')}</span>
                <span className="t-xs">{fmtTime(a.t).slice(-2)}</span>
                {i < list.length - 1 && <span style={{ flex: 1, width: 2, background: 'var(--line)', marginTop: 6, borderRadius: 1 }} />}
              </div>
              <div className="card grow row gap-12" style={{ padding: 12, opacity: a.status === 'completed' ? 0.7 : 1 }}>
                <Avatar name={a.member} hue={(a.patientId.charCodeAt(0) * 7) % 360} size={40} />
                <div className="grow" style={{ minWidth: 0 }}>
                  <div style={{ fontWeight: 700, fontSize: 14.5 }} className="ellipsis">{a.member}{a.instant && <span className="badge accent" style={{ marginLeft: 6 }}>Instant</span>}</div>
                  <div className="t-xs ellipsis">{a.reason}</div>
                </div>
                <div className="stack gap-4" style={{ alignItems: 'flex-end' }}>
                  <span className={`badge ${STATUS[a.status].cls}`}>{STATUS[a.status].label}</span>
                  <Icon name={a.mode === 'video' ? 'Video' : 'Building2'} size={14} style={{ color: 'var(--muted)' }} />
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- consult room

export function ConsultRoom({ nav, id }: { nav: Nav; id: string }) {
  const { doc: d, appts } = useD();
  const toast = useToast();
  const a = appts?.find((x) => x.id === id);
  const [notes, setNotes] = useState<string | null>(null);
  const [noShow, setNoShow] = useState(false);
  if (!a) return <div className="screen"><TopBar onBack={() => nav.back()} /></div>;
  const history = (appts ?? []).filter((x) => x.patientId === a.patientId && x.member === a.member && x.id !== a.id && x.rx).sort((x, y) => y.t - x.t);
  const start = () => (a.status === 'booked' || a.status === 'waiting') ? updateDoc(doc(db, 'appointments', a.id), { status: 'in-consult', startedAt: Date.now(), updatedAt: Date.now() }) : Promise.resolve();
  const done = a.status === 'completed' || a.status === 'cancelled';

  return (
    <div className="screen has-cta">
      <TopBar title={a.mode === 'video' ? 'Video consult' : 'Clinic consult'} onBack={() => nav.back()} right={<button className="icon-btn" onClick={() => nav.push('chat', { id: a.id })} aria-label="Message patient"><Icon name="MessageCircle" size={19} /></button>} />
      <div className="pad stack gap-14" style={{ paddingBottom: 12 }}>
        <div className="card p stack gap-12">
          <div className="row gap-12">
            <Avatar name={a.member} hue={(a.patientId.charCodeAt(0) * 7) % 360} size={56} />
            <div className="grow">
              <div className="t-h2">{a.member}</div>
              <div className="t-sm">{[a.patientInfo?.age && `${a.patientInfo.age} y`, a.patientInfo?.sex].filter(Boolean).join(' · ')}{a.member !== a.patientName ? ` · booked by ${a.patientName}` : ''}</div>
            </div>
            <span className={`badge ${STATUS[a.status].cls}`}>{STATUS[a.status].label}</span>
          </div>
          <Info a={a} />
          <div className="row gap-8 t-xs"><Icon name="Clock" size={13} />{fmtDay(a.t)}, {fmtTime(a.t)}{a.instant ? ' · instant consult' : ''} · fee {money(a.region, a.fee)}</div>
        </div>

        {!done && a.mode === 'video' && (
          <>
            <button className="btn block" onClick={async () => { await start(); await openVideoRoom(a.room, d.name); }}>
              <Icon name="Video" size={18} />{a.status === 'waiting' ? 'Patient is waiting · join now' : a.status === 'in-consult' ? 'Rejoin video room' : 'Open video room'}
            </button>
            <div className="t-xs row gap-6" style={{ marginTop: -6, justifyContent: 'center' }}><Icon name="Info" size={13} />Opens a private Jitsi Meet room. The first time, Jitsi may ask you to sign in to start it.</div>
          </>
        )}
        {!done && a.mode === 'clinic' && a.status !== 'in-consult' && <button className="btn block" onClick={start}><Icon name="ClipboardPen" size={18} />Start consult</button>}

        <div className="field">
          <label htmlFor="notes">Consult notes (only you see these)</label>
          <textarea id="notes" className="input" rows={4} value={notes ?? a.notes ?? ''} onChange={(e) => setNotes(e.target.value)} onBlur={() => notes !== null && updateDoc(doc(db, 'appointments', a.id), { notes, updatedAt: Date.now() })} placeholder="History, examination findings, plan" />
        </div>

        {a.rx && <div className="card p row gap-10"><Icon name="FileCheck2" size={20} style={{ color: 'var(--good)' }} /><div className="grow"><div className="t-h3">Prescription sent</div><div className="t-sm">{a.rx.diagnosis} · {fmtTime(a.rx.signedAt)}</div></div></div>}

        {history.length > 0 && (
          <div className="stack gap-8">
            <div className="t-h3">Earlier visits with you</div>
            {history.map((h) => <div key={h.id} className="card flat" style={{ padding: 12 }}><div className="row between"><span style={{ fontWeight: 700, fontSize: 14 }}>{h.rx!.diagnosis}</span><span className="t-xs">{fmtDay(h.t)}</span></div><div className="t-xs">{h.rx!.meds.map((m) => m.name).join(', ')}</div></div>)}
          </div>
        )}
        {!done && <button className="t-sm tap" onClick={() => setNoShow(true)} style={{ border: 0, background: 'none', color: 'var(--bad)', fontWeight: 700 }}>Patient didn’t show up</button>}
      </div>
      {!done && (
        <div className="cta-bar solid">
          <button className="btn block" onClick={async () => { await start(); nav.push('prescribe', { id: a.id }); }}><Icon name="PenLine" size={18} />End visit and write prescription</button>
        </div>
      )}
      <Sheet open={noShow} onClose={() => setNoShow(false)}>
        <div className="stack gap-12">
          <div className="t-h2">Mark as no-show?</div>
          <div className="t-body">The visit closes and the patient is told they missed it. You still earn the fee for booked (non-instant) visits.</div>
          <button className="btn block danger" onClick={async () => {
            await updateDoc(doc(db, 'appointments', a.id), { status: a.instant ? 'cancelled' : 'completed', notes: `${a.notes ?? ''}\nNo-show`.trim(), endedAt: Date.now(), updatedAt: Date.now() });
            setNoShow(false); toast('Marked as no-show'); nav.back();
          }}>Mark no-show</button>
        </div>
      </Sheet>
    </div>
  );
}

// ---------------------------------------------------------------- prescribe

const DIAGNOSES = ['Viral fever', 'Upper respiratory infection', 'Acute gastritis', 'Migraine', 'Hypertension', 'Type 2 diabetes', 'Allergic rhinitis', 'Muscle strain'];
const ADVICE_TEMPLATES = [
  'Rest, drink 3 litres of fluids a day, steam inhalation twice daily. Come back if fever lasts more than 3 days.',
  'Low-salt diet, 30 minutes of brisk walking daily. Check blood pressure every morning and log it in CareLoop.',
  'Avoid oily and spicy food, eat small frequent meals, don’t lie down within 2 hours of eating.',
];
const FOLLOW = ['3 days', '1 week', '2 weeks', '1 month', 'Not needed'];

export function Prescribe({ nav, id }: { nav: Nav; id: string }) {
  const { doc: d, appts } = useD();
  const toast = useToast();
  const a = appts?.find((x) => x.id === id);
  const [diagnosis, setDiagnosis] = useState('');
  const [meds, setMeds] = useState<RxMed[]>([]);
  const [tests, setTests] = useState<string[]>([]);
  const [advice, setAdvice] = useState('');
  const [follow, setFollow] = useState('1 week');
  const [adding, setAdding] = useState(false);
  const [draft, setDraft] = useState<RxMed>({ name: '', dose: '1-0-1', duration: '5 days', note: 'After food' });
  const [query, setQuery] = useState('');
  if (!a) return null;
  const pro = d.plan !== 'starter';
  const allergy = a.patientInfo?.allergies && a.patientInfo.allergies !== 'None' ? a.patientInfo.allergies : null;
  const custom = query.trim().length > 2 && !MEDICINES.some((m) => m.name.toLowerCase() === query.trim().toLowerCase());

  return (
    <div className="screen has-cta">
      <TopBar title="Prescription" onBack={() => nav.back()} surface />
      <div className="pad stack gap-16" style={{ paddingTop: 16, paddingBottom: 12 }}>
        <div className="card row gap-12" style={{ padding: 14 }}>
          <Avatar name={a.member} hue={(a.patientId.charCodeAt(0) * 7) % 360} size={46} />
          <div className="grow"><div className="t-h3">{a.member}</div><div className="t-xs">{[a.patientInfo?.age && `${a.patientInfo.age} y`, a.patientInfo?.sex, a.reason].filter(Boolean).join(' · ')}</div></div>
          {allergy && <span className="badge bad"><Icon name="TriangleAlert" size={12} />{allergy}</span>}
        </div>

        <div className="field">
          <label htmlFor="dx">Diagnosis</label>
          <input id="dx" className="input" value={diagnosis} onChange={(e) => setDiagnosis(e.target.value)} placeholder="Type or pick below" />
          <div className="hscroll" style={{ paddingTop: 4 }}>{DIAGNOSES.map((x) => <button key={x} className={`chip${diagnosis === x ? ' on' : ''}`} style={{ height: 34, fontSize: 13 }} onClick={() => setDiagnosis(x)}>{x}</button>)}</div>
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
          <div className="row between"><label htmlFor="adv">Advice</label>{!pro && <span className="badge"><Icon name="Lock" size={11} />Templates in Pro</span>}</div>
          <textarea id="adv" className="input" rows={3} value={advice} onChange={(e) => setAdvice(e.target.value)} placeholder="Diet, rest, warning signs to watch for" />
          <div className="stack gap-6">
            {ADVICE_TEMPLATES.map((x, i) => (
              <button key={i} className="chip" style={{ height: 'auto', padding: '8px 12px', whiteSpace: 'normal', textAlign: 'left', fontSize: 12.5, opacity: pro ? 1 : 0.55 }} onClick={() => (pro ? setAdvice(x) : nav.push('plans'))}>
                <Icon name={pro ? 'FileText' : 'Lock'} size={14} />{x.slice(0, 64)}…
              </button>
            ))}
          </div>
        </div>

        <div><div className="t-h3" style={{ marginBottom: 8 }}>Follow-up</div><div className="row wrap gap-6">{FOLLOW.map((f) => <button key={f} className={`chip${follow === f ? ' on' : ''}`} onClick={() => setFollow(f)}>{f === 'Not needed' ? f : `In ${f}`}</button>)}</div></div>
      </div>
      <div className="cta-bar solid">
        <button className="btn block" disabled={!diagnosis.trim() || meds.length === 0} onClick={() => nav.push('rxPreview', {
          id, rx: { diagnosis: diagnosis.trim(), meds, tests, advice: advice.trim() || 'Take the medicines as advised. Contact me through CareLoop if symptoms get worse.', followUp: follow === 'Not needed' ? undefined : `In ${follow}` },
        })}>{meds.length === 0 ? 'Add at least one medicine' : 'Review and sign'}</button>
      </div>

      <Sheet open={adding} onClose={() => setAdding(false)}>
        <div className="stack gap-14">
          <div className="t-h2">Add medicine</div>
          {!draft.name ? (
            <>
              <div className="search" style={{ boxShadow: 'inset 0 0 0 1.5px var(--line)' }}><Icon name="Search" size={18} /><input autoFocus value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search, or type any medicine" /></div>
              <div className="list" style={{ boxShadow: 'inset 0 0 0 1px var(--line)' }}>
                {custom && (
                  <div className="list-row" onClick={() => (allergyConflict(query, allergy ?? undefined) ? toast(`Allergy alert: ${a.member.split(' ')[0]} is allergic to ${allergy}`) : setDraft({ ...draft, name: query.trim() }))}>
                    <span className="tile-icon sm"><Icon name="Plus" size={16} /></span><div className="grow" style={{ fontWeight: 700, fontSize: 14 }}>Use “{query.trim()}”</div>
                  </div>
                )}
                {MEDICINES.filter((m) => m.name.toLowerCase().includes(query.toLowerCase()) && !meds.some((x) => x.name === m.name)).slice(0, 6).map((m) => {
                  const clash = !!allergyConflict(m.name, allergy ?? undefined);
                  return (
                    <div key={m.name} className="list-row" onClick={() => (clash ? toast(`Allergy alert: ${a.member.split(' ')[0]} is allergic to ${allergy}`) : setDraft({ ...draft, name: m.name }))}>
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
              <div><div className="t-sm" style={{ fontWeight: 700, marginBottom: 6 }}>Dose (morning-noon-night)</div><div className="row wrap gap-6">{DOSES.map((x) => <button key={x} className={`chip${draft.dose === x ? ' on' : ''}`} onClick={() => setDraft({ ...draft, dose: x })}>{x}</button>)}</div></div>
              <div><div className="t-sm" style={{ fontWeight: 700, marginBottom: 6 }}>Duration</div><div className="row wrap gap-6">{DURATIONS.map((x) => <button key={x} className={`chip${draft.duration === x ? ' on' : ''}`} onClick={() => setDraft({ ...draft, duration: x })}>{x}</button>)}</div></div>
              <div><div className="t-sm" style={{ fontWeight: 700, marginBottom: 6 }}>Instructions</div><div className="row wrap gap-6">{['After food', 'Before food', 'At bedtime', 'If needed'].map((x) => <button key={x} className={`chip${draft.note === x ? ' on' : ''}`} onClick={() => setDraft({ ...draft, note: x })}>{x}</button>)}</div></div>
              <button className="btn block" onClick={() => { setMeds([...meds, draft]); setAdding(false); }}>Add to prescription</button>
            </>
          )}
        </div>
      </Sheet>
    </div>
  );
}

export function RxPreview({ nav, id, rx }: { nav: Nav; id: string; rx: Omit<Rx, 'signedAt'> }) {
  const { doc: d, appts } = useD();
  const toast = useToast();
  const a = appts?.find((x) => x.id === id);
  const [signing, setSigning] = useState(false);
  if (!a) return null;
  const earn = Math.round(a.fee * (1 - commissionOf(d)) * 100) / 100;
  return (
    <div className="screen has-cta">
      <TopBar title="Review and sign" onBack={() => nav.back()} />
      <div className="pad" style={{ paddingBottom: 12 }}>
        <div className="card" style={{ overflow: 'hidden' }}>
          <div style={{ padding: 18, background: 'linear-gradient(135deg, #0e1330, #27307a)', color: '#fff' }}>
            <div className="t-h3">{d.name}</div>
            <div style={{ fontSize: 12.5, opacity: 0.8 }}>{d.degrees} · {specialtyOf(d.specialty).name}</div>
            <div style={{ fontSize: 12, opacity: 0.65, marginTop: 2 }}>{[d.clinic, d.area].filter(Boolean).join(', ')} · Reg. {d.licenseNo}</div>
          </div>
          <div className="stack gap-12" style={{ padding: 18 }}>
            <div className="row between t-sm"><span><b style={{ color: 'var(--ink)' }}>{a.member}</b>{a.patientInfo?.age ? ` · ${a.patientInfo.age} y` : ''}</span><span>{fmtDay(Date.now())}</span></div>
            <div><div className="t-label">Diagnosis</div><div className="t-h3" style={{ marginTop: 4 }}>{rx.diagnosis}</div></div>
            <div className="stack gap-8"><div className="t-label">Rx</div>{rx.meds.map((m, i) => <div key={m.name} style={{ fontSize: 14 }}><b>{i + 1}. {m.name}</b><div className="t-sm">{m.dose} · {m.duration}{m.note ? ` · ${m.note}` : ''}</div></div>)}</div>
            {rx.tests.length > 0 && <div><div className="t-label">Tests</div><div className="row wrap gap-6" style={{ marginTop: 6 }}>{rx.tests.map((t) => <span key={t} className="badge brand">{t}</span>)}</div></div>}
            <div><div className="t-label">Advice</div><div className="t-body" style={{ fontSize: 14, marginTop: 4 }}>{rx.advice}</div></div>
            {rx.followUp && <div className="t-sm" style={{ fontWeight: 600 }}>Follow-up {rx.followUp.toLowerCase()}</div>}
          </div>
        </div>
        <div className="row gap-8 t-sm" style={{ marginTop: 14 }}><Icon name="Send" size={15} className="t-brand" />Goes straight to {a.patientName.split(' ')[0]}’s CareLoop app, with one-tap medicine ordering and lab booking.</div>
      </div>
      <div className="cta-bar solid">
        <button className="btn block" disabled={signing} onClick={async () => {
          setSigning(true);
          try {
            const now = Date.now();
            await updateDoc(doc(db, 'appointments', a.id), { status: 'completed', rx: { ...rx, signedAt: now }, endedAt: now, updatedAt: now });
            toast(`Prescription sent · ${money(a.region, earn)} added to earnings`);
            nav.reset();
          } catch (e) { toast(errorText(e)); setSigning(false); }
        }}>{signing ? <><span className="spinner" />Signing…</> : <><Icon name="PenLine" size={18} />Sign and send</>}</button>
      </div>
    </div>
  );
}
