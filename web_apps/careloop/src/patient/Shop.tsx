import { useState } from 'react';
import { DAY, LAB_PACKAGES, MEDICINES, fmtDay, medicineByName, startOfToday } from '../data/catalog';
import { REGIONS, money } from '../data/region';
import { Icon, TopBar, useToast, type Nav } from '../ui/kit';
import { useP } from './state';

// ---------------------------------------------------------------- lab tests

export function Labs({ nav, tests }: { nav: Nav; tests?: string[] }) {
  const { s } = useP();
  return (
    <div className="screen">
      <TopBar title="Lab tests at home" onBack={() => nav.back()} />
      <div className="pad stack gap-16" style={{ paddingBottom: 30 }}>
        <div className="hero">
          <div style={{ position: 'relative' }}>
            <span className="hero-pill"><Icon name="House" size={14} />Home sample collection</span>
            <div className="t-h1" style={{ marginTop: 12 }}>Certified labs, reports in 24 hours</div>
            <div className="t-sm" style={{ marginTop: 6 }}>A trained phlebotomist visits at a time you choose. Reports land in your records.</div>
          </div>
        </div>
        {tests && tests.length > 0 && (
          <div className="card p stack gap-10" style={{ boxShadow: 'inset 0 0 0 2px var(--brand), var(--shadow)' }}>
            <div className="row gap-8"><Icon name="FileText" size={18} className="t-brand" /><span className="t-h3">From your prescription</span></div>
            <div className="row wrap gap-6">{tests.map((t) => <span key={t} className="badge brand">{t}</span>)}</div>
            <button className="btn sm" onClick={() => nav.push('labBook', { pkgId: 'rx', tests })}>Book these {tests.length} tests</button>
          </div>
        )}
        <div className="t-h2">Popular packages</div>
        {LAB_PACKAGES.map((p) => {
          const off = Math.round((1 - p.price[s.region] / p.mrp[s.region]) * 100);
          return (
            <div key={p.id} className="card tap" style={{ padding: 16 }} onClick={() => nav.push('labBook', { pkgId: p.id })}>
              <div className="row between">
                <span className="t-h3">{p.name}</span>
                {p.popular ? <span className="badge accent">Bestseller</span> : <span className="badge good">{off}% off</span>}
              </div>
              <div className="t-sm" style={{ marginTop: 4 }}>{p.tests} tests · {p.includes.slice(0, 3).join(', ')} and more</div>
              <div className="row between" style={{ marginTop: 12 }}>
                <div className="row gap-8" style={{ alignItems: 'baseline' }}>
                  <span className="t-h2 num">{money(s.region, p.price[s.region])}</span>
                  <span className="t-sm num" style={{ textDecoration: 'line-through' }}>{money(s.region, p.mrp[s.region])}</span>
                </div>
                <span className="t-xs row gap-4"><Icon name="Clock" size={13} />{p.tat}</span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

const WINDOWS = ['6–7 AM', '7–8 AM', '8–9 AM', '9–10 AM', '10–11 AM'];

export function LabBook({ nav, pkgId, tests }: { nav: Nav; pkgId: string; tests?: string[] }) {
  const { s, set } = useP();
  const toast = useToast();
  const r = REGIONS[s.region];
  const pkg = pkgId === 'rx'
    ? { name: 'Prescribed tests', includes: tests ?? [], price: { IN: 650, US: 59 }, mrp: { IN: 900, US: 90 }, tat: 'Reports in 24 hrs' }
    : LAB_PACKAGES.find((p) => p.id === pkgId)!;
  const [day, setDay] = useState(startOfToday() + DAY);
  const [win, setWin] = useState(WINDOWS[1]);
  const price = pkg.price[s.region];
  const collection = s.plus ? 0 : r.homeCollection;
  const total = price + collection;

  return (
    <div className="screen has-cta">
      <TopBar title="Book test" onBack={() => nav.back()} />
      <div className="pad stack gap-16" style={{ paddingBottom: 12 }}>
        <div className="card p stack gap-10">
          <div className="t-h2">{pkg.name}</div>
          <div className="row wrap gap-6">{pkg.includes.map((t) => <span key={t} className="badge">{t}</span>)}</div>
          <div className="row gap-8 t-sm"><Icon name="Utensils" size={15} />Fast for 10–12 hours before the sample</div>
        </div>
        <div>
          <div className="t-h3" style={{ marginBottom: 10 }}>Collection date</div>
          <div className="hscroll">
            {[1, 2, 3, 4, 5].map((i) => {
              const t = startOfToday() + i * DAY;
              return (
                <button key={t} className={`date-pill${t === day ? ' on' : ''}`} onClick={() => setDay(t)}>
                  <span className="dow">{i === 1 ? 'Tmrw' : new Date(t).toLocaleDateString('en', { weekday: 'short' })}</span>
                  <span className="d num">{new Date(t).getDate()}</span>
                </button>
              );
            })}
          </div>
        </div>
        <div>
          <div className="t-h3" style={{ marginBottom: 10 }}>Time window</div>
          <div className="row wrap gap-8">{WINDOWS.map((w) => <button key={w} className={`chip${win === w ? ' on' : ''}`} onClick={() => setWin(w)}>{w}</button>)}</div>
        </div>
        <div className="card row gap-12" style={{ padding: 14 }}>
          <span className="tile-icon sm neutral"><Icon name="MapPin" size={18} /></span>
          <div className="grow"><div style={{ fontWeight: 700 }}>Home</div><div className="t-sm">{s.region === 'IN' ? '42, 12th Main, Indiranagar, Bengaluru 560038' : '2150 Mission St, Apt 4, San Francisco, CA 94110'}</div></div>
          <button className="btn xs ghost" onClick={() => toast('Address book coming soon')}>Change</button>
        </div>
        <div className="card p">
          <div className="kv"><span>Tests</span><span className="num">{money(s.region, price)}</span></div>
          <div className="kv"><span>You save</span><span className="num" style={{ color: 'var(--good)' }}>{money(s.region, pkg.mrp[s.region] - price)}</span></div>
          <div className="kv"><span>Home collection</span><span className="num">{collection ? money(s.region, collection) : 'Free with Plus'}</span></div>
          <div className="divider" />
          <div className="kv total"><span>Total</span><span className="num">{money(s.region, total)}</span></div>
        </div>
      </div>
      <div className="cta-bar solid">
        <button className="btn block" onClick={() => {
          set((p) => ({ ...p, orders: [{ id: `o-${Date.now()}`, kind: 'lab', title: `${pkg.name} · ${fmtDay(day)}, ${win}`, amount: total, t: Date.now(), status: 'Phlebotomist assigned' }, ...p.orders] }));
          toast('Test booked · we’ll text you the collector’s details');
          nav.reset();
          nav.push('orders');
        }}>Pay {money(s.region, total)} and book</button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- pharmacy

export function Pharmacy({ nav, apptId }: { nav: Nav; apptId?: string }) {
  const { s, set } = useP();
  const toast = useToast();
  const r = REGIONS[s.region];
  const rx = s.appts.find((a) => a.id === apptId)?.rx;
  const priceOf = (name: string) => medicineByName(name)?.price[s.region] ?? (s.region === 'IN' ? 165 : 18);
  const [cart, setCart] = useState<Record<string, number>>(() => Object.fromEntries((rx?.meds ?? []).map((m) => [m.name, 1])));
  const [query, setQuery] = useState('');
  const [placed, setPlaced] = useState(false);

  const items = Object.entries(cart).filter(([, q]) => q > 0);
  const subtotal = items.reduce((a, [n, q]) => a + priceOf(n) * q, 0);
  const discount = Math.round(subtotal * 0.15 * 100) / 100;
  const delivery = s.plus || subtotal - discount > (s.region === 'IN' ? 499 : 35) ? 0 : r.delivery;
  const total = Math.round((subtotal - discount + delivery) * 100) / 100;
  const results = MEDICINES.filter((m) => !cart[m.name] && m.name.toLowerCase().includes(query.toLowerCase())).slice(0, query ? 6 : 4);

  if (placed) {
    const steps = ['Order placed', 'Pharmacist verified prescription', 'Packed', 'Out for delivery'];
    return (
      <div className="screen stack" style={{ padding: '40px 24px 24px' }}>
        <div className="stack center gap-12" style={{ textAlign: 'center' }}>
          <div className="success-ring"><Icon name="PackageCheck" size={48} /></div>
          <div className="t-display" style={{ marginTop: 14 }}>Order placed</div>
          <div className="t-body">Arriving {s.region === 'IN' ? 'today by 8 PM' : 'tomorrow by noon'}. Pay {money(s.region, total)} online or on delivery.</div>
        </div>
        <div className="card p stack gap-14" style={{ marginTop: 24, flex: 1 }}>
          {steps.map((st, i) => (
            <div key={st} className="row gap-12">
              <span className="check-circle" style={{ background: i < 2 ? 'var(--good)' : 'var(--line)' }}>{i < 2 ? <Icon name="Check" size={14} stroke={3} /> : null}</span>
              <span style={{ fontWeight: i < 2 ? 700 : 500, color: i < 2 ? 'var(--ink)' : 'var(--muted)' }}>{st}</span>
            </div>
          ))}
        </div>
        <button className="btn block" style={{ marginTop: 20 }} onClick={() => nav.setTab('home')}>Done</button>
      </div>
    );
  }

  return (
    <div className="screen has-cta">
      <TopBar title="Order medicines" onBack={() => nav.back()} />
      <div className="pad stack gap-16" style={{ paddingBottom: 12 }}>
        {rx ? (
          <div className="row gap-10 card" style={{ padding: 12, background: 'var(--good-soft)', boxShadow: 'none' }}>
            <Icon name="FileCheck2" size={20} style={{ color: 'var(--good)' }} />
            <div className="t-sm" style={{ color: '#14532d', fontWeight: 600 }}>Prescription attached. A pharmacist checks it before dispatch.</div>
          </div>
        ) : (
          <button className="card tap row gap-12" onClick={() => toast('Prescription uploaded')} style={{ border: '2px dashed var(--line)', boxShadow: 'none', padding: 14, textAlign: 'left' }}>
            <span className="tile-icon"><Icon name="Upload" size={20} /></span>
            <div className="grow"><div className="t-h3">Upload a prescription</div><div className="t-sm">Needed for antibiotics and other Rx-only medicines</div></div>
          </button>
        )}
        {items.length > 0 && (
          <div className="list">
            {items.map(([name, q]) => (
              <div key={name} className="list-row no-tap">
                <span className="tile-icon sm neutral"><Icon name="Pill" size={18} /></span>
                <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>{name}</div><div className="t-sm num">{money(s.region, priceOf(name))} · strip of 10</div></div>
                <div className="row gap-6" style={{ background: 'var(--surface-2)', borderRadius: 12, padding: 3 }}>
                  <button className="icon-btn ghost" style={{ width: 30, height: 30 }} onClick={() => setCart({ ...cart, [name]: q - 1 })} aria-label="Less"><Icon name={q === 1 ? 'Trash2' : 'Minus'} size={15} /></button>
                  <span className="num" style={{ fontWeight: 800, minWidth: 16, textAlign: 'center' }}>{q}</span>
                  <button className="icon-btn ghost" style={{ width: 30, height: 30 }} onClick={() => setCart({ ...cart, [name]: q + 1 })} aria-label="More"><Icon name="Plus" size={15} /></button>
                </div>
              </div>
            ))}
          </div>
        )}
        <div className="search" style={{ boxShadow: 'inset 0 0 0 1.5px var(--line)' }}>
          <Icon name="Search" size={18} />
          <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Add a medicine" aria-label="Search medicines" />
        </div>
        <div className="stack gap-8">
          {results.map((m) => (
            <div key={m.name} className="row gap-10 card" style={{ padding: '10px 12px' }}>
              <div className="grow"><div style={{ fontWeight: 600, fontSize: 14 }}>{m.name}</div><div className="t-xs">{m.form} · {money(s.region, m.price[s.region])}</div></div>
              <button className="btn xs soft" onClick={() => setCart({ ...cart, [m.name]: 1 })}><Icon name="Plus" size={14} />Add</button>
            </div>
          ))}
        </div>
        {items.length > 0 && (
          <div className="card p">
            <div className="kv"><span>Item total</span><span className="num">{money(s.region, subtotal)}</span></div>
            <div className="kv"><span>CareLoop discount (15%)</span><span className="num" style={{ color: 'var(--good)' }}>−{money(s.region, discount)}</span></div>
            <div className="kv"><span>Delivery</span><span className="num">{delivery ? money(s.region, delivery) : 'Free'}</span></div>
            <div className="divider" />
            <div className="kv total"><span>To pay</span><span className="num">{money(s.region, total)}</span></div>
          </div>
        )}
      </div>
      <div className="cta-bar solid">
        <button className="btn block" disabled={!items.length} onClick={() => {
          set((p) => ({ ...p, orders: [{ id: `o-${Date.now()}`, kind: 'medicine', title: `${items.length} medicine${items.length > 1 ? 's' : ''}`, amount: total, t: Date.now(), status: 'Out for delivery' }, ...p.orders] }));
          setPlaced(true);
        }}>{items.length ? `Place order · ${money(s.region, total)}` : 'Add medicines to continue'}</button>
      </div>
    </div>
  );
}
