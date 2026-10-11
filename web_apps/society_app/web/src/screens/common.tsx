import { useApp } from '../ctx';
import { E, MONTH_FULL, PURPOSES, type Pair } from '../lib/i18n';
import { relTime } from '../lib/format';
import type { Visitor } from '../lib/types';
import { Badge } from '../ui';

export const initials = (name: string) => name.split(/\s+/).filter(Boolean).slice(0, 2).map(w => w[0]).join('').toUpperCase();
export const firstName = (name: string) => name.split(/\s+/)[0];

export const VISITOR_BADGE: Record<Visitor['status'], [string, string]> = { inside: ['#0f172a', '#fff'], waiting: ['#ef4444', '#fff'], out: ['#f1f5f9', '#475569'], denied: ['#f1f5f9', '#ef4444'] };
export const COMPLAINT_STATUS = { open: ['#ef4444', '#fff', 1], progress: ['#0f172a', '#fff', 2], resolved: ['#f1f5f9', '#475569', 3] } as const;

export const purposeLabel = (p: string): Pair => PURPOSES.find(x => x[0] === p)?.[1] ?? PURPOSES[0][1];

export function useVisitorText() {
  const { st, L, x } = useApp();
  return (v: Visitor) => ({
    purpose: x(purposeLabel(v.purpose)),
    in: relTime(v.inAt, st.today, E.yesterday, L),
    outTxt: v.outAt ? ' → ' + relTime(v.outAt, st.today, E.yesterday, L) : '',
  });
}

export function VisitorBadge({ status }: { status: Visitor['status'] }) {
  const { T } = useApp();
  const [bg, fg] = VISITOR_BADGE[status];
  return <Badge bg={bg} fg={fg}>{T[status]}</Badge>;
}

/** "October maintenance collection" for the current month. */
export const collectionLabel = (today: string, L: 0 | 1) => {
  const m = MONTH_FULL[Number(today.slice(5, 7)) - 1];
  return L ? `${m[1]} maintenance collection` : `${m[0]} મેન્ટેનન્સ વસૂલાત`;
};
