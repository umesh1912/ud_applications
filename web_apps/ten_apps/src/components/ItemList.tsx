import { Icon } from '../icons';
import type { Proto } from '../prototype';
import { stripes } from '../theme';

/** The home-screen item list; each theme picks one of six layouts. Every item opens its detail screen. */
export function ItemList({ p }: { p: Proto }) {
  const { T, S, A, codes } = p;
  const items = A.items.map((it, i) => ({ ...it, i, code: codes[i], open: () => p.openItem(i) }));

  switch (T.list) {
    case 'Rows':
      return (
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {items.map((it) => (
            <div key={it.i} onClick={it.open} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 0', borderBottom: T.rowLine, cursor: 'pointer' }}>
              <div style={{ width: 42, height: 42, borderRadius: T.rs, background: T.iconBg, color: T.iconInk, boxShadow: T.iconRing, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none' }}>
                <Icon name={A.itemIcon} size={20} />
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 15, fontWeight: T.tw }}>{it.t}</div>
                <div style={{ fontSize: 12, color: T.muted, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{it.s}</div>
              </div>
              <span style={S.badge}>{it.r}</span>
            </div>
          ))}
        </div>
      );

    case 'Cards':
      return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {items.map((it) => (
            <div key={it.i} onClick={it.open} style={S.cardRow}>
              <div style={{ width: 62, height: 62, borderRadius: T.rs, background: T.accent2, color: T.onAccent2, display: 'flex', alignItems: 'center', justifyContent: 'center', textAlign: 'center', fontSize: 12, fontWeight: 800, lineHeight: 1.1, flex: 'none', padding: 4, boxSizing: 'border-box' }}>
                {it.r}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 17, fontWeight: T.tw }}>{it.t}</div>
                <div style={{ fontSize: 13, color: T.muted }}>{it.s}</div>
              </div>
              <Icon name="IconChevronRight" size={20} />
            </div>
          ))}
        </div>
      );

    case 'Tracks':
      return (
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {items.map((it) => (
            <div key={it.i} onClick={it.open} style={{ display: 'flex', alignItems: 'baseline', gap: 14, padding: '14px 0', borderBottom: `1px dotted ${T.muted}`, cursor: 'pointer' }}>
              <span style={{ fontFamily: T.fl, fontSize: 13, color: T.accent, fontWeight: 700 }}>{it.code}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontFamily: T.fh, fontStyle: 'italic', fontWeight: 700, fontSize: 19 }}>{it.t}</div>
                <div style={{ fontSize: 12, color: T.muted }}>{it.s}</div>
              </div>
              <span style={{ fontFamily: T.fl, fontSize: 13 }}>{it.r}</span>
            </div>
          ))}
        </div>
      );

    case 'Tickets':
      return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {items.map((it) => (
            <div key={it.i} onClick={it.open} style={{ display: 'flex', alignItems: 'stretch', border: `1.5px dashed ${T.line}`, borderRadius: 2, cursor: 'pointer' }}>
              <div style={{ width: 52, display: 'flex', alignItems: 'center', justifyContent: 'center', borderRight: `1.5px dashed ${T.line}`, fontFamily: T.fl, fontSize: 12, color: T.accent }}>
                #{it.code}
              </div>
              <div style={{ flex: 1, padding: 12, minWidth: 0 }}>
                <div style={{ fontSize: 15, fontWeight: 700 }}>{it.t}</div>
                <div style={{ fontFamily: T.fl, fontSize: 11, color: T.muted, textTransform: 'uppercase', letterSpacing: '0.05em' }}>{it.s}</div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', padding: '0 12px' }}>
                <span style={S.badge}>{it.r}</span>
              </div>
            </div>
          ))}
        </div>
      );

    case 'Tiles':
      return (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: T.tileGap }}>
          {items.map((it) => (
            <div key={it.i} onClick={it.open} style={{ display: 'flex', flexDirection: 'column', gap: 8, cursor: 'pointer' }}>
              <div style={{ height: T.tileH, borderRadius: T.r, background: stripes(T, 10), boxShadow: T.tileRing, position: 'relative' }}>
                <span style={S.tileBadge}>{it.r}</span>
              </div>
              <div>
                <div style={{ fontSize: 15, fontWeight: T.tw, fontFamily: T.tileFont, lineHeight: 1.2 }}>{it.t}</div>
                <div style={{ fontSize: 12, color: T.muted, marginTop: 2 }}>{it.s}</div>
              </div>
            </div>
          ))}
        </div>
      );

    case 'Board':
      return (
        <div style={{ display: 'flex', flexDirection: 'column', borderTop: `3px solid ${T.ink}` }}>
          {items.map((it) => (
            <div key={it.i} onClick={it.open} style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '12px 0', borderBottom: `1px solid ${T.ink}`, cursor: 'pointer' }}>
              <div style={{ width: 30, height: 30, borderRadius: '50%', background: T.accent, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: T.fh, fontWeight: 800, fontSize: 16, flex: 'none' }}>
                {it.code}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontFamily: T.fh, fontWeight: 700, fontSize: 20, textTransform: 'uppercase', lineHeight: 1 }}>{it.t}</div>
                <div style={{ fontSize: 12, color: T.muted, marginTop: 2 }}>{it.s}</div>
              </div>
              <span style={{ fontFamily: T.fh, fontWeight: 800, fontSize: 22, background: T.ink, color: T.accent2, padding: '2px 8px' }}>{it.r}</span>
            </div>
          ))}
        </div>
      );
  }
}
