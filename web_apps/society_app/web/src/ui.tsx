// Repeated building blocks from the prototype, with its exact inline values.
import type { CSSProperties, ReactNode } from 'react';
import { Icon } from './ds';

export const C = { ink: '#0f172a', muted: '#64748b', line: '#e2e8f0', soft: '#f1f5f9', red: '#ef4444', body: '#475569', faint: '#94a3b8' };
export const ring = (color = C.line, w = '1px') => `inset 0 0 0 ${w} ${color}`;
export const col = (gap: number, extra?: CSSProperties): CSSProperties => ({ display: 'flex', flexDirection: 'column', gap, ...extra });
export const wide: CSSProperties = { width: '100%' };
export const wideTall: CSSProperties = { width: '100%', height: 48, fontSize: 15 };
export const btnReset: CSSProperties = { border: 0, cursor: 'pointer', color: C.ink, fontFamily: 'inherit' };

export const Stack = ({ gap, children, style }: { gap: number; children: ReactNode; style?: CSSProperties }) => <div style={col(gap, style)}>{children}</div>;
export const Label = ({ children, style }: { children: ReactNode; style?: CSSProperties }) =>
  <div style={{ fontSize: 13, fontWeight: 600, color: C.muted, ...style }}>{children}</div>;
export const Card = ({ children, style, accent }: { children: ReactNode; style?: CSSProperties; accent?: boolean }) =>
  <div style={{ borderRadius: 6, boxShadow: ring(accent ? C.ink : C.line), ...style }}>{children}</div>;
export const Row = ({ children, style }: { children: ReactNode; style?: CSSProperties }) =>
  <div style={{ padding: '12px 14px', display: 'flex', gap: 10, alignItems: 'center', borderBottom: `1px solid ${C.soft}`, ...style }}>{children}</div>;
export const Lines = ({ title, sub, titleWeight = 600, gap = 2 }: { title: ReactNode; sub?: ReactNode; titleWeight?: number; gap?: number }) => (
  <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap }}>
    <div style={{ fontSize: 14, fontWeight: titleWeight }}>{title}</div>
    {sub !== undefined && <div style={{ fontSize: 12, color: C.muted }}>{sub}</div>}
  </div>
);
export const Badge = ({ bg, fg, children, size = 12 }: { bg: string; fg: string; children: ReactNode; size?: number }) =>
  <span style={{ fontSize: size, fontWeight: 600, padding: size === 12 ? '3px 8px' : '2px 8px', borderRadius: 40, background: bg, color: fg, whiteSpace: 'nowrap' }}>{children}</span>;
export const IconBox = ({ name, box = 40, size = 20, radius = 6, bg = C.soft, color }: { name: string; box?: number; size?: number; radius?: number; bg?: string; color?: string }) => (
  <div style={{ width: box, height: box, borderRadius: radius, background: bg, color, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none' }}>
    <Icon name={name} size={size} />
  </div>
);
export const pill = (on: boolean) => ({ background: on ? C.ink : '#fff', color: on ? '#fff' : C.ink });
export const Chip = ({ on, onClick, children, square }: { on: boolean; onClick: () => void; children: ReactNode; square?: boolean }) => (
  <button onClick={onClick} style={{ ...btnReset, height: square ? 36 : 34, padding: square ? '0 14px' : '0 12px', borderRadius: square ? 6 : 40, fontSize: square ? 14 : 13, fontWeight: 600, boxShadow: ring(), ...pill(on) }}>{children}</button>
);
export const Chips = ({ children }: { children: ReactNode }) => <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>{children}</div>;
export const FieldLabel = ({ children }: { children: ReactNode }) => <div style={{ fontSize: 14, fontWeight: 500 }}>{children}</div>;
export const Empty = ({ children }: { children: ReactNode }) => <div style={{ padding: 16, fontSize: 14, color: C.muted, textAlign: 'center' }}>{children}</div>;
export const IconBtn = ({ name, onClick, size = 16, box = 32, round, bg = 'transparent', label }: { name: string; onClick: () => void; size?: number; box?: number; round?: boolean; bg?: string; label: string }) => (
  <button aria-label={label} className={bg === 'transparent' ? 'hov' : undefined} onClick={onClick} style={{ ...btnReset, width: box, height: box, borderRadius: round ? box : 6, background: bg, display: 'flex', alignItems: 'center', justifyContent: 'center', flex: 'none' }}>
    <Icon name={name} size={size} />
  </button>
);
