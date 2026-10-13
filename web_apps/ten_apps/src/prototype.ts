import { useEffect, useState } from 'react';
import { APPS } from './data/apps';
import { THEMES } from './data/themes';
import type { AppData, Confirmation, Hero, ResolvedTheme } from './data/types';
import { buildStyles, resolveTheme, type Styles } from './theme';

export const SCREENS = [
  ['onboard', 'Onboarding'], ['home', 'Home'], ['tab2', 'Second tab'], ['detail', 'Detail'],
  ['create', 'Create flow'], ['review', 'Review'], ['confirm', 'Confirmation'], ['settings', 'Profile & settings'],
] as const;
export type Screen = (typeof SCREENS)[number][0];

/** Bottom-tab slots map onto these screens; slot 2 always opens a fresh create flow. */
const TAB_SCREENS: Screen[] = ['home', 'tab2', 'create', 'settings'];
const SCREENS_WITH_TABS: Screen[] = ['home', 'tab2', 'settings'];
/** Item codes per list style: track sides for Tracks, platforms for Board, numbers otherwise. */
const CODES = { default: ['01', '02', '03', '04'], Tracks: ['A1', 'A2', 'B1', 'B2'], Board: ['4', '4', '12', 'X'] };

const VIEWER_KEY = 'tenapps-proto-v2';

interface State {
  app: number;
  screen: Screen;
  slide: number;
  item: number;
  step: number;
  picks: Record<number, string>;
  conf: Confirmation | null;
  heroDone: Record<number, boolean>;
  sw: Record<string, boolean>;
}

const INITIAL: State = { app: 0, screen: 'onboard', slide: 0, item: 0, step: 0, picks: {}, conf: null, heroDone: {}, sw: {} };

function load(key: string, fixedApp: number | undefined): State {
  try {
    const saved = JSON.parse(localStorage.getItem(key) || '{}');
    const app = fixedApp ?? (Number.isInteger(saved.app) && APPS[saved.app] ? saved.app : 0);
    const screen = SCREENS.some(([k]) => k === saved.screen) ? saved.screen : 'onboard';
    return { ...INITIAL, app, screen, heroDone: saved.heroDone || {}, sw: saved.sw || {} };
  } catch {
    return { ...INITIAL, app: fixedApp ?? 0 };
  }
}

/**
 * All prototype state and actions. With `fixedApp` (a single-app Android build) the app can't be
 * switched and its state is stored under its own key.
 */
export function usePrototype(fixedApp?: number) {
  const KEY = fixedApp === undefined ? VIEWER_KEY : `tenapps-app-${fixedApp}`;
  const [s, setS] = useState<State>(() => load(KEY, fixedApp));
  const set = (p: Partial<State>) => setS((prev) => ({ ...prev, ...p }));
  const go = (screen: Screen, extra?: Partial<State>) => set({ screen, ...extra });

  useEffect(() => {
    const { app, screen, heroDone, sw } = s;
    try { localStorage.setItem(KEY, JSON.stringify({ app, screen, heroDone, sw })); } catch { /* storage unavailable */ }
  }, [KEY, s]);

  const A: AppData = APPS[s.app];
  const showTabs = SCREENS_WITH_TABS.includes(s.screen);
  const T: ResolvedTheme = resolveTheme(THEMES[s.app], showTabs);
  const n = A.create.steps.length;
  const step = A.create.steps[Math.min(s.step, n - 1)];
  const pick = s.picks[s.step];
  const S: Styles = buildStyles(T, !!pick);
  const fill = (text: string) => text.replace('{item}', A.items[s.item].t);

  const done = !!s.heroDone[s.app] && !!A.hero.done;
  const hero: Hero & { hasCta: boolean } = done ? { ...A.hero.done!, hasCta: false } : { ...A.hero, hasCta: !!A.hero.cta };
  const confirm = s.conf || A.conf;
  const codes = (T.list === 'Tracks' || T.list === 'Board') ? CODES[T.list] : CODES.default;
  const activeTab = TAB_SCREENS.indexOf(s.screen);

  return {
    s, A, T, S, showTabs, hero, done, step, pick, stepCount: n,
    item: A.items[s.item],
    conf: { t: confirm.t, b: fill(confirm.b) },
    codes,

    selectApp: (i: number) => set({ app: i, screen: 'onboard', slide: 0, step: 0, picks: {}, conf: null }),
    jumpTo: (k: Screen) => set({ screen: k, slide: 0, step: k === 'create' ? 0 : s.step, conf: k === 'confirm' ? A.conf : s.conf }),

    nextSlide: () => (s.slide < A.onboard.length - 1 ? set({ slide: s.slide + 1 }) : go('home')),
    skipOnboard: () => go('home'),
    replayOnboard: () => go('onboard', { slide: 0 }),
    goHome: () => go('home'),
    openItem: (i: number) => go('detail', { item: i }),
    heroTap: () => { if (A.hero.cta) set({ heroDone: { ...s.heroDone, [s.app]: !s.heroDone[s.app] } }); },
    doAction: () => go('confirm', { conf: { t: A.conf.t, b: fill(A.conf.b) } }),

    pickOption: (o: string) => set({ picks: { ...s.picks, [s.step]: o } }),
    prevStep: () => (s.screen === 'review' ? go('create', { step: n - 1 }) : set({ step: Math.max(0, s.step - 1) })),
    nextStep: () => { if (!pick) return; if (s.step < n - 1) set({ step: s.step + 1 }); else go('review'); },
    submitCreate: () => go('confirm', { conf: A.create.conf, picks: {}, step: 0 }),

    /** Third setting starts off, the rest on, until toggled. */
    settingOn: (i: number) => s.sw[`${s.app}-${i}`] ?? i !== 2,
    toggleSetting: (i: number) => { const k = `${s.app}-${i}`; set({ sw: { ...s.sw, [k]: !(s.sw[k] ?? i !== 2) } }); },

    /** Android back button. Returns false when there is nowhere to go back to (the app should close). */
    back: (): boolean => {
      switch (s.screen) {
        case 'onboard': if (s.slide === 0) return false; set({ slide: s.slide - 1 }); return true;
        case 'home': return false;
        case 'create': if (s.step > 0) set({ step: s.step - 1 }); else go('home'); return true;
        case 'review': go('create', { step: n - 1 }); return true;
        default: go('home'); return true;
      }
    },

    activeTab,
    tapTab: (i: number) => (i === 2 ? go('create', { step: 0, picks: {} }) : go(TAB_SCREENS[i])),
  };
}

export type Proto = ReturnType<typeof usePrototype>;
