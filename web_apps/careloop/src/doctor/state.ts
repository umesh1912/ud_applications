import { createContext, useContext } from 'react';
import { DAY, doctorsFor, startOfToday, type Doctor } from '../data/catalog';
import { REGIONS, type Region } from '../data/region';
import type { Rx } from '../patient/state';

export interface Patient {
  id: string;
  name: string;
  age: number;
  sex: 'M' | 'F';
  hue: number;
  conditions: string[];
  allergies: string;
  vitals: { bp: string; temp: string; spo2: string; weight: string };
  visits: { t: number; reason: string; diagnosis: string }[];
}

export interface QueueItem {
  id: string;
  patientId: string;
  t: number;
  mode: 'video' | 'clinic';
  reason: string;
  fee: number;
  status: 'upcoming' | 'waiting' | 'in-consult' | 'done' | 'no-show';
  rx?: Rx;
  instant?: boolean;
}

export interface DoctorState {
  region: Region;
  stage: 'welcome' | 'app';
  online: boolean;
  plan: 'starter' | 'pro' | 'clinic';
  fees: { video: number; clinic: number };
  availability: { days: boolean[]; morning: boolean; afternoon: boolean; evening: boolean; slot: 15 | 20 | 30 };
  patients: Patient[];
  queue: QueueItem[];
  /** Gross consult earnings for the previous 6 days (today is computed from the queue). */
  week: number[];
  payouts: { t: number; amount: number; status: 'Paid' | 'Processing' }[];
  timeOff: string[];
}

const NAMES: Record<Region, [string, number, 'M' | 'F'][]> = {
  IN: [['Rahul Verma', 34, 'M'], ['Sneha Kulkarni', 28, 'F'], ['Mohammed Irfan', 45, 'M'], ['Lakshmi Narayan', 61, 'F'], ['Aditi Sharma', 22, 'F'], ['Vikas Gupta', 39, 'M'], ['Pooja Reddy', 31, 'F'], ['Arjun Pillai', 8, 'M']],
  US: [['Alex Morgan', 34, 'M'], ['Hannah Brooks', 28, 'F'], ['Marcus Reed', 45, 'M'], ['Linda Alvarez', 61, 'F'], ['Olivia Bennett', 22, 'F'], ['Kevin O’Brien', 39, 'M'], ['Grace Liu', 31, 'F'], ['Ethan Clarke', 8, 'M']],
};

const CLINICAL: { reason: string; conditions: string[]; allergies: string; vitals: Patient['vitals']; last: string }[] = [
  { reason: 'Fever and cough for 3 days', conditions: [], allergies: 'Penicillin', vitals: { bp: '122/78', temp: '100.4°F', spo2: '97%', weight: '76 kg' }, last: 'Viral fever' },
  { reason: 'Recurring migraines', conditions: ['Migraine'], allergies: 'None', vitals: { bp: '110/70', temp: '98.4°F', spo2: '99%', weight: '58 kg' }, last: 'Tension headache' },
  { reason: 'Blood pressure review', conditions: ['Hypertension'], allergies: 'None', vitals: { bp: '142/92', temp: '98.2°F', spo2: '98%', weight: '84 kg' }, last: 'Stage 1 hypertension' },
  { reason: 'Sugar levels high this week', conditions: ['Type 2 diabetes', 'Hypothyroidism'], allergies: 'Sulfa drugs', vitals: { bp: '134/84', temp: '98.1°F', spo2: '97%', weight: '69 kg' }, last: 'Diabetes follow-up' },
  { reason: 'Itchy rash on arms', conditions: [], allergies: 'None', vitals: { bp: '108/68', temp: '98.6°F', spo2: '99%', weight: '54 kg' }, last: 'Contact dermatitis' },
  { reason: 'Lower back pain after lifting', conditions: [], allergies: 'Ibuprofen', vitals: { bp: '126/82', temp: '98.4°F', spo2: '98%', weight: '81 kg' }, last: 'Muscle strain' },
  { reason: 'Thyroid report review', conditions: ['Hypothyroidism'], allergies: 'None', vitals: { bp: '116/74', temp: '98.3°F', spo2: '99%', weight: '62 kg' }, last: 'Thyroid dose adjusted' },
  { reason: 'Cough at night (with parent)', conditions: ['Asthma'], allergies: 'Dust', vitals: { bp: '—', temp: '99.1°F', spo2: '96%', weight: '24 kg' }, last: 'Mild asthma flare' },
];

export function seed(region: Region): DoctorState {
  const today = startOfToday();
  const now = Date.now();
  const me = doctorsFor(region)[0];
  const patients: Patient[] = NAMES[region].map(([name, age, sex], i) => ({
    id: `p${i}`, name, age, sex, hue: (i * 47 + 190) % 360,
    conditions: CLINICAL[i].conditions, allergies: CLINICAL[i].allergies, vitals: CLINICAL[i].vitals,
    visits: [
      { t: today - (12 + i * 9) * DAY, reason: CLINICAL[i].reason, diagnosis: CLINICAL[i].last },
      ...(i % 3 === 0 ? [{ t: today - (70 + i * 5) * DAY, reason: 'Annual check-up', diagnosis: 'Healthy, routine labs' }] : []),
    ],
  }));
  // Today's list around the current time: two seen, one checked in now, the rest later.
  const offsets = [-150, -95, 4, 35, 70, 110, 160, 210];
  const queue: QueueItem[] = offsets.map((m, i) => {
    const mode = i % 3 === 1 ? 'clinic' : 'video';
    return {
      id: `q${i}`, patientId: `p${i}`, t: Math.round((now + m * 60000) / 300000) * 300000, mode,
      reason: CLINICAL[i].reason, fee: mode === 'video' ? me.feeVideo : me.feeClinic,
      status: m < 0 ? 'done' : i === 2 ? 'waiting' : 'upcoming',
    };
  });
  const IN = region === 'IN';
  return {
    region,
    stage: 'welcome',
    online: true,
    plan: 'starter',
    fees: { video: me.feeVideo, clinic: me.feeClinic },
    availability: { days: [false, true, true, true, true, true, true], morning: true, afternoon: false, evening: true, slot: 15 },
    patients,
    queue,
    week: IN ? [8200, 11400, 9600, 12800, 10300, 6400] : [1180, 1540, 1320, 1710, 1460, 890],
    payouts: [
      { t: today - 2 * DAY, amount: IN ? 41200 : 5860, status: 'Paid' },
      { t: today - 9 * DAY, amount: IN ? 38650 : 5420, status: 'Paid' },
      { t: today - 16 * DAY, amount: IN ? 44100 : 6010, status: 'Paid' },
    ],
    timeOff: [],
  };
}

export const commissionOf = (s: DoctorState) => REGIONS[s.region].doctorPlans.find((p) => p.id === s.plan)!.commission;

export function todayGross(s: DoctorState) {
  return s.queue.filter((q) => q.status === 'done').reduce((a, q) => a + q.fee, 0);
}

export interface DoctorCtx {
  s: DoctorState;
  set: (fn: (s: DoctorState) => DoctorState) => void;
  me: Doctor;
  patient: (id: string) => Patient;
}

export const Ctx = createContext<DoctorCtx>(null as unknown as DoctorCtx);
export const useD = () => useContext(Ctx);
