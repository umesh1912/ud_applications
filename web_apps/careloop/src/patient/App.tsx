import { useCallback, useEffect, useMemo, useRef } from 'react';
import { App as NativeApp } from '@capacitor/app';
import { doctorsFor } from '../data/catalog';
import { TabBar, ToastHost, useNav, usePersistent, type Nav } from '../ui/kit';
import { Onboarding } from './Onboarding';
import { Home } from './Home';
import { Book, Booked, DoctorProfile, Instant, Search } from './Find';
import { ApptDetail, Chat, PatientCall, RateVisit, RxView, Visits } from './Visits';
import { Records, ReportView } from './Records';
import { LabBook, Labs, Pharmacy } from './Shop';
import { Family, Notifications, Orders, Plus, Profile } from './Profile';
import { Ctx, seed, statusOf, type PatientState } from './state';

/* eslint-disable @typescript-eslint/no-explicit-any */
const ROUTES: Record<string, (p: any) => React.ReactNode> = {
  search: Search, doctor: DoctorProfile, instant: Instant, book: Book, booked: Booked,
  appt: ApptDetail, call: PatientCall, rate: RateVisit, rx: RxView, chat: Chat,
  report: ReportView, labs: Labs, labBook: LabBook, pharmacy: Pharmacy,
  plus: Plus, family: Family, orders: Orders, notifications: Notifications,
};
const TABS: Record<string, (p: { nav: Nav }) => React.ReactNode> = { home: Home, visits: Visits, records: Records, profile: Profile };

export function PatientApp({ storageKey = 'careloop-patient-v1' }: { storageKey?: string }) {
  const [s, setS] = usePersistent<PatientState>(storageKey, () => seed('IN'));
  const set = useCallback((fn: (s: PatientState) => PatientState) => setS(fn), [setS]);
  const docs = useMemo(() => doctorsFor(s.region), [s.region]);
  const ctx = useMemo(() => ({ s, set, docs, doctor: (id: string) => docs.find((d) => d.id === id) ?? docs[0] }), [s, set, docs]);
  const nav = useNav('home');

  // Android back button: pop a screen, then go to Home, then leave the app.
  const back = useRef<() => boolean>(() => false);
  back.current = () => {
    if (s.stage !== 'app') return false;
    if (nav.back()) return true;
    if (nav.tab !== 'home') { nav.setTab('home'); return true; }
    return false;
  };
  useEffect(() => {
    const h = NativeApp.addListener('backButton', () => { if (!back.current()) NativeApp.exitApp(); });
    return () => { h.then((x) => x.remove()); };
  }, []);

  const upcoming = s.appts.filter((a) => statusOf(a, Date.now()) === 'upcoming').length;
  const route = nav.top;
  const Screen = route ? ROUTES[route.name] : TABS[nav.tab];

  return (
    <Ctx.Provider value={ctx}>
      <ToastHost>
        <div className="app" data-role="patient">
          {s.stage !== 'app' ? <Onboarding /> : (
            <>
              <Screen key={`${nav.tab}-${nav.depth}-${route?.name ?? ''}`} nav={nav} {...(route?.params ?? {})} />
              {!route && (
                <TabBar
                  active={nav.tab}
                  onChange={(id) => (id === 'consult' ? nav.push('instant') : nav.setTab(id))}
                  tabs={[
                    { id: 'home', label: 'Home', icon: 'House' },
                    { id: 'visits', label: 'Visits', icon: 'CalendarDays', count: upcoming },
                    { id: 'consult', label: 'Consult now', icon: 'Video', fab: true },
                    { id: 'records', label: 'Records', icon: 'FolderHeart' },
                    { id: 'profile', label: 'Profile', icon: 'CircleUser' },
                  ]}
                />
              )}
            </>
          )}
        </div>
      </ToastHost>
    </Ctx.Provider>
  );
}
