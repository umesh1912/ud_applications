import { useCallback, useEffect, useRef, useState } from 'react';
import { Icon } from './ds';
import { IOSDevice } from './IOSDevice';
import { Login } from './Login';
import { JoinSociety, Profile, RegisterSociety, Welcome } from './Onboarding';
import { Phone } from './Phone';
import { ApiError, api, demoTokens, getToken, saveDemoToken, setToken } from './lib/api';
import { ROLES, type Role } from './lib/i18n';
import type { AppState, Me } from './lib/types';
import { C } from './ui';

const POLL_MS = 3000;
const LANG_KEY = 'sr.lang';

const storedLang = (): 'gu' | 'en' => { try { return localStorage.getItem(LANG_KEY) === 'en' ? 'en' : 'gu'; } catch { return 'gu'; } };
const useWide = () => {
  const q = '(min-width: 820px)';
  const [wide, setWide] = useState(() => window.matchMedia(q).matches);
  useEffect(() => {
    const m = window.matchMedia(q); const on = () => setWide(m.matches);
    m.addEventListener('change', on); return () => m.removeEventListener('change', on);
  }, []);
  return wide;
};
const nowHM = () => new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kolkata', hour: 'numeric', minute: '2-digit', hourCycle: 'h23' }).format(new Date());

export function App() {
  const [demo, setDemo] = useState<boolean | null>(null);
  const [me, setMe] = useState<Me | null>(null);
  const [st, setSt] = useState<AppState | null>(null);
  const [authed, setAuthed] = useState(!!getToken());
  const [offline, setOffline] = useState(false);
  const [view, setView] = useState<'app' | 'welcome' | 'register' | 'join'>('app');
  const [lang, setLangState] = useState(storedLang);
  const [clock, setClock] = useState(nowHM);
  const wide = useWide();
  const roleRef = useRef<Role | null>(null);
  roleRef.current = st?.me.role ?? null;

  const setLang = (l: 'gu' | 'en') => { setLangState(l); try { localStorage.setItem(LANG_KEY, l); } catch { /* ignore */ } };
  useEffect(() => { document.documentElement.lang = lang; }, [lang]);

  const signOutLocal = useCallback(() => {
    if (roleRef.current) saveDemoToken(roleRef.current, null);
    setToken(null); setSt(null); setMe(null); setAuthed(false); setView('app');
  }, []);

  /** Loads the account; when it has an active society, also that society's state. */
  const loadMe = useCallback(async () => {
    if (!getToken()) return;
    try {
      const m = await api<Me>('GET', '/me');
      setMe(m); setOffline(false);
      setSt(m.activeMemberId ? await api<AppState>('GET', '/state') : null);
    } catch (e) {
      if (e instanceof ApiError && e.status === 401) signOutLocal();
      else setOffline(true);
    }
  }, [signOutLocal]);

  const refresh = useCallback(async () => {
    if (!getToken()) return;
    try { setSt(await api<AppState>('GET', '/state')); setOffline(false); }
    catch (e) {
      if (e instanceof ApiError && e.status === 401) signOutLocal();
      else if (e instanceof ApiError && e.status === 403) loadMe(); // removed from the society
      else setOffline(true);
    }
  }, [signOutLocal, loadMe]);

  const loginAs = useCallback(async (role: Role) => {
    let token: string | undefined = demoTokens()[role];
    if (!token) { token = (await api<{ token: string }>('POST', '/auth/demo', { role })).token; saveDemoToken(role, token); }
    setToken(token); setAuthed(true); setView('app');
    try { await api('GET', '/me'); }
    catch (e) {
      // Saved demo session went stale (e.g. database reset): start a fresh one.
      if (!(e instanceof ApiError && e.status === 401)) throw e;
      const fresh = (await api<{ token: string }>('POST', '/auth/demo', { role })).token;
      saveDemoToken(role, fresh); setToken(fresh);
    }
    await loadMe();
  }, [loadMe]);

  const switchRole = useCallback((role: Role) => { loginAs(role).catch(() => setOffline(true)); }, [loginAs]);
  const switchSociety = useCallback(async (memberId: number) => {
    await api('POST', '/session/member', { memberId }).catch(() => {});
    setView('app'); await loadMe();
  }, [loadMe]);

  // Startup: read server config, then resume the session, or (demo, first visit) sign in as the demo resident.
  useEffect(() => {
    api<{ demo: boolean }>('GET', '/config').then(c => {
      setDemo(c.demo);
      if (getToken()) loadMe();
      else if (c.demo) switchRole('resident');
    }, () => { setDemo(false); setOffline(true); });
  }, [loadMe, switchRole]);

  // Poll so approvals, visitors, SOS alerts and payments from other members show up.
  useEffect(() => {
    if (!authed) return;
    const id = setInterval(() => {
      setClock(nowHM());
      if (document.visibilityState !== 'visible') return;
      if (st) refresh(); else if (me?.memberships.some(m => m.status === 'pending')) loadMe();
    }, POLL_MS);
    const vis = () => { if (document.visibilityState === 'visible') loadMe(); };
    document.addEventListener('visibilitychange', vis);
    return () => { clearInterval(id); document.removeEventListener('visibilitychange', vis); };
  }, [authed, st, me, refresh, loadMe]);

  const logout = useCallback(() => { api('POST', '/auth/logout').catch(() => {}); signOutLocal(); }, [signOutLocal]);
  const onLoggedIn = (token: string) => { setToken(token); setAuthed(true); loadMe(); };

  const framed = !!demo && wide;
  const common = { lang, setLang, framed };
  let screen;
  if (!authed) screen = <Login {...common} demo={!!demo} onLoggedIn={onLoggedIn} />;
  else if (!me) screen = <Splash />;
  else {
    const ob = { ...common, me, reload: loadMe, logout };
    const back = st ? () => setView('app') : () => setView('welcome');
    if (!me.account.name) screen = <Profile {...ob} />;
    else if (view === 'register') screen = <RegisterSociety {...ob} onBack={back} onDone={() => setView('app')} />;
    else if (view === 'join') screen = <JoinSociety {...ob} onBack={back} onDone={() => setView('app')} />;
    else if (!st || view === 'welcome')
      screen = <Welcome {...ob} onBack={st ? () => setView('app') : undefined} onRegister={() => setView('register')} onJoin={() => setView('join')} onSwitch={switchSociety} />;
    else screen = <Phone key={`${st.society.id}-${st.me.id}`} st={st} memberships={me.memberships} {...common} offline={offline} refresh={refresh} switchRole={switchRole}
      switchSociety={switchSociety} addSociety={() => setView('welcome')} logout={logout} onUnauthorized={signOutLocal} />;
  }

  if (!framed) return <div style={{ height: '100dvh' }}>{screen}</div>;

  const role = st?.me.role;
  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexWrap: 'wrap', gap: 48, justifyContent: 'center', alignItems: 'flex-start', padding: '40px 24px', background: C.soft }}>
      <aside style={{ width: 300, display: 'flex', flexDirection: 'column', gap: 20, paddingTop: 24 }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <div style={{ fontSize: 24, fontWeight: 700, letterSpacing: -0.4 }}>Shivam Residency app</div>
          <div style={{ fontSize: 14, color: C.muted, lineHeight: 1.5, textWrap: 'pretty' }}>Demo mode. Switch roles to see each view — actions carry across roles (a visitor logged at the gate appears for the resident, a bill submitted by the treasurer waits for the secretary).</div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: C.muted, textTransform: 'uppercase', letterSpacing: 0.5 }}>Role</div>
          {ROLES.map(r => {
            const on = r.id === role;
            return (
              <button key={r.id} onClick={() => switchRole(r.id)} aria-pressed={on}
                style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px', border: 0, borderRadius: 6, cursor: 'pointer', textAlign: 'left', background: on ? C.ink : '#fff', color: on ? '#fff' : C.ink, boxShadow: `inset 0 0 0 1px ${C.line}` }}>
                <Icon name={r.icon} size={18} />
                <span style={{ display: 'flex', flexDirection: 'column', gap: 2 }}><span style={{ fontSize: 14, fontWeight: 600 }}>{r.en}</span><span style={{ fontSize: 12, opacity: 0.7 }}>{r.sub}</span></span>
              </button>
            );
          })}
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <div style={{ fontSize: 12, fontWeight: 600, color: C.muted, textTransform: 'uppercase', letterSpacing: 0.5 }}>Language</div>
          <div style={{ display: 'flex', gap: 4, padding: 4, background: C.line, borderRadius: 6 }}>
            {(['gu', 'en'] as const).map(l => (
              <button key={l} onClick={() => setLang(l)} aria-pressed={lang === l}
                style={{ flex: 1, border: 0, padding: 8, borderRadius: 4, cursor: 'pointer', fontSize: 14, fontWeight: 600, background: lang === l ? '#fff' : 'transparent', color: C.ink }}>{l === 'gu' ? 'ગુજરાતી' : 'English'}</button>
            ))}
          </div>
        </div>
        <div style={{ fontSize: 13, color: C.muted, lineHeight: 1.6 }}>Try: pay bills → receipt · approve the visitor at the gate · book the clubhouse · vote in a poll · send an SOS · as watchman, log a visitor for B-304 · as treasurer, submit the light bill · as secretary, approve it.</div>
      </aside>
      <IOSDevice time={clock}><div style={{ height: 874 }}>{screen}</div></IOSDevice>
    </div>
  );
}

function Splash() {
  return <div style={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#fff' }}><span className="sc-btn-spinner" style={{ boxShadow: `inset 0 0 0 2px ${C.ink}` }} /></div>;
}
