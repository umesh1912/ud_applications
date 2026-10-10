# UD Applications

A family of Flutter apps for Android that share one design system ("Paper & Ink"):
serif typography (Fraunces + Literata, Noto Serif for Hindi and Gujarati), a warm
paper background, one accent colour per app, and a floating action dock in the
thumb zone so the main job is always one tap away.

Every app works offline and keeps files on the phone. Languages: English, हिन्दी, ગુજરાતી.

| App | Folder | What it does |
|---|---|---|
| **DocScan** | `apps/doc_scanner` | Scan paper with automatic edge detection → clean PDF. One-tap names (Aadhaar, PAN, Marksheet…). |
| **Vault** | `apps/doc_vault` | Store documents by category, PIN lock, expiry alerts. |
| **Signa** | `apps/sign_maker` | Draw or type a signature, export a transparent PNG. |
| **PDF Studio** | `apps/pdf_studio` | View, merge, extract/delete pages, photos→PDF, rotate, sign, page numbers, watermark, lock/unlock. |
| **FillIt** | `apps/pdf_fill` | Fill PDF forms: type text, tick, cross, date and signature right on the page. |
| **Likho** | `apps/doc_writer` | Write and edit documents; open .docx, .txt or PDF text; export Word or PDF; templates. |
| **Ludo Royale** | `apps/ludo_star` | Ludo with Classic, Quick and Rush modes, 2–4 players, computer opponents. |
| **Deutsch Dost** | `apps/learn_german` | A1 German in 8 units with meanings in English/Hindi/Gujarati, flashcards, quiz, listening. |
| **Sur** | `apps/learn_music` | Piano with sargam labels, play-along songs, ear training, tanpura drone, metronome. |
| **Ghar** | `apps/property_ghar` | Property listings with a WhatsApp flyer; EMI, stamp duty and area calculators. |
| **BillBook** | `apps/bill_book` | Monthly bill tracker with due dates, official pay links and payment history. |
| **PF Saathi** | `apps/pf_saathi` | EPF balance via EPFO missed call / SMS, official portals, retirement calculator. |
| **Gaadi** | `apps/vehicle_gaadi` | Vehicles, RTO lookup from number plate, insurance/PUC reminders, fuel log, Parivahan links. |
| **Dial Abroad** | `apps/dial_abroad` | Contacts abroad with their local time, call with the right code or on WhatsApp. |
| **Milo** | `apps/meet_milo` | Free video meetings on Jitsi Meet with shareable links and scheduling. |
| **Safar** | `apps/safar_trips` | Train booking and Tatkal opening countdowns, PNR check, saved passengers. |

Shared code lives in `packages/ud_core` (theme, fonts, translations, widgets, file helpers).

## Getting the APKs

Every push to `main` builds all apps on GitHub Actions.

1. Open the **Releases** page of this repository.
2. In the newest "Build N", download `<app>.apk` on your phone and install it
   (allow "Install unknown apps" when Android asks).
3. The `.aab` files in the same release are for Google Play Console.

## Publishing on Google Play

Play only accepts files signed with your own upload key. Do this once:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
base64 -w 0 upload-keystore.jks > keystore.txt   # on macOS: base64 -i upload-keystore.jks
```

Keep `upload-keystore.jks` and its password safe — you need the same key for every
future update. Then in GitHub → **Settings → Secrets and variables → Actions** add:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | contents of `keystore.txt` |
| `KEYSTORE_PASSWORD` | the password you chose |
| `KEY_ALIAS` | `upload` |

The next build produces Play-ready `.aab` files. In Play Console create each app,
upload its `.aab` under **Testing → Internal testing** first, then Production.
Package names are `com.udapps.<folder name>`, e.g. `com.udapps.doc_scanner`.

Play also needs, per app: a privacy policy URL, screenshots, a short and full
description, and the Data safety form (these apps collect and share no data; files stay on the phone).

## Running locally

```bash
cd apps/doc_scanner
flutter create --platforms=android --org com.udapps --project-name doc_scanner .
python3 ../../tool/prepare_android.py . DocScan
flutter pub get && dart run flutter_launcher_icons
flutter run
```

## Adding a language

Add an entry to `udLanguages` in `packages/ud_core/lib/src/l10n.dart`, then add the
same language code to `udCoreStrings` and to each app's `lib/strings.dart`.
Missing keys fall back to English.

## Notes

- PDF Studio uses Syncfusion's PDF libraries, which are free under the
  Syncfusion Community License for individuals and small companies
  (under USD 1M revenue). Check their licence terms before a commercial launch.
- DocScan uses Google ML Kit's document scanner, which needs Google Play services.
