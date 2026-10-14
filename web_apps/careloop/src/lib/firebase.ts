import { initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth, indexedDBLocalPersistence, initializeAuth } from 'firebase/auth';
import { connectFirestoreEmulator, initializeFirestore, persistentLocalCache, persistentMultipleTabManager } from 'firebase/firestore';
import { connectFunctionsEmulator, getFunctions } from 'firebase/functions';
import { Capacitor } from '@capacitor/core';
import { FIREBASE_CONFIG } from '../firebase-config';
import { ROLE } from './role';

/**
 * The Firebase project the apps talk to. Set your project's web config in src/firebase-config.ts.
 * `VITE_EMULATOR=1` (npm run dev:emulator) points everything at the local Firebase emulators instead.
 */
export const usingEmulator = import.meta.env.VITE_EMULATOR === '1' || FIREBASE_CONFIG.projectId.startsWith('demo-');

// Named per role so the patient and doctor apps keep separate sign-ins when both run in one browser.
export const app = initializeApp(usingEmulator ? { ...FIREBASE_CONFIG, apiKey: 'demo-key', projectId: 'demo-careloop', authDomain: 'demo-careloop.firebaseapp.com' } : FIREBASE_CONFIG, `careloop-${ROLE}`);

// In the Android WebView, the default popup/redirect resolver isn't needed and indexedDB keeps users signed in.
export const auth = Capacitor.isNativePlatform() ? initializeAuth(app, { persistence: indexedDBLocalPersistence }) : getAuth(app);

// Offline cache: screens open instantly from the last snapshot and writes queue while offline.
export const db = initializeFirestore(app, {
  localCache: usingEmulator ? undefined : persistentLocalCache({ tabManager: persistentMultipleTabManager() }),
  ignoreUndefinedProperties: true,
});

export const functions = getFunctions(app, FIREBASE_CONFIG.functionsRegion ?? 'us-central1');

if (usingEmulator) {
  const host = import.meta.env.VITE_EMULATOR_HOST || location.hostname || 'localhost';
  connectAuthEmulator(auth, `http://${host}:9099`, { disableWarnings: true });
  connectFirestoreEmulator(db, host, 8080);
  connectFunctionsEmulator(functions, host, 5001);
}
