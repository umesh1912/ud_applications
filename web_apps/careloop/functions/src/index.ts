/**
 * Payment functions for CareLoop. Needs the Firebase Blaze plan.
 *
 * Set the secret keys once (never put them in the app):
 *   firebase functions:secrets:set RAZORPAY_KEY_ID
 *   firebase functions:secrets:set RAZORPAY_KEY_SECRET
 *   firebase functions:secrets:set STRIPE_SECRET_KEY
 * Then: cd functions && npm install && npm run deploy
 * and set PAYMENTS.functionsDeployed = true in src/firebase-config.ts.
 */
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import Stripe from 'stripe';
import Razorpay from 'razorpay';

const RAZORPAY_KEY_ID = defineSecret('RAZORPAY_KEY_ID');
const RAZORPAY_KEY_SECRET = defineSecret('RAZORPAY_KEY_SECRET');
const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');

// Largest single charge the app ever asks for (a yearly plan or a big lab order), in minor units.
const MAX_MINOR = 2_000_000;

function checkAmount(amount: unknown) {
  if (typeof amount !== 'number' || !Number.isInteger(amount) || amount < 100 || amount > MAX_MINOR) {
    throw new HttpsError('invalid-argument', 'Invalid amount.');
  }
  return amount;
}

/** India: creates a Razorpay order so the payment can be verified server-side. */
export const createRazorpayOrder = onCall({ secrets: [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET], region: 'us-central1' }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Log in first.');
  const amount = checkAmount(req.data?.amount);
  const rz = new Razorpay({ key_id: RAZORPAY_KEY_ID.value(), key_secret: RAZORPAY_KEY_SECRET.value() });
  const order = await rz.orders.create({ amount, currency: 'INR', receipt: `cl_${req.auth.uid.slice(0, 8)}_${Date.now()}`, notes: { uid: req.auth.uid } });
  return { orderId: order.id };
});

/** US: creates a Stripe PaymentIntent for the Payment Element in the app. */
export const createStripePaymentIntent = onCall({ secrets: [STRIPE_SECRET_KEY], region: 'us-central1' }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Log in first.');
  const amount = checkAmount(req.data?.amount);
  const stripe = new Stripe(STRIPE_SECRET_KEY.value());
  const intent = await stripe.paymentIntents.create({
    amount,
    currency: 'usd',
    description: String(req.data?.description ?? 'CareLoop').slice(0, 200),
    automatic_payment_methods: { enabled: true },
    metadata: { uid: req.auth.uid },
  });
  return { clientSecret: intent.client_secret };
});
