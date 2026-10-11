# Society management app

_Started 2026-10-08 07:02 UTC_

---

## User

Design a mobile app for building in one society for maitenance, payment, lightbill and every bill submission, watchmen, event management, Expesne of society everything in one application make it in gujrati and add more feature also.

## Assistant



## User

Answered — roles: Resident / member, Secretary / committee admin, Watchman / security, Treasurer; lang: Gujarati + English toggle; extras: Visitor entry & gate pass, Complaints / helpdesk, Notice board, Polls & voting, Amenity booking (hall, gym), Parking management, Emergency SOS, Member directory, Document vault, Daily help (maid, mil…; payments: UPI, Card, Net banking, Cash (recorded by admin), Auto-pay; variations: One full interactive prototype

## Assistant

_[tool: ask_user]_

_[tool: copy_starter_component]_

_[tool: list_files]_

_[tool: list_files]_

_[tool: grep]_

_[tool: read_file]_

_[tool: run_script]_

_[tool: run_script]_

_[tool: run_script]_

_[tool: run_script]_

_[tool: dc_write]_

_[tool: dc_js_str_replace]_

_[tool: dc_js_str_replace]_

_[tool: show_html]_

_[tool: ready_for_verification]_

I've built **Society App.dc.html**, an interactive phone prototype for Shivam Residency. It opens in Gujarati, and an ગુ/EN button in the app header switches it to English. A panel beside the phone lets you switch between four roles. What one role does shows up for the others: a visitor the watchman logs for B-304 appears on the resident's home screen for approval, a bill the treasurer submits waits for the secretary to approve, and an SOS from a resident shows as an alert banner for the other roles.

- **Resident:** pay maintenance, the light bill share and water charges by UPI, card or net banking, then get a receipt. Auto-pay can be switched on. Also covers guest gate passes with codes, complaints with status tracking, notices, events with RSVP, polls, booking the clubhouse, gym, lawn or guest room, parking, daily help attendance, the member directory and documents.
- **Secretary:** dashboard with the fund balance and how much of this month's maintenance is collected, approving or rejecting submitted bills, posting notices and moving complaints from open to resolved.
- **Treasurer:** submit bills such as the light bill or lift AMC with an attachment, record cash payments, send dues reminders, a category breakdown of expenses and a monthly report.
- **Watchman:** gate dashboard, logging new visitors and sending them for approval, checking gate pass codes, marking visitors out, staff check-in and out, and SOS alerts.

**Caveats:**
- Some Gujarati sentences are machine-written, so please have a native speaker check them.
- Downloads, calls and WhatsApp reminders only show a confirmation message.
- Names, flats and amounts are sample data, and changes reset when the page reloads.

**Tweaks:** you can set the starting role and language, and hide the side panel.

