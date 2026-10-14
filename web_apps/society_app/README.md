# Society app

A society management app for many housing societies at once, in Gujarati and English. It was built from the Claude Design handoff (`project/Society App.dc.html`, `chats/`, `DESIGN_HANDOFF.md`).

- **Sign up and log in** with a mobile number and an SMS OTP. New users add their name.
- **Register a society.** Enter the name, city, wings (floors × flats per floor), monthly maintenance, due day and the society's UPI ID. The flats are created automatically, the person who registers becomes the **secretary**, and the society gets a 6-character **society code**.
- **Join a society.** Enter the society code, pick your flat (owner or tenant) or choose "security guard", and wait for the secretary to approve. The secretary assigns the role: resident, treasurer, secretary or watchman.
- **Members:** the secretary approves or rejects join requests, changes roles and removes members. Every society needs at least one secretary.
- **Billing:** each month's maintenance bill is raised for every flat automatically. The committee can add extra charges for all flats or one flat. Residents pay the society's **UPI ID** from any UPI app and enter the UTR. The treasurer or secretary confirms it against the bank statement and a receipt (PDF) is issued. The committee can also record cash, cheque, bank or UPI payments themselves. Pending dues, reminders and a monthly PDF report are included.
- **Expenses:** bills are submitted with a photo or PDF, and the secretary approves them. The fund balance updates automatically.
- **Gate:** the watchman logs visitors and the resident approves from their phone. Guest gate pass codes, staff check-in and out, and SOS alerts to guards and the committee.
- **Community:** notices, events with RSVP and polls (created by the secretary), complaints with status tracking, amenity booking (paid bookings become bills), parking and vehicles, the directory (members plus emergency and service contacts) and the document vault (uploads).
- Each society's data is kept separate. A person can belong to several societies and switch between them under **More**.

Phones get updates by polling every 3 seconds.

## Run locally

```bash
npm install
npm run dev          # API on :8787, web on http://localhost:5173 (demo society + OTP 123456)
npm test             # API tests: signup, onboarding, approvals, UPI claims, isolation, demo flows
```

Requires Node 22.5 or later (it uses the built-in `node:sqlite`).

In development, **demo mode** adds a sample society, Shivam Residency. Its members sign in with one tap from the panel beside the phone frame, or with 98250 12345 / 23456 / 34567 / 41122 and OTP `123456`.

## Put it online (Railway)

1. Create an account at **railway.com** and choose **New project → Deploy from GitHub repo → `ud_applications`**.
2. In the service **Settings**:
   - Set **Root directory** to `web_apps/society_app`. The Dockerfile and `railway.json` there are picked up automatically.
   - Set **Branch** to `main`.
   - Under **Networking**, choose **Generate domain**. You get something like `https://society-app-production.up.railway.app`.
3. **Add a volume** (right-click the service → *Attach volume*) mounted at **`/data`**. The database and uploads live there. Without a volume, data is lost on every deploy.
4. Add these **variables**:

   | Variable | Value |
   |---|---|
   | `TWILIO_ACCOUNT_SID` | from the Twilio console |
   | `TWILIO_AUTH_TOKEN` | from the Twilio console |
   | `TWILIO_VERIFY_SERVICE_SID` | Twilio → Verify → Services → create a service → its `VA…` SID |

   Twilio Verify sends OTPs in India on Twilio's own registered templates, so you don't need DLT registration. MSG91 works too: set `MSG91_AUTH_KEY` and `MSG91_TEMPLATE_ID` (a DLT-approved template containing `##OTP##`) instead.
   Until SMS is set up, codes are only written to the Railway **logs**, which is enough for testing yourself.
5. In GitHub, go to **Settings → Secrets and variables → Actions → Variables** and add `SOCIETY_APP_URL` = your Railway address. The next APK build then opens that server. Without the variable, the APK is the offline single-phone demo.

Optional variables: `DEMO_MODE=true` (adds the sample society and one-tap logins; never use this for real societies), `OTP_DEV_CODE` (a fixed code, for testing only), `ONLINE_PAYMENTS=stub`.

## Android app

`web/android` is a Capacitor project. With `CAP_SERVER_URL` set, the APK loads the live server, so app updates need no reinstall. Without it, the APK bundles the offline demo: the server's own route table runs on the phone using sql.js.

```bash
CAP_SERVER_URL=https://your-app.up.railway.app npm run apk -w web   # needs JDK 21 + Android SDK
```

`.github/workflows/society-app.yml` builds it on every push and publishes `society_app.apk` as a "Society App" release.

## Layout

```
server/src
  routes.ts         every API action as a transport-neutral table (Express + offline app)
  auth.ts           phone normalisation, sessions, active society membership
  society.ts        register a society (flats, defaults), monthly maintenance billing, receipt numbers
  state.ts          GET /api/state: everything one member's app shows, scoped by society and role
  store.ts          storage interface, schema, shared types
  seed.ts           demo society (demo mode only)
  services/         otp.ts (Twilio Verify / MSG91 / console), payments.ts, notifier.ts, pdf.ts
web/src
  App.tsx           sign-in → name → register/join → society app; polling
  Login.tsx, Onboarding.tsx, Phone.tsx, Sheets.tsx, screens/
  local/backend.ts  offline demo backend (sql.js)
```

## Not done yet

- **Online card or net-banking gateway (Razorpay etc.):** payments go to the society's UPI ID and the treasurer confirms them. `PaymentProvider` is the place to plug a gateway in.
- **Push notifications:** the app polls instead. SMS and WhatsApp reminders and notices are only logged (`Notifier`).
- **Editing amenities and fees, and editing or deleting notices, events and polls.**
- **Gujarati text written by members** is shown as typed in both languages. The built-in Gujarati was machine-written and should be reviewed by a native speaker.
- **PDFs are English-only.**
