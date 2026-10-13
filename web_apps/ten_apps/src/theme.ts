import type { CSSProperties } from 'react';
import type { ResolvedTheme, Theme } from './data/types';

export function resolveTheme(t: Theme, showTabs: boolean): ResolvedTheme {
  const T: ResolvedTheme = {
    hi: 'normal', scrollPad: '0px', bgImg: 'none', bgSize: 'auto', tileH: '150px', tileGap: '12px', tileFont: t.fb,
    tabFont: t.fl, tabSize: '12px', tabStyle: 'normal', tabLs: '0.06em', tabLine: '1px solid ' + t.line,
    tabShadow: 'none', rowLine: '1px solid ' + t.line, iconBg: t.surface, iconInk: t.accent, iconRing: 'none',
    tabCase: 'none',
    ...(Object.fromEntries(Object.entries(t).filter(([, v]) => v !== undefined)) as Theme),
  } as ResolvedTheme;
  // Floating tab bars reserve room at the bottom of the scroll area, but only where tabs show.
  if (!showTabs) T.scrollPad = '0px';
  return T;
}

export type Styles = ReturnType<typeof buildStyles>;

export function buildStyles(T: ResolvedTheme, canContinue: boolean) {
  const hs: CSSProperties = {
    fontFamily: T.fh, fontWeight: T.hw, fontStyle: T.hi, textTransform: T.ht as CSSProperties['textTransform'],
    letterSpacing: T.hls, lineHeight: 1.05, textWrap: 'pretty',
  };
  const lab: CSSProperties = {
    fontFamily: T.fl, fontSize: T.lsz || 11, fontWeight: T.lw || 700, letterSpacing: T.lls || '0.08em',
    textTransform: (T.ltt || 'uppercase') as CSSProperties['textTransform'], color: T.muted,
  };
  const btnBase: CSSProperties = {
    display: 'flex', alignItems: 'center', justifyContent: 'center', height: 52, padding: '0 20px', cursor: 'pointer',
    fontFamily: T.fb, fontWeight: 700, fontSize: 15, boxSizing: 'border-box', userSelect: 'none',
  };
  const btn: CSSProperties = { ...btnBase, ...T.btn };
  const ghost: CSSProperties = { ...btnBase, ...T.btn, background: 'transparent', color: T.ink, boxShadow: 'inset 0 0 0 1.5px ' + T.ink };
  const badgeBg = T.badge.background === 'transparent' ? T.bg : (T.badge.background as string);

  return {
    h1: { ...hs, fontSize: T.h1 },
    h2: { ...hs, fontSize: Math.round(T.h1 * 0.7) },
    big: { ...hs, fontSize: T.big, lineHeight: 0.95 },
    bigRel: { ...hs, fontSize: T.big, lineHeight: 0.95, position: 'relative' },
    h1Top: { ...hs, fontSize: T.h1, marginTop: 12 },
    brand: { ...hs, fontSize: 18 },
    brandLg: { ...hs, fontSize: 24 },
    label: lab,
    labelOn: { ...lab, color: T.onAccent, opacity: 0.85 },
    labelOnRel: { ...lab, color: T.onAccent, opacity: 0.85, position: 'relative' },
    labelInk: { ...lab, color: T.ink },
    labelA2: { ...lab, color: T.accent2 },
    labelAccent: { ...lab, color: T.accentText },
    body: { fontSize: T.bodySize || 15.5, lineHeight: 1.5, color: T.muted, textWrap: 'pretty' },
    link: { fontSize: 14, fontWeight: 600, color: T.muted, cursor: 'pointer', fontFamily: T.fl },
    back: { display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', fontSize: 14, fontWeight: 600, color: T.muted, fontFamily: T.fl },
    card: { borderRadius: T.r, ...T.card, display: 'flex', flexDirection: 'column' },
    cardRow: {
      display: 'flex', alignItems: 'center', gap: 14, padding: 14, cursor: 'pointer', borderRadius: T.r,
      ...(T.cardRow || T.card), ...(T.cardRow ? {} : { padding: 14 }),
    },
    btn,
    btnSm: { ...btn, height: 40, fontSize: 13 },
    btnGhost: ghost,
    btnGhostHalf: { ...ghost, width: 110, flex: 'none' },
    btnNext: { ...btn, flex: 1, opacity: canContinue ? 1 : 0.4, cursor: canContinue ? 'pointer' : 'not-allowed' },
    btnStretch: { ...btn, alignSelf: 'stretch' },
    specTag: { position: 'absolute', top: -9, left: 12, background: T.bg, padding: '0 6px', fontFamily: T.fl, fontSize: 11, letterSpacing: '0.08em', color: T.muted },
    tileBadge: {
      position: 'absolute', left: 8, top: 8, fontFamily: T.fl, fontSize: 11, fontWeight: 700, padding: '3px 8px',
      background: badgeBg, color: T.badge.color, boxShadow: T.badge.boxShadow || 'none',
    },
    badge: { fontFamily: T.fl, fontSize: 12, fontWeight: 700, padding: '4px 9px', borderRadius: T.rs, whiteSpace: 'nowrap', ...T.badge },
    placeholderCaption: { font: "500 11px 'JetBrains Mono',monospace", color: T.muted },
  } satisfies Record<string, CSSProperties>;
}

/** Diagonal-stripe stand-in for photos and maps. */
export const stripes = (T: ResolvedTheme, w: number) =>
  `repeating-linear-gradient(135deg,${T.ph1} 0 ${w}px,${T.ph2} ${w}px ${w * 2}px)`;
