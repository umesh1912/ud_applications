import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import {
  RecaptchaVerifier, createUserWithEmailAndPassword, onAuthStateChanged, sendEmailVerification, sendPasswordResetEmail,
  signInWithEmailAndPassword, signInWithPhoneNumber, signOut, updateProfile, type ConfirmationResult, type User,
} from 'firebase/auth';
import { doc, onSnapshot, setDoc } from 'firebase/firestore';
import type { Region } from '../data/region';
import { auth, db } from './firebase';
import type { Role, UserDoc } from './model';

interface AuthState {
  /** undefined while Firebase restores the session. */
  user: User | null | undefined;
  /** users/{uid}; undefined while loading, null if the account has no profile yet. */
  profile: UserDoc | null | undefined;
}

const Ctx = createContext<AuthState>({ user: undefined, profile: undefined });
export const useAuth = () => useContext(Ctx);

/** The signed-in person's account and profile, kept live. */
export function useMe() {
  const { user, profile } = useAuth();
  return { uid: user!.uid, user: user!, profile: profile! };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null | undefined>(undefined);
  const [profile, setProfile] = useState<UserDoc | null | undefined>(undefined);

  useEffect(() => onAuthStateChanged(auth, (u) => { setUser(u); if (!u) setProfile(null); }), []);

  useEffect(() => {
    if (!user) return;
    setProfile(undefined);
    return onSnapshot(doc(db, 'users', user.uid),
      (snap) => setProfile(snap.exists() ? ({ id: snap.id, ...snap.data() } as UserDoc) : null),
      () => setProfile(null));
  }, [user]);

  return <Ctx.Provider value={{ user, profile }}>{children}</Ctx.Provider>;
}

// ---------------------------------------------------------------- actions

export async function createProfile(uid: string, data: { role: Role; name: string; region: Region; email?: string; phone?: string }) {
  const base: Omit<UserDoc, 'id'> = { ...data, createdAt: Date.now() };
  const patientDefaults = data.role === 'patient'
    ? { family: [], plus: null, vitals: { bp: [], sugar: [], weight: [] }, reminders: true, conditions: [] }
    : {};
  await setDoc(doc(db, 'users', uid), { ...base, ...patientDefaults });
}

export async function signUpWithEmail(input: { role: Role; name: string; email: string; password: string; phone: string; region: Region }) {
  const cred = await createUserWithEmailAndPassword(auth, input.email.trim(), input.password);
  await updateProfile(cred.user, { displayName: input.name.trim() });
  await createProfile(cred.user.uid, { role: input.role, name: input.name.trim(), region: input.region, email: input.email.trim(), phone: input.phone.trim() });
  // Verification mail is best-effort; it doesn't block using the app.
  sendEmailVerification(cred.user).catch(() => undefined);
  return cred.user;
}

export const logIn = (email: string, password: string) => signInWithEmailAndPassword(auth, email.trim(), password);
export const resetPassword = (email: string) => sendPasswordResetEmail(auth, email.trim());
export const logOut = () => signOut(auth);

let verifier: RecaptchaVerifier | null = null;

/** Sends an SMS code. `containerId` is an element for the invisible reCAPTCHA. */
export async function sendPhoneCode(phoneE164: string, containerId: string): Promise<ConfirmationResult> {
  verifier?.clear();
  verifier = new RecaptchaVerifier(auth, containerId, { size: 'invisible' });
  return signInWithPhoneNumber(auth, phoneE164, verifier);
}
