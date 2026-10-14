import { useEffect, useState } from 'react';
import {
  collection, collectionGroup, doc, onSnapshot, query, where, type DocumentData, type QueryConstraint,
} from 'firebase/firestore';
import { db } from './firebase';

export type WithId<T> = T & { id: string };

/** Live single document. `undefined` while loading, `null` if it doesn't exist. */
export function useDoc<T>(path: string | null): T | null | undefined {
  const [data, setData] = useState<T | null | undefined>(undefined);
  useEffect(() => {
    if (!path) { setData(null); return; }
    setData(undefined);
    return onSnapshot(doc(db, path), (snap) => setData(snap.exists() ? ({ id: snap.id, ...snap.data() } as T) : null), (e) => {
      console.warn('doc', path, e.code);
      setData(null);
    });
  }, [path]);
  return data;
}

/**
 * Live query. Pass a stable `key` describing the query (it re-subscribes when the key changes).
 * Returns `undefined` while loading.
 */
export function useQuery<T>(key: string | null, coll: string, ...constraints: QueryConstraint[]): WithId<T>[] | undefined {
  return useAnyQuery<T>(key, false, coll, constraints);
}

/** Live query across every subcollection with this name (e.g. all `messages`). */
export function useGroupQuery<T>(key: string | null, coll: string, ...constraints: QueryConstraint[]): WithId<T>[] | undefined {
  return useAnyQuery<T>(key, true, coll, constraints);
}

function useAnyQuery<T>(key: string | null, group: boolean, coll: string, constraints: QueryConstraint[]): WithId<T>[] | undefined {
  const [rows, setRows] = useState<WithId<T>[] | undefined>(undefined);
  useEffect(() => {
    if (!key) { setRows([]); return; }
    setRows(undefined);
    return onSnapshot(query(group ? collectionGroup(db, coll) : collection(db, coll), ...constraints), (snap) => {
      setRows(snap.docs.map((d) => ({ id: d.id, ...(d.data() as DocumentData) }) as WithId<T>));
    }, (e) => {
      console.warn('query', key, e.code);
      setRows([]);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  return rows;
}

export { where };

/** Short random id for Jitsi rooms and order numbers. */
export function randomId(n = 10) {
  const a = 'abcdefghijkmnpqrstuvwxyz23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(n));
  return Array.from(bytes, (b) => a[b % a.length]).join('');
}

/** Human-readable message for Firebase auth/firestore errors. */
export function errorText(e: unknown) {
  const code = (e as { code?: string })?.code ?? '';
  const map: Record<string, string> = {
    'auth/invalid-credential': 'Email or password is incorrect.',
    'auth/wrong-password': 'Email or password is incorrect.',
    'auth/user-not-found': 'No account with that email.',
    'auth/email-already-in-use': 'An account with this email already exists. Log in instead.',
    'auth/weak-password': 'Use at least 8 characters for your password.',
    'auth/invalid-email': 'That email address doesn’t look right.',
    'auth/too-many-requests': 'Too many attempts. Wait a minute and try again.',
    'auth/network-request-failed': 'No internet connection. Check your network and try again.',
    'auth/invalid-phone-number': 'That phone number doesn’t look right.',
    'auth/invalid-verification-code': 'That code is incorrect.',
    'auth/code-expired': 'That code has expired. Send a new one.',
    'auth/operation-not-allowed': 'This sign-in method isn’t enabled for the app yet.',
    'permission-denied': 'You don’t have permission to do that.',
    'unavailable': 'Can’t reach the server. Check your connection.',
  };
  return map[code] ?? (e as Error)?.message ?? 'Something went wrong. Please try again.';
}
