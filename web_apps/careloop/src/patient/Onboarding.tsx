import { useEffect, useRef, useState } from 'react';
import { REGIONS, type Region } from '../data/region';
import { Icon, TopBar } from '../ui/kit';
import { seed, useP } from './state';

const SLIDES = [
  { icon: 'Video', title: 'See a doctor in minutes', body: 'Verified doctors across 25+ specialties, by video or at a clinic near you. Most visits start within 15 minutes.', tint: '#0f766e' },
  { icon: 'FileHeart', title: 'Every record in one place', body: 'Prescriptions, lab reports and vitals for your whole family, ready to share with any doctor.', tint: '#ff7a59' },
  { icon: 'Pill', title: 'Medicines and tests at home', body: 'Order prescribed medicines and book lab tests with home sample collection in a tap.', tint: '#7c3aed' },
];

/** Concentric "pulse" illustration behind each slide's icon. */
function Illustration({ icon, tint }: { icon: string; tint: string }) {
  return (
    <div style={{ position: 'relative', height: 300, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      {[260, 196, 136].map((d, i) => (
        <div key={d} style={{ position: 'absolute', width: d, height: d, borderRadius: '50%', background: tint, opacity: [0.06, 0.1, 0.16][i] }} />
      ))}
      <div style={{ position: 'relative', width: 96, height: 96, borderRadius: 30, background: tint, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: `0 20px 40px -16px ${tint}`, transform: 'rotate(-6deg)' }}>
        <Icon name={icon} size={44} />
      </div>
      <div className="card" style={{ position: 'absolute', left: 24, top: 46, padding: '10px 12px', display: 'flex', gap: 8, alignItems: 'center', borderRadius: 14 }}>
        <span className="check-circle" style={{ width: 22, height: 22, background: 'var(--good)' }}><Icon name="Check" size={14} stroke={3} /></span>
        <span style={{ fontSize: 12.5, fontWeight: 700 }}>Verified doctors</span>
      </div>
      <div className="card" style={{ position: 'absolute', right: 22, bottom: 40, padding: '10px 12px', display: 'flex', gap: 8, alignItems: 'center', borderRadius: 14 }}>
        <Icon name="Star" size={16} style={{ color: 'var(--star)', fill: 'var(--star)' }} />
        <span style={{ fontSize: 12.5, fontWeight: 700 }}>4.8 average rating</span>
      </div>
    </div>
  );
}

export function Onboarding() {
  const { s, set } = useP();
  const [slide, setSlide] = useState(0);
  const go = (stage: typeof s.stage) => set((p) => ({ ...p, stage }));

  if (s.stage === 'welcome') {
    const sl = SLIDES[slide];
    const last = slide === SLIDES.length - 1;
    return (
      <div className="screen stack" style={{ padding: '8px 24px 28px' }}>
        <div className="row between" style={{ height: 48 }}>
          <div className="row gap-8" style={{ fontWeight: 800, fontSize: 18, letterSpacing: '-0.02em' }}>
            <span className="tile-icon sm" style={{ background: 'var(--brand)', color: '#fff' }}><Icon name="HeartPulse" size={20} /></span>CareLoop
          </div>
          <button className="btn xs ghost" onClick={() => go('region')}>Skip</button>
        </div>
        <Illustration icon={sl.icon} tint={sl.tint} />
        <div className="stack gap-12" style={{ flex: 1 }}>
          <div className="t-display">{sl.title}</div>
          <div className="t-body">{sl.body}</div>
        </div>
        <div className="row between" style={{ marginTop: 24 }}>
          <div className="row gap-6">
            {SLIDES.map((_, i) => <div key={i} style={{ height: 8, width: i === slide ? 28 : 8, borderRadius: 4, background: i === slide ? 'var(--brand)' : 'var(--line)', transition: 'width 200ms' }} />)}
          </div>
          <button className="btn" onClick={() => (last ? go('region') : setSlide(slide + 1))}>
            {last ? 'Get started' : 'Next'}<Icon name="ArrowRight" size={18} />
          </button>
        </div>
      </div>
    );
  }

  if (s.stage === 'region') return <RegionStep />;
  if (s.stage === 'phone') return <PhoneStep />;
  if (s.stage === 'otp') return <OtpStep />;
  return <ProfileStep />;
}

function RegionStep() {
  const { s, set } = useP();
  const [pick, setPick] = useState<Region>(s.region);
  const opts: { id: Region; flag: string; note: string }[] = [
    { id: 'IN', flag: '₹', note: 'Pay with UPI or card · Hindi and regional languages' },
    { id: 'US', flag: '$', note: 'Use your insurance or HSA · Board-certified doctors' },
  ];
  return (
    <div className="screen stack">
      <TopBar onBack={() => set((p) => ({ ...p, stage: 'welcome' }))} />
      <div className="pad stack gap-8" style={{ flex: 1 }}>
        <div className="t-h1">Where are you?</div>
        <div className="t-body">We show doctors licensed where you live, in your currency and with local payment options.</div>
        <div className="stack gap-12" style={{ marginTop: 16 }}>
          {opts.map((o) => (
            <button key={o.id} className="card tap row gap-16" onClick={() => setPick(o.id)}
              style={{ padding: 18, border: 0, textAlign: 'left', boxShadow: pick === o.id ? 'inset 0 0 0 2px var(--brand), var(--shadow)' : 'var(--shadow)' }}>
              <div className="tile-icon" style={{ width: 52, height: 52, fontSize: 22, fontWeight: 800 }}>{o.flag}</div>
              <div className="grow stack gap-4">
                <div className="t-h3">{REGIONS[o.id].name}</div>
                <div className="t-sm">{o.note}</div>
              </div>
              <span className={`radio${pick === o.id ? ' on' : ''}`} />
            </button>
          ))}
        </div>
      </div>
      <div style={{ padding: 20 }}>
        <button className="btn block" onClick={() => set(() => ({ ...seed(pick), stage: 'phone' }))}>Continue</button>
      </div>
    </div>
  );
}

function PhoneStep() {
  const { s, set } = useP();
  const r = REGIONS[s.region];
  const [phone, setPhone] = useState(r.samplePhone);
  const valid = phone.replace(/\D/g, '').length >= 10;
  return (
    <div className="screen stack">
      <TopBar onBack={() => set((p) => ({ ...p, stage: 'region' }))} />
      <div className="pad stack gap-8" style={{ flex: 1 }}>
        <div className="t-h1">Your mobile number</div>
        <div className="t-body">We’ll text you a 4-digit code. Your number is also how doctors reach you if a call drops.</div>
        <div className="row gap-10" style={{ marginTop: 20 }}>
          <div className="input row center" style={{ width: 76, flex: 'none', fontWeight: 700 }}>{r.phonePrefix}</div>
          <input className="input" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} aria-label="Mobile number" autoFocus />
        </div>
        <div className="row gap-8 t-sm" style={{ marginTop: 14 }}><Icon name="ShieldCheck" size={16} className="t-brand" />{r.compliance}</div>
      </div>
      <div style={{ padding: 20 }}>
        <button className="btn block" disabled={!valid} onClick={() => set((p) => ({ ...p, stage: 'otp', user: { ...p.user, phone } }))}>Send code</button>
      </div>
    </div>
  );
}

function OtpStep() {
  const { s, set } = useP();
  const [code, setCode] = useState('');
  const ref = useRef<HTMLInputElement>(null);
  // Demo: the code "arrives" by SMS auto-read after a moment.
  useEffect(() => {
    const id = window.setTimeout(() => setCode('2468'), 1200);
    return () => window.clearTimeout(id);
  }, []);
  useEffect(() => {
    if (code.length === 4) {
      const id = window.setTimeout(() => set((p) => ({ ...p, stage: 'profile' })), 500);
      return () => window.clearTimeout(id);
    }
  }, [code, set]);
  return (
    <div className="screen stack">
      <TopBar onBack={() => set((p) => ({ ...p, stage: 'phone' }))} />
      <div className="pad stack gap-8">
        <div className="t-h1">Enter the code</div>
        <div className="t-body">Sent to {REGIONS[s.region].phonePrefix} {s.user.phone}</div>
        <div className="row gap-12" style={{ marginTop: 24 }} onClick={() => ref.current?.focus()}>
          {[0, 1, 2, 3].map((i) => (
            <div key={i} className="input row center num" style={{ width: 64, height: 68, fontSize: 26, fontWeight: 800, boxShadow: code.length === i ? 'inset 0 0 0 2px var(--brand)' : undefined }}>
              {code[i] ?? ''}
            </div>
          ))}
        </div>
        <input ref={ref} value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 4))} inputMode="numeric" autoComplete="one-time-code" aria-label="Code" style={{ position: 'absolute', opacity: 0, pointerEvents: 'none' }} />
        <div className="t-sm" style={{ marginTop: 16 }}>{code.length === 4 ? 'Verifying…' : 'Reading the SMS automatically…'}</div>
      </div>
    </div>
  );
}

function ProfileStep() {
  const { s, set } = useP();
  const [name, setName] = useState(s.user.name);
  const [sex, setSex] = useState(s.user.sex);
  const [age, setAge] = useState(String(s.user.age));
  return (
    <div className="screen stack">
      <TopBar title="About you" />
      <div className="pad stack gap-16" style={{ flex: 1 }}>
        <div className="t-body">Doctors see this before your visit, so you don’t repeat it every time.</div>
        <div className="field"><label>Full name</label><input className="input" value={name} onChange={(e) => setName(e.target.value)} /></div>
        <div className="row gap-12">
          <div className="field grow"><label>Age</label><input className="input" inputMode="numeric" value={age} onChange={(e) => setAge(e.target.value.replace(/\D/g, '').slice(0, 3))} /></div>
          <div className="field grow">
            <label>Sex</label>
            <div className="segmented" style={{ height: 52, alignItems: 'center' }}>
              {['Male', 'Female', 'Other'].map((o) => <button key={o} className={sex === o ? 'on' : ''} onClick={() => setSex(o)} style={{ fontSize: 13 }}>{o}</button>)}
            </div>
          </div>
        </div>
      </div>
      <div style={{ padding: 20 }}>
        <button className="btn block" disabled={!name.trim()} onClick={() => set((p) => ({
          ...p,
          stage: 'app',
          user: { ...p.user, name: name.trim(), sex, age: Number(age) || p.user.age },
          appts: p.appts.map((a) => (a.member === p.user.name ? { ...a, member: name.trim() } : a)),
        }))}>Start using CareLoop</button>
      </div>
    </div>
  );
}
