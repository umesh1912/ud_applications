import { useState } from 'react';
import { logOut, useAuth } from '../lib/auth';
import { errorText } from '../lib/db';
import { Icon, TopBar } from '../ui/kit';
import { updateMe } from './ctx';

const SLIDES = [
  { icon: 'Video', title: 'See a doctor in minutes', body: 'Licensed doctors by video or at a clinic near you. Book a time or talk to the next available doctor now.', tint: '#0f766e' },
  { icon: 'FileHeart', title: 'Every record in one place', body: 'Prescriptions, lab reports and vitals for your whole family, ready for any doctor you see.', tint: '#ff7a59' },
  { icon: 'Pill', title: 'Medicines and tests at home', body: 'Order prescribed medicines and book lab tests with home sample collection in a tap.', tint: '#7c3aed' },
];

function Illustration({ icon, tint }: { icon: string; tint: string }) {
  return (
    <div style={{ position: 'relative', height: 280, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      {[250, 186, 126].map((d, i) => (
        <div key={d} style={{ position: 'absolute', width: d, height: d, borderRadius: '50%', background: tint, opacity: [0.06, 0.1, 0.16][i] }} />
      ))}
      <div style={{ position: 'relative', width: 92, height: 92, borderRadius: 30, background: tint, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 20px 40px -16px ${tint}`, transform: 'rotate(-6deg)', transition: 'background 300ms' }}>
        <Icon name={icon} size={42} />
      </div>
      <div className="card" style={{ position: 'absolute', left: 22, top: 40, padding: '10px 12px', display: 'flex', gap: 8, alignItems: 'center', borderRadius: 14 }}>
        <span className="check-circle" style={{ width: 22, height: 22, background: 'var(--good)' }}><Icon name="Check" size={14} stroke={3} /></span>
        <span style={{ fontSize: 12.5, fontWeight: 700 }}>License-verified doctors</span>
      </div>
      <div className="card" style={{ position: 'absolute', right: 20, bottom: 34, padding: '10px 12px', display: 'flex', gap: 8, alignItems: 'center', borderRadius: 14 }}>
        <Icon name="Lock" size={16} className="t-brand" />
        <span style={{ fontSize: 12.5, fontWeight: 700 }}>Private and encrypted</span>
      </div>
    </div>
  );
}

export function Landing({ signup, login }: { signup: () => void; login: () => void }) {
  const [slide, setSlide] = useState(0);
  const sl = SLIDES[slide];
  return (
    <div className="screen stack" style={{ padding: '8px 24px 24px' }}>
      <div className="row gap-8" style={{ height: 48, fontWeight: 800, fontSize: 18, letterSpacing: '-0.02em' }}>
        <span className="tile-icon sm" style={{ background: 'var(--brand)', color: '#fff' }}><Icon name="HeartPulse" size={20} /></span>CareLoop
      </div>
      <div onClick={() => setSlide((slide + 1) % SLIDES.length)} className="tap"><Illustration icon={sl.icon} tint={sl.tint} /></div>
      <div className="stack gap-12" style={{ flex: 1 }}>
        <div className="t-display">{sl.title}</div>
        <div className="t-body">{sl.body}</div>
        <div className="row gap-6" style={{ marginTop: 6 }}>
          {SLIDES.map((_, i) => <button key={i} onClick={() => setSlide(i)} aria-label={`Slide ${i + 1}`} style={{ height: 8, width: i === slide ? 28 : 8, borderRadius: 4, border: 0, padding: 0, background: i === slide ? 'var(--brand)' : 'var(--line)', transition: 'width 200ms' }} />)}
        </div>
      </div>
      <div className="stack gap-10" style={{ marginTop: 20 }}>
        <button className="btn block" onClick={signup}>Create free account</button>
        <button className="btn block ghost" onClick={login}>Log in</button>
      </div>
    </div>
  );
}

const BLOOD = ['A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−', 'Don’t know'];
const CONDITIONS = ['Diabetes', 'Hypertension', 'Asthma', 'Thyroid', 'Heart disease', 'PCOS'];

/** Health basics after signup; doctors see these before each visit. */
export function HealthProfile() {
  const { profile } = useAuth();
  const [age, setAge] = useState('');
  const [sex, setSex] = useState('');
  const [blood, setBlood] = useState('');
  const [allergies, setAllergies] = useState('');
  const [conditions, setConditions] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const valid = Number(age) > 0 && Number(age) < 120 && sex;
  return (
    <form className="screen stack" onSubmit={async (e) => {
      e.preventDefault(); setBusy(true); setErr(null);
      try { await updateMe(profile!.id, { age: Number(age), sex, blood: blood || 'Don’t know', allergies: allergies.trim() || 'None', conditions }); }
      catch (x) { setErr(errorText(x)); setBusy(false); }
    }}>
      <TopBar title="Your health basics" right={<button type="button" className="icon-btn" onClick={() => logOut()} aria-label="Log out"><Icon name="LogOut" size={18} /></button>} />
      <div className="pad stack gap-16" style={{ paddingBottom: 24 }}>
        <div className="t-body">Hi {profile?.name.split(' ')[0]}! Doctors see this before your visit, so you don’t repeat it every time. You can change it later.</div>
        <div className="row gap-12">
          <div className="field" style={{ width: 100 }}><label htmlFor="hp-age">Age</label><input id="hp-age" className="input" inputMode="numeric" value={age} onChange={(e) => setAge(e.target.value.replace(/\D/g, '').slice(0, 3))} /></div>
          <div className="field grow">
            <label>Sex</label>
            <div className="segmented" style={{ height: 52, alignItems: 'center' }}>
              {['Male', 'Female', 'Other'].map((o) => <button type="button" key={o} className={sex === o ? 'on' : ''} onClick={() => setSex(o)} style={{ fontSize: 13 }}>{o}</button>)}
            </div>
          </div>
        </div>
        <div className="field"><label>Blood group</label><div className="row wrap gap-6">{BLOOD.map((b) => <button type="button" key={b} className={`chip${blood === b ? ' on' : ''}`} onClick={() => setBlood(b)} style={{ height: 34 }}>{b}</button>)}</div></div>
        <div className="field"><label>Long-term conditions</label><div className="row wrap gap-6">{CONDITIONS.map((c) => <button type="button" key={c} className={`chip${conditions.includes(c) ? ' on' : ''}`} onClick={() => setConditions(conditions.includes(c) ? conditions.filter((x) => x !== c) : [...conditions, c])} style={{ height: 34 }}>{c}</button>)}</div></div>
        <div className="field"><label htmlFor="hp-all">Allergies</label><input id="hp-all" className="input" value={allergies} onChange={(e) => setAllergies(e.target.value)} placeholder="e.g. Penicillin, peanuts (leave empty if none)" /></div>
        {err && <div className="t-sm t-bad" role="alert">{err}</div>}
        <button className="btn block" type="submit" disabled={!valid || busy}>{busy ? <span className="spinner" /> : 'Continue to CareLoop'}</button>
      </div>
    </form>
  );
}
