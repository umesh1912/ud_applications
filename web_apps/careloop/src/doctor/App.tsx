import { useEffect, useMemo, useRef } from 'react';
import { App as NativeApp } from '@capacitor/app';
import { useAuth } from '../lib/auth';
import { useDoc, useGroupQuery, useQuery, where } from '../lib/db';
import type { ApptDoc, DoctorDoc, InstantRequest, MessageDoc, PayoutDoc, UserDoc } from '../lib/model';
import { PaymentProvider } from '../lib/pay';
import { lastRead } from '../lib/care';
import { AuthFlow, CompleteAccount, Splash, WrongApp } from '../ui/AuthFlow';
import { TabBar, ToastHost, useNav, type Nav } from '../ui/kit';
import { AdminConsole } from './Admin';
import { DoctorSetup, Pending, Welcome } from './Onboarding';
import { ConsultRoom, Prescribe, RxPreview, Today } from './Today';
import { DoctorProfile, EditPractice, Earnings, PatientChart, Patients, Plans, Schedule, VisitChat } from './Practice';
import { Ctx } from './ctx';

/* eslint-disable @typescript-eslint/no-explicit-any */
const ROUTES: Record<string, (p: any) => React.ReactNode> = {
  consult: ConsultRoom, prescribe: Prescribe, rxPreview: RxPreview, patient: PatientChart, plans: Plans, editPractice: EditPractice, chat: VisitChat,
};
const TABS: Record<string, (p: { nav: Nav }) => React.ReactNode> = {
  today: Today, schedule: Schedule, patients: Patients, earnings: Earnings, profile: DoctorProfile,
};

/** CareLoop Pro for doctors: sign in, verify, then the practice on live Firestore data. */
export function DoctorApp() {
  const { user, profile } = useAuth();
  let body: React.ReactNode;
  if (user === undefined || (user && profile === undefined)) body = <Splash label="CareLoop Pro" />;
  else if (!user) body = <AuthFlow role="doctor" landing={(go) => <Welcome {...go} />} />;
  else if (!profile) body = <CompleteAccount role="doctor" />;
  else if (profile.role === 'admin') body = <AdminConsole me={profile} />;
  else if (profile.role !== 'doctor') body = <WrongApp expected="doctor" />;
  else body = <DoctorGate me={profile} />;
  return (
    <ToastHost>
      <PaymentProvider>
        <div className="app" data-role="doctor">{body}</div>
      </PaymentProvider>
    </ToastHost>
  );
}

function DoctorGate({ me }: { me: UserDoc }) {
  const d = useDoc<DoctorDoc>(`doctors/${me.id}`);
  if (d === undefined) return <Splash label="CareLoop Pro" />;
  if (d === null) return <DoctorSetup me={me} />;
  if (d.status !== 'approved') return <Pending me={me} d={d} />;
  return <Practice me={me} d={d} />;
}

function Practice({ me, d }: { me: UserDoc; d: DoctorDoc }) {
  const uid = me.id;
  const appts = useQuery<ApptDoc>(`dappts-${uid}`, 'appointments', where('doctorId', '==', uid));
  const open = useQuery<InstantRequest>(d.online ? `req-${d.region}` : null, 'instantRequests', where('region', '==', d.region), where('status', '==', 'open'));
  const payouts = useQuery<PayoutDoc>(`payouts-${uid}`, 'payouts', where('doctorId', '==', uid));
  const rawInbox = useGroupQuery<MessageDoc>(`dinbox-${uid}`, 'messages', where('to', '==', uid));
  const inbox = useMemo(() => [...(rawInbox ?? [])].sort((a, b) => b.t - a.t), [rawInbox]);
  // Requests older than 30 minutes are refunded to the patient, so they're not shown.
  const requests = useMemo(() => (open ?? []).filter((r) => Date.now() - r.createdAt < 30 * 60000).sort((a, b) => a.createdAt - b.createdAt), [open]);
  const ctx = useMemo(() => ({ uid, me, doc: d, appts, requests, payouts, inbox }), [uid, me, d, appts, requests, payouts, inbox]);
  const nav = useNav('today');

  const back = useRef<() => boolean>(() => false);
  back.current = () => {
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
  const waiting = (appts ?? []).filter((a) => a.status === 'waiting').length + requests.length + inbox.filter((m, i) => m.t > lastRead(m.apptId) && inbox.findIndex((x) => x.apptId === m.apptId) === i).length;

  return (
    <Ctx.Provider value={ctx}>
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
    </Ctx.Provider>
  );
}
