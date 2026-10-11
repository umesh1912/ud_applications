import { createContext, useContext } from 'react';
import type { Pair, Role, Strings } from './lib/i18n';
import type { AppState } from './lib/types';

export type Sheet = 'pay' | 'receipt' | 'sos' | 'pass' | 'complaint' | 'visitor' | 'notice' | 'bill' | 'cash';
export type CommTab = 'notices' | 'events' | 'polls';

export interface Receipt { id: number; amt: number; no: string; via: string; time: string; date: string }

export interface Ui {
  screen: string; sheet: Sheet | null; commTab: CommTab;
  unselected: number[]; payMethod: 'upi' | 'card' | 'net'; paying: boolean; receipt: Receipt | null;
  amenity: string; date: string; slot: string | null;
  sosType: string; sosSent: boolean; codeResult: string | null;
  file: File | null;
  f: { code: string; q: string; passName: string; passWhen: 'today' | 'tomorrow'; comp: string; compCat: string; vName: string; vFlat: string; vP: string;
    nTitle: string; nBody: string; nPin: boolean; bVendor: string; bAmt: string; bCat: string; cashFlat: string | null };
}

export interface Ctx {
  st: AppState; L: 0 | 1; T: Strings; x: (p: Pair) => string;
  role: Role; isRes: boolean; isAdmin: boolean; isW: boolean;
  ui: Ui; set: (patch: Partial<Ui> | ((u: Ui) => Partial<Ui>)) => void; setF: (k: keyof Ui['f'], v: Ui['f'][keyof Ui['f']]) => void;
  go: (screen: string) => void; open: (sheet: Sheet) => void; close: () => void;
  toast: (msg: string) => void;
  /** Runs a mutation, refreshes state, and shows the localized error if it fails. */
  run: <T>(fn: () => Promise<T>) => Promise<T | undefined>;
  dl: (path: string, name: string, okMsg: string) => void;
  switchRole: (r: Role) => void; logout: () => void;
}

export const AppCtx = createContext<Ctx>(null!);
export const useApp = () => useContext(AppCtx);
