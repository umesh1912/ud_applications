/**
 * Your Firebase project's web app config: Firebase console → Project settings → General → Your apps → Web.
 * These values identify the project; they are not secrets (access is controlled by firebase/firestore.rules).
 *
 * While projectId starts with "demo-", the apps run against the local Firebase emulators (npm run emulators).
 */
export const FIREBASE_CONFIG: {
  apiKey: string;
  authDomain: string;
  projectId: string;
  storageBucket?: string;
  messagingSenderId?: string;
  appId?: string;
  /** Region of the payment Cloud Functions, if deployed. */
  functionsRegion?: string;
} = {
  apiKey: 'demo-key',
  authDomain: 'demo-careloop.firebaseapp.com',
  projectId: 'demo-careloop',
};

/** Payment keys (publishable/test only). Leave empty to use the built-in test checkout. */
export const PAYMENTS = {
  /** Razorpay key id for India, e.g. rzp_test_xxx. */
  razorpayKeyId: '',
  /** Stripe publishable key for the US, e.g. pk_test_xxx. Needs the Cloud Functions in functions/ deployed. */
  stripePublishableKey: '',
  /** True once functions/ is deployed (creates Razorpay orders and Stripe payment intents server-side). */
  functionsDeployed: false,
};
