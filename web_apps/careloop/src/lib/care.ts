import { addDoc, collection, doc, increment, runTransaction, serverTimestamp, updateDoc, writeBatch } from 'firebase/firestore';
import { Browser } from '@capacitor/browser';
import { Capacitor } from '@capacitor/core';
import { DAY, startOfToday } from '../data/catalog';
import { db } from './firebase';
import { randomId } from './db';
import type { ApptDoc, DoctorDoc, SlotDoc } from './model';

// ---------------------------------------------------------------- slots

const SESSIONS = { morning: [9, 13], afternoon: [14, 17], evening: [17, 20] } as const;

/** Bookable times on `day` from the doctor's availability, minus booked slots, days off and the past. */
export function slotsFor(d: DoctorDoc, day: number, taken: SlotDoc[]) {
  const date = new Date(day);
  if (!d.availability.days[date.getDay()] || d.timeOff?.includes(day)) return [];
  const step = d.availability.slot * 60000;
  const takenSet = new Set(taken.map((s) => s.t));
  const soon = Date.now() + 20 * 60000;
  const out: { t: number; taken: boolean; session: keyof typeof SESSIONS }[] = [];
  (Object.keys(SESSIONS) as (keyof typeof SESSIONS)[]).forEach((k) => {
    if (!d.availability[k]) return;
    const [from, to] = SESSIONS[k];
    for (let t = day + from * 3600000; t < day + to * 3600000; t += step) {
      if (t < soon) continue;
      out.push({ t, taken: takenSet.has(t), session: k });
    }
  });
  return out;
}

/** "Available in 20 min", "Today, 5:30 PM", "Tomorrow, 9 AM" or "Not taking bookings". */
export function nextFreeLabel(d: DoctorDoc, takenByDay: (day: number) => SlotDoc[] = () => []) {
  if (d.online) return { label: 'Online now', soon: true };
  for (let i = 0; i < 7; i++) {
    const day = startOfToday() + i * DAY;
    const free = slotsFor(d, day, takenByDay(day)).find((s) => !s.taken);
    if (free) {
      const mins = Math.round((free.t - Date.now()) / 60000);
      const time = new Date(free.t).toLocaleTimeString('en', { hour: 'numeric', minute: '2-digit' });
      if (mins < 90) return { label: `Available in ${mins} min`, soon: true };
      return { label: `${i === 0 ? 'Today' : i === 1 ? 'Tomorrow' : new Date(day).toLocaleDateString('en', { weekday: 'short' })}, ${time}`, soon: false };
    }
  }
  return { label: 'Not taking bookings this week', soon: false };
}

// ---------------------------------------------------------------- booking

export class SlotTakenError extends Error {
  constructor() { super('Someone just booked this time. Please pick another slot.'); }
}

/** Books atomically: the slot document can exist only once, so two people can't get the same time. */
export async function bookAppointment(a: Omit<ApptDoc, 'id' | 'createdAt' | 'status' | 'room' | 'day'>) {
  const day = new Date(a.t).setHours(0, 0, 0, 0);
  const slotRef = doc(db, 'slots', `${a.doctorId}_${a.t}`);
  const apptRef = doc(collection(db, 'appointments'));
  await runTransaction(db, async (tx) => {
    if ((await tx.get(slotRef)).exists()) throw new SlotTakenError();
    tx.set(slotRef, { doctorId: a.doctorId, patientId: a.patientId, t: a.t, day, apptId: apptRef.id });
    tx.set(apptRef, { ...a, day, status: 'booked', room: `careloop-${randomId(12)}`, createdAt: Date.now() });
  });
  return apptRef.id;
}

export async function cancelAppointment(a: ApptDoc, by: 'patient' | 'doctor') {
  const b = writeBatch(db);
  b.update(doc(db, 'appointments', a.id), by === 'patient'
    ? { status: 'cancelled', updatedAt: Date.now(), payment: { ...a.payment, status: 'refund-pending' } }
    : { status: 'cancelled', updatedAt: Date.now() });
  if (!a.instant) b.delete(doc(db, 'slots', `${a.doctorId}_${a.t}`));
  await b.commit();
}

export async function rateVisit(a: ApptDoc, rating: number, review: string) {
  const b = writeBatch(db);
  b.update(doc(db, 'appointments', a.id), { rating, review, updatedAt: Date.now() });
  b.set(doc(db, 'reviews', a.id), { doctorId: a.doctorId, patientId: a.patientId, name: a.patientName.split(' ')[0] + ' ' + (a.patientName.split(' ')[1]?.[0] ?? '') + '.', rating, text: review, t: Date.now() });
  b.update(doc(db, 'doctors', a.doctorId), { ratingSum: increment(rating), ratingCount: increment(1) });
  await b.commit();
}

export async function sendMessage(a: Pick<ApptDoc, 'id' | 'patientId' | 'doctorId' | 'member' | 'doctorName'>, from: string, text: string) {
  const toDoctor = from === a.patientId;
  await addDoc(collection(db, 'appointments', a.id, 'messages'), {
    from, to: toDoctor ? a.doctorId : a.patientId, apptId: a.id, text: text.trim(), t: Date.now(), at: serverTimestamp(),
    // Shown in the recipient's inbox without reading the visit.
    fromName: toDoctor ? a.member : a.doctorName,
  });
}

const READ_KEY = 'careloop-read';
/** When this device last opened each visit's chat (for unread badges). */
export function lastRead(apptId: string): number {
  try { return JSON.parse(localStorage.getItem(READ_KEY) || '{}')[apptId] ?? 0; } catch { return 0; }
}
export function markRead(apptId: string) {
  try { const m = JSON.parse(localStorage.getItem(READ_KEY) || '{}'); m[apptId] = Date.now(); localStorage.setItem(READ_KEY, JSON.stringify(m)); } catch { /* storage unavailable */ }
}

export const markJoined = (a: ApptDoc) =>
  a.status === 'booked' ? updateDoc(doc(db, 'appointments', a.id), { status: 'waiting', joinedAt: Date.now(), updatedAt: Date.now() }) : Promise.resolve();

// ---------------------------------------------------------------- video

/**
 * Opens the visit's private Jitsi Meet room. On Android it opens in a Chrome Custom Tab (camera and
 * microphone work there; Jitsi limits embedded calls, so the room isn't embedded in the app).
 */
export async function openVideoRoom(room: string, displayName: string) {
  const url = `https://meet.jit.si/${room}#userInfo.displayName=${encodeURIComponent(JSON.stringify(displayName))}&config.prejoinConfig.enabled=false&config.disableDeepLinking=true`;
  if (Capacitor.isNativePlatform()) await Browser.open({ url, presentationStyle: 'fullscreen', toolbarColor: '#0b1220' });
  else window.open(url, '_blank', 'noopener');
}

