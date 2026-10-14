# CareLoop: telehealth for patients and doctors

Two Android apps on one Firebase backend, for India and the United States:

| | App | For |
|:-:|---|---|
| <img src="store/careloop-512.png" width="56"> | **CareLoop** (`com.udapps.careloop`) | Patients: sign up, find verified doctors, book video or clinic visits or an instant consult, pay, join the video visit, get prescriptions, chat with the doctor, order medicines and lab tests, keep family records |
| <img src="store/careloop_pro-512.png" width="56"> | **CareLoop Pro** (`com.udapps.careloop_pro`) | Doctors: sign up with a license, get verified, set hours and fees, take booked and instant consults, write e-prescriptions, chat with patients, track earnings and request payouts. Admins approve doctors in the same app. |

Everything is real and shared between the apps through Firebase. A booking a patient makes appears on the doctor's schedule. A prescription the doctor signs appears in the patient's records. Messages arrive in each other's inboxes.

## Set up (once)

1. **Create a Firebase project.** In console.firebase.google.com, add a project.
   - **Authentication**: enable **Email/Password**. Optionally enable **Phone**, which needs the Blaze plan for real SMS; test numbers work on the free plan.
   - **Firestore Database**: create it in production mode.
   - **Project settings → Your apps**: add a **Web** app and copy its config.
2. **Paste the config** into `src/firebase-config.ts`, replacing the `demo-careloop` placeholder.
3. **Apply the security rules and the index.** Do one of these:
   - In the console: copy `firebase/firestore.rules` into Firestore → Rules → Publish. Then add an index exemption under Firestore → Indexes → Single field → **messages / to**, with collection group scope enabled.
   - Or automatically: add a service-account key as the GitHub secret `FIREBASE_SERVICE_ACCOUNT`; `careloop.yml` then runs `firebase deploy --only firestore` on every push.
4. **Make yourself an admin.** Sign up in CareLoop Pro with your email. In Firestore → `users` → your document, set `role` to `admin`. Reopen the app and you'll see the doctor-verification console.
5. **Push.** `.github/workflows/careloop.yml` tests the rules, builds both APKs and publishes a **CareLoop N** release. Until step 2 is done, it skips the APKs, because they'd point at the local test server.

### Payments

With no keys, checkout runs as a **test checkout**: real validation and processing, marked "Test mode", and no money moves. To take payments:

- **India (Razorpay):** set `PAYMENTS.razorpayKeyId` in `src/firebase-config.ts` (an `rzp_test_…` or live key). Checkout opens Razorpay with UPI, cards and net banking.
- **US (Stripe):** needs the Cloud Functions in `functions/` (Blaze plan):
  ```bash
  firebase functions:secrets:set STRIPE_SECRET_KEY        # and RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET for server-side Razorpay orders
  cd functions && npm install && npm run deploy
  ```
  Then set `PAYMENTS.stripePublishableKey` and `PAYMENTS.functionsDeployed = true`.

Refunds for cancelled visits are flagged on the booking (`payment.status = refund-pending`). Issue them from your Razorpay or Stripe dashboard.

### Video visits

Each visit has its own private, random room on **Jitsi Meet** (meet.jit.si), which is free and needs no account. On Android it opens in Chrome, where the camera and microphone work. The first person to join a room may be asked by Jitsi to sign in (Google, GitHub and others) to start it. For your own branding and no sign-in, run your own Jitsi server or use 8x8 JaaS, and change the URL in `openVideoRoom` in `src/lib/care.ts`.

## How it works

| Data (Firestore) | Who can see it |
|---|---|
| `users/{uid}`: profile, health basics, family, vitals, Plus | that person; admins |
| `doctors/{uid}`: public profile, fees, hours, rating | everyone signed in once approved; pending ones only themselves and admins |
| `appointments/{id}` and `/messages`: visit, prescription, chat | the patient and the doctor on the visit only |
| `slots/{doctor_time}` | used to block double-booking: each time can be booked once |
| `instantRequests/{id}` | the patient; approved doctors while it's open (the first to accept wins) |
| `reports`, `orders` | the patient only |
| `payouts` | the doctor only |

`tests/rules.test.ts` checks these rules against the emulator (17 tests): people can't read others' visits or records, change their own role, approve themselves, write prescriptions as a patient, double-book a slot, take an instant request someone already accepted, or send messages on someone else's visit.

**Accounts.** Email and password, with password reset and email verification; or a phone code. Each app checks the role: a patient account opening CareLoop Pro is told to use the patient app, and the other way round.

## How it makes money

| Stream | India | United States |
|---|---|---|
| Commission on every consult | 20% Starter, 10% Pro, 8% Clinic | same |
| Doctor subscriptions | Pro ₹1,999/mo · Clinic ₹4,999/mo | Pro $49/mo · Practice $149/mo |
| Patient booking fee | ₹29 + GST | $3 |
| Instant consults (flat fee) | ₹399 | $49 |
| CareLoop Plus (patients) | ₹299/mo or ₹1,999/yr | $14.99/mo or $119/yr |
| Medicines and lab tests | partner margin + delivery/collection fees | same |

The apps show these at the moments they matter:
- Plus is offered at checkout ("Save ₹129 with Plus") and on Home.
- Pro is offered in Earnings ("Keep ₹X more a month") and on locked prescription templates.
- Every prescription ends with **Order medicines** and **Book tests**.

## Develop

```bash
npm install
npm run emulators            # Firebase Auth + Firestore emulators (needs Java)
npm run dev:emulator         # both apps side by side at http://localhost:5173 (each frame has its own login)
npm run test:rules           # security rules tests (with the emulators running)
npm run build                # typecheck + build
```

`?app=patient` or `?app=doctor` opens one app full screen. With a `demo-` project id in `src/firebase-config.ts`, the app always uses the emulators.

### Build an APK locally

You need JDK 21 and the Android SDK, plus `pip install pillow`.

```bash
VITE_ROLE=patient npx vite build           # or VITE_ROLE=doctor
APP=careloop npx cap add android            # or APP=careloop_pro
python3 tool/prepare_android.py careloop
cd android && ./gradlew assembleDebug
```

## Layout

```
src/firebase-config.ts   your Firebase web config + payment keys
firebase/                Firestore security rules and indexes
functions/               payment Cloud Functions (Razorpay orders, Stripe payment intents)
src/lib/                 Firebase setup, auth, live queries, booking/chat/video helpers, payments, data model
src/ui/                  design system, sign-up/log-in screens, charts, icons
src/patient/             CareLoop screens
src/doctor/              CareLoop Pro screens, including doctor onboarding and the admin console
tests/rules.test.ts      security rules tests
tool/                    icon drawing, Android setup, release notes
```
