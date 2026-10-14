import { createContext, useContext } from 'react';
import { doc, updateDoc } from 'firebase/firestore';
import { REGIONS, type Region } from '../data/region';
import { db } from '../lib/firebase';
import type { ApptDoc, ApptStatus, DoctorDoc, MessageDoc, OrderDoc, PatientInfo, ReportDoc, UserDoc } from '../lib/model';

export interface PatientCtx {
  uid: string;
  me: UserDoc;
  region: Region;
  /** Approved doctors in my country (live). undefined while loading. */
  doctors: DoctorDoc[] | undefined;
  doctor: (id: string) => DoctorDoc | undefined;
  appts: ApptDoc[] | undefined;
  reports: ReportDoc[] | undefined;
  orders: OrderDoc[] | undefined;
  /** Messages from my doctors, newest first. */
  inbox: MessageDoc[];
}

export const Ctx = createContext<PatientCtx>(null as unknown as PatientCtx);
export const useP = () => useContext(Ctx);

export const updateMe = (uid: string, patch: Partial<UserDoc>) => updateDoc(doc(db, 'users', uid), patch as Record<string, unknown>);

/** A visit counts as missed if nobody started it within 45 minutes. */
export function statusOf(a: ApptDoc, now: number): ApptStatus | 'missed' {
  if ((a.status === 'booked' || a.status === 'waiting') && now > a.t + 45 * 60000) return 'missed';
  return a.status;
}
export const isUpcoming = (a: ApptDoc, now: number) => ['booked', 'waiting', 'in-consult'].includes(statusOf(a, now));

/** What the doctor sees about the patient when they book. */
export function patientInfo(me: UserDoc, member: string): PatientInfo {
  if (member !== me.name) {
    const f = me.family?.find((x) => x.name === member);
    return { age: f?.age };
  }
  const last = (xs?: number[]) => (xs && xs.length ? xs[xs.length - 1] : undefined);
  return { age: me.age, sex: me.sex, allergies: me.allergies, conditions: me.conditions, bp: last(me.vitals?.bp), sugar: last(me.vitals?.sugar), weight: last(me.vitals?.weight) };
}

/** Plus discount and booking fee for a consult fee. */
export function priceFor(me: UserDoc, region: Region, fee: number) {
  const r = REGIONS[region];
  const plus = !!me.plus && me.plus.until > Date.now();
  const discount = plus ? Math.round(fee * 0.2 * 100) / 100 : 0;
  const bookingFee = plus ? 0 : r.bookingFee;
  const tax = region === 'IN' ? Math.round(bookingFee * 0.18) : 0;
  return { fee, discount, bookingFee, tax, plus, total: Math.round((fee - discount + bookingFee + tax) * 100) / 100 };
}

export const hasPlus = (me: UserDoc) => !!me.plus && me.plus.until > Date.now();

/** Flat price for an instant consult with the next available doctor. */
export const INSTANT_FEE: Record<Region, number> = { IN: 399, US: 49 };
