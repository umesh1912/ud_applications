import { Icon } from '../icons';
import type { Proto } from '../prototype';
import { stripes } from '../theme';

/** The home-screen headline block; each theme picks one of eight shapes. */
export function Hero({ p }: { p: Proto }) {
  const { T, S, hero } = p;
  switch (T.hero) {
    case 'Block':
      return (
        <div style={{ background: T.accent, color: T.onAccent, padding: 20, boxShadow: `inset 0 0 0 2px ${T.ink},6px 6px 0 ${T.ink}`, display: 'flex', flexDirection: 'column', gap: 8, marginRight: 6 }}>
          <span style={S.labelOn}>{hero.k}</span>
          <span style={S.big}>{hero.v}</span>
          <span style={{ fontSize: 13 }}>{hero.sub}</span>
        </div>
      );

    case 'Ring':
      return (
        <div style={{ position: 'relative', height: 270, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ position: 'absolute', width: 270, height: 270, borderRadius: '50%', boxShadow: `inset 0 0 0 1px ${T.accent}`, opacity: 0.18 }} />
          <div style={{ position: 'absolute', width: 206, height: 206, borderRadius: '50%', boxShadow: `inset 0 0 0 1px ${T.accent}`, opacity: 0.35 }} />
          <div style={{ position: 'absolute', width: 142, height: 142, borderRadius: '50%', background: T.accent, opacity: 0.12 }} />
          <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, textAlign: 'center', maxWidth: 220 }}>
            <span style={S.label}>{hero.k}</span>
            <span style={S.big}>{hero.v}</span>
            <span style={{ fontSize: 13, color: T.muted }}>{hero.sub}</span>
          </div>
        </div>
      );

    case 'Card':
      return (
        <div style={{ position: 'relative', overflow: 'hidden', background: T.accent, color: T.onAccent, borderRadius: T.r, padding: '24px 22px', display: 'flex', flexDirection: 'column', gap: 6 }}>
          <div style={{ position: 'absolute', width: 150, height: 150, borderRadius: '50%', right: -40, top: -50, background: T.accent2 }} />
          <span style={S.labelOnRel}>{hero.k}</span>
          <span style={S.bigRel}>{hero.v}</span>
          <span style={{ fontSize: 14, position: 'relative', opacity: 0.9 }}>{hero.sub}</span>
        </div>
      );

    case 'Tape':
      return (
        <div style={{ background: T.surface, borderRadius: 6, padding: 14, boxShadow: `inset 0 0 0 1px ${T.line},0 10px 20px -14px rgba(59,36,24,.5)`, display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={{ background: T.accent2, borderRadius: 3, padding: '10px 12px', display: 'flex', flexDirection: 'column', gap: 2 }}>
            <span style={S.labelInk}>{hero.k} · side A</span>
            <span style={S.h2}>{hero.v}</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 40, padding: '6px 0', background: T.ink, borderRadius: 40, margin: '0 30px' }}>
            <div style={{ width: 38, height: 38, borderRadius: '50%', background: T.surface, boxShadow: `inset 0 0 0 10px ${T.accent2}` }} />
            <div style={{ width: 38, height: 38, borderRadius: '50%', background: T.surface, boxShadow: `inset 0 0 0 4px ${T.accent2}` }} />
          </div>
          <span style={{ fontStyle: 'italic', fontSize: 14, lineHeight: 1.4, fontFamily: T.fh }}>{hero.sub}</span>
          {hero.hasCta && <div onClick={p.heroTap} style={S.btnSm}>{hero.cta}</div>}
        </div>
      );

    case 'Spec':
      return (
        <div style={{ border: `1.5px dashed ${T.line}`, borderRadius: 2, padding: 16, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, position: 'relative' }}>
          <span style={S.specTag}>FIG. 01 — SUMMARY</span>
          <div style={{ gridColumn: '1/-1', display: 'flex', flexDirection: 'column', gap: 2 }}>
            <span style={S.label}>{hero.k}</span>
            <span style={S.big}>{hero.v}</span>
          </div>
          <div style={{ gridColumn: '1/-1', borderTop: `1px solid ${T.line}`, paddingTop: 10, fontFamily: T.fl, fontSize: 12, color: T.accent }}>→ {hero.sub}</div>
        </div>
      );

    case 'Giant':
      return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6, padding: '8px 0' }}>
          <span style={S.label}>{hero.k}</span>
          <span style={S.big}>{hero.v}</span>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 40, height: 6, background: T.accent, borderRadius: T.dotR }} />
            <span style={{ fontSize: 14, color: T.muted }}>{hero.sub}</span>
          </div>
        </div>
      );

    case 'Cover':
      return (
        <div style={{ position: 'relative', height: 290, background: stripes(T, 12), display: 'flex', flexDirection: 'column', justifyContent: 'space-between', padding: 16, boxSizing: 'border-box', boxShadow: `inset 0 0 0 1px ${T.line}` }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={S.labelInk}>Issue 10 · Autumn</span>
            <span style={S.labelA2}>{hero.k}</span>
          </div>
          <div>
            <div style={S.big}>{hero.v}</div>
            <div style={{ fontFamily: T.fh, fontStyle: 'italic', fontSize: 18, marginTop: 4 }}>{hero.sub}</div>
          </div>
        </div>
      );

    case 'Circle': {
      const { done } = p;
      return (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14, padding: '6px 0' }}>
          <span style={S.label}>{hero.k}</span>
          <div
            onClick={p.heroTap}
            style={{
              width: 230, height: 230, borderRadius: '50%', background: done ? T.accent : T.surface, color: done ? T.onAccent : T.accentText,
              boxShadow: `0 0 0 14px ${T.surface},0 0 0 15px ${T.line}`, display: 'flex', flexDirection: 'column', alignItems: 'center',
              justifyContent: 'center', gap: 6, cursor: 'pointer', textAlign: 'center', transition: 'all 250ms',
            }}
          >
            <Icon name={done ? 'IconCheck' : 'IconHand'} size={44} />
            <span style={S.h2}>{done ? hero.v : p.A.hero.cta || hero.v}</span>
          </div>
          <span style={{ fontSize: 16, color: T.muted, textAlign: 'center', maxWidth: 260 }}>{hero.sub}</span>
        </div>
      );
    }
  }
}
