// Typed ports of the shadcn/ui design system components used by the app (same markup and classes as _ds_bundle.js).
import { useId, type ButtonHTMLAttributes, type CSSProperties, type InputHTMLAttributes, type ReactNode, type SVGProps, type TextareaHTMLAttributes } from 'react';
import icons from './icons.json';
import './colors.css';
import './spacing.css';
import './typography.css';
import './components.css';

const ICONS: Record<string, { viewBox: string; body: string }> = {
  ...icons,
  // Not in the design system's icon set; drawn to match its 2px outline style.
  IconReceipt: {
    viewBox: '0 0 24 24',
    body: '<g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 2v20l2-1 2 1 2-1 2 1 2-1 2 1 2-1 2 1V2l-2 1-2-1-2 1-2-1-2 1-2-1-2 1Z"/><path d="M16 8h-6a2 2 0 1 0 0 4h4a2 2 0 1 1 0 4H8"/><path d="M12 17.5v-11"/></g>',
  },
};

export type IconName = string;

export function Icon({ name, size, ...rest }: { name: IconName; size: number } & Omit<SVGProps<SVGSVGElement>, 'name'>) {
  const d = ICONS[name];
  if (!d) return null;
  return <svg width={size} height={size} viewBox={d.viewBox} fill="none" aria-hidden dangerouslySetInnerHTML={{ __html: d.body }} {...rest} />;
}

const VARIANT = { default: '', destructive: 'sc-btn--destructive', outline: 'sc-btn--outline', subtle: 'sc-btn--subtle', ghost: 'sc-btn--ghost', link: 'sc-btn--link' };
export type ButtonVariant = keyof typeof VARIANT;

export function Button({ variant = 'default', icon, loading = false, children, className = '', type = 'button', ...rest }:
  { variant?: ButtonVariant; icon?: IconName; loading?: boolean } & ButtonHTMLAttributes<HTMLButtonElement>) {
  const cls = ['sc-btn', VARIANT[variant], loading ? 'sc-btn--loading' : '', icon ? 'has-icon' : '', className].filter(Boolean).join(' ');
  return (
    <button type={type} className={cls} aria-busy={loading || undefined} {...rest}>
      {loading ? <span className="sc-btn-spinner" /> : null}
      {!loading && icon ? <Icon name={icon} size={16} style={{ flex: 'none', display: 'block' }} /> : null}
      {children}
    </button>
  );
}

export function Input({ label, style, ...rest }: { label?: ReactNode } & InputHTMLAttributes<HTMLInputElement>) {
  const id = useId();
  return (
    <div className="sc sc-field" style={style}>
      {label ? <label htmlFor={id} className="sc-field-label">{label}</label> : null}
      <div className="sc-field-row">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6, flex: 1, minWidth: 0 }}>
          <input id={id} className="sc-input" {...rest} />
        </div>
      </div>
    </div>
  );
}

export function Textarea({ label, style, ...rest }: { label?: ReactNode } & TextareaHTMLAttributes<HTMLTextAreaElement>) {
  const id = useId();
  return (
    <div className="sc sc-textarea-wrap" style={style}>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        {label ? <label htmlFor={id} className="sc-field-label" style={{ lineHeight: '14px' }}>{label}</label> : null}
        <textarea id={id} className="sc-textarea" style={{ width: '100%' }} {...rest} />
      </div>
    </div>
  );
}

export function Switch({ label, checked, onChange, style }: { label?: ReactNode; checked: boolean; onChange: (v: boolean) => void; style?: CSSProperties }) {
  return (
    <button type="button" role="switch" aria-checked={checked} className={'sc sc-switch' + (checked ? ' is-on' : '')} style={style} onClick={() => onChange(!checked)}>
      <span className="sc-switch-track"><span className="sc-switch-thumb" /></span>
      {label ? <span className="sc-label" style={{ lineHeight: '20px' }}>{label}</span> : null}
    </button>
  );
}

export function Progress({ value, style }: { value: number; style?: CSSProperties }) {
  const v = Math.max(0, Math.min(100, value));
  return (
    <div role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(v)} className="sc sc-progress" style={{ width: '100%', ...style }}>
      <div className="sc-progress-bar" style={{ width: v + '%' }} />
    </div>
  );
}

export function Avatar({ initials, size = 40 }: { initials: string; size?: number }) {
  return <span className="sc sc-avatar" style={{ width: size, height: size }}>{initials}</span>;
}
