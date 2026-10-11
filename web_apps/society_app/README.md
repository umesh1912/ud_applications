# Shivam Residency — society app

Implementation of `project/Society App.dc.html` (the Claude Design handoff in `project/`, `chats/` and `DESIGN_HANDOFF.md`).

**Get the APK:** open this repository's **Releases** page and download `society_app.apk` from the newest "Society App" release.
It is a mobile-first web app (React + Vite) with a real backend (Express + SQLite), in Gujarati with an English toggle, for four roles:

- **Resident:** dues and payments with receipts, auto-pay, guest gate passes, approving visitors, complaints, notices, events and RSVPs, polls, amenity booking, parking, daily help, the directory and documents.
- **Secretary:** fund balance, collection progress, approving or rejecting bills, posting notices, moving complaints from open to resolved, and dues reminders.
- **Treasurer:** submitting bills with attachments, recording cash payments, reminders, the expense breakdown and the monthly PDF report.
- **Watchman:** logging visitors and sending them for approval, verifying gate pass codes, marking visitors out, staff check-in and check-out, and responding to SOS alerts.

Actions carry across roles through the shared database. Every client polls every 3 seconds, so an approval or SOS reaches other members within about 3 seconds.

## Run it

```bash
npm install
npm run dev        # API on :8787, web on http://localhost:5173 (proxied /api)
npm test           # API integration tests
npm run build && NODE_ENV=production npm start   # single server on :8787 serving web/dist
npm run seed -- --reset                           # wipe and re-seed the database
```

Requires Node 22.5+ (it uses the built-in `node:sqlite`). The data lives in `server/data/society.db`, with uploads in `server/data/uploads/`.

### Demo mode

This is on by default in development.

- On a wide screen the app is drawn inside the iPhone frame, with the role and language panel from the prototype beside it. On a phone it fills the screen.
- A new visitor is signed in as the resident automatically, and the panel or **More → Switch role** switches between the four seeded members.
- Visitors logged for flats with no app user are approved after about 3 seconds, which stands in for the guard phoning the flat.
- **Sign out** shows the real OTP login. The sample numbers are 98250 12345 (resident), 98250 23456 (secretary), 98250 34567 (treasurer) and 98250 41122 (watchman). The OTP is `123456` in development.

### Environment

| Variable | Default | |
|---|---|---|
| `PORT` | `8787` | |
| `DEMO_MODE` | `true` in dev, `false` when `NODE_ENV=production` | One-tap role logins and simulated flat approvals |
| `OTP_DEV_CODE` | `123456` in dev, unset in production | A fixed OTP. When it is unset, OTPs are random. |
| `DATA_DIR` / `DB_FILE` | `server/data` | |

## Android app (APK)

`web/android` is a Capacitor project wrapping an **offline demo build**. The app bundles its own SQLite database (sql.js) and runs the server's route table, seed data and state logic on the phone, so it needs no server. The data stays on that one phone, so the roles can't talk across devices. Switch roles under **More → Switch role** instead. PDF downloads are only available with the server.

```bash
npm run apk -w web    # needs JDK 21 + Android SDK (ANDROID_HOME); output: web/android/app/build/outputs/apk/debug/app-debug.apk
```

On GitHub, `.github/workflows/society-app.yml` (at the repository root) builds the APK on every push that touches `web_apps/society_app/` and publishes it as a release.
To point the APK at a real server instead, build without `VITE_LOCAL` and set `server.url` in `web/capacitor.config.ts`.

## Layout

```
server/src
  app.ts            routes (auth, bills/payments, gate, community, facilities, finance)
  state.ts          GET /api/state: everything one member's app shows, scoped by role
  auth.ts           phone + OTP, bearer sessions, role guards
  db.ts, seed.ts    SQLite schema and the prototype's sample data
  routes.ts         member actions as a transport-neutral table (used by Express and the offline app)
  store.ts          storage interface, schema and shared types
  services/         payments.ts, notifier.ts, pdf.ts: integration boundaries
web/src
  ds/               shadcn design-system components and tokens, copied from project/_ds
  Phone.tsx         header, SOS banner, tab bar, toast, sheets
  screens/, Sheets.tsx
  lib/i18n.ts       prototype strings, verbatim ([Gujarati, English])
  local/backend.ts  offline backend for the APK (sql.js)
web/android         Capacitor Android project
```

## Stubs to replace before going live

- **Payments:** `StubPaymentProvider` approves every charge. Implement `PaymentProvider` with Razorpay, Cashfree or similar: create an order, open checkout, and verify the webhook.
- **SMS, WhatsApp and push:** `ConsoleNotifier` only logs OTPs, dues reminders, notices, SOS alerts and visitor requests. Implement `Notifier` with MSG91, Twilio, the WhatsApp Business API or FCM.
- **Calls** use `tel:` links. **PDFs** (receipts, the monthly report, document placeholders) are real files, but they are English-only because PDFKit cannot shape Gujarati text.

## Differences from the prototype

- Dates, collections and expenses use the real current date and month instead of the fixed "08 Oct".
- "Pending dues" lists every flat with unpaid maintenance, including the resident's own flat until it pays.
- Attach and photo buttons open a real file picker, or the camera on phones, and upload the file.
- New: an OTP login screen, Sign out, empty states, and an offline notice.
- `IconReceipt` is not in the design system, so the prototype shows a blank icon there. The app draws a matching receipt glyph.
- Members can create notices, complaints and other content in one language only, and it is shown unchanged in both. The seeded content is bilingual.

## Not built yet

- Generating each month's maintenance bills, and running auto-pay. The toggle saves the preference but does not charge anyone.
- Managing members and flats, and uploading documents to the vault. Committee members have no screens for these yet.
- Push notifications. The app polls every 3 seconds instead.
- A native speaker should still review the Gujarati, as noted in the design chat.
