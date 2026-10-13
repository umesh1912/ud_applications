import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react';
import { ChevronLeft, Star, CheckCircle2 } from 'lucide-react';
import { ICONS } from './icons';

// ---------------------------------------------------------------- icons

export function Icon({ name, size = 20, stroke = 2, className, style }: { name: string; size?: number; stroke?: number; className?: string; style?: React.CSSProperties }) {
  const C = ICONS[name];
  if (!C) {
    if (import.meta.env.DEV) console.error(`Icon "${name}" is not registered in ui/icons.ts`);
    return null;
  }
  return <C size={size} strokeWidth={stroke} className={className} style={{ flex: 'none', ...style }} />;
}

// ---------------------------------------------------------------- avatar

export function initials(name: string) {
  return name.replace(/^Dr\.\s*/, '').split(/\s+/).map((w) => w[0]).slice(0, 2).join('').toUpperCase();
}

/** Portrait stand-in: initials on a soft two-tone gradient derived from `hue`. */
export function Avatar({ name, hue = 168, size = 48, square, online }: { name: string; hue?: number; size?: number; square?: boolean; online?: boolean }) {
  return (
    <div
      className={`avatar${square ? ' square' : ''}`}
      style={{ width: size, height: size, fontSize: size * 0.36, background: `linear-gradient(140deg, hsl(${hue} 62% 52%), hsl(${(hue + 28) % 360} 58% 38%))` }}
      aria-hidden
    >
      {initials(name)}
      {online && <span className="online" />}
    </div>
  );
}

export function Stars({ rating, count }: { rating: number; count?: number }) {
  return (
    <span className="stars">
      <Star size={14} strokeWidth={0} />
      {rating.toFixed(1)}
      {count !== undefined && <span className="t-sm" style={{ fontWeight: 500 }}>({count.toLocaleString()})</span>}
    </span>
  );
}

// ---------------------------------------------------------------- bars

export function TopBar({ title, onBack, right, left, surface }: { title?: ReactNode; onBack?: () => void; right?: ReactNode; left?: boolean; surface?: boolean }) {
  return (
    <div className={`topbar${surface ? ' on-surface' : ''}`}>
      {onBack ? (
        <button className="icon-btn" onClick={onBack} aria-label="Back"><ChevronLeft size={22} /></button>
      ) : !left ? <span style={{ width: 42 }} /> : null}
      <div className={`title${left ? ' left' : ''}`}>{title}</div>
      {right ?? (left ? null : <span style={{ width: 42 }} />)}
    </div>
  );
}

export interface Tab { id: string; label: string; icon: string; count?: number; fab?: boolean }

export function TabBar({ tabs, active, onChange }: { tabs: Tab[]; active: string; onChange: (id: string) => void }) {
  return (
    <nav className="tabbar">
      {tabs.map((t) =>
        t.fab ? (
          <button key={t.id} className="fab" onClick={() => onChange(t.id)} aria-label={t.label}>
            <Icon name={t.icon} size={26} />
          </button>
        ) : (
          <button key={t.id} className={active === t.id ? 'on' : ''} onClick={() => onChange(t.id)}>
            <span className="pill"><Icon name={t.icon} size={22} stroke={active === t.id ? 2.4 : 2} /></span>
            {t.label}
            {!!t.count && <span className="count">{t.count}</span>}
          </button>
        ),
      )}
    </nav>
  );
}

export function Segmented<T extends string>({ options, value, onChange }: { options: { id: T; label: string }[]; value: T; onChange: (v: T) => void }) {
  return (
    <div className="segmented" role="tablist">
      {options.map((o) => (
        <button key={o.id} role="tab" aria-selected={value === o.id} className={value === o.id ? 'on' : ''} onClick={() => onChange(o.id)}>{o.label}</button>
      ))}
    </div>
  );
}

export function Toggle({ on, onChange, label }: { on: boolean; onChange: (v: boolean) => void; label?: string }) {
  return <button className={`toggle${on ? ' on' : ''}`} role="switch" aria-checked={on} aria-label={label} onClick={() => onChange(!on)} />;
}

export function SectionHead({ title, action, onAction }: { title: string; action?: string; onAction?: () => void }) {
  return (
    <div className="section-head">
      <div className="t-h2">{title}</div>
      {action && <button className="link" onClick={onAction}>{action}</button>}
    </div>
  );
}

// ---------------------------------------------------------------- sheet

export function Sheet({ open, onClose, children }: { open: boolean; onClose: () => void; children: ReactNode }) {
  if (!open) return null;
  return (
    <div className="scrim" onClick={onClose}>
      <div className="sheet" onClick={(e) => e.stopPropagation()} role="dialog">
        <div className="grabber" />
        {children}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- toast

const ToastCtx = createContext<(msg: string) => void>(() => {});
export const useToast = () => useContext(ToastCtx);

export function ToastHost({ children }: { children: ReactNode }) {
  const [msg, setMsg] = useState<string | null>(null);
  const timer = useRef<number | undefined>(undefined);
  const show = useCallback((m: string) => {
    setMsg(m);
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => setMsg(null), 2400);
  }, []);
  return (
    <ToastCtx.Provider value={show}>
      {children}
      {msg && <div className="toast" role="status"><CheckCircle2 size={20} />{msg}</div>}
    </ToastCtx.Provider>
  );
}

// ---------------------------------------------------------------- navigation

export interface Route { name: string; params?: Record<string, unknown> }

/** Tabs, each with its own stack of pushed screens. `back()` returns false at a tab root. */
export function useNav(initialTab: string) {
  const [tab, setTabState] = useState(initialTab);
  const [stack, setStack] = useState<Route[]>([]);
  const nav = {
    tab,
    top: stack[stack.length - 1] as Route | undefined,
    depth: stack.length,
    push: (name: string, params?: Record<string, unknown>) => setStack((s) => [...s, { name, params }]),
    replace: (name: string, params?: Record<string, unknown>) => setStack((s) => [...s.slice(0, -1), { name, params }]),
    back: () => {
      if (stack.length === 0) return false;
      setStack((s) => s.slice(0, -1));
      return true;
    },
    reset: () => setStack([]),
    setTab: (t: string) => { setTabState(t); setStack([]); },
  };
  return nav;
}
export type Nav = ReturnType<typeof useNav>;

// ---------------------------------------------------------------- persistent state

/** useState that survives app restarts (localStorage). */
export function usePersistent<T>(key: string, initial: () => T) {
  const [state, setState] = useState<T>(() => {
    try {
      const raw = localStorage.getItem(key);
      if (raw) return JSON.parse(raw) as T;
    } catch { /* fall back to the seed */ }
    return initial();
  });
  useEffect(() => {
    try { localStorage.setItem(key, JSON.stringify(state)); } catch { /* storage unavailable */ }
  }, [key, state]);
  return [state, setState] as const;
}

// ---------------------------------------------------------------- misc

export function useNow(intervalMs = 30000) {
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), intervalMs);
    return () => window.clearInterval(id);
  }, [intervalMs]);
  return now;
}

export function Empty({ icon, title, body, action }: { icon: string; title: string; body: string; action?: ReactNode }) {
  return (
    <div className="empty stack center gap-12">
      <div className="tile-icon" style={{ width: 64, height: 64, borderRadius: 22 }}><Icon name={icon} size={28} /></div>
      <div className="t-h3" style={{ color: 'var(--ink)' }}>{title}</div>
      <div className="t-sm" style={{ maxWidth: 260 }}>{body}</div>
      {action}
    </div>
  );
}
