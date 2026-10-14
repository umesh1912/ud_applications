import type { Region } from '../data/region';

/** Firestore documents. See firebase/firestore.rules for who can read and write each. */

export type Role = 'patient' | 'doctor' | 'admin';

export interface Member { name: string; relation: string; age: number }

/** users/{uid} */
export interface UserDoc {
  id: string;
  role: Role;
  name: string;
  email?: string;
  phone?: string;
  region: Region;
  createdAt: number;
  // Patient health profile (filled after signup).
  age?: number;
  sex?: string;
  blood?: string;
  allergies?: string;
  conditions?: string[];
  family?: Member[];
  plus?: { plan: 'monthly' | 'yearly'; since: number; until: number; paymentRef: string } | null;
  vitals?: { bp: number[]; sugar: number[]; weight: number[] };
  reminders?: boolean;
}

export interface Availability { days: boolean[]; morning: boolean; afternoon: boolean; evening: boolean; slot: 15 | 20 | 30 }

/** doctors/{uid}: public directory profile once approved. */
export interface DoctorDoc {
  id: string;
  uid: string;
  name: string;
  specialty: string;
  degrees: string;
  years: number;
  languages: string[];
  clinic: string;
  area: string;
  region: Region;
  licenseNo: string;
  about: string;
  feeVideo: number;
  feeClinic: number;
  status: 'pending' | 'approved' | 'rejected';
  online: boolean;
  availability: Availability;
  timeOff: number[];
  plan: 'starter' | 'pro' | 'clinic';
  hue: number;
  ratingSum: number;
  ratingCount: number;
  createdAt: number;
  reviewedAt?: number;
}

export interface RxMed { name: string; dose: string; duration: string; note?: string }
export interface Rx { diagnosis: string; meds: RxMed[]; tests: string[]; advice: string; followUp?: string; signedAt: number }

export interface Payment { provider: 'razorpay' | 'stripe' | 'test' | 'insurance'; ref: string; method: string; amount: number; status: 'paid' | 'refund-pending' }

export interface PatientInfo { age?: number; sex?: string; allergies?: string; conditions?: string[]; bp?: number; sugar?: number; weight?: number }

export type ApptStatus = 'booked' | 'waiting' | 'in-consult' | 'completed' | 'cancelled';

/** appointments/{id} */
export interface ApptDoc {
  id: string;
  patientId: string;
  patientName: string;
  member: string;
  patientInfo: PatientInfo;
  doctorId: string;
  doctorName: string;
  doctorHue: number;
  specialty: string;
  region: Region;
  mode: 'video' | 'clinic';
  t: number;
  day: number;
  reason: string;
  fee: number;
  payment: Payment;
  status: ApptStatus;
  room: string;
  instant?: boolean;
  rx?: Rx;
  notes?: string;
  rating?: number;
  review?: string;
  createdAt: number;
  updatedAt?: number;
  joinedAt?: number;
  startedAt?: number;
  endedAt?: number;
}

export interface MessageDoc { id: string; from: string; to: string; apptId: string; fromName: string; text: string; t: number }

/** slots/{doctorId}_{t}: one per booked time, so a slot can't be taken twice. */
export interface SlotDoc { id: string; doctorId: string; patientId: string; t: number; day: number; apptId: string }

export interface InstantRequest {
  id: string;
  patientId: string;
  patientName: string;
  patientInfo: PatientInfo;
  concern: string;
  region: Region;
  fee: number;
  payment: Payment;
  status: 'open' | 'accepted' | 'cancelled';
  doctorId?: string;
  doctorName?: string;
  apptId?: string;
  createdAt: number;
  updatedAt?: number;
}

export interface ReportItem { name: string; value: string; unit: string; range: string; flag: 'normal' | 'high' | 'low' }
export interface ReportDoc { id: string; patientId: string; name: string; t: number; lab: string; status: 'ready' | 'processing'; items: ReportItem[]; image?: string; note?: string }

export interface OrderDoc {
  id: string;
  patientId: string;
  kind: 'medicine' | 'lab' | 'plus' | 'plan';
  title: string;
  items?: { name: string; qty: number; price: number }[];
  amount: number;
  t: number;
  scheduledFor?: number;
  address?: string;
  payment: Payment;
}

export interface PayoutDoc { id: string; doctorId: string; amount: number; t: number; status: 'requested' | 'paid' }

export const ratingOf = (d: Pick<DoctorDoc, 'ratingSum' | 'ratingCount'>) => (d.ratingCount ? d.ratingSum / d.ratingCount : 0);

export const DEFAULT_AVAILABILITY: Availability = { days: [false, true, true, true, true, true, true], morning: true, afternoon: false, evening: true, slot: 15 };
