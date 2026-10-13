import { useState } from 'react';
import { fmtDay, specialtyOf } from '../data/catalog';
import { Sparkline } from '../ui/charts';
import { Empty, Icon, Segmented, Sheet, TopBar, useToast, type Nav } from '../ui/kit';
import { useP, type PatientState } from './state';

type Kind = 'rx' | 'reports' | 'vitals';

export function Records({ nav }: { nav: Nav }) {
  const { s, set, doctor } = useP();
  const toast = useToast();
  const [tab, setTab] = useState<Kind>('rx');
  const [upload, setUpload] = useState(false);
  const [logVital, setLogVital] = useState<null | keyof PatientState['vitals']>(null);
  const [val, setVal] = useState('');
  const rxs = s.appts.filter((a) => a.rx).sort((a, b) => b.t - a.t);

  const addUpload = (name: string) => {
    set((p) => ({ ...p, reports: [{ id: `r-${Date.now()}`, name, t: Date.now(), lab: 'Uploaded by you', status: 'processing', items: [] }, ...p.reports] }));
    setUpload(false);
    setTab('reports');
    toast('Uploaded · we’re reading the values');
  };

  const VITALS: { key: keyof PatientState['vitals']; label: string; unit: string; icon: string; fmt: (v: number) => string; range: string }[] = [
    { key: 'bp', label: 'Blood pressure (systolic)', unit: 'mmHg', icon: 'HeartPulse', fmt: (v) => `${v}/78`, range: 'Target below 120' },
    { key: 'sugar', label: 'Fasting blood sugar', unit: 'mg/dL', icon: 'Droplet', fmt: (v) => String(v), range: 'Normal 70–99' },
    { key: 'weight', label: 'Weight', unit: 'kg', icon: 'Scale', fmt: (v) => v.toFixed(1), range: 'BMI 24.8' },
  ];

  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="Health records" left right={<button className="icon-btn" onClick={() => setUpload(true)} aria-label="Upload"><Icon name="Upload" size={19} /></button>} />
      <div className="pad stack gap-16">
        <div className="card row gap-12" style={{ padding: 14 }}>
          <span className="tile-icon"><Icon name="ShieldCheck" size={22} /></span>
          <div className="grow"><div className="t-h3">{s.user.name}</div><div className="t-sm">{s.user.age} y · {s.user.sex} · Blood {s.user.blood} · Allergic to {s.user.allergies.toLowerCase()}</div></div>
        </div>
        <Segmented options={[{ id: 'rx', label: 'Prescriptions' }, { id: 'reports', label: 'Reports' }, { id: 'vitals', label: 'Vitals' }]} value={tab} onChange={setTab} />

        {tab === 'rx' && (rxs.length ? (
          <div className="list">
            {rxs.map((a) => {
              const d = doctor(a.doctorId);
              return (
                <div key={a.id} className="list-row" onClick={() => nav.push('rx', { id: a.id })}>
                  <span className="tile-icon"><Icon name="FileText" size={20} /></span>
                  <div className="grow">
                    <div className="t-h3 ellipsis">{a.rx!.diagnosis}</div>
                    <div className="t-sm">{d.name} · {specialtyOf(d.specialty).name}</div>
                    <div className="t-xs" style={{ marginTop: 2 }}>{fmtDay(a.t)} · {a.member.split(' ')[0]}</div>
                  </div>
                  <Icon name="ChevronRight" size={18} className="chev" />
                </div>
              );
            })}
          </div>
        ) : <Empty icon="FileText" title="No prescriptions yet" body="Prescriptions from your CareLoop visits appear here automatically." />)}

        {tab === 'reports' && (
          <div className="list">
            {s.reports.map((r) => {
              const flagged = r.items.filter((i) => i.flag !== 'normal').length;
              return (
                <div key={r.id} className="list-row" onClick={() => r.status === 'ready' && nav.push('report', { id: r.id })}>
                  <span className={`tile-icon ${r.status === 'ready' ? 'good' : 'neutral'}`}><Icon name={r.status === 'ready' ? 'FlaskConical' : 'Loader'} size={20} /></span>
                  <div className="grow">
                    <div className="t-h3 ellipsis">{r.name}</div>
                    <div className="t-sm">{r.lab} · {fmtDay(r.t)}</div>
                  </div>
                  {r.status === 'processing' ? <span className="badge">Processing</span> : flagged ? <span className="badge warn">{flagged} to review</span> : <span className="badge good">All normal</span>}
                </div>
              );
            })}
          </div>
        )}

        {tab === 'vitals' && (
          <div className="stack gap-12">
            {VITALS.map((v) => {
              const data = s.vitals[v.key];
              return (
                <div key={v.key} className="card p stack gap-12">
                  <div className="row gap-10">
                    <span className="tile-icon sm"><Icon name={v.icon} size={18} /></span>
                    <div className="grow"><div className="t-h3">{v.label}</div><div className="t-xs">{v.range} · last 7 readings</div></div>
                    <button className="btn xs soft" onClick={() => { setLogVital(v.key); setVal(''); }}><Icon name="Plus" size={14} />Log</button>
                  </div>
                  <div className="row between" style={{ alignItems: 'flex-end' }}>
                    <div className="row gap-4" style={{ alignItems: 'baseline' }}><span className="t-display num">{v.fmt(data[data.length - 1])}</span><span className="t-sm">{v.unit}</span></div>
                    <Sparkline values={data} width={150} height={48} />
                  </div>
                </div>
              );
            })}
            <button className="card tap row gap-12" onClick={() => nav.push('search', { specialty: 'endo' })} style={{ border: 0, padding: 14, textAlign: 'left' }}>
              <span className="tile-icon accent"><Icon name="Stethoscope" size={20} /></span>
              <div className="grow"><div className="t-h3">Share trends with a doctor</div><div className="t-sm">Your readings are attached to the visit automatically</div></div>
              <Icon name="ChevronRight" size={18} className="chev" />
            </button>
          </div>
        )}
      </div>

      <Sheet open={upload} onClose={() => setUpload(false)}>
        <div className="t-h2" style={{ marginBottom: 6 }}>Add a record</div>
        <div className="t-sm" style={{ marginBottom: 14 }}>Old prescriptions, reports from other labs, discharge summaries.</div>
        <div className="list" style={{ boxShadow: 'inset 0 0 0 1px var(--line)' }}>
          {[{ icon: 'Camera', label: 'Take a photo', name: 'Scanned prescription' }, { icon: 'FileUp', label: 'Upload a PDF', name: 'Thyroid profile (PDF)' }, { icon: 'Images', label: 'Choose from gallery', name: 'X-ray report' }].map((o) => (
            <div key={o.label} className="list-row" onClick={() => addUpload(o.name)}>
              <span className="tile-icon sm"><Icon name={o.icon} size={18} /></span>
              <div className="grow t-h3">{o.label}</div>
              <Icon name="ChevronRight" size={18} className="chev" />
            </div>
          ))}
        </div>
      </Sheet>

      <Sheet open={!!logVital} onClose={() => setLogVital(null)}>
        {logVital && (() => {
          const v = VITALS.find((x) => x.key === logVital)!;
          return (
            <div className="stack gap-12">
              <div className="t-h2">Log {v.label.toLowerCase()}</div>
              <div className="row gap-10">
                <input className="input num" inputMode="decimal" autoFocus value={val} onChange={(e) => setVal(e.target.value.replace(/[^\d.]/g, ''))} placeholder={v.fmt(s.vitals[logVital].at(-1)!)} style={{ fontSize: 22, fontWeight: 800 }} />
                <span className="t-h3" style={{ width: 70 }}>{v.unit}</span>
              </div>
              <button className="btn block" disabled={!Number(val)} onClick={() => {
                set((p) => ({ ...p, vitals: { ...p.vitals, [logVital]: [...p.vitals[logVital].slice(1), Number(val)] } }));
                setLogVital(null);
                toast('Reading saved');
              }}>Save reading</button>
            </div>
          );
        })()}
      </Sheet>
    </div>
  );
}

export function ReportView({ nav, id }: { nav: Nav; id: string }) {
  const { s } = useP();
  const toast = useToast();
  const r = s.reports.find((x) => x.id === id)!;
  return (
    <div className="screen has-cta">
      <TopBar title="Report" onBack={() => nav.back()} right={<button className="icon-btn" onClick={() => toast('Report PDF shared')} aria-label="Share"><Icon name="Share2" size={19} /></button>} />
      <div className="pad stack gap-16">
        <div>
          <div className="t-h1">{r.name}</div>
          <div className="t-sm" style={{ marginTop: 4 }}>{r.lab} · Collected {fmtDay(r.t)}</div>
        </div>
        <div className="list">
          {r.items.map((i) => (
            <div key={i.name} className="list-row no-tap">
              <div className="grow">
                <div style={{ fontWeight: 700 }}>{i.name}</div>
                <div className="t-xs">Range {i.range} {i.unit}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div className="num" style={{ fontWeight: 800, fontSize: 17, color: i.flag === 'normal' ? 'var(--ink)' : 'var(--warn)' }}>{i.value} <span className="t-xs">{i.unit}</span></div>
                <span className={`badge ${i.flag === 'normal' ? 'good' : 'warn'}`}>{i.flag === 'normal' ? 'Normal' : i.flag === 'high' ? 'High' : 'Low'}</span>
              </div>
            </div>
          ))}
        </div>
        <div className="card row gap-10" style={{ padding: 14, background: 'var(--brand-soft)', boxShadow: 'none' }}>
          <Icon name="Info" size={18} className="t-brand" />
          <div className="t-sm" style={{ color: 'var(--brand-strong)' }}>Values outside the range aren’t always a problem. A doctor can explain what they mean for you.</div>
        </div>
      </div>
      <div className="cta-bar solid">
        <button className="btn block" onClick={() => nav.push('search', { specialty: r.name.includes('Lipid') ? 'cardio' : 'gp' })}><Icon name="Stethoscope" size={18} />Ask a doctor about this report</button>
      </div>
    </div>
  );
}
