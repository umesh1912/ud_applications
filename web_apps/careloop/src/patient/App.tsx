import { useEffect, useMemo, useRef } from 'react';
import { App as NativeApp } from '@capacitor/app';
import { useAuth } from '../lib/auth';
import { useGroupQuery, useQuery, where } from '../lib/db';
import type { ApptDoc, DoctorDoc, MessageDoc, OrderDoc, ReportDoc, UserDoc } from '../lib/model';
import { PaymentProvider } from '../lib/pay';
import { AuthFlow, CompleteAccount, Splash, WrongApp } from '../ui/AuthFlow';
import { TabBar, ToastHost, useNav, type Nav } from '../ui/kit';
import { HealthProfile, Landing } from './Onboarding';
import { Home } from './Home';
import { Book, Booked, DoctorProfile, Instant, InstantWait, Search } from './Find';
import { ApptDetail, Chat, RateVisit, RxView, Visits } from './Visits';
import { Records, ReportView } from './Records';
import { LabBook, Labs, Pharmacy } from './Shop';
import { EditProfile, Family, Notifications, Orders, Plus, Profile } from './Profile';
import { Ctx, isUpcoming } from './ctx';

/* eslint-disable @typescript-eslint/no-explicit-any */
const ROUTES: Record<string, (p: any) => React.ReactNode> = {
  search: Search, doctor: DoctorProfile, instant: Instant, instantWait: InstantWait, book: Book, booked: Booked,
  appt: ApptDetail, rate: RateVisit, rx: RxView, chat: Chat,
  report: ReportView, labs: Labs, labBook: LabBook, pharmacy: Pharmacy,
  plus: Plus, family: Family, orders: Orders, notifications: Notifications, editProfile: EditProfile,
};
const TABS: Record<string, (p: { nav: Nav }) => React.ReactNode> = { home: Home, visits: Visits, records: Records, profile: Profile };

/** CareLoop for patients: sign in, then the app on live Firestore data. */
export function PatientApp() {
  const { user, profile } = useAuth();
  let body: React.ReactNode;
  if (user === undefined || (user && profile === undefined)) body = <Splash label="CareLoop" />;
  else if (!user) body = <AuthFlow role="patient" landing={(go) => <Landing {...go} />} />;
  else if (!profile) body = <CompleteAccount role="patient" />;
  else if (profile.role !== 'patient') body = <WrongApp expected="patient" />;
  else if (profile.age === undefined) body = <HealthProfile />;
  else body = <SignedIn me={profile} />;
  return (
    <ToastHost>
      <PaymentProvider>
        <div className="app" data-role="patient">{body}</div>
      </PaymentProvider>
    </ToastHost>
  );
}

function SignedIn({ me }: { me: UserDoc }) {
  const uid = me.id;
  const doctors = useQuery<DoctorDoc>(`docs-${me.region}`, 'doctors', where('status', '==', 'approved'), where('region', '==', me.region));
  const appts = useQuery<ApptDoc>(`appts-${uid}`, 'appointments', where('patientId', '==', uid));
  const reports = useQuery<ReportDoc>(`reports-${uid}`, 'reports', where('patientId', '==', uid));
  const orders = useQuery<OrderDoc>(`orders-${uid}`, 'orders', where('patientId', '==', uid));
  const rawInbox = useGroupQuery<MessageDoc>(`inbox-${uid}`, 'messages', where('to', '==', uid));
  const inbox = useMemo(() => [...(rawInbox ?? [])].sort((a, b) => b.t - a.t), [rawInbox]);
  const ctx = useMemo(() => ({
    uid, me, region: me.region, doctors, appts, reports, orders, inbox,
    doctor: (id: string) => doctors?.find((d) => d.id === id),
  }), [uid, me, doctors, appts, reports, orders, inbox]);
  const nav = useNav('home');

  // Android back button: pop a screen, then go to Home, then leave the app.
  const back = useRef<() => boolean>(() => false);
  back.current = () => {
    if (nav.back()) return true;
    if (nav.tab !== 'home') { nav.setTab('home'); return true; }
    return false;
  };
  useEffect(() => {
    const h = NativeApp.addListener('backButton', () => { if (!back.current()) NativeApp.exitApp(); });
    return () => { h.then((x) => x.remove()); };
  }, []);

  const upcoming = (appts ?? []).filter((a) => isUpcoming(a, Date.now())).length;
  const route = nav.top;
  const Screen = route ? ROUTES[route.name] : TABS[nav.tab];

  return (
    <Ctx.Provider value={ctx}>
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
    </Ctx.Provider>
  );
}
