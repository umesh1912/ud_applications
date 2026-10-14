import { useState } from 'react';
import { specialtyOf } from '../data/catalog';
import { REGIONS, money } from '../data/region';
import { logOut } from '../lib/auth';
import { errorText, useQuery, where } from '../lib/db';
import type { DoctorDoc, UserDoc } from '../lib/model';
import { Avatar, Empty, Icon, Segmented, TopBar, useToast } from '../ui/kit';
import { updateDoctor } from './ctx';

/**
 * Admin console (shown in CareLoop Pro to accounts whose users/{uid}.role is "admin").
 * Grant admin in the Firebase console: Firestore → users → your uid → role = "admin".
 */
export function AdminConsole({ me }: { me: UserDoc }) {
  const toast = useToast();
  const [tab, setTab] = useState<'pending' | 'approved' | 'rejected'>('pending');
  const list = useQuery<DoctorDoc>(`admin-${tab}`, 'doctors', where('status', '==', tab));
  const [busy, setBusy] = useState<string | null>(null);
  const decide = async (d: DoctorDoc, status: 'approved' | 'rejected') => {
    setBusy(d.id);
    try { await updateDoctor(d.id, { status, reviewedAt: Date.now() }); toast(`${d.name} ${status}`); }
    catch (e) { toast(errorText(e)); }
    setBusy(null);
  };
  return (
    <div className="screen">
      <TopBar title="Doctor verification" left right={<button className="icon-btn" onClick={() => logOut()} aria-label="Log out"><Icon name="LogOut" size={18} /></button>} />
      <div className="pad stack gap-14" style={{ paddingBottom: 24 }}>
        <div className="t-sm">Signed in as admin: {me.name}. Check each license against the {REGIONS.IN.name} medical council or US state board before approving.</div>
        <Segmented options={[{ id: 'pending', label: 'Pending' }, { id: 'approved', label: 'Approved' }, { id: 'rejected', label: 'Rejected' }]} value={tab} onChange={setTab} />
        {list === undefined && <div className="t-sm">Loading…</div>}
        {list?.length === 0 && <Empty icon="ShieldCheck" title={tab === 'pending' ? 'No doctors waiting' : `No ${tab} doctors`} body="New doctor signups appear here for review." />}
        {(list ?? []).sort((a, b) => a.createdAt - b.createdAt).map((d) => (
          <div key={d.id} className="card p stack gap-10">
            <div className="row gap-12">
              <Avatar name={d.name} hue={d.hue} size={48} />
              <div className="grow"><div className="t-h3">{d.name}</div><div className="t-sm">{specialtyOf(d.specialty).name} · {d.years} yrs · {REGIONS[d.region].name}</div></div>
            </div>
            <div className="kv"><span>License</span><span>{d.licenseNo}</span></div>
            <div className="kv"><span>Qualifications</span><span style={{ maxWidth: 190 }}>{d.degrees}</span></div>
            <div className="kv"><span>Practice</span><span style={{ maxWidth: 190 }}>{[d.clinic, d.area].filter(Boolean).join(', ')}</span></div>
            <div className="kv"><span>Fees</span><span>{money(d.region, d.feeVideo)} video · {money(d.region, d.feeClinic)} clinic</span></div>
            <div className="row gap-10">
              {d.status !== 'rejected' && <button className="btn danger grow" disabled={busy === d.id} onClick={() => decide(d, 'rejected')}>Reject</button>}
              {d.status !== 'approved' && <button className="btn good grow" disabled={busy === d.id} onClick={() => decide(d, 'approved')}><Icon name="BadgeCheck" size={18} />Approve</button>}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
