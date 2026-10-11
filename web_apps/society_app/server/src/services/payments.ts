export type PayMethod = 'upi' | 'card' | 'net';

export interface ChargeRequest { amount: number; method: PayMethod; flatId: string; description: string }
export interface ChargeResult { ok: boolean; providerRef?: string; error?: string }

/**
 * Payment gateway boundary. Swap StubPaymentProvider for a real gateway (Razorpay, Cashfree, PayU…)
 * that creates an order, opens checkout on the client and verifies the webhook signature here.
 */
export interface PaymentProvider { charge(req: ChargeRequest): Promise<ChargeResult> }

/** Approves every charge after a short delay so the checkout flow feels real. */
export class StubPaymentProvider implements PaymentProvider {
  constructor(private delayMs = 1400) {}
  async charge(req: ChargeRequest): Promise<ChargeResult> {
    if (!(req.amount > 0)) return { ok: false, error: 'Invalid amount' };
    await new Promise(r => setTimeout(r, this.delayMs));
    return { ok: true, providerRef: 'stub_' + Date.now().toString(36) };
  }
}
