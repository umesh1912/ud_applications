import type { CSSProperties } from 'react';

export type IconName = string;

export interface Item {
  t: string;
  s: string;
  r: string;
  d: string;
  f: [string, string][];
}

export interface Hero {
  k: string;
  v: string;
  sub: string;
  cta?: string;
  done?: { k: string; v: string; sub: string };
}

export interface Confirmation {
  t: string;
  b: string;
}

export interface AppData {
  name: string;
  tag: string;
  a: string;
  b: string;
  tint: string;
  itemIcon: IconName;
  about: string;
  tabs: [IconName, string][];
  onboard: [IconName, string, string][];
  hero: Hero;
  homeTitle: string;
  items: Item[];
  action: string;
  conf: Confirmation;
  tab2: { title: string; ph: string; items: [string, string, string][] };
  create: {
    title: string;
    steps: { q: string; o: string[] }[];
    cta: string;
    conf: Confirmation;
  };
  settings: string[];
  user: { n: string; i: string; m: string };
}

export type HeroKind = 'Block' | 'Ring' | 'Card' | 'Tape' | 'Spec' | 'Giant' | 'Cover' | 'Circle';
export type ListKind = 'Rows' | 'Cards' | 'Tracks' | 'Tickets' | 'Tiles' | 'Board';
export type TabKind = 'Bar' | 'Pill' | 'Text';
export type OnboardKind = 'Top' | 'Center';

/** A per-app visual system. Optional fields fall back to the defaults in `resolveTheme`. */
export interface Theme {
  style: string;
  fonts: string;
  bezel: string;
  bg: string;
  bgImg?: string;
  bgSize?: string;
  ink: string;
  muted: string;
  line: string;
  surface: string;
  accent: string;
  accent2: string;
  onAccent: string;
  onAccent2: string;
  accentText: string;
  /** Heading font, weight, italic, case, tracking. */
  fh: string;
  hw: number;
  hi?: string;
  ht: string;
  hls: string;
  /** Body and label fonts. */
  fb: string;
  fl: string;
  /** Label tracking, case, size, weight. */
  lls?: string;
  ltt?: string;
  lsz?: number;
  lw?: number;
  /** Radii: large, small, mark/avatar, progress dots, toggles. */
  r: string;
  rs: string;
  markR: string;
  dotR: string;
  toggleR: string;
  h1: number;
  big: number;
  bodySize?: number;
  card: CSSProperties;
  cardRow?: CSSProperties;
  blockShadow: string;
  btn: CSSProperties;
  chipOn: CSSProperties;
  chipOff: CSSProperties;
  chipR: number | string;
  chipSize?: number;
  hero: HeroKind;
  list: ListKind;
  tab: TabKind;
  onb: OnboardKind;
  rowLine?: string;
  iconBg?: string;
  iconInk?: string;
  iconRing?: string;
  /** Title weight in list rows. */
  tw: number;
  badge: CSSProperties;
  ph1: string;
  ph2: string;
  tileRing: string;
  tileH?: string;
  tileGap?: string;
  tileFont?: string;
  tabBg: string;
  tabLine?: string;
  tabShadow?: string;
  tabActive: string;
  tabIdle: string;
  tabPillOn?: string;
  tabFont?: string;
  tabSize?: string;
  tabStyle?: string;
  tabLs?: string;
  tabCase?: string;
  toggleRing: string;
  trackOn: string;
  knobOn: string;
  trackOff: string;
  knobOff: string;
  scrollPad?: string;
}

export type ResolvedTheme = Theme &
  Required<
    Pick<
      Theme,
      | 'hi' | 'scrollPad' | 'bgImg' | 'bgSize' | 'tileH' | 'tileGap' | 'tileFont' | 'tabFont' | 'tabSize'
      | 'tabStyle' | 'tabLs' | 'tabLine' | 'tabShadow' | 'rowLine' | 'iconBg' | 'iconInk' | 'iconRing' | 'tabCase'
    >
  >;
