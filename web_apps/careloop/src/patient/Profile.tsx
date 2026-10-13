import { useState } from 'react';
import { fmtDay, relDay } from '../data/catalog';
import { REGIONS, money, type Region } from '../data/region';
import { Avatar, Empty, Icon, Sheet, Toggle, TopBar, useToast, type Nav } from '../ui/kit';
import { seed, useP } from './state';

export function Profile({ nav }: { nav: Nav }) {
  const { s, set } = useP();
  const toast = useToast();
  const [regionSheet, setRegionSheet] = useState(false);
  const rows: { icon: string; label: string; sub?: string; onClick: () => void; tone?: string }[] = [
    { icon: 'Users', label: 'Family members', sub: `${s.family.length} people on your account`, onClick: () => nav.push('family') },
    { icon: 'ShoppingBag', label: 'Orders', sub: 'Medicines and lab tests', onClick: () => nav.push('orders') },
    { icon: 'HeartPulse', label: 'Health profile', sub: `Blood ${s.user.blood} · Allergies: ${s.user.allergies}`, onClick: () => toast('Health profile is shared only with doctors you consult') },
    { icon: 'CreditCard', label: 'Payment methods', sub: REGIONS[s.region].pay.slice(0, 2).map((p) => p.label).join(', '), onClick: () => toast('Saved securely with your payment provider') },
    { icon: 'Globe', label: 'Country', sub: REGIONS[s.region].name, onClick: () => setRegionSheet(true) },
  ];
  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="Profile" left />
      <div className="pad stack gap-16">
        <div className="card p-lg row gap-16">
          <Avatar name={s.user.name} hue={200} size={64} />
          <div className="grow">
            <div className="t-h2">{s.user.name}</div>
            <div className="t-sm">{REGIONS[s.region].phonePrefix} {s.user.phone}</div>
            <div className="t-xs" style={{ marginTop: 4 }}>{s.user.age} y · {s.user.sex} · {s.appts.filter((a) => a.status === 'completed').length} visits</div>
          </div>
        </div>

        <button className="hero tap" onClick={() => nav.push('plus')} style={{ border: 0, textAlign: 'left', background: s.plus ? 'linear-gradient(135deg, #1f2937, #4b5563)' : 'linear-gradient(135deg, #ff7a59, #f43f5e)' }}>
          <div className="row gap-12" style={{ position: 'relative' }}>
            <span className="tile-icon" style={{ background: 'rgba(255,255,255,.2)', color: '#fff' }}><Icon name="Crown" size={22} /></span>
            <div className="grow">
              <div className="t-h3">{s.plus ? 'You’re a Plus member' : 'Get CareLoop Plus'}</div>
              <div className="t-sm">{s.plus ? `Renews ${s.plus.plan === 'yearly' ? 'yearly' : 'monthly'} · family covered` : `20% off consults and free delivery from ${money(s.region, REGIONS[s.region].plus.monthly)}/mo`}</div>
            </div>
            <Icon name="ChevronRight" size={20} />
          </div>
        </button>

        <div className="list">
          {rows.map((r) => (
            <div key={r.label} className="list-row" onClick={r.onClick}>
              <span className="tile-icon sm neutral"><Icon name={r.icon} size={18} /></span>
              <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>{r.label}</div>{r.sub && <div className="t-xs ellipsis">{r.sub}</div>}</div>
              <Icon name="ChevronRight" size={18} className="chev" />
            </div>
          ))}
        </div>
        <div className="list">
          <div className="list-row no-tap">
            <span className="tile-icon sm neutral"><Icon name="BellRing" size={18} /></span>
            <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>Medicine and visit reminders</div><div className="t-xs">15 min before visits, at each dose time</div></div>
            <Toggle on={s.reminders} onChange={(v) => set((p) => ({ ...p, reminders: v }))} label="Reminders" />
          </div>
          <div className="list-row" onClick={() => toast('Our care team replies within 5 minutes')}>
            <span className="tile-icon sm neutral"><Icon name="Headset" size={18} /></span>
            <div className="grow" style={{ fontWeight: 700, fontSize: 14.5 }}>Help and support</div>
            <Icon name="ChevronRight" size={18} className="chev" />
          </div>
          <div className="list-row" onClick={() => toast(REGIONS[s.region].compliance)}>
            <span className="tile-icon sm neutral"><Icon name="Lock" size={18} /></span>
            <div className="grow" style={{ fontWeight: 700, fontSize: 14.5 }}>Privacy and data</div>
            <Icon name="ChevronRight" size={18} className="chev" />
          </div>
        </div>
        <button className="btn block danger" onClick={() => set((p) => ({ ...seed(p.region), stage: 'welcome' }))}><Icon name="LogOut" size={18} />Sign out</button>
        <div className="t-xs" style={{ textAlign: 'center', paddingBottom: 8 }}>CareLoop 1.0 · Demo data, nothing leaves this phone</div>
      </div>

      <Sheet open={regionSheet} onClose={() => setRegionSheet(false)}>
        <div className="t-h2" style={{ marginBottom: 6 }}>Switch country</div>
        <div className="t-sm" style={{ marginBottom: 14 }}>Doctors, prices and payment options change to match. Your demo data resets.</div>
        <div className="stack gap-10">
          {(['IN', 'US'] as Region[]).map((r) => (
            <button key={r} className="btn block ghost" style={{ justifyContent: 'space-between', boxShadow: s.region === r ? 'inset 0 0 0 2px var(--brand)' : undefined }}
              onClick={() => { set((p) => ({ ...seed(r, p.user.name), stage: 'app' })); setRegionSheet(false); toast(`Switched to ${REGIONS[r].name}`); }}>
              {REGIONS[r].name}<span className="t-sm">{r === 'IN' ? '₹ · UPI' : '$ · Insurance'}</span>
            </button>
          ))}
        </div>
      </Sheet>
    </div>
  );
}

export function Plus({ nav }: { nav: Nav }) {
  const { s, set } = useP();
  const toast = useToast();
  const r = REGIONS[s.region];
  const [plan, setPlan] = useState<'monthly' | 'yearly'>('yearly');
  const perks = [
    { icon: 'BadgePercent', title: '20% off every consultation', sub: 'Video and clinic, all specialties' },
    { icon: 'Receipt', title: 'No booking fees', sub: `Save ${money(s.region, r.bookingFee)} on every visit` },
    { icon: 'Truck', title: 'Free medicine delivery', sub: 'And free home sample collection' },
    { icon: 'MessageCircle', title: 'Unlimited GP chat', sub: 'Quick questions answered in minutes' },
    { icon: 'Users', title: 'Covers 4 family members', sub: 'One plan for the whole household' },
  ];
  const yearlySave = Math.round(r.plus.monthly * 12 - r.plus.yearly);
  return (
    <div className="screen has-cta">
      <TopBar onBack={() => nav.back()} />
      <div className="pad stack gap-16" style={{ paddingBottom: 12 }}>
        <div className="stack center gap-8" style={{ textAlign: 'center' }}>
          <span className="tile-icon accent" style={{ width: 64, height: 64, borderRadius: 22 }}><Icon name="Crown" size={30} /></span>
          <div className="t-display" style={{ marginTop: 6 }}>CareLoop Plus</div>
          <div className="t-body">Members save on average {money(s.region, s.region === 'IN' ? 3800 : 260)} a year.</div>
        </div>
        <div className="stack gap-10">
          {(['yearly', 'monthly'] as const).map((p) => (
            <button key={p} className="card tap row gap-12" onClick={() => setPlan(p)} style={{ border: 0, padding: 16, textAlign: 'left', boxShadow: plan === p ? 'inset 0 0 0 2px var(--accent), var(--shadow)' : 'var(--shadow)' }}>
              <span className={`radio${plan === p ? ' on' : ''}`} style={plan === p ? { boxShadow: 'inset 0 0 0 7px var(--accent)' } : undefined} />
              <div className="grow">
                <div className="row gap-8"><span className="t-h3">{p === 'yearly' ? 'Yearly' : 'Monthly'}</span>{p === 'yearly' && <span className="badge accent">Save {money(s.region, yearlySave)}</span>}</div>
                <div className="t-sm">{p === 'yearly' ? `${money(s.region, Math.round((r.plus.yearly / 12) * 100) / 100)}/month, billed yearly` : 'Cancel anytime'}</div>
              </div>
              <span className="t-h2 num">{money(s.region, p === 'yearly' ? r.plus.yearly : r.plus.monthly)}</span>
            </button>
          ))}
        </div>
        <div className="card p stack gap-14">
          {perks.map((p) => (
            <div key={p.title} className="row gap-12">
              <span className="tile-icon sm accent"><Icon name={p.icon} size={18} /></span>
              <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>{p.title}</div><div className="t-xs">{p.sub}</div></div>
            </div>
          ))}
        </div>
      </div>
      <div className="cta-bar solid">
        {s.plus ? (
          <button className="btn block ghost" onClick={() => { set((p) => ({ ...p, plus: null })); toast('Plus cancelled'); nav.back(); }}>Cancel membership</button>
        ) : (
          <button className="btn block accent" onClick={() => {
            const amount = plan === 'yearly' ? r.plus.yearly : r.plus.monthly;
            set((p) => ({ ...p, plus: { plan, since: Date.now() }, orders: [{ id: `o-${Date.now()}`, kind: 'plus', title: `CareLoop Plus (${plan})`, amount, t: Date.now(), status: 'Active' }, ...p.orders] }));
            toast('Welcome to Plus! Discounts are live');
            nav.back();
          }}>Join Plus · {money(s.region, plan === 'yearly' ? r.plus.yearly : r.plus.monthly)}</button>
        )}
      </div>
    </div>
  );
}

export function Family({ nav }: { nav: Nav }) {
  const { s, set } = useP();
  const toast = useToast();
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  const [relation, setRelation] = useState('Parent');
  const [age, setAge] = useState('');
  return (
    <div className="screen has-cta">
      <TopBar title="Family members" onBack={() => nav.back()} />
      <div className="pad stack gap-12">
        <div className="t-sm">Book visits and keep records for everyone in one account.</div>
        <div className="list">
          <div className="list-row no-tap"><Avatar name={s.user.name} hue={200} size={44} /><div className="grow"><div className="t-h3">{s.user.name}</div><div className="t-sm">You · {s.user.age} y</div></div></div>
          {s.family.map((f, i) => (
            <div key={f.name} className="list-row no-tap">
              <Avatar name={f.name} hue={(i * 70 + 20) % 360} size={44} />
              <div className="grow"><div className="t-h3">{f.name}</div><div className="t-sm">{f.relation} · {f.age} y</div></div>
            </div>
          ))}
        </div>
      </div>
      <div className="cta-bar solid"><button className="btn block soft" onClick={() => setOpen(true)}><Icon name="UserPlus" size={18} />Add family member</button></div>
      <Sheet open={open} onClose={() => setOpen(false)}>
        <div className="stack gap-14">
          <div className="t-h2">Add family member</div>
          <div className="field"><label>Name</label><input className="input" value={name} onChange={(e) => setName(e.target.value)} autoFocus /></div>
          <div className="row wrap gap-8">{['Parent', 'Spouse', 'Child', 'Sibling', 'Other'].map((r) => <button key={r} className={`chip${relation === r ? ' on' : ''}`} onClick={() => setRelation(r)}>{r}</button>)}</div>
          <div className="field"><label>Age</label><input className="input" inputMode="numeric" value={age} onChange={(e) => setAge(e.target.value.replace(/\D/g, '').slice(0, 3))} /></div>
          <button className="btn block" disabled={!name.trim() || !age} onClick={() => {
            set((p) => ({ ...p, family: [...p.family, { name: name.trim(), relation, age: Number(age) }] }));
            setOpen(false); setName(''); setAge('');
            toast('Family member added');
          }}>Save</button>
        </div>
      </Sheet>
    </div>
  );
}

export function Orders({ nav }: { nav: Nav }) {
  const { s } = useP();
  const icon = { medicine: 'Pill', lab: 'FlaskConical', plus: 'Crown' } as const;
  return (
    <div className="screen">
      <TopBar title="Orders" onBack={() => nav.back()} />
      <div className="pad">
        {s.orders.length === 0 ? <Empty icon="ShoppingBag" title="No orders yet" body="Medicines and lab tests you order show up here." /> : (
          <div className="list">
            {s.orders.map((o) => (
              <div key={o.id} className="list-row no-tap">
                <span className="tile-icon sm"><Icon name={icon[o.kind]} size={18} /></span>
                <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }} className="ellipsis">{o.title}</div><div className="t-xs">{fmtDay(o.t)} · {o.status}</div></div>
                <span className="num" style={{ fontWeight: 800 }}>{money(s.region, o.amount)}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export function Notifications({ nav }: { nav: Nav }) {
  const { s, doctor } = useP();
  const up = s.appts.find((a) => a.status === 'upcoming');
  const items = [
    up && { icon: 'CalendarClock', title: 'Visit reminder', body: `${doctor(up.doctorId).name} · ${relDay(up.t)}`, when: 'Now', tone: '' },
    { icon: 'FlaskConical', title: 'CBC report is ready', body: '2 values to review with your doctor', when: '3 days ago', tone: 'good' },
    { icon: 'Pill', title: 'Time for Cetirizine 10 mg', body: 'Bedtime dose · tap to mark taken', when: 'Yesterday', tone: 'accent' },
    { icon: 'BadgePercent', title: 'Full body checkup at 60% off', body: 'This week only, with free home collection', when: '2 days ago', tone: 'neutral' },
  ].filter(Boolean) as { icon: string; title: string; body: string; when: string; tone: string }[];
  return (
    <div className="screen">
      <TopBar title="Notifications" onBack={() => nav.back()} />
      <div className="pad"><div className="list">
        {items.map((n) => (
          <div key={n.title} className="list-row no-tap" style={{ alignItems: 'flex-start' }}>
            <span className={`tile-icon sm ${n.tone}`}><Icon name={n.icon} size={18} /></span>
            <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>{n.title}</div><div className="t-sm">{n.body}</div></div>
            <span className="t-xs">{n.when}</span>
          </div>
        ))}
      </div></div>
    </div>
  );
}
