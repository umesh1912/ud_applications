import { createContext, useContext } from 'react';
import { DAY, doctorsFor, startOfToday, type Doctor } from '../data/catalog';
import { REGIONS, type Region } from '../data/region';

export interface RxMed { name: string; dose: string; duration: string; note?: string }
export interface Rx { diagnosis: string; meds: RxMed[]; tests: string[]; advice: string; followUp?: string }

export interface Appt {
  id: string;
  doctorId: string;
  member: string;
  mode: 'video' | 'clinic';
  t: number;
  reason: string;
  paid: number;
  status: 'upcoming' | 'completed' | 'cancelled';
  rx?: Rx;
  rated?: number;
}

export interface ReportItem { name: string; value: string; unit: string; range: string; flag: 'normal' | 'high' | 'low' }
export interface Report { id: string; name: string; t: number; lab: string; status: 'ready' | 'processing'; items: ReportItem[] }
export interface Order { id: string; kind: 'medicine' | 'lab' | 'plus'; title: string; amount: number; t: number; status: string }
export interface Member { name: string; relation: string; age: number }

export interface PatientState {
  region: Region;
  stage: 'welcome' | 'region' | 'phone' | 'otp' | 'profile' | 'app';
  user: { name: string; phone: string; age: number; sex: string; blood: string; allergies: string };
  family: Member[];
  appts: Appt[];
  reports: Report[];
  orders: Order[];
  plus: null | { plan: 'monthly' | 'yearly'; since: number };
  vitals: { bp: number[]; sugar: number[]; weight: number[] };
  reminders: boolean;
}

export const VIRAL_RX: Rx = {
  diagnosis: 'Acute viral fever with upper respiratory infection',
  meds: [
    { name: 'Paracetamol 650 mg', dose: '1-1-1', duration: '3 days', note: 'After food, only if fever above 100°F' },
    { name: 'Cetirizine 10 mg', dose: '0-0-1', duration: '5 days', note: 'At bedtime' },
    { name: 'ORS sachet', dose: '1-1-1', duration: '3 days', note: 'Dissolve in 1 litre of water' },
  ],
  tests: ['CBC', 'Dengue NS1'],
  advice: 'Rest, drink 3 litres of fluids a day, steam inhalation twice daily. Come back if fever lasts beyond 3 days or you notice rashes or bleeding.',
  followUp: 'In 3 days',
};

const SKIN_RX: Rx = {
  diagnosis: 'Mild acne vulgaris',
  meds: [
    { name: 'Adapalene 0.1% gel', dose: '0-0-1', duration: '1 month', note: 'Pea-sized amount on dry skin at night' },
    { name: 'Benzoyl peroxide 2.5% wash', dose: '1-0-1', duration: '1 month' },
  ],
  tests: [],
  advice: 'Use a gentle, non-comedogenic moisturiser and SPF 30+ every morning. Avoid picking. Review photos in 4 weeks.',
  followUp: 'In 4 weeks',
};

export function seed(region: Region, name = region === 'IN' ? 'Rahul Verma' : 'Alex Morgan'): PatientState {
  const docs = doctorsFor(region);
  const now = Date.now();
  const today = startOfToday();
  const at = (dayOffset: number, hour: number) => today + dayOffset * DAY + hour * 3600000;
  const IN = region === 'IN';
  return {
    region,
    stage: 'welcome',
    user: { name, phone: REGIONS[region].samplePhone, age: 34, sex: 'Male', blood: 'B+', allergies: 'Penicillin' },
    family: IN
      ? [{ name: 'Priya Verma', relation: 'Spouse', age: 31 }, { name: 'Aarav Verma', relation: 'Son', age: 6 }, { name: 'Sunita Verma', relation: 'Mother', age: 62 }]
      : [{ name: 'Jamie Morgan', relation: 'Spouse', age: 33 }, { name: 'Lily Morgan', relation: 'Daughter', age: 5 }],
    appts: [
      // Starts in ~10 minutes so "Join visit" is live straight away in the demo.
      { id: 'a-up', doctorId: docs[0].id, member: name, mode: 'video', t: Math.ceil((now + 10 * 60000) / 60000) * 60000, reason: 'Follow-up: fever and cough', paid: docs[0].feeVideo, status: 'upcoming' },
      { id: 'a-up2', doctorId: docs[3].id, member: IN ? 'Aarav Verma' : 'Lily Morgan', mode: 'clinic', t: at(3, 10.5), reason: 'Routine check-up and vaccines', paid: docs[3].feeClinic, status: 'upcoming' },
      { id: 'a-p1', doctorId: docs[0].id, member: name, mode: 'video', t: at(-4, 19), reason: 'Fever, sore throat, body ache', paid: docs[0].feeVideo, status: 'completed', rx: VIRAL_RX, rated: 5 },
      { id: 'a-p2', doctorId: docs[2].id, member: name, mode: 'video', t: at(-38, 18.5), reason: 'Acne on forehead and cheeks', paid: docs[2].feeVideo, status: 'completed', rx: SKIN_RX },
    ],
    reports: [
      {
        id: 'r1', name: 'Complete blood count (CBC)', t: at(-3, 8), lab: IN ? 'CareLoop Labs, Indiranagar' : 'Quest Diagnostics', status: 'ready',
        items: [
          { name: 'Haemoglobin', value: '13.9', unit: 'g/dL', range: '13.0–17.0', flag: 'normal' },
          { name: 'WBC count', value: '11.8', unit: '×10³/µL', range: '4.0–10.0', flag: 'high' },
          { name: 'Platelets', value: '1.62', unit: 'lakh/µL', range: '1.5–4.1', flag: 'normal' },
          { name: 'Neutrophils', value: '74', unit: '%', range: '40–70', flag: 'high' },
        ],
      },
      {
        id: 'r2', name: 'Lipid profile', t: at(-60, 8), lab: IN ? 'CareLoop Labs, Indiranagar' : 'Labcorp', status: 'ready',
        items: [
          { name: 'Total cholesterol', value: '212', unit: 'mg/dL', range: '< 200', flag: 'high' },
          { name: 'LDL', value: '128', unit: 'mg/dL', range: '< 100', flag: 'high' },
          { name: 'HDL', value: '46', unit: 'mg/dL', range: '> 40', flag: 'normal' },
          { name: 'Triglycerides', value: '148', unit: 'mg/dL', range: '< 150', flag: 'normal' },
        ],
      },
    ],
    orders: [
      { id: 'o1', kind: 'medicine', title: '3 medicines from Dr. ' + docs[0].name.replace('Dr. ', '').split(' ')[0] + '’s prescription', amount: IN ? 214 : 24, t: at(-4, 20), status: 'Delivered' },
    ],
    plus: null,
    vitals: { bp: [128, 126, 131, 124, 122, 121, 119], sugar: [112, 108, 118, 104, 101, 99, 102], weight: [78.4, 78.1, 77.6, 77.9, 77.2, 76.8, 76.5] },
    reminders: true,
  };
}

export const statusOf = (a: Appt, now: number) =>
  a.status === 'upcoming' && now > a.t + 45 * 60000 ? 'missed' : a.status;

/** Consult price after Plus discount, plus the booking fee. */
export function priceFor(s: PatientState, fee: number) {
  const r = REGIONS[s.region];
  const discount = s.plus ? Math.round(fee * 0.2 * 100) / 100 : 0;
  const bookingFee = s.plus ? 0 : r.bookingFee;
  const tax = s.region === 'IN' ? Math.round(bookingFee * 0.18) : 0;
  return { fee, discount, bookingFee, tax, total: Math.round((fee - discount + bookingFee + tax) * 100) / 100 };
}

export interface PatientCtx {
  s: PatientState;
  set: (fn: (s: PatientState) => PatientState) => void;
  docs: Doctor[];
  doctor: (id: string) => Doctor;
}

export const Ctx = createContext<PatientCtx>(null as unknown as PatientCtx);
export const useP = () => useContext(Ctx);
