# CLAUDE.md — D-CLIX Club Management App

Expo Router React Native app for a martial-arts club, wired to the live **Club.Api**
backend. Repo is PRIVATE — keep it private (docs + prefilled login hold test creds).

## API environments (switchable at runtime)
- **prod** `http://apimac.zyncbook.com` — live academy data, 69 endpoints.
- **uat** `https://apimacuat.zyncbook.com` — same 69 endpoints byte-for-byte **plus** the four
  Boost gateway routes (`/Bcpg/PayInvoices|Callback|Redirect|VerifyPayment`).

The app ships on **prod** and no longer shows a server switcher — the Server chips were removed
from the login screen, so users never pick a server. Registry lives in `frontend/src/api/config.ts`;
override the build default with `EXPO_PUBLIC_API_ENV=prod|uat` in `frontend/.env` for local work.

**Boost runs cross-host.** `/Bcpg/*` is not deployed to prod (it 404s there, 401s on UAT), so the
prod environment declares `boostVia: "uat"` and `src/api/http.ts` sends only those four routes to
the UAT host — auth, invoices and everything else stay on prod. That is only sound because the two
hosts are the **same database** (one token authenticates against both; identical invoice ids come
back from each). **Delete the `boostVia` line the moment `/Bcpg` ships to prod.** Caveat: UAT's
gateway is the `stage-pay.boostconnect.biz` sandbox pointed at live records, and it is unreachable
from a phone (self-signed cert), so Boost works in the browser only.

Two known UAT blockers are backend-owned — the host serves a self-signed Plesk certificate, and
the **invoice/term** paths of `/Bcpg/PayInvoices` 400 while looking the amount up
(`"The JSON value could not be converted to System.String. Path: $.status"`). The gateway itself
works: `purchaseItems` returns a real Boost checkout link. Details, repro, and the release
checklist: `docs/superpowers/specs/2026-07-28-uat-boost-gateway-integration.md` (§6 = latest).

## Layout
- `frontend/` — the app. Screens in `frontend/app`, API layer in `frontend/src/api`, theme in `frontend/src/theme.ts`.
- `frontend/scripts/cors-proxy.js` — local CORS proxy (port 8082) the web preview needs (API is plain HTTP).
- `docs/superpowers/` — design specs + plans.
- `backend/`, `flutter_port/` — unused legacy (mock).

## Run the web preview (iPhone layout, localhost:8081)
From `frontend/` (no yarn on the dev box; `npx expo` is broken — use the node cli):
```
npm install
node node_modules/expo/bin/cli start --web --port 8081
```
The CORS proxy must also run (port 8082) for browser API calls. `start-web.js` at the repo root
launches both (`node start-web.js`, also what `.claude/launch.json` / the preview tool runs).
Resize the preview to 375x812. NOTE: this dev box also has a copy of the launcher one level up,
outside the repo (`D:\Club-Management-Mobile-app-main (1)\start-web.js`) — that one is
machine-specific and is what the preview tool currently uses; the tracked copy is the portable one.

`frontend/.env` (gitignored) holds `EXPO_PUBLIC_API_URL` + `EXPO_PUBLIC_WEB_API_PROXY=http://localhost:8082`;
copy from `frontend/.env.example` if missing.

## Git workflow
- **`main` is the live app** — all real work lands here. `feat/payments-phase1` carries the same
  history and is kept in sync.
- The pre-2026-08 `main` (the original Emergent mock, unrelated history) is archived on
  `main-mock-archive`. Nothing references it; it exists so the old snapshot is not lost.
- `.git/hooks/post-commit` auto-pushes every commit **if the hook is installed** — a fresh clone
  has no hooks, so push manually there.

## API quick reference
- Auth `POST /Account/Authenticate` (multipart? no — JSON). Bearer token. Student `DARSHANMUTHU`/`1234` (userType 3).
- Payments: `POST /Outstanding/PayInvoices` is **multipart** — `InvoiceIds` (repeated) + `PaymentMethod`
  (2=Online → returns gateway URL; 1=Bank-In → requires `files` slip; **3=Cash, settles the invoice
  instantly with no payment — don't send it**).
- Boost: `POST /Bcpg/PayInvoices` is **JSON** — `{ invoiceIds, payTermPayments, purchaseItems }` →
  gateway URL in `data` (`https://stage-pay.boostconnect.biz?t=…`; that `t` is a checkout token,
  NOT a `VerifyPayment` reference). Use `api.startPayment(intent)`, which prefers `/Bcpg`, falls
  back to the legacy route on 404 so one build serves both servers, and refuses to mix
  `purchaseItems` with invoices. After the browser returns, `api.confirmPayment()` decides the
  outcome by reconciliation — never assume a payment succeeded.
  `payTermPayments` in the body is what makes **advance months with no invoice yet** payable
  (the legacy query flag never did); `purchaseItems` is the only way to raise a purchase request.
- Class booking: `TrainingTimeWithDateAndInstructor` returns a **weekly** timetable (the month in
  the path is ignored) and **`classLimit` is capacity, not availability — `0` books fine**, so never
  disable a slot on it. `BookNow` accepts duplicates and a weekday that doesn't match the slot, so
  the app owns the date choice and the duplicate check. `NextBookings` is always `[]` — filter
  `GetBookings` instead. Details: `docs/superpowers/specs/2026-07-29-class-booking-contract.md`.
- Attendance check-in: `POST /Attendance/Add` `{ qrCode, attendanceType, tTimeId? }`. **`attendanceType`
  must be 1** (student self check-in) — 0 and 3 always answer `data.status:-1 "Invalid QR Code"`, 2 is
  instructor marking. The centre QR (`Utilities/TrainingCenterQRCode/{clubId}/{tcid}` PDF) encodes
  **`TC-` + tcid padded to 8 digits** (`TC-00001945`); the student QR encodes `ST-00035842` and is NOT
  accepted. `data.status`: 0 = checked in, 1 = "Select your training class time" → resend with a
  `tTimeId` from `Listing/TrainingTimeByTcId/{tcid}`, -1 = not a centre code.
- Receipt/invoice PDF (public): `GET /Utilities/ReceiptAsPDF/{clubId}/0/{invoiceId}` (the id from
  Reports/Receipts is an **invoiceId** → use the 3rd slot, not paymentId, or you get a BLANK PDF).
- Profile edit + photo: `POST /Profile/UpdateProfile` multipart (PascalCase fields + `files` photo →
  returns `data` = DP url; photo then comes back as `user.profilePic`).
- Full details: `docs/superpowers/` and the project memory.

## Report-route quirks (all probed live on prod 2026-08-10, instructor RICK1/RTT branch KCP)
These are the contract, not bugs in the app — screens work around them, so don't "simplify" the
workarounds away.
- **`reportType` is cast to an int** by `/Reports/Reimbursement` and `/Reports/TournamentSummary`.
  A word ("Reimbursed", "upcoming") returns `{"status":400,"meta":{"code":0,"error":"Error
  converting data type nvarchar to int."}}`. `api.reimbursementReport` / `api.tournamentSummary`
  strip non-numeric values; those screens filter their rows client-side instead.
- **Failure envelopes carry `meta.code: 0` with the real code in `status`.** `http.ts` inspects
  both slots — reading `meta.code` first made failed requests look successful and handed screens
  the error envelope where they expected an array.
- **An envelope may omit `data` entirely** (`GET /Listing/DropdownListByType/6` →
  `{"status":200,"meta":{"code":200}}`). `http.ts` unwraps that to `null`; never key off
  `"data" in parsed` alone or callers get the envelope object and `.map` throws.
- **`/Reports/GradingSchedule` applies none of its filters** — `fromDate`, `toDate` and `eCenterId`
  are accepted and ignored (one week in 2026 and the whole of 2019 both return the same 713 rows).
  `app/r-grading.tsx` narrows the rows itself. It also returns `[]` for **any student token**,
  whatever the body — the schedule is instructor-scoped server-side, which is why students have no
  upcoming-grading list. Backend-owned.
- **`/Reports/TournamentSummary` is a medal summary, not a schedule** — rows are
  `{id, name, gender, playerCount, medal*}` grouped by gender, with `name` empty and **no date at
  all**, and dates in the body are ignored. "Upcoming" vs "Past" cannot be told apart from it.
- **`/Outstanding/Fetch` with null dates defaults to the current month** (7 rows for RTT in
  Aug-2026); an explicit wide range returns the full history (649 rows). `/Reports/HomePageStats`
  answers a *different* question again — it returned 3 / RM 420, exactly the current month's
  `Advanced*` invoices, while the list held 7 / RM 785. Anything that shows a dues headline must
  read the same query as the list it links to.
- **No route returns a student photo for a list.** DPs are `Files/DP/<guid>.png` keyed by a
  per-student GUID (`AuthUser.profilePic`), so a roster photo URL cannot be derived from a student
  id; `/Listing/StudentListByTcId` returns `{id, value, text}` only.
- **Student QR content is `ST-` + the student id padded to 8 digits** (`ST-00089623`) — read out of
  the text layer of the official `GET /Utilities/StudentQRCode/{clubId}/{branchId}/{id}` poster.
  Use `studentQrContent()`; a QR of the bare id is not a D-CLIX code and scanners reject it.

## State note
DARSHAN's demo invoices were consumed by testing Bank-In (now pending payment slips → Fees Due RM 0).
Admin rejecting the slips restores them. Not a bug.
