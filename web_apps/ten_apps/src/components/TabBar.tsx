import type { CSSProperties } from 'react';
import { Icon } from '../icons';
import type { Proto } from '../prototype';

/** Bottom navigation: a docked icon bar, a floating pill, or text-only tabs. */
export function TabBar({ p }: { p: Proto }) {
  const { T, A, activeTab } = p;
  if (!p.showTabs) return null;
  const tabs = A.tabs.map(([icon, label], i) => {
    const on = i === activeTab;
    return { i, icon, label, on, color: on ? T.tabActive : T.tabIdle, tap: () => p.tapTab(i) };
  });
  const tabCase = T.tabCase as CSSProperties['textTransform'];

  switch (T.tab) {
    case 'Bar':
      return (
        <div style={{ display: 'flex', justifyContent: 'space-around', padding: '10px 12px 24px', background: T.tabBg, borderTop: T.tabLine, flex: 'none' }}>
          {tabs.map((tb) => (
            <div key={tb.i} onClick={tb.tap} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, cursor: 'pointer', width: 68, color: tb.color }}>
              <Icon name={tb.icon} size={22} />
              <span style={{ fontFamily: T.fl, fontSize: 10.5, fontWeight: 700, letterSpacing: '0.06em', textTransform: tabCase }}>{tb.label}</span>
            </div>
          ))}
        </div>
      );

    case 'Pill':
      return (
        <div style={{ position: 'absolute', left: 24, right: 24, bottom: 22, height: 62, borderRadius: 999, background: T.tabBg, boxShadow: T.tabShadow, display: 'flex', alignItems: 'center', justifyContent: 'space-around', padding: '0 8px' }}>
          {tabs.map((tb) => (
            <div
              key={tb.i}
              onClick={tb.tap}
              title={tb.label}
              aria-label={tb.label}
              style={{ width: 46, height: 46, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', background: tb.on ? T.tabPillOn || 'transparent' : 'transparent', color: tb.color, transition: 'background 150ms' }}
            >
              <Icon name={tb.icon} size={21} />
            </div>
          ))}
        </div>
      );

    case 'Text':
      return (
        <div style={{ display: 'flex', justifyContent: 'space-around', padding: '14px 16px 26px', borderTop: `1px solid ${T.line}`, background: T.tabBg, flex: 'none' }}>
          {tabs.map((tb) => (
            <div
              key={tb.i}
              onClick={tb.tap}
              style={{ cursor: 'pointer', fontFamily: T.tabFont, fontSize: T.tabSize, fontStyle: T.tabStyle, letterSpacing: T.tabLs, textTransform: tabCase, color: tb.color, paddingBottom: 4, borderBottom: `2px solid ${tb.on ? T.tabActive : 'transparent'}` }}
            >
              {tb.label}
            </div>
          ))}
        </div>
      );
  }
}
