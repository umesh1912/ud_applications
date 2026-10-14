import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react';
import { httpsCallable } from 'firebase/functions';
import { REGIONS, money, type Region } from '../data/region';
import { PAYMENTS } from '../firebase-config';
import { Icon, Sheet } from '../ui/kit';
import { functions } from './firebase';
import type { Payment } from './model';

export interface PayRequest {
  region: Region;
  amount: number;
  title: string;
  /** Offer "Insurance" as a method (US visits): the copay is charged instead of `amount`. */
  copay?: number;
  prefill?: { name?: string; email?: string; phone?: string };
}

type Resolver = (p: Payment | null) => void;
const Ctx = createContext<(r: PayRequest) => Promise<Payment | null>>(async () => null);

/** `const pay = usePay(); const payment = await pay({...})` → null if the person backs out. */
export const usePay = () => useContext(Ctx);

export const paymentMode = (region: Region) =>
  region === 'IN' ? (PAYMENTS.razorpayKeyId ? 'razorpay' : 'test') : (PAYMENTS.stripePublishableKey && PAYMENTS.functionsDeployed ? 'stripe' : 'test');

// ---------------------------------------------------------------- providers

function loadScript(src: string) {
  return new Promise<void>((resolve, reject) => {
    if (document.querySelector(`script[src="${src}"]`)) return resolve();
    const s = document.createElement('script');
    s.src = src; s.onload = () => resolve(); s.onerror = () => reject(new Error('Could not load the payment page. Check your connection.'));
    document.head.appendChild(s);
  });
}

declare global {
  interface Window {
    Razorpay?: new (opts: Record<string, unknown>) => { open: () => void; on: (e: string, cb: (r: unknown) => void) => void };
    Stripe?: (pk: string) => StripeLike;
  }
}
interface StripeLike {
  elements: (o: Record<string, unknown>) => { create: (t: string) => { mount: (el: HTMLElement) => void; destroy: () => void } };
  confirmPayment: (o: Record<string, unknown>) => Promise<{ error?: { message: string }; paymentIntent?: { id: string; status: string } }>;
}

async function razorpay(req: PayRequest, amount: number, method: string): Promise<Payment | null> {
  await loadScript('https://checkout.razorpay.com/v1/checkout.js');
  let orderId: string | undefined;
  if (PAYMENTS.functionsDeployed) {
    const res = await httpsCallable<{ amount: number; currency: string }, { orderId: string }>(functions, 'createRazorpayOrder')({ amount: Math.round(amount * 100), currency: 'INR' });
    orderId = res.data.orderId;
  }
  return new Promise((resolve) => {
    const rz = new window.Razorpay!({
      key: PAYMENTS.razorpayKeyId,
      amount: Math.round(amount * 100),
      currency: 'INR',
      name: 'CareLoop',
      description: req.title,
      order_id: orderId,
      prefill: { name: req.prefill?.name, email: req.prefill?.email, contact: req.prefill?.phone?.replace(/\D/g, ''), method: method === 'netbanking' ? 'netbanking' : method === 'card' ? 'card' : 'upi' },
      theme: { color: '#0f766e' },
      handler: (r: { razorpay_payment_id: string }) => resolve({ provider: 'razorpay', ref: r.razorpay_payment_id, method, amount, status: 'paid' }),
      modal: { ondismiss: () => resolve(null) },
    });
    rz.on('payment.failed', () => resolve(null));
    rz.open();
  });
}

// ---------------------------------------------------------------- sheet

export function PaymentProvider({ children }: { children: ReactNode }) {
  const [req, setReq] = useState<PayRequest | null>(null);
  const resolver = useRef<Resolver | null>(null);
  const pay = useCallback((r: PayRequest) => new Promise<Payment | null>((resolve) => { resolver.current = resolve; setReq(r); }), []);
  const finish = (p: Payment | null) => { resolver.current?.(p); resolver.current = null; setReq(null); };
  return (
    <Ctx.Provider value={pay}>
      {children}
      {req && <PaySheet req={req} onDone={finish} />}
    </Ctx.Provider>
  );
}

function PaySheet({ req, onDone }: { req: PayRequest; onDone: (p: Payment | null) => void }) {
  const r = REGIONS[req.region];
  const methods = r.pay.filter((m) => m.id !== 'wallet' && (m.id !== 'insurance' || req.copay !== undefined));
  const [method, setMethod] = useState(methods[0].id);
  const [stage, setStage] = useState<'choose' | 'card' | 'stripe' | 'busy'>('choose');
  const [err, setErr] = useState<string | null>(null);
  const [insurer, setInsurer] = useState({ name: 'Aetna', member: '' });
  const mode = paymentMode(req.region);
  const insurance = method === 'insurance';
  const amount = insurance ? req.copay! : req.amount;

  const start = async () => {
    setErr(null);
    if (insurance && insurer.member.trim().length < 5) { setErr('Enter your insurance member ID.'); return; }
    if (mode === 'razorpay') {
      setStage('busy');
      try {
        const p = await razorpay(req, amount, method);
        if (p) onDone(p); else setStage('choose');
      } catch (e) { setErr((e as Error).message); setStage('choose'); }
      return;
    }
    if (mode === 'stripe') { setStage('stripe'); return; }
    setStage('card');
  };

  return (
    <Sheet open onClose={() => stage !== 'busy' && onDone(null)}>
      <div className="stack gap-14">
        <div className="row between">
          <div><div className="t-xs">{req.title}</div><div className="t-display num" style={{ fontSize: 30 }}>{money(req.region, amount)}</div></div>
          {mode === 'test' && <span className="badge warn"><Icon name="FlaskConical" size={12} />Test mode</span>}
        </div>

        {stage === 'choose' && (
          <>
            <div className="list" style={{ boxShadow: 'inset 0 0 0 1px var(--line)' }}>
              {methods.map((m) => (
                <div key={m.id} className="list-row" onClick={() => setMethod(m.id)}>
                  <span className="tile-icon sm neutral"><Icon name={m.icon} size={18} /></span>
                  <div className="grow"><div style={{ fontWeight: 700, fontSize: 14.5 }}>{m.label}</div><div className="t-xs">{m.id === 'insurance' ? `You pay a ${money(req.region, req.copay!)} copay` : m.sub}</div></div>
                  <span className={`radio${method === m.id ? ' on' : ''}`} />
                </div>
              ))}
            </div>
            {insurance && (
              <div className="row gap-8">
                <select className="input" style={{ width: 150, flex: 'none' }} value={insurer.name} onChange={(e) => setInsurer({ ...insurer, name: e.target.value })} aria-label="Insurer">
                  {['Aetna', 'Cigna', 'UnitedHealthcare', 'Blue Cross Blue Shield', 'Kaiser', 'Humana'].map((x) => <option key={x}>{x}</option>)}
                </select>
                <input className="input" placeholder="Member ID" value={insurer.member} onChange={(e) => setInsurer({ ...insurer, member: e.target.value })} />
              </div>
            )}
            {err && <div className="t-sm t-bad" style={{ fontWeight: 600 }}>{err}</div>}
            <button className="btn block" onClick={start}><Icon name="Lock" size={16} />Pay {money(req.region, amount)}</button>
            <div className="t-xs row gap-6" style={{ justifyContent: 'center' }}>
              <Icon name="ShieldCheck" size={13} />
              {mode === 'razorpay' ? 'Secured by Razorpay' : mode === 'stripe' ? 'Secured by Stripe' : 'Test checkout · no real money is charged'}
            </div>
          </>
        )}

        {stage === 'card' && <TestCard req={req} amount={amount} method={insurance ? `insurance:${insurer.name}:${insurer.member}` : method} onDone={onDone} onBack={() => setStage('choose')} />}
        {stage === 'stripe' && <StripeElement req={req} amount={amount} method={insurance ? `insurance:${insurer.name}:${insurer.member}` : method} onDone={onDone} onBack={() => setStage('choose')} />}
        {stage === 'busy' && <div className="row center gap-10" style={{ padding: 20 }}><span className="spinner" style={{ borderColor: 'var(--line)', borderTopColor: 'var(--brand)' }} />Opening secure checkout…</div>}
      </div>
    </Sheet>
  );
}

/** Built-in test checkout: behaves like a gateway (validation, processing, decline card) without moving money. */
function TestCard({ req, amount, method, onDone, onBack }: { req: PayRequest; amount: number; method: string; onDone: (p: Payment) => void; onBack: () => void }) {
  const upi = method === 'upi' || method === 'gpay';
  const [card, setCard] = useState(upi ? 'success@upi' : '4242 4242 4242 4242');
  const [exp, setExp] = useState('12/30');
  const [cvc, setCvc] = useState('123');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const submit = () => {
    setErr(null);
    if (!upi && card.replace(/\s/g, '').length < 15) { setErr('Enter a valid card number.'); return; }
    if (upi && !/^[\w.-]+@[\w]+$/.test(card)) { setErr('Enter a valid UPI ID, like name@okbank.'); return; }
    if (card.replace(/\s/g, '') === '4000000000000002' || card === 'failure@upi') { setErr('Your bank declined this payment. Try another method.'); return; }
    setBusy(true);
    window.setTimeout(() => onDone({ provider: method.startsWith('insurance') ? 'insurance' : 'test', ref: `test_${Date.now().toString(36)}`, method, amount, status: 'paid' }), 1100);
  };
  return (
    <div className="stack gap-12">
      <div className="row gap-8" style={{ padding: '10px 12px', borderRadius: 12, background: 'var(--warn-soft)', color: 'var(--warn)', fontSize: 12.5, fontWeight: 600 }}>
        <Icon name="FlaskConical" size={15} />Test checkout. Add payment keys in src/firebase-config.ts to take real payments. Decline test: {upi ? 'failure@upi' : '4000 0000 0000 0002'}.
      </div>
      <div className="field"><label>{upi ? 'UPI ID' : 'Card number'}</label><input className="input num" value={card} onChange={(e) => setCard(e.target.value)} inputMode={upi ? 'email' : 'numeric'} /></div>
      {!upi && (
        <div className="row gap-10">
          <div className="field grow"><label>Expiry</label><input className="input num" value={exp} onChange={(e) => setExp(e.target.value)} /></div>
          <div className="field grow"><label>CVC</label><input className="input num" value={cvc} onChange={(e) => setCvc(e.target.value)} /></div>
        </div>
      )}
      {err && <div className="t-sm t-bad" style={{ fontWeight: 600 }} role="alert">{err}</div>}
      <div className="row gap-10">
        <button className="btn ghost" onClick={onBack} disabled={busy}>Back</button>
        <button className="btn grow" onClick={submit} disabled={busy}>{busy ? <><span className="spinner" />Processing…</> : `Pay ${money(req.region, amount)}`}</button>
      </div>
    </div>
  );
}

/** Stripe Payment Element (US). The PaymentIntent is created by the createStripePaymentIntent Cloud Function. */
function StripeElement({ req, amount, method, onDone, onBack }: { req: PayRequest; amount: number; method: string; onDone: (p: Payment) => void; onBack: () => void }) {
  const box = useRef<HTMLDivElement>(null);
  const stripe = useRef<StripeLike | null>(null);
  const elements = useRef<ReturnType<StripeLike['elements']> | null>(null);
  const [ready, setReady] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    let el: { destroy: () => void } | null = null;
    (async () => {
      try {
        await loadScript('https://js.stripe.com/v3/');
        const res = await httpsCallable<{ amount: number; currency: string; description: string }, { clientSecret: string }>(functions, 'createStripePaymentIntent')({ amount: Math.round(amount * 100), currency: 'usd', description: req.title });
        stripe.current = window.Stripe!(PAYMENTS.stripePublishableKey);
        elements.current = stripe.current.elements({ clientSecret: res.data.clientSecret, appearance: { theme: 'stripe', variables: { colorPrimary: '#0f766e', borderRadius: '12px' } } });
        const pe = elements.current.create('payment');
        pe.mount(box.current!);
        el = pe;
        setReady(true);
      } catch (e) { setErr((e as Error).message); }
    })();
    return () => el?.destroy();
  }, [amount, req.title]);
  const submit = async () => {
    setBusy(true); setErr(null);
    const r = await stripe.current!.confirmPayment({ elements: elements.current, redirect: 'if_required', confirmParams: { return_url: location.href } });
    if (r.error) { setErr(r.error.message); setBusy(false); return; }
    onDone({ provider: 'stripe', ref: r.paymentIntent!.id, method, amount, status: 'paid' });
  };
  return (
    <div className="stack gap-12">
      <div ref={box} style={{ minHeight: ready ? undefined : 120 }} />
      {err && <div className="t-sm t-bad" style={{ fontWeight: 600 }}>{err}</div>}
      <div className="row gap-10">
        <button className="btn ghost" onClick={onBack} disabled={busy}>Back</button>
        <button className="btn grow" onClick={submit} disabled={!ready || busy}>{busy ? <span className="spinner" /> : `Pay ${money(req.region, amount)}`}</button>
      </div>
    </div>
  );
}
