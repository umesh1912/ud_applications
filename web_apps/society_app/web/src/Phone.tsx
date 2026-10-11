import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Icon } from './ds';
import { AppCtx, type Ctx, type Sheet, type Ui } from './ctx';
import { ApiError, api, download } from './lib/api';
import { E, SOS_SHORT, TABS, strings, type Pair, type Role } from './lib/i18n';
import type { AppState } from './lib/types';
import { SheetHost } from './Sheets';
import { AdminHome, GateHome, ResidentHome } from './screens/Home';
import { Amenities, Bills, Complaints, Gate, Parking } from './screens/Resident';
import { Community, Directory, Docs, Help, More, VisitorLog } from './screens/Shared';
import { Expenses, Reports } from './screens/Admin';
import { btnReset, C } from './ui';

const ERRORS: Record<string, keyof typeof E> = {
  phone_unknown: 'phoneUnknown', phone_invalid: 'phoneInvalid', otp_invalid: 'otpInvalid', otp_expired: 'otpExpired', slot_taken: 'slotTaken',
  parking_full: 'parkingFull', flat_unknown: 'flatUnknown', offline: 'offline', no_flat: 'noFlat', poll_closed: 'pollClosed', offline_file: 'offlineFile',
};
export const errorText = (e: unknown, L: 0 | 1) => (E[ERRORS[e instanceof ApiError ? e.code : ''] ?? 'error'] as Pair)[L];

const initialUi = (today: string): Ui => ({
  screen: 'home', sheet: null, commTab: 'notices', unselected: [], payMethod: 'upi', paying: false, receipt: null,
  amenity: 'hall', date: today, slot: null, sosType: 'medical', sosSent: false, codeResult: null, file: null,
  f: { code: '', q: '', passName: '', passWhen: 'today', comp: '', compCat: 'plumb', vName: '', vFlat: '', vP: 'guest', nTitle: '', nBody: '', nPin: false, bVendor: '', bAmt: '', bCat: 'light', cashFlat: null },
});

export interface PhoneProps {
  st: AppState; lang: 'gu' | 'en'; setLang: (l: 'gu' | 'en') => void; framed: boolean; offline: boolean;
  refresh: () => Promise<void>; switchRole: (r: Role) => void; logout: () => void; onUnauthorized: () => void;
}

export function Phone({ st, lang, setLang, framed, offline, refresh, switchRole, logout, onUnauthorized }: PhoneProps) {
  const L = lang === 'gu' ? 0 : 1;
  const T = useMemo(() => strings(L), [L]);
  const x = useCallback((p: Pair) => p[L], [L]);
  const role = st.me.role;
  const [ui, setUi] = useState<Ui>(() => initialUi(st.today));
  const [toastMsg, setToast] = useState<string | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined);
  const scroller = useRef<HTMLDivElement>(null);
  useEffect(() => () => clearTimeout(timer.current), []);
  useEffect(() => { scroller.current?.scrollTo(0, 0); }, [ui.screen]);

  const toast = useCallback((msg: string) => {
    clearTimeout(timer.current); setToast(msg); timer.current = setTimeout(() => setToast(null), 2400);
  }, []);
  const set = useCallback((p: Partial<Ui> | ((u: Ui) => Partial<Ui>)) => setUi(u => ({ ...u, ...(typeof p === 'function' ? p(u) : p) })), []);

  const ctx: Ctx = {
    st, L, T, x, role, isRes: role === 'resident', isAdmin: role === 'secretary' || role === 'treasurer', isW: role === 'watchman',
    ui, set, setF: (k, v) => setUi(u => ({ ...u, f: { ...u.f, [k]: v } })),
    go: screen => set({ screen }),
    open: (sheet: Sheet) => set(u => ({ sheet, file: null, sosSent: sheet === 'sos' ? false : u.sosSent })),
    close: () => set({ sheet: null }),
    toast,
    run: async fn => {
      try { const r = await fn(); await refresh(); return r; }
      catch (e) {
        if (e instanceof ApiError && e.status === 401) onUnauthorized();
        else { toast(errorText(e, L)); refresh(); }
        return undefined;
      }
    },
    dl: (path, name, okMsg) => { download(path, name).then(() => okMsg && toast(okMsg), e => toast(errorText(e, L))); },
    switchRole, logout,
  };

  const isW = ctx.isW, isAdmin = ctx.isAdmin;
  const tabIds = TABS[role].map(t => t[0]);
  const scr = ui.screen;
  const titles: Record<string, string> = {
    home: isW ? x(['મુખ્ય ગેટ', 'Main gate']) : isAdmin ? x(['ડેશબોર્ડ', 'Dashboard']) : x([st.society.gu, st.society.en]),
    bills: T.bills, gate: T.gatePass, community: T.community, more: T.more, reports: T.reports, expenses: T.expenses, log: T.visitors,
    help: T.dailyHelp, complaints: T.complaints, amenities: T.amenities, parking: T.parking, directory: T.directory, docs: T.docs,
  };
  const roleLocal = { resident: T.resident, secretary: T.secretary, treasurer: T.treasurer, watchman: T.watchman }[role];
  const society = x([st.society.gu, st.society.en]);
  const headerSub = scr === 'home' && !isW ? `${society} · ${x([st.society.cityGu, st.society.cityEn])}` : scr === 'home' ? society : roleLocal;

  const screens: Record<string, ReactNode> = {
    home: ctx.isRes ? <ResidentHome /> : isAdmin ? <AdminHome /> : <GateHome />,
    bills: <Bills />, gate: <Gate />, community: <Community />, complaints: <Complaints />, amenities: <Amenities />, parking: <Parking />,
    directory: <Directory />, docs: <Docs />, help: <Help />, log: <VisitorLog />, more: <More />,
    reports: isAdmin ? <Reports /> : null, expenses: isAdmin ? <Expenses /> : null,
  };

  const sos = st.sos && !ctx.isRes ? st.sos : null;
  const resolveSos = async () => {
    if (sos && await ctx.run(() => api('POST', `/sos/${sos.id}/resolve`))) toast(x(['સભ્યને જાણ કરી: મદદ આવી રહી છે', 'Resident notified: help is coming']));
  };

  return (
    <AppCtx.Provider value={ctx}>
      <div lang={lang} className="phone" style={{ height: '100%', position: 'relative', display: 'flex', flexDirection: 'column', background: '#fff', color: C.ink }}>
        <header style={{ padding: framed ? '58px 16px 12px' : 'calc(env(safe-area-inset-top) + 12px) 16px 12px', display: 'flex', alignItems: 'center', gap: 10, borderBottom: `1px solid ${C.soft}` }}>
          {!tabIds.includes(scr) && (
            <button aria-label="Back" onClick={() => ctx.go('home')} style={{ ...btnReset, width: 36, height: 36, borderRadius: 6, background: C.soft, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none' }}>
              <Icon name="IconChevronLeft" size={20} />
            </button>
          )}
          <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 1 }}>
            <div style={{ fontSize: 12, color: C.muted, fontWeight: 500 }}>{headerSub}</div>
            <h1 style={{ margin: 0, fontSize: 20, fontWeight: 700, letterSpacing: -0.3, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{titles[scr]}</h1>
          </div>
          <button onClick={() => setLang(L === 0 ? 'en' : 'gu')} aria-label="Language"
            style={{ ...btnReset, height: 32, padding: '0 10px', borderRadius: 6, boxShadow: `inset 0 0 0 1px ${C.line}`, background: '#fff', fontSize: 13, fontWeight: 600 }}>{L === 0 ? 'EN' : 'ગુ'}</button>
          <button onClick={() => ctx.open('sos')} style={{ ...btnReset, height: 32, padding: '0 10px', borderRadius: 6, background: C.red, color: '#fff', fontSize: 13, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 4 }}>
            <Icon name="IconSiren" size={15} />SOS
          </button>
        </header>

        <main ref={scroller} style={{ flex: 1, overflowY: 'auto', padding: '16px 16px 24px' }}>
          {offline && <div role="status" style={{ marginBottom: 12, padding: '8px 12px', borderRadius: 6, background: C.soft, fontSize: 13, color: C.body }}>{T.offline}</div>}
          {sos && (
            <div role="alert" style={{ background: C.red, color: '#fff', borderRadius: 6, padding: 14, display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 16 }}>
              <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}><Icon name="IconSiren" size={22} style={{ flex: 'none' }} /><div style={{ fontWeight: 700, fontSize: 15 }}>SOS: {sos.flat ?? x(['ગેટ', 'Gate'])} – {x(SOS_SHORT[sos.type] ?? SOS_SHORT.medical)}</div></div>
              <button onClick={resolveSos} style={{ ...btnReset, height: 40, borderRadius: 6, background: '#fff', color: C.red, fontWeight: 700, fontSize: 14 }}>{T.responding}</button>
            </div>
          )}
          {screens[scr] ?? screens.home}
        </main>

        <nav style={{ display: 'flex', borderTop: `1px solid ${C.line}`, background: '#fff', padding: framed ? '6px 6px 30px' : '6px 6px calc(env(safe-area-inset-bottom) + 6px)' }}>
          {TABS[role].map(([id, icon]) => {
            const on = scr === id;
            return (
              <button key={id} onClick={() => ctx.go(id)} aria-current={on ? 'page' : undefined}
                style={{ ...btnReset, flex: 1, background: 'transparent', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, padding: '6px 0', color: on ? C.ink : C.faint }}>
                <Icon name={icon} size={22} />
                <span style={{ fontSize: 11, fontWeight: on ? 700 : 500 }}>{id === 'home' ? T.home : id === 'log' ? T.visitors : id === 'help' ? T.help : T[id as keyof typeof T]}</span>
              </button>
            );
          })}
        </nav>

        {toastMsg && (
          <div role="status" style={{ position: 'absolute', left: 16, right: 16, bottom: framed ? 100 : 'calc(env(safe-area-inset-bottom) + 76px)', background: C.ink, color: '#fff', borderRadius: 6, padding: '12px 14px', fontSize: 14, fontWeight: 500, display: 'flex', gap: 8, alignItems: 'center', boxShadow: '0 4px 6px rgba(0,0,0,.09)', zIndex: 30 }}>
            <Icon name="IconCheckCircle2" size={18} style={{ flex: 'none' }} />{toastMsg}
          </div>
        )}
        <SheetHost />
      </div>
    </AppCtx.Provider>
  );
}
