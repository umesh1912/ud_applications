import { createContext, useContext } from 'react';
import { doc, updateDoc } from 'firebase/firestore';
import { REGIONS } from '../data/region';
import { db } from '../lib/firebase';
import type { ApptDoc, DoctorDoc, InstantRequest, MessageDoc, PayoutDoc, UserDoc } from '../lib/model';

export interface DoctorCtx {
  uid: string;
  me: UserDoc;
  doc: DoctorDoc;
  appts: ApptDoc[] | undefined;
  requests: InstantRequest[];
  payouts: PayoutDoc[] | undefined;
  /** Messages from patients, newest first. */
  inbox: MessageDoc[];
}

export const Ctx = createContext<DoctorCtx>(null as unknown as DoctorCtx);
export const useD = () => useContext(Ctx);

export const updateDoctor = (uid: string, patch: Partial<DoctorDoc>) => updateDoc(doc(db, 'doctors', uid), patch as Record<string, unknown>);

export const commissionOf = (d: DoctorDoc) => REGIONS[d.region].doctorPlans.find((p) => p.id === d.plan)!.commission;

/** Completed consults: gross, platform fee, net, and what's left after payouts already requested. */
export function earnings(d: DoctorDoc, appts: ApptDoc[], payouts: PayoutDoc[]) {
  const done = appts.filter((a) => a.status === 'completed');
  const gross = done.reduce((s, a) => s + a.fee, 0);
  const rate = commissionOf(d);
  const net = Math.round(gross * (1 - rate) * 100) / 100;
  const paidOut = payouts.reduce((s, p) => s + p.amount, 0);
  return { done, gross, rate, fee: Math.round(gross * rate * 100) / 100, net, available: Math.max(0, Math.round((net - paidOut) * 100) / 100) };
}

/** Patients seen or booked, newest first, with their latest snapshot and visit history. */
export function patientsOf(appts: ApptDoc[]) {
  const map = new Map<string, { key: string; name: string; patientId: string; latest: ApptDoc; visits: ApptDoc[] }>();
  [...appts].sort((a, b) => b.t - a.t).forEach((a) => {
    const key = `${a.patientId}:${a.member}`;
    const p = map.get(key);
    if (p) p.visits.push(a);
    else map.set(key, { key, name: a.member, patientId: a.patientId, latest: a, visits: [a] });
  });
  return [...map.values()];
}
