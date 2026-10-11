import { MON_EN, MON_GU, type Pair } from './i18n';

const TZ = 'Asia/Kolkata';
export const fmt = (n: number) => '₹' + Math.round(n).toLocaleString('en-IN');

const ymd = (iso: string) => iso.length === 10 ? iso : new Intl.DateTimeFormat('en-CA', { timeZone: TZ }).format(new Date(iso));
/** "07 Oct" — the prototype uses English month abbreviations in both languages. */
export const dayMon = (isoOrYmd: string) => { const d = ymd(isoOrYmd); return `${d.slice(8)} ${MON_EN[Number(d.slice(5, 7)) - 1]}`; };
export const dayMonYear = (isoOrYmd: string) => `${dayMon(isoOrYmd)} ${ymd(isoOrYmd).slice(0, 4)}`;
export const monUpper = (d: string) => MON_EN[Number(d.slice(5, 7)) - 1].toUpperCase();
export const dayMonLocal = (d: string, L: 0 | 1) => `${Number(d.slice(8))} ${(L ? MON_EN : MON_GU)[Number(d.slice(5, 7)) - 1]}`;
export const hm = (iso: string) => new Intl.DateTimeFormat('en-GB', { timeZone: TZ, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(new Date(iso));
export const addDays = (d: string, n: number) => { const x = new Date(d + 'T00:00:00Z'); x.setUTCDate(x.getUTCDate() + n); return x.toISOString().slice(0, 10); };
export const dow = (d: string) => new Date(d + 'T00:00:00Z').getUTCDay();

/** Time of day for today, otherwise "Yesterday" or a short date. */
export const relTime = (iso: string, today: string, yesterday: Pair, L: 0 | 1) => {
  const d = ymd(iso);
  return d === today ? hm(iso) : d === addDays(today, -1) ? yesterday[L] : dayMon(iso);
};
