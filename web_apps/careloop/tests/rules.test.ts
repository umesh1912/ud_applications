// Security rules tests. Run with the Firestore emulator up: npm run test:rules
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, collectionGroup, getDocs, query, where } from 'firebase/firestore';

let env: RulesTestEnvironment;

const patient = { role: 'patient', name: 'Pat', region: 'IN' };
const doctorUser = { role: 'doctor', name: 'Dr. Doc', region: 'IN' };
const doctorProfile = (status: string) => ({ uid: 'doc', name: 'Dr. Doc', region: 'IN', status, ratingSum: 0, ratingCount: 0, feeVideo: 500 });
const appt = { patientId: 'pat', doctorId: 'doc', status: 'booked', t: 1, fee: 500 };

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-careloop-rules',
    firestore: { rules: readFileSync('firebase/firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (c) => {
    const d = c.firestore();
    await setDoc(doc(d, 'users/pat'), patient);
    await setDoc(doc(d, 'users/pat2'), { ...patient, name: 'Other' });
    await setDoc(doc(d, 'users/doc'), doctorUser);
    await setDoc(doc(d, 'users/admin'), { role: 'admin', name: 'Admin', region: 'IN' });
    await setDoc(doc(d, 'doctors/doc'), doctorProfile('approved'));
    await setDoc(doc(d, 'doctors/pending'), { ...doctorProfile('pending'), uid: 'pending' });
    await setDoc(doc(d, 'appointments/a1'), appt);
  });
});

const as = (uid: string) => env.authenticatedContext(uid).firestore();

describe('accounts', () => {
  it('lets people create their own patient or doctor profile only', async () => {
    await assertSucceeds(setDoc(doc(as('new'), 'users/new'), { role: 'patient', name: 'N', region: 'US' }));
    await assertFails(setDoc(doc(as('new2'), 'users/new2'), { role: 'admin', name: 'N', region: 'US' }));
    await assertFails(setDoc(doc(as('new3'), 'users/someoneelse'), { role: 'patient', name: 'N', region: 'US' }));
  });
  it('never lets a user change their role', async () => {
    await assertFails(updateDoc(doc(as('pat'), 'users/pat'), { role: 'admin' }));
    await assertSucceeds(updateDoc(doc(as('pat'), 'users/pat'), { name: 'New name' }));
  });
  it('keeps profiles private', async () => {
    await assertFails(getDoc(doc(as('pat2'), 'users/pat')));
    await assertSucceeds(getDoc(doc(as('admin'), 'users/pat')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/pat')));
  });
});

describe('doctor approval', () => {
  it('new doctors start pending and cannot approve themselves', async () => {
    await assertFails(setDoc(doc(as('d2'), 'doctors/d2'), { ...doctorProfile('approved'), uid: 'd2' }));
    await assertSucceeds(setDoc(doc(as('d3'), 'doctors/d3'), { ...doctorProfile('pending'), uid: 'd3' }));
    await assertFails(updateDoc(doc(as('pending'), 'doctors/pending'), { status: 'approved' }));
  });
  it('rejected doctors can resubmit for review but not approve themselves', async () => {
    await env.withSecurityRulesDisabled((c) => updateDoc(doc(c.firestore(), 'doctors/pending'), { status: 'rejected' }));
    await assertFails(updateDoc(doc(as('pending'), 'doctors/pending'), { status: 'approved' }));
    await assertSucceeds(updateDoc(doc(as('pending'), 'doctors/pending'), { status: 'pending', licenseNo: 'KMC 1' }));
  });
  it('only admins approve', async () => {
    await assertFails(updateDoc(doc(as('doc'), 'doctors/pending'), { status: 'approved' }));
    await assertSucceeds(updateDoc(doc(as('admin'), 'doctors/pending'), { status: 'approved', reviewedAt: 1 }));
  });
  it('patients only see approved doctors', async () => {
    await assertSucceeds(getDoc(doc(as('pat'), 'doctors/doc')));
    await assertFails(getDoc(doc(as('pat'), 'doctors/pending')));
    await assertSucceeds(getDocs(query(collection(as('pat'), 'doctors'), where('status', '==', 'approved'), where('region', '==', 'IN'))));
  });
  it('ratings move by one review of 1–5 stars', async () => {
    await assertSucceeds(updateDoc(doc(as('pat'), 'doctors/doc'), { ratingSum: 5, ratingCount: 1 }));
    await assertFails(updateDoc(doc(as('pat'), 'doctors/doc'), { ratingSum: 105, ratingCount: 2 }));
  });
});

describe('appointments', () => {
  it('are visible only to their patient and doctor', async () => {
    await assertSucceeds(getDoc(doc(as('pat'), 'appointments/a1')));
    await assertSucceeds(getDoc(doc(as('doc'), 'appointments/a1')));
    await assertFails(getDoc(doc(as('pat2'), 'appointments/a1')));
    await assertFails(getDocs(collection(as('pat2'), 'appointments')));
  });
  it('patients book for themselves only', async () => {
    await assertSucceeds(setDoc(doc(as('pat'), 'appointments/a2'), { ...appt }));
    await assertFails(setDoc(doc(as('pat2'), 'appointments/a3'), { ...appt }));
  });
  it('patients cannot write a prescription or mark a visit completed', async () => {
    await assertFails(updateDoc(doc(as('pat'), 'appointments/a1'), { rx: { diagnosis: 'x' } }));
    await assertFails(updateDoc(doc(as('pat'), 'appointments/a1'), { status: 'completed' }));
    await assertSucceeds(updateDoc(doc(as('pat'), 'appointments/a1'), { status: 'cancelled' }));
  });
  it('doctors write the prescription', async () => {
    await assertSucceeds(updateDoc(doc(as('doc'), 'appointments/a1'), { status: 'completed', rx: { diagnosis: 'Viral fever' } }));
    await assertFails(updateDoc(doc(as('doc'), 'appointments/a1'), { fee: 1 }));
  });
  it('chat is limited to the two people on the visit', async () => {
    await assertSucceeds(setDoc(doc(as('pat'), 'appointments/a1/messages/m1'), { from: 'pat', to: 'doc', text: 'hi' }));
    await assertFails(setDoc(doc(as('pat2'), 'appointments/a1/messages/m2'), { from: 'pat2', to: 'doc', text: 'hi' }));
    await assertFails(setDoc(doc(as('pat'), 'appointments/a1/messages/m3'), { from: 'doc', to: 'pat', text: 'spoof' }));
    await assertFails(setDoc(doc(as('pat'), 'appointments/a1/messages/m4'), { from: 'pat', to: 'pat2', text: 'misdirected' }));
  });
  it('inbox shows only messages to or from me', async () => {
    await env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), 'appointments/a1/messages/x'), { from: 'pat', to: 'doc', text: 'hi' }));
    await assertSucceeds(getDocs(query(collectionGroup(as('doc'), 'messages'), where('to', '==', 'doc'))));
    await assertFails(getDocs(query(collectionGroup(as('pat2'), 'messages'), where('to', '==', 'doc'))));
  });
});

describe('slots', () => {
  it('cannot be double-booked', async () => {
    const slot = { doctorId: 'doc', patientId: 'pat', t: 100, apptId: 'a1' };
    await assertSucceeds(setDoc(doc(as('pat'), 'slots/doc_100'), slot));
    await assertFails(setDoc(doc(as('pat2'), 'slots/doc_100'), { ...slot, patientId: 'pat2' }));
    await assertFails(deleteDoc(doc(as('pat2'), 'slots/doc_100')));
    await assertSucceeds(deleteDoc(doc(as('pat'), 'slots/doc_100')));
  });
});

describe('instant consults', () => {
  it('the first approved doctor to accept wins', async () => {
    await assertSucceeds(setDoc(doc(as('pat'), 'instantRequests/r1'), { patientId: 'pat', status: 'open', region: 'IN' }));
    await assertFails(updateDoc(doc(as('pending'), 'instantRequests/r1'), { status: 'accepted', doctorId: 'pending' }));
    await assertSucceeds(updateDoc(doc(as('doc'), 'instantRequests/r1'), { status: 'accepted', doctorId: 'doc', apptId: 'x' }));
    await assertFails(updateDoc(doc(as('doc'), 'instantRequests/r1'), { status: 'accepted', doctorId: 'doc', apptId: 'y' }));
  });
});

describe('patient records', () => {
  it('are private to the patient', async () => {
    await assertSucceeds(setDoc(doc(as('pat'), 'reports/r1'), { patientId: 'pat', name: 'CBC' }));
    await assertFails(getDoc(doc(as('doc'), 'reports/r1')));
    await assertFails(setDoc(doc(as('pat2'), 'orders/o1'), { patientId: 'pat', amount: 1 }));
  });
});
