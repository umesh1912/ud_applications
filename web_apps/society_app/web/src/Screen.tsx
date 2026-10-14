import type { ReactNode } from 'react';
import { Icon } from './ds';
import { btnReset, C } from './ui';

/** Full-height page with the app's header, used by sign-in and onboarding screens. */
export function Screen({ sub, title, lang, setLang, framed, onBack, children }: {
  sub: string; title: string; lang: 'gu' | 'en'; setLang: (l: 'gu' | 'en') => void; framed: boolean; onBack?: () => void; children: ReactNode;
}) {
  return (
    <div lang={lang} style={{ height: '100%', display: 'flex', flexDirection: 'column', background: '#fff', color: C.ink }}>
      <header style={{ padding: framed ? '58px 16px 12px' : 'calc(env(safe-area-inset-top) + 12px) 16px 12px', display: 'flex', alignItems: 'center', gap: 10, borderBottom: `1px solid ${C.soft}` }}>
        {onBack && (
          <button aria-label="Back" onClick={onBack} style={{ ...btnReset, width: 36, height: 36, borderRadius: 6, background: C.soft, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none' }}>
            <Icon name="IconChevronLeft" size={20} />
          </button>
        )}
        <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 1 }}>
          <div style={{ fontSize: 12, color: C.muted, fontWeight: 500 }}>{sub}</div>
          <h1 style={{ margin: 0, fontSize: 20, fontWeight: 700, letterSpacing: -0.3, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{title}</h1>
        </div>
        <button onClick={() => setLang(lang === 'gu' ? 'en' : 'gu')} aria-label="Language"
          style={{ ...btnReset, height: 32, padding: '0 10px', borderRadius: 6, boxShadow: `inset 0 0 0 1px ${C.line}`, background: '#fff', fontSize: 13, fontWeight: 600 }}>{lang === 'gu' ? 'EN' : 'ગુ'}</button>
      </header>
      <main style={{ flex: 1, overflowY: 'auto', padding: framed ? '20px 16px 40px' : '20px 16px calc(env(safe-area-inset-bottom) + 24px)' }}>{children}</main>
    </div>
  );
}

export const ErrorBox = ({ children }: { children: ReactNode }) =>
  <div role="alert" style={{ fontSize: 13, padding: 10, borderRadius: 6, background: '#fef2f2', color: C.red, fontWeight: 500 }}>{children}</div>;
