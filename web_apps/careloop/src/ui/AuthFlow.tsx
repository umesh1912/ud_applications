import { useState, type ReactNode } from 'react';
import type { ConfirmationResult } from 'firebase/auth';
import { REGIONS, type Region } from '../data/region';
import { createProfile, logIn, logOut, resetPassword, sendPhoneCode, signUpWithEmail, useAuth } from '../lib/auth';
import { errorText } from '../lib/db';
import type { Role } from '../lib/model';
import { Icon, Segmented, TopBar } from './kit';

type Step = 'landing' | 'signup' | 'login' | 'phone';

/**
 * Account screens shared by both apps: landing, sign up, log in (email or phone code), reset password.
 * `landing` is the app's own welcome screen; it receives callbacks to move on.
 */
export function AuthFlow({ role, landing }: { role: Role; landing: (go: { signup: () => void; login: () => void }) => ReactNode }) {
  const [step, setStep] = useState<Step>('landing');
  if (step === 'landing') return <>{landing({ signup: () => setStep('signup'), login: () => setStep('login') })}</>;
  if (step === 'signup') return <SignUp role={role} onBack={() => setStep('landing')} onLogin={() => setStep('login')} />;
  if (step === 'phone') return <PhoneLogin onBack={() => setStep('login')} />;
  return <LogIn role={role} onBack={() => setStep('landing')} onSignup={() => setStep('signup')} onPhone={() => setStep('phone')} />;
}

function ErrorNote({ msg }: { msg: string | null }) {
  if (!msg) return null;
  return <div className="row gap-8" role="alert" style={{ padding: '10px 12px', borderRadius: 12, background: 'var(--bad-soft)', color: 'var(--bad)', fontSize: 13.5, fontWeight: 600 }}><Icon name="CircleAlert" size={16} />{msg}</div>;
}

function PasswordInput({ value, onChange, autoComplete }: { value: string; onChange: (v: string) => void; autoComplete: string }) {
  const [show, setShow] = useState(false);
  return (
    <div style={{ position: 'relative' }}>
      <input className="input" type={show ? 'text' : 'password'} value={value} onChange={(e) => onChange(e.target.value)} autoComplete={autoComplete} style={{ paddingRight: 52 }} />
      <button type="button" className="icon-btn ghost" onClick={() => setShow(!show)} aria-label={show ? 'Hide password' : 'Show password'} style={{ position: 'absolute', right: 5, top: 5 }}>
        <Icon name={show ? 'EyeOff' : 'Eye'} size={19} />
      </button>
    </div>
  );
}

const emailOk = (e: string) => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(e.trim());

function SignUp({ role, onBack, onLogin }: { role: Role; onBack: () => void; onLogin: () => void }) {
  const [region, setRegion] = useState<Region>('IN');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [agree, setAgree] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const strong = password.length >= 8 && /\d/.test(password) && /[A-Za-z]/.test(password);
  const valid = name.trim().length > 1 && emailOk(email) && phone.replace(/\D/g, '').length >= 10 && strong && agree;

  const submit = async () => {
    setBusy(true); setErr(null);
    try {
      await signUpWithEmail({ role, name, email, password, phone: `${REGIONS[region].phonePrefix} ${phone.trim()}`, region });
    } catch (e) { setErr(errorText(e)); setBusy(false); }
  };

  return (
    <form className="screen stack" onSubmit={(e) => { e.preventDefault(); if (valid && !busy) submit(); }}>
      <TopBar title="Create account" onBack={onBack} />
      <div className="pad stack gap-14" style={{ paddingBottom: 24 }}>
        <div className="t-body">{role === 'doctor' ? 'Set up your practice account. We’ll verify your license next.' : 'One account for you and your family.'}</div>
        <div className="field"><label>Country</label><Segmented options={[{ id: 'IN', label: 'India' }, { id: 'US', label: 'United States' }]} value={region} onChange={setRegion} /></div>
        <div className="field"><label htmlFor="su-name">{role === 'doctor' ? 'Full name (as on your license)' : 'Full name'}</label><input id="su-name" className="input" value={name} onChange={(e) => setName(e.target.value)} autoComplete="name" /></div>
        <div className="field"><label htmlFor="su-email">Email</label><input id="su-email" className="input" type="email" inputMode="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" /></div>
        <div className="field">
          <label htmlFor="su-phone">Mobile number</label>
          <div className="row gap-8">
            <div className="input row center" style={{ width: 70, flex: 'none', fontWeight: 700 }}>{REGIONS[region].phonePrefix}</div>
            <input id="su-phone" className="input" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder={REGIONS[region].samplePhone} autoComplete="tel-national" />
          </div>
        </div>
        <div className="field">
          <label>Password</label>
          <PasswordInput value={password} onChange={setPassword} autoComplete="new-password" />
          <div className="row gap-6 t-xs" style={{ color: password && !strong ? 'var(--warn)' : undefined }}>
            <Icon name={strong ? 'CircleCheck' : 'Info'} size={13} style={strong ? { color: 'var(--good)' } : undefined} />At least 8 characters with a letter and a number
          </div>
        </div>
        <label className="row gap-10 tap" style={{ fontSize: 13.5, color: 'var(--ink-2)', alignItems: 'flex-start' }}>
          <input type="checkbox" checked={agree} onChange={(e) => setAgree(e.target.checked)} style={{ width: 20, height: 20, marginTop: 1, accentColor: 'var(--brand)' }} />
          <span>I agree to the Terms of Service and Privacy Policy, and consent to my health information being shared with doctors I consult. {REGIONS[region].compliance}.</span>
        </label>
        <ErrorNote msg={err} />
        <button className="btn block" type="submit" disabled={!valid || busy}>{busy ? <><span className="spinner" />Creating account…</> : 'Create account'}</button>
        <button type="button" className="btn block ghost" style={{ background: 'none', boxShadow: 'none' }} onClick={onLogin}>I already have an account</button>
      </div>
    </form>
  );
}

function LogIn({ role, onBack, onSignup, onPhone }: { role: Role; onBack: () => void; onSignup: () => void; onPhone: () => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  const submit = async () => {
    setBusy(true); setErr(null);
    try { await logIn(email, password); } catch (e) { setErr(errorText(e)); setBusy(false); }
  };
  const forgot = async () => {
    setErr(null);
    if (!emailOk(email)) { setErr('Enter your email above first.'); return; }
    try { await resetPassword(email); setInfo(`We sent a password reset link to ${email.trim()}.`); } catch (e) { setErr(errorText(e)); }
  };

  return (
    <form className="screen stack" onSubmit={(e) => { e.preventDefault(); if (!busy) submit(); }}>
      <TopBar title="Log in" onBack={onBack} />
      <div className="pad stack gap-14">
        <div className="t-h1">{role === 'doctor' ? 'Welcome back, doctor' : 'Welcome back'}</div>
        <div className="field"><label htmlFor="li-email">Email</label><input id="li-email" className="input" type="email" inputMode="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="username" /></div>
        <div className="field"><label>Password</label><PasswordInput value={password} onChange={setPassword} autoComplete="current-password" /></div>
        <button type="button" className="t-sm tap" onClick={forgot} style={{ alignSelf: 'flex-end', border: 0, background: 'none', fontWeight: 700, color: 'var(--brand)' }}>Forgot password?</button>
        <ErrorNote msg={err} />
        {info && <div className="row gap-8" style={{ padding: '10px 12px', borderRadius: 12, background: 'var(--good-soft)', color: '#14532d', fontSize: 13.5, fontWeight: 600 }}><Icon name="MailCheck" size={16} />{info}</div>}
        <button className="btn block" type="submit" disabled={!emailOk(email) || !password || busy}>{busy ? <><span className="spinner" />Logging in…</> : 'Log in'}</button>
        <div className="row gap-10 t-xs" style={{ margin: '4px 0' }}><span className="grow divider" />or<span className="grow divider" /></div>
        <button type="button" className="btn block ghost" onClick={onPhone}><Icon name="Smartphone" size={18} />Log in with a phone code</button>
        <button type="button" className="btn block ghost" style={{ background: 'none', boxShadow: 'none' }} onClick={onSignup}>New here? Create an account</button>
      </div>
    </form>
  );
}

function PhoneLogin({ onBack }: { onBack: () => void }) {
  const [region, setRegion] = useState<Region>('IN');
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [conf, setConf] = useState<ConfirmationResult | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const e164 = `${REGIONS[region].phonePrefix}${phone.replace(/\D/g, '')}`;

  const send = async () => {
    setBusy(true); setErr(null);
    try { setConf(await sendPhoneCode(e164, 'recaptcha-box')); } catch (e) { setErr(errorText(e)); }
    setBusy(false);
  };
  const verify = async () => {
    setBusy(true); setErr(null);
    try { await conf!.confirm(code); } catch (e) { setErr(errorText(e)); setBusy(false); }
  };

  return (
    <form className="screen stack" onSubmit={(e) => { e.preventDefault(); if (!busy) (conf ? verify() : send()); }}>
      <TopBar title="Phone login" onBack={onBack} />
      <div className="pad stack gap-14">
        {!conf ? (
          <>
            <div className="t-body">We’ll text a 6-digit code to your mobile.</div>
            <Segmented options={[{ id: 'IN', label: 'India' }, { id: 'US', label: 'United States' }]} value={region} onChange={setRegion} />
            <div className="row gap-8">
              <div className="input row center" style={{ width: 70, flex: 'none', fontWeight: 700 }}>{REGIONS[region].phonePrefix}</div>
              <input className="input" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} placeholder={REGIONS[region].samplePhone} aria-label="Mobile number" autoComplete="tel-national" />
            </div>
          </>
        ) : (
          <>
            <div className="t-body">Enter the code sent to {e164}.</div>
            <input className="input num" inputMode="numeric" autoComplete="one-time-code" value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))} aria-label="Code" style={{ fontSize: 24, fontWeight: 800, letterSpacing: '0.3em', textAlign: 'center' }} autoFocus />
            <button type="button" className="t-sm tap" onClick={() => { setConf(null); setCode(''); }} style={{ border: 0, background: 'none', fontWeight: 700, color: 'var(--brand)' }}>Change number or resend</button>
          </>
        )}
        <ErrorNote msg={err} />
        <button className="btn block" type="submit" disabled={busy || (conf ? code.length !== 6 : phone.replace(/\D/g, '').length < 10)}>
          {busy ? <span className="spinner" /> : conf ? 'Verify and log in' : 'Send code'}
        </button>
        <div id="recaptcha-box" />
      </div>
    </form>
  );
}

/** Shown after a phone-code login when the number has no CareLoop profile yet. */
export function CompleteAccount({ role }: { role: Role }) {
  const { user } = useAuth();
  const [name, setName] = useState('');
  const [region, setRegion] = useState<Region>(user?.phoneNumber?.startsWith('+1') ? 'US' : 'IN');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  return (
    <form className="screen stack" onSubmit={async (e) => {
      e.preventDefault(); setBusy(true); setErr(null);
      try { await createProfile(user!.uid, { role, name: name.trim(), region, phone: user!.phoneNumber ?? undefined, email: user!.email ?? undefined }); }
      catch (x) { setErr(errorText(x)); setBusy(false); }
    }}>
      <TopBar title="Finish setting up" right={<button type="button" className="icon-btn" onClick={() => logOut()} aria-label="Log out"><Icon name="LogOut" size={18} /></button>} />
      <div className="pad stack gap-14">
        <div className="t-body">You’re verified as {user?.phoneNumber}. Tell us your name to finish.</div>
        <div className="field"><label>Country</label><Segmented options={[{ id: 'IN', label: 'India' }, { id: 'US', label: 'United States' }]} value={region} onChange={setRegion} /></div>
        <div className="field"><label htmlFor="ca-name">Full name</label><input id="ca-name" className="input" value={name} onChange={(e) => setName(e.target.value)} autoFocus /></div>
        <ErrorNote msg={err} />
        <button className="btn block" type="submit" disabled={name.trim().length < 2 || busy}>{busy ? <span className="spinner" /> : 'Continue'}</button>
      </div>
    </form>
  );
}

/** A patient account opened the doctor app, or the other way round. */
export function WrongApp({ expected }: { expected: Role }) {
  const { profile } = useAuth();
  const other = expected === 'doctor' ? 'CareLoop (the patient app)' : 'CareLoop Pro (the doctor app)';
  return (
    <div className="screen stack center gap-14" style={{ padding: 28, textAlign: 'center' }}>
      <div className="tile-icon" style={{ width: 72, height: 72, borderRadius: 24 }}><Icon name="ArrowLeftRight" size={32} /></div>
      <div className="t-h1">This is a {profile?.role} account</div>
      <div className="t-body">{profile?.name}, your account is set up for {other}. Log in there, or log out and use a different account here.</div>
      <button className="btn block" onClick={() => logOut()}><Icon name="LogOut" size={18} />Log out</button>
    </div>
  );
}

export function Splash({ label }: { label: string }) {
  return (
    <div className="screen stack center gap-16" style={{ background: 'linear-gradient(160deg, var(--hero-a), var(--hero-b))', color: '#fff' }}>
      <div className="tile-icon" style={{ width: 76, height: 76, borderRadius: 26, background: 'rgba(255,255,255,.16)', color: '#fff' }}><Icon name="HeartPulse" size={38} /></div>
      <div className="t-h2">{label}</div>
      <span className="spinner" style={{ width: 24, height: 24 }} />
    </div>
  );
}
