import { useEffect, useRef, type ReactNode } from 'react';
import { App as NativeApp } from '@capacitor/app';
import { APPS } from './data/apps';
import APP_META from '../apps.json';
import { THEMES } from './data/themes';
import { Icon } from './icons';
import { SCREENS, usePrototype, type Proto, type Screen } from './prototype';
import { Confirm, Create, Detail, Home, Onboarding, Review, SecondTab, Settings } from './components/Screens';
import { TabBar } from './components/TabBar';

const mono = "'JetBrains Mono',monospace";

const SCREEN_VIEWS: Record<Screen, (p: { p: Proto }) => ReactNode> = {
  onboard: Onboarding, home: Home, tab2: SecondTab, detail: Detail,
  create: Create, review: Review, confirm: Confirm, settings: Settings,
};

/** Set by single-app builds (`VITE_APP=3 npm run build`): the whole page is that one app. */
const SINGLE_APP = import.meta.env.VITE_APP;

const ICON_URLS = import.meta.glob<string>('../icons/*/small.png', { eager: true, query: '?url', import: 'default' });

export default function App() {
  return SINGLE_APP === undefined ? <Viewer /> : <StandaloneApp index={Number(SINGLE_APP)} />;
}

/** One app filling the device screen, as packaged in its APK. */
function StandaloneApp({ index }: { index: number }) {
  const p = usePrototype(index);
  const back = useRef(p.back);
  back.current = p.back;

  useEffect(() => {
    document.body.style.background = p.T.bg;
  }, [p.T.bg]);

  useEffect(() => {
    const handle = NativeApp.addListener('backButton', () => {
      if (!back.current()) NativeApp.exitApp();
    });
    return () => { handle.then((h) => h.remove()); };
  }, []);

  return (
    <div style={{ position: 'fixed', inset: 0 }}>
      <ScreenBody p={p} topPad={10} />
    </div>
  );
}

/** The prototype viewer: app picker, phone frame and style panel. */
function Viewer() {
  const p = usePrototype();
  return (
    <div className="layout">
      <AppPicker p={p} />
      <Phone p={p} />
      <StylePanel p={p} />
    </div>
  );
}

function AppPicker({ p }: { p: Proto }) {
  return (
    <nav style={{ width: 250, display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div>
        <div style={{ font: `600 11px ${mono}`, color: '#777', letterSpacing: '0.08em' }}>10 APPS · 10 STYLES</div>
        <h1 style={{ font: "400 30px/1.1 'Instrument Serif',serif", margin: 0 }}>Prototypes</h1>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        {APPS.map((x, i) => {
          const th = THEMES[i];
          return (
            <div
              key={x.name}
              className="hover-white"
              onClick={() => p.selectApp(i)}
              aria-current={i === p.s.app}
              style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '9px 10px', borderRadius: 8, cursor: 'pointer', background: i === p.s.app ? '#fff' : 'transparent' }}
            >
              <img src={ICON_URLS[`../icons/${APP_META[i].slug}/small.png`]} alt="" width={34} height={34} style={{ flex: 'none', display: 'block' }} />
              <div style={{ minWidth: 0 }}>
                <div style={{ fontSize: 15, fontWeight: 600, fontFamily: th.fh }}>{x.name}</div>
                <div style={{ fontSize: 11.5, color: '#777' }}>{th.style}</div>
              </div>
            </div>
          );
        })}
      </div>
    </nav>
  );
}

function Phone({ p }: { p: Proto }) {
  const { T } = p;
  return (
    <div style={{ width: 360, height: 740, background: T.bezel, borderRadius: 50, padding: 10, boxSizing: 'border-box', flex: 'none', boxShadow: '0 30px 60px -20px rgba(0,0,0,.4)' }}>
      <div style={{ width: '100%', height: '100%', borderRadius: 41, overflow: 'hidden' }}>
        <ScreenBody p={p} statusBar />
      </div>
    </div>
  );
}

/** The app itself: (fake) status bar, scrolling screen and tab bar. */
function ScreenBody({ p, statusBar = false, topPad = 0 }: { p: Proto; statusBar?: boolean; topPad?: number }) {
  const { T, s } = p;
  const View = SCREEN_VIEWS[s.screen];
  return (
    <div
      style={{
        width: '100%', height: '100%', display: 'flex', flexDirection: 'column', position: 'relative', overflow: 'hidden',
        background: T.bg, backgroundImage: T.bgImg, backgroundSize: T.bgSize, color: T.ink, fontFamily: T.fb, paddingTop: topPad, boxSizing: 'border-box',
      }}
    >
      {statusBar && (
        <div style={{ display: 'flex', justifyContent: 'space-between', padding: '14px 28px 6px', fontSize: 13, fontWeight: 600, flex: 'none', fontFamily: T.fb }}>
          <span>9:41</span>
          <Icon name="IconBattery" size={16} />
        </div>
      )}
      <div className="no-scrollbar" style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden', display: 'flex', flexDirection: 'column', paddingBottom: T.scrollPad }}>
        {/* Key by app + screen so scroll and transient UI reset when either changes. */}
        <View key={`${s.app}-${s.screen}`} p={p} />
      </div>
      <TabBar p={p} />
    </div>
  );
}

function StylePanel({ p }: { p: Proto }) {
  const { T, A, s } = p;
  const swatch = (bg: string, ring = true) => (
    <div style={{ width: 28, height: 28, borderRadius: 6, background: bg, boxShadow: ring ? 'inset 0 0 0 1px rgba(0,0,0,.1)' : undefined }} />
  );
  return (
    <aside style={{ width: 270, display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div style={{ display: 'flex', gap: 6 }}>
        {swatch(T.accent)}{swatch(T.accent2)}{swatch(T.bg)}{swatch(T.ink, false)}
      </div>
      <div style={{ fontSize: 30, lineHeight: 1.05, fontFamily: T.fh, fontWeight: T.hw, fontStyle: T.hi, textTransform: T.ht as 'none' }}>{A.name}</div>
      <div style={{ font: `600 11px ${mono}`, color: '#555', letterSpacing: '0.06em', textTransform: 'uppercase' }}>{T.style} · {T.fonts}</div>
      <div style={{ fontSize: 14, lineHeight: 1.55, color: '#444', textWrap: 'pretty' }}>{A.about}</div>
      <div style={{ font: `600 11px ${mono}`, color: '#777', letterSpacing: '0.08em' }}>JUMP TO SCREEN</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
        {SCREENS.map(([k, label], i) => (
          <div
            key={k}
            className="hover-white"
            onClick={() => p.jumpTo(k)}
            aria-current={s.screen === k}
            style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 10px', borderRadius: 6, cursor: 'pointer', fontSize: 14, fontWeight: 500, background: s.screen === k ? '#fff' : 'transparent' }}
          >
            <span style={{ font: `600 11px ${mono}`, color: '#999', width: 18 }}>{String(i + 1).padStart(2, '0')}</span>
            {label}
          </div>
        ))}
      </div>
    </aside>
  );
}
