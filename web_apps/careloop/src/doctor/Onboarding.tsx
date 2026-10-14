import { useState } from 'react';
import { doc, setDoc } from 'firebase/firestore';
import { SPECIALTIES } from '../data/catalog';
import { REGIONS } from '../data/region';
import { logOut } from '../lib/auth';
import { errorText } from '../lib/db';
import { db } from '../lib/firebase';
import { DEFAULT_AVAILABILITY, type DoctorDoc, type UserDoc } from '../lib/model';
import { Icon, TopBar } from '../ui/kit';
import { updateDoctor } from './ctx';

export function Welcome({ signup, login }: { signup: () => void; login: () => void }) {
  return (
    <div className="screen stack" style={{ background: 'linear-gradient(170deg, #0e1330 0%, #1d2468 55%, #3b3fb0 100%)', color: '#fff', padding: '20px 24px 28px' }}>
      <div className="row gap-8" style={{ fontWeight: 800, fontSize: 18 }}>
        <span className="tile-icon sm" style={{ background: '#fff', color: 'var(--brand)' }}><Icon name="Stethoscope" size={20} /></span>CareLoop <span className="badge" style={{ background: 'rgba(255,255,255,.16)', color: '#fff' }}>PRO</span>
      </div>
      <div className="stack gap-12" style={{ flex: 1, justifyContent: 'center' }}>
        <div className="t-display" style={{ fontSize: 34 }}>Your practice, in your pocket</div>
        <div style={{ fontSize: 15.5, lineHeight: 1.5, opacity: 0.82 }}>Video and clinic patients, e-prescriptions, patient history and payouts in one app.</div>
        <div className="stack gap-10" style={{ marginTop: 10 }}>
          {['Set your own fees and hours', 'Take instant consults when you’re free', 'Sign and send prescriptions in seconds', 'Track earnings and request payouts'].map((t) => (
            <div key={t} className="row gap-10" style={{ fontSize: 14.5, fontWeight: 600 }}><span className="check-circle" style={{ background: 'rgba(255,255,255,.18)' }}><Icon name="Check" size={14} stroke={3} /></span>{t}</div>
          ))}
        </div>
      </div>
      <div className="stack gap-10">
        <button className="btn block white" onClick={signup}>Join as a doctor</button>
        <button className="btn block" style={{ background: 'rgba(255,255,255,.14)' }} onClick={login}>Log in</button>
      </div>
    </div>
  );
}

const LANGS = ['English', 'Hindi', 'Gujarati', 'Marathi', 'Tamil', 'Telugu', 'Kannada', 'Malayalam', 'Bengali', 'Urdu', 'Spanish', 'Mandarin'];

interface PracticeForm {
  specialty: string; degrees: string; licenseNo: string; years: string; clinic: string; area: string;
  languages: string[]; feeVideo: string; feeClinic: string; about: string;
}

export function PracticeFields({ f, set, region }: { f: PracticeForm; set: (p: Partial<PracticeForm>) => void; region: 'IN' | 'US' }) {
  const IN = region === 'IN';
  return (
    <>
      <div className="field">
        <label>Specialty</label>
        <div className="row wrap gap-6">{SPECIALTIES.map((s) => <button type="button" key={s.id} className={`chip${f.specialty === s.id ? ' on' : ''}`} onClick={() => set({ specialty: s.id })} style={{ height: 34 }}><Icon name={s.icon} size={14} />{s.name}</button>)}</div>
      </div>
      <div className="field"><label htmlFor="pf-deg">Qualifications</label><input id="pf-deg" className="input" value={f.degrees} onChange={(e) => set({ degrees: e.target.value })} placeholder={IN ? 'MBBS, MD (Internal Medicine)' : 'MD, Board-certified Family Medicine'} /></div>
      <div className="row gap-10">
        <div className="field grow"><label htmlFor="pf-lic">{IN ? 'Medical council reg. no.' : 'State license / NPI'}</label><input id="pf-lic" className="input" value={f.licenseNo} onChange={(e) => set({ licenseNo: e.target.value })} /></div>
        <div className="field" style={{ width: 96 }}><label htmlFor="pf-yrs">Years</label><input id="pf-yrs" className="input" inputMode="numeric" value={f.years} onChange={(e) => set({ years: e.target.value.replace(/\D/g, '').slice(0, 2) })} /></div>
      </div>
      <div className="field"><label htmlFor="pf-cl">Clinic or hospital (leave empty for video only)</label><input id="pf-cl" className="input" value={f.clinic} onChange={(e) => set({ clinic: e.target.value })} /></div>
      <div className="field"><label htmlFor="pf-ar">Area and city</label><input id="pf-ar" className="input" value={f.area} onChange={(e) => set({ area: e.target.value })} placeholder={IN ? 'Indiranagar, Bengaluru' : 'Mission District, San Francisco'} /></div>
      <div className="field"><label>Languages</label><div className="row wrap gap-6">{LANGS.map((l) => <button type="button" key={l} className={`chip${f.languages.includes(l) ? ' on' : ''}`} onClick={() => set({ languages: f.languages.includes(l) ? f.languages.filter((x) => x !== l) : [...f.languages, l] })} style={{ height: 34 }}>{l}</button>)}</div></div>
      <div className="row gap-10">
        <div className="field grow"><label htmlFor="pf-fv">Video fee ({REGIONS[region].currency})</label><input id="pf-fv" className="input num" inputMode="numeric" value={f.feeVideo} onChange={(e) => set({ feeVideo: e.target.value.replace(/[^\d.]/g, '') })} /></div>
        <div className="field grow"><label htmlFor="pf-fc">Clinic fee ({REGIONS[region].currency})</label><input id="pf-fc" className="input num" inputMode="numeric" value={f.feeClinic} onChange={(e) => set({ feeClinic: e.target.value.replace(/[^\d.]/g, '') })} /></div>
      </div>
      <div className="field"><label htmlFor="pf-ab">About you (patients see this)</label><textarea id="pf-ab" className="input" rows={3} value={f.about} onChange={(e) => set({ about: e.target.value })} placeholder="What you treat and how you work with patients" /></div>
    </>
  );
}

export const practiceValid = (f: PracticeForm) =>
  !!f.specialty && f.degrees.trim().length > 2 && f.licenseNo.trim().length > 3 && Number(f.years) >= 0 && f.years !== '' && f.area.trim().length > 2 && f.languages.length > 0 && Number(f.feeVideo) > 0 && Number(f.feeClinic) > 0;

export const formOf = (d?: DoctorDoc, region: 'IN' | 'US' = 'IN'): PracticeForm => ({
  specialty: d?.specialty ?? '', degrees: d?.degrees ?? '', licenseNo: d?.licenseNo ?? '', years: d ? String(d.years) : '',
  clinic: d?.clinic ?? '', area: d?.area ?? '', languages: d?.languages ?? ['English'],
  feeVideo: String(d?.feeVideo ?? (region === 'IN' ? 499 : 59)), feeClinic: String(d?.feeClinic ?? (region === 'IN' ? 700 : 89)), about: d?.about ?? '',
});

export const practiceOf = (f: PracticeForm) => ({
  specialty: f.specialty, degrees: f.degrees.trim(), licenseNo: f.licenseNo.trim(), years: Number(f.years), clinic: f.clinic.trim(), area: f.area.trim(),
  languages: f.languages, feeVideo: Number(f.feeVideo), feeClinic: Number(f.feeClinic), about: f.about.trim(),
});

/** Professional details right after signup; creates the (pending) public profile. */
export function DoctorSetup({ me }: { me: UserDoc }) {
  const [f, setF] = useState<PracticeForm>(formOf(undefined, me.region));
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const submit = async () => {
    setBusy(true); setErr(null);
    const profile: Omit<DoctorDoc, 'id'> = {
      uid: me.id, name: me.name.startsWith('Dr') ? me.name : `Dr. ${me.name}`, region: me.region, ...practiceOf(f),
      status: 'pending', online: false, availability: DEFAULT_AVAILABILITY, timeOff: [], plan: 'starter',
      hue: Math.floor(Math.random() * 360), ratingSum: 0, ratingCount: 0, createdAt: Date.now(),
    };
    try { await setDoc(doc(db, 'doctors', me.id), profile); } catch (e) { setErr(errorText(e)); setBusy(false); }
  };
  return (
    <form className="screen has-cta" onSubmit={(e) => { e.preventDefault(); if (practiceValid(f) && !busy) submit(); }}>
      <TopBar title="Your practice" right={<button type="button" className="icon-btn" onClick={() => logOut()} aria-label="Log out"><Icon name="LogOut" size={18} /></button>} />
      <div className="pad stack gap-14" style={{ paddingBottom: 12 }}>
        <div className="row gap-10" style={{ padding: 12, borderRadius: 14, background: 'var(--brand-soft)', color: 'var(--brand-strong)', fontSize: 13.5, fontWeight: 600 }}>
          <Icon name="ShieldCheck" size={18} />We verify every license before patients can book you. This usually takes under a day.
        </div>
        <PracticeFields f={f} set={(p) => setF({ ...f, ...p })} region={me.region} />
        {err && <div className="t-sm t-bad" role="alert">{err}</div>}
      </div>
      <div className="cta-bar solid"><button className="btn block" type="submit" disabled={!practiceValid(f) || busy}>{busy ? <span className="spinner" /> : 'Submit for verification'}</button></div>
    </form>
  );
}

export function Pending({ me, d }: { me: UserDoc; d: DoctorDoc }) {
  const [editing, setEditing] = useState(false);
  const [f, setF] = useState<PracticeForm>(formOf(d, me.region));
  const [busy, setBusy] = useState(false);
  if (editing) {
    return (
      <form className="screen has-cta" onSubmit={async (e) => {
        e.preventDefault(); setBusy(true);
        await updateDoctor(me.id, { ...practiceOf(f), ...(d.status === 'rejected' ? { status: 'pending' as const } : {}) });
        setBusy(false); setEditing(false);
      }}>
        <TopBar title="Edit details" onBack={() => setEditing(false)} />
        <div className="pad stack gap-14" style={{ paddingBottom: 12 }}><PracticeFields f={f} set={(p) => setF({ ...f, ...p })} region={me.region} /></div>
        <div className="cta-bar solid"><button className="btn block" type="submit" disabled={!practiceValid(f) || busy}>Save</button></div>
      </form>
    );
  }
  const rejected = d.status === 'rejected';
  return (
    <div className="screen stack" style={{ padding: '48px 24px 24px' }}>
      <div className="stack center gap-14" style={{ flex: 1, textAlign: 'center' }}>
        <div className={`tile-icon ${rejected ? 'bad' : 'accent'}`} style={{ width: 84, height: 84, borderRadius: 28 }}><Icon name={rejected ? 'CircleX' : 'Hourglass'} size={38} /></div>
        <div className="t-h1">{rejected ? 'We couldn’t verify your license' : 'Verification in progress'}</div>
        <div className="t-body" style={{ maxWidth: 310 }}>
          {rejected
            ? 'Check that your registration number and name match your medical council or state board record, then resubmit.'
            : `Thanks, ${d.name}. We’re checking ${d.licenseNo} with the ${me.region === 'IN' ? 'medical council' : 'state board'}. This screen updates by itself once you’re approved.`}
        </div>
        <div className="card p" style={{ width: '100%', textAlign: 'left' }}>
          <div className="kv"><span>Name</span><span>{d.name}</span></div>
          <div className="kv"><span>License</span><span>{d.licenseNo}</span></div>
          <div className="kv"><span>Qualifications</span><span style={{ maxWidth: 180 }}>{d.degrees}</span></div>
          <div className="kv"><span>Submitted</span><span>{new Date(d.createdAt).toLocaleDateString()}</span></div>
        </div>
      </div>
      <div className="stack gap-10">
        <button className="btn block soft" onClick={() => setEditing(true)}><Icon name="Pencil" size={16} />{rejected ? 'Fix and resubmit' : 'Edit details'}</button>
        <button className="btn block ghost" onClick={() => logOut()}>Log out</button>
      </div>
    </div>
  );
}
