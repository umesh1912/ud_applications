import { useRef, useState } from 'react';
import { addDoc, collection, deleteDoc, doc } from 'firebase/firestore';
import { fmtDay } from '../data/catalog';
import { errorText } from '../lib/db';
import { db } from '../lib/firebase';
import type { UserDoc } from '../lib/model';
import { Sparkline } from '../ui/charts';
import { Empty, Icon, Segmented, Sheet, TopBar, useToast, type Nav } from '../ui/kit';
import { updateMe, useP } from './ctx';

type Kind = 'rx' | 'reports' | 'vitals';
type VitalKey = keyof NonNullable<UserDoc['vitals']>;

/** Shrinks a photo to ~1200px JPEG so it fits in a Firestore document (≤ ~400 KB). */
function compressImage(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      const scale = Math.min(1, 1200 / Math.max(img.width, img.height));
      const c = document.createElement('canvas');
      c.width = Math.round(img.width * scale); c.height = Math.round(img.height * scale);
      c.getContext('2d')!.drawImage(img, 0, 0, c.width, c.height);
      let q = 0.75, out = c.toDataURL('image/jpeg', q);
      while (out.length > 520_000 && q > 0.3) { q -= 0.1; out = c.toDataURL('image/jpeg', q); }
      URL.revokeObjectURL(img.src);
      resolve(out);
    };
    img.onerror = () => reject(new Error('That file isn’t an image we can read. Upload a photo (JPG or PNG).'));
    img.src = URL.createObjectURL(file);
  });
}

const VITALS: { key: VitalKey; label: string; unit: string; icon: string; range: string; min: number; max: number }[] = [
  { key: 'bp', label: 'Blood pressure (systolic)', unit: 'mmHg', icon: 'HeartPulse', range: 'Target below 120', min: 60, max: 260 },
  { key: 'sugar', label: 'Fasting blood sugar', unit: 'mg/dL', icon: 'Droplet', range: 'Normal 70–99', min: 30, max: 600 },
  { key: 'weight', label: 'Weight', unit: 'kg', icon: 'Scale', range: 'Track weekly', min: 2, max: 400 },
];

export function Records({ nav }: { nav: Nav }) {
  const { uid, me, appts, reports } = useP();
  const toast = useToast();
  const [tab, setTab] = useState<Kind>('rx');
  const [upload, setUpload] = useState(false);
  const [name, setName] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [logVital, setLogVital] = useState<VitalKey | null>(null);
  const [val, setVal] = useState('');
  const fileRef = useRef<HTMLInputElement>(null);
  const rxs = (appts ?? []).filter((a) => a.rx).sort((a, b) => b.rx!.signedAt - a.rx!.signedAt);
  const vitals = me.vitals ?? { bp: [], sugar: [], weight: [] };

  const save = async () => {
    if (!file) return;
    setBusy(true);
    try {
      const image = await compressImage(file);
      await addDoc(collection(db, 'reports'), { patientId: uid, name: name.trim() || file.name.replace(/\.\w+$/, ''), t: Date.now(), lab: 'Uploaded by you', status: 'ready', items: [], image });
      setUpload(false); setName(''); setFile(null); setTab('reports');
      toast('Record saved to your account');
    } catch (e) { toast(errorText(e)); }
    setBusy(false);
  };

  return (
    <div className="screen has-tabs tab-root">
      <TopBar title="Health records" left right={<button className="icon-btn" onClick={() => setUpload(true)} aria-label="Upload a record"><Icon name="Upload" size={19} /></button>} />
      <div className="pad stack gap-16">
        <button className="card tap row gap-12" style={{ padding: 14, border: 0, textAlign: 'left' }} onClick={() => nav.push('editProfile')}>
          <span className="tile-icon"><Icon name="ShieldCheck" size={22} /></span>
          <div className="grow"><div className="t-h3">{me.name}</div><div className="t-sm">{me.age} y · {me.sex} · Blood {me.blood} · Allergies: {me.allergies}{me.conditions?.length ? ` · ${me.conditions.join(', ')}` : ''}</div></div>
          <Icon name="Pencil" size={16} className="chev" />
        </button>
        <Segmented options={[{ id: 'rx', label: 'Prescriptions' }, { id: 'reports', label: 'Reports' }, { id: 'vitals', label: 'Vitals' }]} value={tab} onChange={setTab} />

        {tab === 'rx' && (rxs.length ? (
          <div className="list">
            {rxs.map((a) => (
              <div key={a.id} className="list-row" onClick={() => nav.push('rx', { id: a.id })}>
                <span className="tile-icon"><Icon name="FileText" size={20} /></span>
                <div className="grow" style={{ minWidth: 0 }}>
                  <div className="t-h3 ellipsis">{a.rx!.diagnosis}</div>
                  <div className="t-sm">{a.doctorName}</div>
                  <div className="t-xs" style={{ marginTop: 2 }}>{fmtDay(a.rx!.signedAt)} · {a.member.split(' ')[0]}</div>
                </div>
                <Icon name="ChevronRight" size={18} className="chev" />
              </div>
            ))}
          </div>
        ) : <Empty icon="FileText" title="No prescriptions yet" body="Prescriptions from your CareLoop visits appear here automatically." />)}

        {tab === 'reports' && ((reports ?? []).length ? (
          <div className="list">
            {[...reports!].sort((a, b) => b.t - a.t).map((r) => {
              const flagged = r.items.filter((i) => i.flag !== 'normal').length;
              return (
                <div key={r.id} className="list-row" onClick={() => nav.push('report', { id: r.id })}>
                  <span className={`tile-icon ${r.image ? 'neutral' : 'good'}`}><Icon name={r.image ? 'Image' : 'FlaskConical'} size={20} /></span>
                  <div className="grow" style={{ minWidth: 0 }}><div className="t-h3 ellipsis">{r.name}</div><div className="t-sm">{r.lab} · {fmtDay(r.t)}</div></div>
                  {r.status === 'processing' ? <span className="badge">Processing</span> : flagged ? <span className="badge warn">{flagged} to review</span> : r.items.length ? <span className="badge good">All normal</span> : null}
                </div>
              );
            })}
          </div>
        ) : <Empty icon="FolderHeart" title="No reports yet" body="Lab results you book through CareLoop land here. You can also upload photos of reports from other labs." action={<button className="btn sm soft" onClick={() => setUpload(true)}><Icon name="Upload" size={16} />Upload a report</button>} />)}

        {tab === 'vitals' && (
          <div className="stack gap-12">
            {VITALS.map((v) => {
              const data = vitals[v.key] ?? [];
              return (
                <div key={v.key} className="card p stack gap-12">
                  <div className="row gap-10">
                    <span className="tile-icon sm"><Icon name={v.icon} size={18} /></span>
                    <div className="grow"><div className="t-h3">{v.label}</div><div className="t-xs">{v.range}{data.length ? ` · last ${data.length} readings` : ''}</div></div>
                    <button className="btn xs soft" onClick={() => { setLogVital(v.key); setVal(''); }}><Icon name="Plus" size={14} />Log</button>
                  </div>
                  {data.length ? (
                    <div className="row between" style={{ alignItems: 'flex-end' }}>
                      <div className="row gap-4" style={{ alignItems: 'baseline' }}><span className="t-display num">{data[data.length - 1]}</span><span className="t-sm">{v.unit}</span></div>
                      {data.length > 1 && <Sparkline values={data} width={150} height={48} />}
                    </div>
                  ) : <div className="t-sm">No readings yet. Log one to start a trend your doctor can see.</div>}
                </div>
              );
            })}
          </div>
        )}
      </div>

      <Sheet open={upload} onClose={() => !busy && setUpload(false)}>
        <div className="stack gap-12">
          <div className="t-h2">Add a record</div>
          <div className="t-sm">Old prescriptions, reports from other labs, discharge summaries. Saved privately to your account.</div>
          <input ref={fileRef} type="file" accept="image/*" capture="environment" style={{ display: 'none' }} onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
          <button className="card tap row gap-12" onClick={() => fileRef.current?.click()} style={{ border: '2px dashed var(--line)', boxShadow: 'none', padding: 16, textAlign: 'left' }}>
            <span className="tile-icon"><Icon name={file ? 'CircleCheck' : 'Camera'} size={20} /></span>
            <div className="grow"><div className="t-h3">{file ? file.name : 'Take a photo or choose one'}</div><div className="t-xs">{file ? `${Math.round(file.size / 1024)} KB` : 'JPG or PNG'}</div></div>
          </button>
          <input className="input" value={name} onChange={(e) => setName(e.target.value)} placeholder="Name, e.g. Thyroid report March" />
          <button className="btn block" disabled={!file || busy} onClick={save}>{busy ? <><span className="spinner" />Saving…</> : 'Save record'}</button>
        </div>
      </Sheet>

      <Sheet open={!!logVital} onClose={() => setLogVital(null)}>
        {logVital && (() => {
          const v = VITALS.find((x) => x.key === logVital)!;
          const n = Number(val);
          const ok = n >= v.min && n <= v.max;
          return (
            <form className="stack gap-12" onSubmit={async (e) => {
              e.preventDefault(); if (!ok) return;
              const prev = vitals[logVital] ?? [];
              await updateMe(uid, { vitals: { ...vitals, [logVital]: [...prev, n].slice(-12) } });
              setLogVital(null); toast('Reading saved');
            }}>
              <div className="t-h2">Log {v.label.toLowerCase()}</div>
              <div className="row gap-10">
                <input className="input num" inputMode="decimal" autoFocus value={val} onChange={(e) => setVal(e.target.value.replace(/[^\d.]/g, ''))} style={{ fontSize: 22, fontWeight: 800 }} aria-label={v.label} />
                <span className="t-h3" style={{ width: 70 }}>{v.unit}</span>
              </div>
              {val && !ok && <div className="t-sm t-bad">Enter a value between {v.min} and {v.max}.</div>}
              <button className="btn block" type="submit" disabled={!ok}>Save reading</button>
            </form>
          );
        })()}
      </Sheet>
    </div>
  );
}

export function ReportView({ nav, id }: { nav: Nav; id: string }) {
  const { reports } = useP();
  const toast = useToast();
  const r = reports?.find((x) => x.id === id);
  if (!r) return null;
  return (
    <div className="screen has-cta">
      <TopBar title="Report" onBack={() => nav.back()} right={<button className="icon-btn" aria-label="Delete" onClick={async () => { await deleteDoc(doc(db, 'reports', id)); toast('Record deleted'); nav.back(); }}><Icon name="Trash2" size={18} /></button>} />
      <div className="pad stack gap-16">
        <div><div className="t-h1">{r.name}</div><div className="t-sm" style={{ marginTop: 4 }}>{r.lab} · {fmtDay(r.t)}</div></div>
        {r.image && <img src={r.image} alt={r.name} style={{ width: '100%', borderRadius: 16, boxShadow: 'var(--shadow)' }} />}
        {r.items.length > 0 && (
          <div className="list">
            {r.items.map((i) => (
              <div key={i.name} className="list-row no-tap">
                <div className="grow"><div style={{ fontWeight: 700 }}>{i.name}</div><div className="t-xs">Range {i.range} {i.unit}</div></div>
                <div style={{ textAlign: 'right' }}>
                  <div className="num" style={{ fontWeight: 800, fontSize: 17, color: i.flag === 'normal' ? 'var(--ink)' : 'var(--warn)' }}>{i.value} <span className="t-xs">{i.unit}</span></div>
                  <span className={`badge ${i.flag === 'normal' ? 'good' : 'warn'}`}>{i.flag === 'normal' ? 'Normal' : i.flag === 'high' ? 'High' : 'Low'}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
      <div className="cta-bar solid">
        <button className="btn block" onClick={() => nav.push('search', { specialty: 'gp' })}><Icon name="Stethoscope" size={18} />Ask a doctor about this report</button>
      </div>
    </div>
  );
}
