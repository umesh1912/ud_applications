import { useCallback, useEffect, useMemo, useRef } from 'react';
import { App as NativeApp } from '@capacitor/app';
import { doctorsFor } from '../data/catalog';
import { TabBar, ToastHost, useNav, usePersistent, type Nav } from '../ui/kit';
import { Consult, Prescribe, RxPreview, Today, Welcome } from './Today';
import { DoctorProfile, Earnings, PatientChart, Patients, Plans, Schedule } from './Practice';
import { Ctx, seed, type DoctorState } from './state';

/* eslint-disable @typescript-eslint/no-explicit-any */
const ROUTES: Record<string, (p: any) => React.ReactNode> = {
  consult: Consult, prescribe: Prescribe, rxPreview: RxPreview, patient: PatientChart, plans: Plans,
};
const TABS: Record<string, (p: { nav: Nav }) => React.ReactNode> = {
  today: Today, schedule: Schedule, patients: Patients, earnings: Earnings, profile: DoctorProfile,
};

export function DoctorApp({ storageKey = 'careloop-doctor-v1' }: { storageKey?: string }) {
  const [s, setS] = usePersistent<DoctorState>(storageKey, () => seed('IN'));
  const set = useCallback((fn: (s: DoctorState) => DoctorState) => setS(fn), [setS]);
  const me = useMemo(() => doctorsFor(s.region)[0], [s.region]);
  const ctx = useMemo(() => ({ s, set, me, patient: (id: string) => s.patients.find((p) => p.id === id) ?? s.patients[0] }), [s, set, me]);
  const nav = useNav('today');

  const back = useRef<() => boolean>(() => false);
  back.current = () => {
    if (s.stage !== 'app') return false;
    if (nav.back()) return true;
    if (nav.tab !== 'today') { nav.setTab('today'); return true; }
    return false;
  };
  useEffect(() => {
    const h = NativeApp.addListener('backButton', () => { if (!back.current()) NativeApp.exitApp(); });
    return () => { h.then((x) => x.remove()); };
  }, []);

  const route = nav.top;
  const Screen = route ? ROUTES[route.name] : TABS[nav.tab];
  const waiting = s.queue.filter((q) => q.status === 'waiting').length;

  return (
    <Ctx.Provider value={ctx}>
      <ToastHost>
        <div className="app" data-role="doctor">
          {s.stage !== 'app' ? <Welcome /> : (
            <>
              <Screen key={`${nav.tab}-${nav.depth}-${route?.name ?? ''}`} nav={nav} {...(route?.params ?? {})} />
              {!route && (
                <TabBar
                  active={nav.tab}
                  onChange={nav.setTab}
                  tabs={[
                    { id: 'today', label: 'Today', icon: 'LayoutDashboard', count: waiting },
                    { id: 'schedule', label: 'Schedule', icon: 'CalendarDays' },
                    { id: 'patients', label: 'Patients', icon: 'Users' },
                    { id: 'earnings', label: 'Earnings', icon: 'Wallet' },
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
