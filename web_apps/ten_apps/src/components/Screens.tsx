import { Icon } from '../icons';
import type { Proto } from '../prototype';
import { stripes } from '../theme';
import { Hero } from './Hero';
import { ItemList } from './ItemList';

type P = { p: Proto };

function Placeholder({ p, height, w, caption }: P & { height: number; w: number; caption: string }) {
  const { T, S } = p;
  return (
    <div style={{ height, borderRadius: T.r, background: stripes(T, w), boxShadow: T.tileRing, display: 'flex', alignItems: 'flex-end', padding: 12, boxSizing: 'border-box' }}>
      <span style={S.placeholderCaption}>{caption}</span>
    </div>
  );
}

function Back({ p, label, onClick }: P & { label: string; onClick: () => void }) {
  return (
    <div onClick={onClick} style={p.S.back}>
      <Icon name="IconChevronLeft" size={20} />
      {label}
    </div>
  );
}

export function Onboarding({ p }: P) {
  const { T, S, A, s } = p;
  const [icon, title, body] = A.onboard[s.slide];
  const last = s.slide === A.onboard.length - 1;
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
      {T.onb === 'Top' && (
        <div style={{ margin: '6px 14px 0', height: 300, borderRadius: T.r, background: T.accent, color: T.onAccent, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', overflow: 'hidden', boxShadow: T.blockShadow }}>
          <div style={{ position: 'absolute', width: 260, height: 260, borderRadius: '50%', right: -80, top: -90, background: T.accent2, opacity: 0.9 }} />
          <div style={{ position: 'relative' }}><Icon name={icon} size={96} /></div>
          <span style={{ position: 'absolute', left: 18, bottom: 14, fontFamily: T.fl, fontSize: 12, letterSpacing: '0.08em' }}>
            {`0${s.slide + 1} / 0${A.onboard.length}`}
          </span>
        </div>
      )}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', padding: '20px 24px 28px', gap: 16 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={S.brand}>{A.name}</span>
          <span onClick={p.skipOnboard} style={S.link}>Skip</span>
        </div>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 16 }}>
          {T.onb === 'Center' && (
            <div style={{ width: 120, height: 120, borderRadius: T.markR, background: T.accent, color: T.onAccent, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: T.blockShadow }}>
              <Icon name={icon} size={52} />
            </div>
          )}
          <div style={S.h1}>{title}</div>
          <div style={S.body}>{body}</div>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          {A.onboard.map((_, i) => (
            <div key={i} style={{ height: 6, borderRadius: T.dotR, width: i === s.slide ? 28 : 8, background: i === s.slide ? T.accent : T.line, transition: 'width 200ms' }} />
          ))}
        </div>
        <div onClick={p.nextSlide} style={S.btn}>{last ? 'Get started' : 'Continue'}</div>
      </div>
    </div>
  );
}

export function Home({ p }: P) {
  const { S, A } = p;
  return (
    <div style={{ padding: '8px 20px 20px', display: 'flex', flexDirection: 'column', gap: 20 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={S.brandLg}>{A.name}</span>
        <Icon name="IconBell" size={20} />
      </div>
      <Hero p={p} />
      <div style={S.label}>{A.homeTitle}</div>
      <ItemList p={p} />
    </div>
  );
}

export function SecondTab({ p }: P) {
  const { T, S, A } = p;
  return (
    <div style={{ padding: '8px 20px 20px', display: 'flex', flexDirection: 'column', gap: 18 }}>
      <div style={S.h1}>{A.tab2.title}</div>
      <Placeholder p={p} height={160} w={12} caption={A.tab2.ph} />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {A.tab2.items.map(([t, sub, r]) => (
          <div key={t} style={S.cardRow}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 15, fontWeight: T.tw }}>{t}</div>
              <div style={{ fontSize: 12, color: T.muted }}>{sub}</div>
            </div>
            <span style={S.badge}>{r}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

export function Detail({ p }: P) {
  const { T, S, A, item } = p;
  return (
    <div style={{ padding: '4px 20px 24px', display: 'flex', flexDirection: 'column', gap: 16, flex: 1 }}>
      <Back p={p} label="Back" onClick={p.goHome} />
      <Placeholder p={p} height={190} w={12} caption={`photo · ${item.t}`} />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        <div style={S.h1}>{item.t}</div>
        <div style={{ fontSize: 13, color: T.muted }}>{item.s}</div>
      </div>
      <div style={S.body}>{item.d}</div>
      <div style={S.card}>
        {item.f.map(([l, v]) => (
          <div key={l} style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', fontSize: 14, borderBottom: `1px solid ${T.line}` }}>
            <span style={{ color: T.muted }}>{l}</span>
            <span style={{ fontWeight: 700 }}>{v}</span>
          </div>
        ))}
      </div>
      <div style={{ flex: 1 }} />
      <div onClick={p.doAction} style={S.btn}>{A.action}</div>
    </div>
  );
}

export function Create({ p }: P) {
  const { T, S, A, s, step, pick, stepCount: n } = p;
  return (
    <div style={{ padding: '4px 20px 24px', display: 'flex', flexDirection: 'column', gap: 20, flex: 1 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span onClick={p.goHome} style={{ cursor: 'pointer', display: 'flex' }} aria-label="Close"><Icon name="IconX" size={22} /></span>
        <span style={S.label}>{`Step ${Math.min(s.step + 1, n)} of ${n}`}</span>
      </div>
      <div style={{ height: 6, borderRadius: T.dotR, background: T.line, overflow: 'hidden' }}>
        <div style={{ height: '100%', width: Math.round(((s.step + 1) / (n + 1)) * 100) + '%', background: T.accent, transition: 'width 250ms' }} />
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        <span style={S.labelAccent}>{A.create.title}</span>
        <span style={S.h1}>{step.q}</span>
      </div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {step.o.map((o) => (
          <div
            key={o}
            onClick={() => p.pickOption(o)}
            style={{
              padding: '12px 16px', borderRadius: T.chipR, fontSize: T.chipSize || 14, fontWeight: 600, cursor: 'pointer', fontFamily: T.fb, transition: 'all 150ms',
              ...(pick === o ? T.chipOn : { color: T.ink, ...T.chipOff }),
            }}
          >
            {o}
          </div>
        ))}
      </div>
      <div style={{ flex: 1 }} />
      <div style={{ display: 'flex', gap: 10 }}>
        {s.step > 0 && <div onClick={p.prevStep} style={S.btnGhostHalf}>Back</div>}
        <div onClick={p.nextStep} style={S.btnNext} aria-disabled={!pick}>Continue</div>
      </div>
    </div>
  );
}

export function Review({ p }: P) {
  const { T, S, A, s } = p;
  return (
    <div style={{ padding: '4px 20px 24px', display: 'flex', flexDirection: 'column', gap: 20, flex: 1 }}>
      <Back p={p} label="Edit" onClick={p.prevStep} />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        <span style={S.labelAccent}>{A.create.title}</span>
        <span style={S.h1}>Check and confirm</span>
      </div>
      <div style={S.card}>
        {A.create.steps.map((st, i) => (
          <div key={st.q} style={{ display: 'flex', flexDirection: 'column', gap: 3, padding: '12px 0', borderBottom: `1px solid ${T.line}` }}>
            <span style={{ fontSize: 12, color: T.muted }}>{st.q}</span>
            <span style={{ fontSize: 16, fontWeight: 700 }}>{s.picks[i] || '—'}</span>
          </div>
        ))}
      </div>
      <div style={{ flex: 1 }} />
      <div onClick={p.submitCreate} style={S.btn}>{A.create.cta}</div>
    </div>
  );
}

export function Confirm({ p }: P) {
  const { T, S, conf } = p;
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '24px 28px 28px', gap: 16, textAlign: 'center' }}>
      <div style={{ width: 104, height: 104, borderRadius: T.markR, background: T.accent, color: T.onAccent, display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: T.blockShadow }}>
        <Icon name="IconCheck" size={48} />
      </div>
      <div style={S.h1Top}>{conf.t}</div>
      <div style={S.body}>{conf.b}</div>
      <div style={{ height: 20 }} />
      <div onClick={p.goHome} style={S.btnStretch}>Done</div>
    </div>
  );
}

export function Settings({ p }: P) {
  const { T, S, A } = p;
  return (
    <div style={{ padding: '8px 20px 20px', display: 'flex', flexDirection: 'column', gap: 18 }}>
      <div style={S.h1}>Profile</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
        <div style={{ width: 60, height: 60, borderRadius: T.markR, background: T.accent, color: T.onAccent, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: T.fh, fontSize: 20, fontWeight: 700, flex: 'none', boxShadow: T.blockShadow }}>
          {A.user.i}
        </div>
        <div>
          <div style={S.h2}>{A.user.n}</div>
          <div style={{ fontSize: 13, color: T.muted, marginTop: 2 }}>{A.user.m}</div>
        </div>
      </div>
      <div style={S.label}>Settings</div>
      <div style={S.card}>
        {A.settings.map((label, i) => {
          const on = p.settingOn(i);
          return (
            <div key={label} onClick={() => p.toggleSetting(i)} role="switch" aria-checked={on} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 0', borderBottom: `1px solid ${T.line}`, cursor: 'pointer' }}>
              <span style={{ flex: 1, fontSize: 14, lineHeight: 1.35 }}>{label}</span>
              <div style={{ width: 44, height: 26, borderRadius: T.toggleR, background: on ? T.trackOn : T.trackOff, boxShadow: T.toggleRing, position: 'relative', flex: 'none', transition: 'background 150ms' }}>
                <div style={{ position: 'absolute', top: 3, left: on ? 21 : 3, width: 20, height: 20, borderRadius: T.toggleR, background: on ? T.knobOn : T.knobOff, transition: 'left 150ms' }} />
              </div>
            </div>
          );
        })}
      </div>
      <div onClick={p.replayOnboard} style={S.btnGhost}>Replay onboarding</div>
      <div onClick={p.replayOnboard} style={{ textAlign: 'center', fontSize: 14, fontWeight: 600, color: '#e5484d', cursor: 'pointer', padding: 6 }}>Sign out</div>
    </div>
  );
}
