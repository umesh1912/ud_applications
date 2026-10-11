// All society-facing dates and times are in India Standard Time.
const TZ = 'Asia/Kolkata';

const parts = (d: Date) => {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat('en-GB', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })
      .formatToParts(d).map(x => [x.type, x.value]),
  );
  return { y: p.year, m: p.month, d: p.day, hh: p.hour, mm: p.minute };
};

/** YYYY-MM-DD in IST. */
export const today = (d = new Date()) => { const p = parts(d); return `${p.y}-${p.m}-${p.d}`; };
/** HH:MM in IST. */
export const nowHM = (d = new Date()) => { const p = parts(d); return `${p.hh}:${p.mm}`; };
/** YYYY-MM billing period in IST. */
export const period = (d = new Date()) => today(d).slice(0, 7);
export const nowIso = () => new Date().toISOString();
/** Adds days to a YYYY-MM-DD string. */
export const addDays = (ymd: string, n: number) => {
  const d = new Date(ymd + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10);
};
/** ISO timestamp for a given IST date and HH:MM. */
export const istIso = (ymd: string, hm: string) => new Date(`${ymd}T${hm}:00+05:30`).toISOString();
