import { useMemo, useState } from 'react';
import { Button, Icon, Input } from './ds';
import { api } from './lib/api';
import { strings } from './lib/i18n';
import { errorText } from './Phone';
import { btnReset, C, Stack, wide, wideTall } from './ui';

export function Login({ lang, setLang, framed, demo, onLoggedIn }: { lang: 'gu' | 'en'; setLang: (l: 'gu' | 'en') => void; framed: boolean; demo: boolean; onLoggedIn: (token: string) => void }) {
  const L = lang === 'gu' ? 0 : 1;
  const T = useMemo(() => strings(L), [L]);
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [step, setStep] = useState<'phone' | 'otp'>('phone');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [devCode, setDevCode] = useState<string | undefined>();

  const submit = async () => {
    setBusy(true); setError(null);
    try {
      if (step === 'phone') {
        const r = await api<{ devCode?: string }>('POST', '/auth/otp', { phone });
        setDevCode(r.devCode); setStep('otp');
      } else {
        onLoggedIn((await api<{ token: string }>('POST', '/auth/verify', { phone, code })).token);
      }
    } catch (e) { setError(errorText(e, L)); }
    finally { setBusy(false); }
  };

  return (
    <div lang={lang} style={{ height: '100%', display: 'flex', flexDirection: 'column', background: '#fff', color: C.ink }}>
      <header style={{ padding: framed ? '58px 16px 12px' : 'calc(env(safe-area-inset-top) + 12px) 16px 12px', display: 'flex', alignItems: 'center', gap: 10, borderBottom: `1px solid ${C.soft}` }}>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 1 }}>
          <div style={{ fontSize: 12, color: C.muted, fontWeight: 500 }}>{L ? 'Shivam Residency · Ahmedabad' : 'શિવમ રેસિડેન્સી · અમદાવાદ'}</div>
          <h1 style={{ margin: 0, fontSize: 20, fontWeight: 700, letterSpacing: -0.3 }}>{T.login}</h1>
        </div>
        <button onClick={() => setLang(L === 0 ? 'en' : 'gu')} style={{ ...btnReset, height: 32, padding: '0 10px', borderRadius: 6, boxShadow: `inset 0 0 0 1px ${C.line}`, background: '#fff', fontSize: 13, fontWeight: 600 }}>{L === 0 ? 'EN' : 'ગુ'}</button>
      </header>
      <form onSubmit={e => { e.preventDefault(); submit(); }} style={{ flex: 1, overflowY: 'auto', padding: '32px 16px 24px', display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div style={{ width: 56, height: 56, borderRadius: 6, background: C.ink, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="IconBuilding2" size={28} /></div>
        <Stack gap={6}>
          <div style={{ fontSize: 24, fontWeight: 700, letterSpacing: -0.4 }}>{L ? 'Shivam Residency' : 'શિવમ રેસિડેન્સી'}</div>
          <div style={{ fontSize: 14, color: C.muted, lineHeight: 1.5 }}>{step === 'phone' ? T.loginSub : T.otpSent + phone}</div>
        </Stack>
        {step === 'phone'
          ? <Input label={T.mobile} type="tel" inputMode="tel" autoComplete="tel" placeholder="98250 12345" value={phone} onChange={e => setPhone(e.target.value)} autoFocus style={wide} />
          : <Input label={T.otp} inputMode="numeric" autoComplete="one-time-code" maxLength={6} placeholder="••••••" value={code} onChange={e => setCode(e.target.value.replace(/\D/g, ''))} autoFocus style={wide} />}
        {error && <div role="alert" style={{ fontSize: 13, padding: 10, borderRadius: 6, background: '#fef2f2', color: C.red, fontWeight: 500 }}>{error}</div>}
        <Button type="submit" loading={busy} style={wideTall}>{step === 'phone' ? T.sendOtp : T.verify}</Button>
        {step === 'otp' && <button type="button" onClick={() => { setStep('phone'); setCode(''); setError(null); }} style={{ ...btnReset, background: 'none', fontSize: 14, fontWeight: 500, textDecoration: 'underline' }}>{T.changeNumber}</button>}
        {demo && <div style={{ fontSize: 12, color: C.muted, lineHeight: 1.6, padding: 12, borderRadius: 6, background: C.soft }}>
          {T.demoHint}{devCode ?? '123456'}<br />98250 12345 · 98250 23456 · 98250 34567 · 98250 41122
        </div>}
      </form>
    </div>
  );
}
