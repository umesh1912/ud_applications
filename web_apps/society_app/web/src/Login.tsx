import { useMemo, useState } from 'react';
import { Button, Icon, Input } from './ds';
import { api } from './lib/api';
import { errorText } from './lib/errors';
import { strings } from './lib/i18n';
import { ErrorBox, Screen } from './Screen';
import { btnReset, C, Stack, wide, wideTall } from './ui';

/** Sign up and sign in are the same step: mobile number, then the SMS code. */
export function Login({ lang, setLang, framed, demo, onLoggedIn }: { lang: 'gu' | 'en'; setLang: (l: 'gu' | 'en') => void; framed: boolean; demo: boolean; onLoggedIn: (token: string) => void }) {
  const L = lang === 'gu' ? 0 : 1;
  const T = useMemo(() => strings(L), [L]);
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [step, setStep] = useState<'phone' | 'otp'>('phone');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [devCode, setDevCode] = useState<string | undefined>();

  const send = async () => {
    const r = await api<{ devCode?: string }>('POST', '/auth/otp', { phone });
    setDevCode(r.devCode); setStep('otp');
  };
  const submit = async () => {
    setBusy(true); setError(null);
    try {
      if (step === 'phone') await send();
      else onLoggedIn((await api<{ token: string }>('POST', '/auth/verify', { phone, code })).token);
    } catch (e) { setError(errorText(e, L)); }
    finally { setBusy(false); }
  };

  return (
    <Screen sub={L ? 'Society app' : 'સોસાયટી એપ'} title={T.login} lang={lang} setLang={setLang} framed={framed}>
      <form onSubmit={e => { e.preventDefault(); submit(); }} style={{ display: 'flex', flexDirection: 'column', gap: 16, paddingTop: 12 }}>
        <div style={{ width: 56, height: 56, borderRadius: 6, background: C.ink, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="IconBuilding2" size={28} /></div>
        <Stack gap={6}>
          <div style={{ fontSize: 24, fontWeight: 700, letterSpacing: -0.4 }}>{L ? 'Your society, in one app' : 'તમારી સોસાયટી, એક જ એપમાં'}</div>
          <div style={{ fontSize: 14, color: C.muted, lineHeight: 1.5 }}>{step === 'phone' ? T.loginSub : T.otpSent + phone}</div>
        </Stack>
        {step === 'phone'
          ? <Input label={T.mobile} type="tel" inputMode="tel" autoComplete="tel" placeholder="98250 12345" value={phone} onChange={e => setPhone(e.target.value)} autoFocus style={wide} />
          : <Input label={T.otp} inputMode="numeric" autoComplete="one-time-code" maxLength={6} placeholder="••••••" value={code} onChange={e => setCode(e.target.value.replace(/\D/g, ''))} autoFocus style={wide} />}
        {error && <ErrorBox>{error}</ErrorBox>}
        <Button type="submit" loading={busy} style={wideTall}>{step === 'phone' ? T.sendOtp : T.verify}</Button>
        {step === 'otp' && (
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <button type="button" onClick={() => { setStep('phone'); setCode(''); setError(null); }} style={{ ...btnReset, background: 'none', fontSize: 14, fontWeight: 500, textDecoration: 'underline' }}>{T.changeNumber}</button>
            <button type="button" onClick={() => { setError(null); send().catch(e => setError(errorText(e, L))); }} style={{ ...btnReset, background: 'none', fontSize: 14, fontWeight: 500, textDecoration: 'underline' }}>{T.sendOtp}</button>
          </div>
        )}
        {devCode && <div style={{ fontSize: 12, color: C.muted, lineHeight: 1.6, padding: 12, borderRadius: 6, background: C.soft }}>{L ? 'Test mode – OTP: ' : 'ટેસ્ટ મોડ – OTP: '}<b>{devCode}</b></div>}
        {demo && step === 'phone' && <div style={{ fontSize: 12, color: C.muted, lineHeight: 1.6, padding: 12, borderRadius: 6, background: C.soft }}>
          {L ? 'Demo society members: ' : 'ડેમો સોસાયટીના સભ્યો: '}98250 12345 · 98250 23456 · 98250 34567 · 98250 41122
        </div>}
      </form>
    </Screen>
  );
}
