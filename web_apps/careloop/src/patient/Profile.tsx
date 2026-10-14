import { useState } from 'react';
import { addDoc, collection } from 'firebase/firestore';
import { fmtDay, fmtTime, relDay } from '../data/catalog';
import { REGIONS, money } from '../data/region';
import { logOut, resetPassword } from '../lib/auth';
import { lastRead } from '../lib/care';
import { errorText } from '../lib/db';
import { db } from '../lib/firebase';
import { usePay } from '../lib/pay';
import { Avatar, Empty, Icon, Sheet, Toggle, TopBar, useToast, type Nav } from '../ui/kit';
import { hasPlus, isUpcoming, updateMe, useP } from './ctx';

export function Profile({ nav }: { nav: Nav }) {
  const { uid, me, region, appts } = useP();
  const toast = useToast();
  const [confirmOut, setConfirmOut] = useState(false);
  const rows: { icon: string; label: string; sub?: string; onClick: () => void }[] = [
    { icon: 'UserPen', label: 'Personal and health details', sub: `${me.age} y · Blood ${me.blood} · Allergies: ${me.allergies}`, onClick: () => nav.push('editProfile') },
    { icon: 'Users', label: 'Family members', sub: `${me.family?.length ?? 0} people on your account`, onClick: () => nav.push('family') },
    { icon: 'ShoppingBag', label: 'Orders and payments', sub: 'Medicines, lab tests, memberships', onClick: () => nav.push('orders') },
    { icon: 'KeyRound', label: 'Change password', sub: me.email ?? 'Phone login', onClick: async () => {
      if (!me.email) { toast('You log in with a phone code, so there’s no password'); return; }
      try { await resetPassword(me.email); toast(`Password reset link sent to ${me.email}`); } catch (e) { toast(errorText(e)); }
    } },
  ];
  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="Profile" left />
      <div className="pad stack gap-16">
        <div className="card p-lg row gap-16">
          <Avatar name={me.name} hue={200} size={64} />
          <div className="grow" style={{ minWidth: 0 }}>
            <div className="t-h2">{me.name}</div>
            <div className="t-sm ellipsis">{me.email ?? me.phone}</div>
            <div className="t-xs" style={{ marginTop: 4 }}>{REGIONS[region].name} · {(appts ?? []).filter((a) => a.status === 'completed').length} visits</div>
          </div>
        </div>

        <button className="hero tap" onClick={() => nav.push('plus')} style={{ border: 0, textAlign: 'left', background: hasPlus(me) ? 'linear-gradient(135deg, #1f2937, #4b5563)' : 'linear-gradient(135deg, #ff7a59, #f43f5e)' }}>
          <div className="row gap-12" style={{ position: 'relative' }}>
            <span className="tile-icon" style={{ background: 'rgba(255,255,255,.2)', color: '#fff' }}><Icon name="Crown" size={22} /></span>
            <div className="grow">
              <div className="t-h3">{hasPlus(me) ? 'You’re a Plus member' : 'Get CareLoop Plus'}</div>
              <div className="t-sm">{hasPlus(me) ? `Active until ${fmtDay(me.plus!.until)}` : `20% off consults and free delivery from ${money(region, REGIONS[region].plus.monthly)}/mo`}</div>
            </div>
            <Icon name="ChevronRight" size={20} />
          </div>
        </button>

        <div className="list">
          {rows.map((r) => (
            <div key={r.label} className="list-row" onClick={r.onClick}>
              <span className="tile-icon sm neutral"><Icon name={r.icon} size={18} /></span>
              <div className="grow" style={{ minWidth: 0 }}><div style={{ fontWeight: 700, fontSize: 14.5 }}>{r.label}</div>{r.sub && <div className="t-xs ellipsis">{r.sub}</div>}</div>
              <Icon name="ChevronRight" size={18} className="chev" />
            </div>
          ))}
        </div>
        <div className="list">
          <div className="list-row no-tap">
            <span className="tile-icon sm neutral"><Icon name="BellRing" size={18} /></span>
            <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>Visit reminders</div><div className="t-xs">Shown in the app before each visit</div></div>
            <Toggle on={me.reminders !== false} onChange={(v) => updateMe(uid, { reminders: v })} label="Reminders" />
          </div>
          <div className="list-row" onClick={() => toast(REGIONS[region].compliance)}>
            <span className="tile-icon sm neutral"><Icon name="Lock" size={18} /></span>
            <div className="grow" style={{ fontWeight: 700, fontSize: 14.5 }}>Privacy and data</div>
            <Icon name="ChevronRight" size={18} className="chev" />
          </div>
        </div>
        <button className="btn block danger" onClick={() => setConfirmOut(true)}><Icon name="LogOut" size={18} />Log out</button>
        <div className="t-xs" style={{ textAlign: 'center', paddingBottom: 8 }}>CareLoop 2.0</div>
      </div>
      <Sheet open={confirmOut} onClose={() => setConfirmOut(false)}>
        <div className="stack gap-12">
          <div className="t-h2">Log out?</div>
          <div className="t-body">Your visits and records stay safe in your account. Log in again any time.</div>
          <button className="btn block danger" onClick={() => logOut()}>Log out</button>
          <button className="btn block ghost" onClick={() => setConfirmOut(false)}>Stay logged in</button>
        </div>
      </Sheet>
    </div>
  );
}

const CONDITIONS = ['Diabetes', 'Hypertension', 'Asthma', 'Thyroid', 'Heart disease', 'PCOS'];

export function EditProfile({ nav }: { nav: Nav }) {
  const { uid, me } = useP();
  const toast = useToast();
  const [name, setName] = useState(me.name);
  const [phone, setPhone] = useState(me.phone ?? '');
  const [age, setAge] = useState(String(me.age ?? ''));
  const [blood, setBlood] = useState(me.blood ?? '');
  const [allergies, setAllergies] = useState(me.allergies ?? '');
  const [conditions, setConditions] = useState<string[]>(me.conditions ?? []);
  const [busy, setBusy] = useState(false);
  return (
    <form className="screen has-cta" onSubmit={async (e) => {
      e.preventDefault(); setBusy(true);
      try {
        await updateMe(uid, { name: name.trim(), phone: phone.trim(), age: Number(age), blood, allergies: allergies.trim() || 'None', conditions });
        toast('Profile saved'); nav.back();
      } catch (x) { toast(errorText(x)); setBusy(false); }
    }}>
      <TopBar title="Your details" onBack={() => nav.back()} />
      <div className="pad stack gap-14" style={{ paddingBottom: 12 }}>
        <div className="field"><label>Full name</label><input className="input" value={name} onChange={(e) => setName(e.target.value)} /></div>
        <div className="field"><label>Mobile number</label><input className="input" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} /></div>
        <div className="row gap-12">
          <div className="field" style={{ width: 100 }}><label>Age</label><input className="input" inputMode="numeric" value={age} onChange={(e) => setAge(e.target.value.replace(/\D/g, '').slice(0, 3))} /></div>
          <div className="field grow"><label>Blood group</label><input className="input" value={blood} onChange={(e) => setBlood(e.target.value)} /></div>
        </div>
        <div className="field"><label>Long-term conditions</label><div className="row wrap gap-6">{CONDITIONS.map((c) => <button type="button" key={c} className={`chip${conditions.includes(c) ? ' on' : ''}`} onClick={() => setConditions(conditions.includes(c) ? conditions.filter((x) => x !== c) : [...conditions, c])} style={{ height: 34 }}>{c}</button>)}</div></div>
        <div className="field"><label>Allergies</label><input className="input" value={allergies} onChange={(e) => setAllergies(e.target.value)} /></div>
      </div>
      <div className="cta-bar solid"><button className="btn block" type="submit" disabled={busy || name.trim().length < 2 || !Number(age)}>{busy ? <span className="spinner" /> : 'Save'}</button></div>
    </form>
  );
}

export function Plus({ nav }: { nav: Nav }) {
  const { uid, me, region } = useP();
  const pay = usePay();
  const toast = useToast();
  const r = REGIONS[region];
  const [plan, setPlan] = useState<'monthly' | 'yearly'>('yearly');
  const [busy, setBusy] = useState(false);
  const active = hasPlus(me);
  const perks = [
    { icon: 'BadgePercent', title: '20% off every consultation', sub: 'Video and clinic, all specialties' },
    { icon: 'Receipt', title: 'No booking fees', sub: `Save ${money(region, r.bookingFee)} on every visit` },
    { icon: 'Truck', title: 'Free medicine delivery', sub: 'And free home sample collection' },
    { icon: 'Users', title: 'Covers your whole family', sub: 'Everyone on your account' },
  ];
  const yearlySave = Math.round(r.plus.monthly * 12 - r.plus.yearly);
  const amount = plan === 'yearly' ? r.plus.yearly : r.plus.monthly;

  const join = async () => {
    const payment = await pay({ region, amount, title: `CareLoop Plus (${plan})`, prefill: { name: me.name, email: me.email, phone: me.phone } });
    if (!payment) return;
    setBusy(true);
    try {
      const until = Date.now() + (plan === 'yearly' ? 365 : 30) * 86400000;
      await updateMe(uid, { plus: { plan, since: Date.now(), until, paymentRef: payment.ref } });
      await addDoc(collection(db, 'orders'), { patientId: uid, kind: 'plus', title: `CareLoop Plus (${plan})`, amount, t: Date.now(), payment });
      toast('Welcome to Plus! Discounts apply from your next booking');
      nav.back();
    } catch (e) { toast(errorText(e)); setBusy(false); }
  };

  return (
    <div className="screen has-cta">
      <TopBar onBack={() => nav.back()} />
      <div className="pad stack gap-16" style={{ paddingBottom: 12 }}>
        <div className="stack center gap-8" style={{ textAlign: 'center' }}>
          <span className="tile-icon accent" style={{ width: 64, height: 64, borderRadius: 22 }}><Icon name="Crown" size={30} /></span>
          <div className="t-display" style={{ marginTop: 6 }}>CareLoop Plus</div>
          <div className="t-body">{active ? `Your ${me.plus!.plan} plan is active until ${fmtDay(me.plus!.until)}.` : 'Pays for itself after about two visits a year.'}</div>
        </div>
        {!active && (
          <div className="stack gap-10">
            {(['yearly', 'monthly'] as const).map((p) => (
              <button key={p} className="card tap row gap-12" onClick={() => setPlan(p)} style={{ border: 0, padding: 16, textAlign: 'left', boxShadow: plan === p ? 'inset 0 0 0 2px var(--accent), var(--shadow)' : 'var(--shadow)' }}>
                <span className={`radio${plan === p ? ' on' : ''}`} style={plan === p ? { boxShadow: 'inset 0 0 0 7px var(--accent)' } : undefined} />
                <div className="grow">
                  <div className="row gap-8"><span className="t-h3">{p === 'yearly' ? 'Yearly' : 'Monthly'}</span>{p === 'yearly' && <span className="badge accent">Save {money(region, yearlySave)}</span>}</div>
                  <div className="t-sm">{p === 'yearly' ? `${money(region, Math.round((r.plus.yearly / 12) * 100) / 100)}/month, billed yearly` : 'Renew each month'}</div>
                </div>
                <span className="t-h2 num">{money(region, p === 'yearly' ? r.plus.yearly : r.plus.monthly)}</span>
              </button>
            ))}
          </div>
        )}
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
        {active
          ? <button className="btn block ghost" onClick={() => nav.back()}>Done</button>
          : <button className="btn block accent" disabled={busy} onClick={join}>{busy ? <span className="spinner" /> : `Join Plus · ${money(region, amount)}`}</button>}
      </div>
    </div>
  );
}

export function Family({ nav }: { nav: Nav }) {
  const { uid, me } = useP();
  const toast = useToast();
  const [open, setOpen] = useState(false);
  const [name, setName] = useState('');
  const [relation, setRelation] = useState('Parent');
  const [age, setAge] = useState('');
  const family = me.family ?? [];
  return (
    <div className="screen has-cta">
      <TopBar title="Family members" onBack={() => nav.back()} />
      <div className="pad stack gap-12">
        <div className="t-sm">Book visits and keep records for everyone in one account.</div>
        <div className="list">
          <div className="list-row no-tap"><Avatar name={me.name} hue={200} size={44} /><div className="grow"><div className="t-h3">{me.name}</div><div className="t-sm">You · {me.age} y</div></div></div>
          {family.map((f, i) => (
            <div key={f.name} className="list-row no-tap">
              <Avatar name={f.name} hue={(i * 70 + 20) % 360} size={44} />
              <div className="grow"><div className="t-h3">{f.name}</div><div className="t-sm">{f.relation} · {f.age} y</div></div>
              <button className="icon-btn ghost" aria-label={`Remove ${f.name}`} onClick={async () => { await updateMe(uid, { family: family.filter((x) => x.name !== f.name) }); toast(`${f.name} removed`); }}><Icon name="Trash2" size={17} /></button>
            </div>
          ))}
        </div>
      </div>
      <div className="cta-bar solid"><button className="btn block soft" onClick={() => setOpen(true)}><Icon name="UserPlus" size={18} />Add family member</button></div>
      <Sheet open={open} onClose={() => setOpen(false)}>
        <form className="stack gap-14" onSubmit={async (e) => {
          e.preventDefault();
          if (family.some((f) => f.name.toLowerCase() === name.trim().toLowerCase())) { toast('That name is already on your account'); return; }
          await updateMe(uid, { family: [...family, { name: name.trim(), relation, age: Number(age) }] });
          setOpen(false); setName(''); setAge(''); toast('Family member added');
        }}>
          <div className="t-h2">Add family member</div>
          <div className="field"><label htmlFor="fm-name">Name</label><input id="fm-name" className="input" value={name} onChange={(e) => setName(e.target.value)} autoFocus /></div>
          <div className="row wrap gap-8">{['Parent', 'Spouse', 'Child', 'Sibling', 'Other'].map((r) => <button type="button" key={r} className={`chip${relation === r ? ' on' : ''}`} onClick={() => setRelation(r)}>{r}</button>)}</div>
          <div className="field"><label htmlFor="fm-age">Age</label><input id="fm-age" className="input" inputMode="numeric" value={age} onChange={(e) => setAge(e.target.value.replace(/\D/g, '').slice(0, 3))} /></div>
          <button className="btn block" type="submit" disabled={name.trim().length < 2 || !age}>Save</button>
        </form>
      </Sheet>
    </div>
  );
}

export function Orders({ nav }: { nav: Nav }) {
  const { region, orders, appts } = useP();
  const icon = { medicine: 'Pill', lab: 'FlaskConical', plus: 'Crown', plan: 'Gem' } as const;
  const rows = [
    ...(orders ?? []).map((o) => ({ id: o.id, icon: icon[o.kind], title: o.title, t: o.t, amount: o.amount, sub: o.kind === 'lab' ? `Collection ${fmtDay(o.scheduledFor ?? o.t)}` : o.kind === 'medicine' ? 'Pharmacist review, then delivery' : 'Membership', ref: o.payment.ref, refund: false })),
    ...(appts ?? []).map((a) => ({ id: a.id, icon: a.mode === 'video' ? 'Video' : 'Building2', title: `Visit · ${a.doctorName}`, t: a.createdAt, amount: a.payment.amount, sub: a.status === 'cancelled' ? 'Cancelled · refund in 3–5 days' : `${relDay(a.t)}, ${fmtTime(a.t)}`, ref: a.payment.ref, refund: a.payment.status === 'refund-pending' })),
  ].sort((a, b) => b.t - a.t);
  return (
    <div className="screen">
      <TopBar title="Orders and payments" onBack={() => nav.back()} />
      <div className="pad">
        {rows.length === 0 ? <Empty icon="ShoppingBag" title="Nothing yet" body="Visits, medicines and lab tests you pay for show up here." /> : (
          <div className="list">
            {rows.map((o) => (
              <div key={o.id} className="list-row no-tap">
                <span className="tile-icon sm"><Icon name={o.icon} size={18} /></span>
                <div className="grow" style={{ minWidth: 0 }}><div style={{ fontWeight: 700, fontSize: 14.5 }} className="ellipsis">{o.title}</div><div className="t-xs ellipsis">{fmtDay(o.t)} · {o.sub}</div></div>
                <div style={{ textAlign: 'right' }}><div className="num" style={{ fontWeight: 800 }}>{money(region, o.amount)}</div>{o.refund && <span className="badge warn">Refunding</span>}</div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export function Notifications({ nav }: { nav: Nav }) {
  const { appts, reports, inbox } = useP();
  const now = Date.now();
  const latestPerVisit = inbox.filter((m, i) => inbox.findIndex((x) => x.apptId === m.apptId) === i);
  const items = [
    ...latestPerVisit.map((m) => ({ id: `m-${m.id}`, icon: 'MessageCircle', title: `${lastRead(m.apptId) < m.t ? 'New message' : 'Message'} from ${m.fromName}`, body: m.text, t: m.t, tone: lastRead(m.apptId) < m.t ? 'accent' : 'neutral', go: () => nav.push('chat', { id: m.apptId }) })),
    ...(appts ?? []).filter((a) => isUpcoming(a, now)).map((a) => ({ id: a.id, icon: 'CalendarClock', title: `Visit with ${a.doctorName}`, body: `${relDay(a.t)}, ${fmtTime(a.t)} · ${a.mode === 'video' ? 'video' : 'clinic'}`, t: a.t, tone: '', go: () => nav.push('appt', { id: a.id }) })),
    ...(appts ?? []).filter((a) => a.rx && a.rx.signedAt > now - 14 * 86400000).map((a) => ({ id: `rx-${a.id}`, icon: 'FileText', title: 'Prescription ready', body: `${a.doctorName} · ${a.rx!.diagnosis}`, t: a.rx!.signedAt, tone: 'good', go: () => nav.push('rx', { id: a.id }) })),
    ...(reports ?? []).filter((r) => r.t > now - 14 * 86400000).map((r) => ({ id: r.id, icon: 'FlaskConical', title: 'Record added', body: r.name, t: r.t, tone: 'neutral', go: () => nav.push('report', { id: r.id }) })),
  ].sort((a, b) => b.t - a.t);
  return (
    <div className="screen">
      <TopBar title="Notifications" onBack={() => nav.back()} />
      <div className="pad">
        {items.length === 0 ? <Empty icon="Bell" title="You’re all caught up" body="Visit reminders, prescriptions and reports appear here." /> : (
          <div className="list">
            {items.map((n) => (
              <div key={n.id} className="list-row" onClick={n.go} style={{ alignItems: 'flex-start' }}>
                <span className={`tile-icon sm ${n.tone}`}><Icon name={n.icon} size={18} /></span>
                <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>{n.title}</div><div className="t-sm">{n.body}</div></div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
