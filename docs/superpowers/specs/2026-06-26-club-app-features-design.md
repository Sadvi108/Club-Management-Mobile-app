# D-CLIX App — Payments / Home / Settings Feature Design

**Date:** 2026-06-26
**Status:** Approved (pending spec review)
**App:** `frontend/` (Expo Router RN, D-CLIX UI) against live `apimac.zyncbook.com` (Club.Api)

## Context

The app was wired from mock data to the live API in a prior session (see API client in
`frontend/src/api/`). This spec adds three feature areas on top of that, built in order:
**(1) Payments**, **(2) Home**, **(3) Settings/Profile**. All three ship in one combined
spec but as separate implementation phases.

Decisions locked with the user:
- Real payment gateway (Billplz) for **all** methods, opened in the **external system browser** (`expo-web-browser`).
- Profile **photo endpoint is off-spec** — not discoverable from reachable test accounts. Resolve during the Settings phase; ship a best-effort URL + initials fallback until then.
- **Invoices and receipts both download real server PDFs** via `ReceiptAsPDF` (verified).

## Verified API facts (this session)

- `GET /Utilities/ReceiptAsPDF/{clubId}/{paymentId}/{invoiceId}` → `application/pdf`.
  - Paid receipt: `/{clubId}/{receiptId}/0`
  - **Unpaid invoice: `/{clubId}/0/{invoiceId}`** (tested on a Pending invoice → `%PDF-1.3`, 166 KB)
  - Requires `Authorization: bearer` → download must be an **authed fetch → blob**, not a bare link.
- `POST /Outstanding/PayInvoices?PayTermPayments={bool}&PurchaseItems=...` with an inline body → returns a Billplz bill URL. (400 on empty; exact body shape confirmed at build time — see Open Items.)
- `GET /Payment/Initiate?url=<billUrl>` → renders the gateway page. `POST /Payment/Callback` carries Billplz fields (`collection_id`, `x_signature`, `paid`, `paid_amount`, …). `GET /Payment/Completed/{status}` confirms.
- `POST /Outstanding/FetchTermPayments` body `{ studentIds:[], year, months:[] }` → advance-payment (prepay) items.
- `GET /Listing/MySiblings` → `[{ id, value, text }]` linked student accounts.
- `POST /Outstanding/Fetch` body `{ studentId, startDate, endDate }` → outstanding invoices.
- Notifications: `GET /Profile/MyNotifications` (one row per group), `GET /Profile/NotificationDetails/{groupId}` (full thread), `GET /Profile/MyUnreadNotificationCount`, `GET /Profile/UpdateNotification2Read` (mark read).
- `GET /Profile/StudentAddtnlInfo` → `height`, `weight`?, `bloodtype` (varies per student; BMI computed).
- `POST /Profile/UpdateProfile` → inline body (400 on empty; shape confirmed via a `MyInfo` round-trip at build time).
- **CORS:** web calls go through the local proxy (`frontend/scripts/cors-proxy.js`, :8082); native calls hit the API directly. PDF download on web also routes through the proxy.

---

## Phase 1 — Payments

### Screen structure
`app/(tabs)/payments.tsx` becomes a 3-segment screen: **Pay · Prepay · History**.

A shared **selection cart** (React state/context local to the screen) holds chosen items, each
tagged with `studentId`, so items from the user + siblings can be paid together.

### Account switcher
Chips at the top: the logged-in student + `MySiblings`. Selecting a chip loads that account's
invoices via `Outstanding/Fetch({ studentId })`. Cart selections persist across switches.

### Pay segment
- Invoice cards (checkbox to select), each showing **Inv No, Inv Type, Period, Name, Discount, Due Amt** (matches the reference screenshot).
- Per-invoice **Download** action → `ReceiptAsPDF/{clubId}/0/{invoiceId}` (real invoice PDF).

### Prepay segment
- Pick upcoming month(s) for the year → `FetchTermPayments({ studentIds:[id], year, months })`.
- Returned term items add to the cart, flagged so payment sends `PayTermPayments=true`.

### History segment
- Receipts via `Reports/Receipts` (already wired). Per-receipt **Download** → `ReceiptAsPDF/{clubId}/{receiptId}/0`.

### Pay execution
1. Bottom bar shows the cart total + **Pay** → method sheet (Card / FPX / Bank Transfer) → **Confirm & Pay Securely**.
2. `PayInvoices?PayTermPayments=<bool>` with the cart body → Billplz bill URL.
3. **2:00 countdown** starts and is shown on the sheet.
4. Open the bill URL in the system browser (`expo-web-browser.openBrowserAsync`).
5. On return → `Payment/Completed/{status}`; refresh invoices + receipts.
6. If the countdown reaches 0:00 first → cancel the attempt, show "Payment session expired", reopen the cart.

### PDF download helper (`src/api/download.ts`)
- **Web:** authed `fetch` (through proxy) → `blob` → `URL.createObjectURL` → open in new tab / trigger download.
- **Native:** `expo-file-system` `downloadAsync(url, dest, { headers: { Authorization } })` → `expo-sharing` to open/share. (**New deps:** `expo-file-system`, `expo-sharing`.)

### New endpoints added to `src/api/endpoints.ts`
`fetchTermPayments`, `payInvoices`, `paymentCompleted`, `receiptPdfUrl(clubId, paymentId, invoiceId)`, plus `outstanding` already exists. New `download.ts` helper.

---

## Phase 2 — Home

### Notifications
- Bell badge = `MyUnreadNotificationCount`.
- Tap → new `app/notifications.tsx`: list groups from `MyNotifications`; tap a group → `NotificationDetails/{groupId}` thread; `UpdateNotification2Read` marks read and refreshes the badge.

### Quick Access grid
Expand the home grid to mirror the old Reports menu, each routing to a screen (existing or a new
lightweight list view): **Training Time, Grading Schedule, Outstanding, Attendance, Receipt,
Grading Past, Purchase Request, Paymentslip, Tournaments (Past)**. New report screens are thin
lists over `Reports/*` (`PaymentSlips`, `PurchaseRequests`, `GradingSchedule`, `TournamentSummary`)
and `Outstanding/Fetch`.

### Health stats card
A Reports-style header card — **Height / Weight / BMI / Blood Group** — from `StudentAddtnlInfo`
(BMI computed from height + weight). Shown where available; omit fields the account lacks.

---

## Phase 3 — Settings/Profile

- Profile shows student photo (best-effort URL + initials fallback) + Name / Email / Mobile / IC.
- **Edit Profile** → form → `UpdateProfile`. Body shape confirmed via a `MyInfo` round-trip (fetch current values, resubmit with edits) so we never blank fields.
- **Photo upload** → `expo-image-picker` (**new dep**) → upload via the resolved endpoint (`UpdateProfile` base64 or the off-spec route discovered this phase). If unresolved, ship display-only with fallback and surface the gap.

---

## Testing / Verification

- **Web preview (localhost:8081):** verify invoice list + account switcher + prepay listing + **invoice/receipt PDF download (blob)** + notifications list/thread + Quick Access nav + health stats + edit-profile round-trip. The proxy must forward `ReceiptAsPDF` (binary) correctly.
- **Native-only (verified via logs / device):** Billplz gateway browser handoff, `Payment/Completed` confirm, `expo-file-system` download, `expo-image-picker` upload.
- Use test accounts: student the student test account, `Aunty1`/the test password (has siblings TTT, KHAIRUL SHAMIN).

## Open Items (resolved at implementation, not blockers)

1. `PayInvoices` exact request body — confirm safely (creating a Billplz bill ≠ charging; money moves only on the gateway page). Derive from `Outstanding/Fetch` invoice fields + the `PayTermPayments` flag.
2. `UpdateProfile` body shape — confirm via `MyInfo` round-trip.
3. Student photo get/upload endpoint — investigate further in Phase 3 (file-URL patterns, gateway pages, `UpdateProfile` image field) or request from the user.

## New dependencies

`expo-file-system`, `expo-sharing` (Phase 1 native download), `expo-image-picker` (Phase 3). `expo-web-browser` and `react-native-webview` already installed.

## Out of scope

Instructor-role payment flows; offline caching; push notifications; multi-currency.
