# CareLoop: telehealth for patients and doctors

Two Android apps from one React + Capacitor codebase, for India and the United States:

| | App | For |
|:-:|---|---|
| <img src="store/careloop-512.png" width="56"> | **CareLoop** (`com.udapps.careloop`) | Patients: find a doctor, book video or clinic visits, pay, join the call, get prescriptions, order medicines and lab tests, keep the family's records |
| <img src="store/careloop_pro-512.png" width="56"> | **CareLoop Pro** (`com.udapps.careloop_pro`) | Doctors: today's queue, instant consult requests, video consults with notes, e-prescriptions, patient charts, schedule and fees, earnings and payouts |

**Get the APKs:** open this repository's **Releases** page. The newest "CareLoop N" release has `careloop.apk` and `careloop_pro.apk`. `.github/workflows/careloop.yml` builds both on every push that touches this folder.

On first launch you pick **India** or the **United States**. That sets the doctors, the currency, the payment methods (UPI, cards and net banking in India; insurance, cards and HSA/FSA in the US), the prices and the compliance notes.

## What's in each app

**CareLoop (patient)**
- Onboarding: country, phone number with an auto-read one-time code, and a short profile.
- Home: the next visit with a live **Join** button, quick actions, browse by symptom, top doctors, a vitals snapshot and an emergency notice.
- Find and book: search with filters (specialty, available today, video or clinic, sort by rating or fee) and doctor profiles with stats, reviews, clinic details and a date and time picker. Checkout lets you choose the family member, the reason and the payment method, shows the price breakdown (Plus discount, booking fee, GST, insurance copay), then confirms.
- **Instant consult**: pick a concern and get matched to the next available GP.
- Video visit with mute, camera and speaker controls. Afterwards you rate the doctor and get a signed digital prescription.
- From the prescription you can order the medicines (cart, discount and delivery tracking) or book the prescribed tests at home.
- Records: prescriptions, lab reports with flagged values, and vitals trends you can log. You can also upload outside records.
- Visits: upcoming and past visits, cancel with refund, reschedule, clinic token, a free 7-day follow-up chat, and invoices.
- Profile: **CareLoop Plus** membership, family members, orders, reminders and country switch.

**CareLoop Pro (doctor)**
- License sign-in with a medical council number (India) or state license/NPI (US).
- Today: an online toggle for instant consults, today's earnings, an "Up next" patient card with vitals and allergy alerts, and a timeline of the day's queue.
- **Instant consult requests** arrive while the doctor is online, showing what the doctor would earn; accept starts the call.
- Video consult with a notes panel holding the patient summary. Ending the call opens the **e-prescription builder**: diagnosis chips, a medicine picker with dose, duration and instructions plus allergy checks, tests, advice templates (a Pro feature) and follow-up. Then **review, sign and send**, which adds the fee to earnings.
- Schedule: a week view, working days, morning/afternoon/evening sessions, slot length, blocked days off, and fee editing with market comparisons.
- Patients: search, and charts with vitals, conditions, allergies and visit history.
- Earnings: withdrawable balance, a 7-day revenue chart, the platform fee breakdown, payouts, and a Pro upgrade prompt that shows the savings.
- Plans: Starter, Pro and Clinic/Practice, each showing what the doctor would keep per month.

## How it makes money

| Stream | India | United States |
|---|---|---|
| **Commission on every consult** (doctor side) | 20% Starter, 10% Pro, 8% Clinic | same |
| **Doctor subscriptions** (SaaS) | Pro ₹1,999/mo · Clinic ₹4,999/mo | Pro $49/mo · Practice $149/mo |
| **Patient booking fee** | ₹29 + GST per booking | $3 per booking |
| **CareLoop Plus** (patient membership) | ₹299/mo or ₹1,999/yr | $14.99/mo or $119/yr |
| **Pharmacy margin** on medicine orders | 15% discount still leaves partner margin; delivery fee | delivery fee + partner margin |
| **Lab test packages** with home collection | package margin + ₹99 collection | package margin + $15 collection |
| Insurance (US) | n/a | per-visit billing with copay shown before booking |

The apps nudge these streams at the moments they make sense:
- Plus offers appear at checkout ("Save ₹129 on this visit") and on Home.
- Pro offers appear in Earnings ("Keep ₹23,972 more a month") and on locked prescription templates.
- Every prescription ends with **Order medicines** and **Book tests**.

## What's simulated

These are complete, working prototypes with sample data and no server:
- Payments, the one-time code, video, chat replies and payouts are simulated.
- The patient and doctor apps don't talk to each other.
- All data stays on the phone (localStorage).

A real launch needs:
- **Backend and data:** a backend (accounts, bookings, queue, records); HIPAA (US) or DPDP Act (India) hosting and consent.
- **Video:** a video provider such as Twilio, Agora or 100ms, behind `src/ui/call.tsx`.
- **Payments and insurance:** Razorpay or Cashfree in India, Stripe in the US, and an insurance eligibility API in the US.
- **Prescriptions:** e-prescribing rules: India's Telemedicine Practice Guidelines; Surescripts/EPCS in the US.
- **Doctors and partners:** doctor credential checks, and pharmacy and lab partners.

## Run it

```bash
npm install
npm run dev              # both apps side by side in phone frames
npm run dev:patient      # just the patient app, full screen
npm run dev:doctor       # just the doctor app, full screen
npm run build            # typecheck + build
```

## Build an APK locally

You need JDK 21 and the Android SDK (`ANDROID_HOME`), plus `pip install pillow`.

```bash
VITE_ROLE=patient npx vite build          # or VITE_ROLE=doctor
APP=careloop npx cap add android           # or APP=careloop_pro; android/ is generated, not committed
python3 tool/prepare_android.py careloop   # icons, launch screen, bar colours, version
cd android && ./gradlew assembleDebug      # app/build/outputs/apk/debug/app-debug.apk
```

The Android back button steps back through screens, then to the first tab, then closes the app.

## Layout

```
apps.json              the two apps: slug, role, name, colours (used by capacitor.config.ts and tool/)
src/data/region.ts     India / US: currency, payment methods, fees, Plus and doctor plan pricing
src/data/catalog.ts    specialties, doctors, slots, lab packages, medicines
src/ui/                design system (theme.css), components (kit.tsx), video call, charts, icon registry
src/patient/           CareLoop: state + onboarding, home, find/book, visits, records, shop, profile
src/doctor/            CareLoop Pro: state + today/consult/prescribe, schedule, patients, earnings, plans
tool/                  icon drawing (make_icons.py), Android setup, release notes
```

`python3 tool/make_icons.py` (needs `pip install cairosvg pillow`) redraws both icons as adaptive-icon layers in `icons/` and the 512 px Play Store icons in `store/`.
