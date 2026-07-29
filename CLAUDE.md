# CLAUDE.md — D-CLIX Club Management App

Expo Router React Native app for a martial-arts club, wired to the live **Club.Api**
backend. Repo is PRIVATE — keep it private (docs + prefilled login hold test creds).

## API environments (switchable at runtime)
- **prod** `http://apimac.zyncbook.com` — live academy data, 69 endpoints.
- **uat** `https://apimacuat.zyncbook.com` — same 69 endpoints byte-for-byte **plus** the four
  Boost gateway routes (`/Bcpg/PayInvoices|Callback|Redirect|VerifyPayment`).

Pick the default with `EXPO_PUBLIC_API_ENV=prod|uat` in `frontend/.env` (currently **uat**);
users switch at runtime from the **Server** chips on the login screen, which also drops the
session. Registry lives in `frontend/src/api/config.ts`.

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
- Branch `feat/payments-phase1` (all live-API work). `main` = old mock (unrelated history; don't force-push).
- `.git/hooks/post-commit` auto-pushes every commit. Just commit; it pushes.

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

## State note
DARSHAN's demo invoices were consumed by testing Bank-In (now pending payment slips → Fees Due RM 0).
Admin rejecting the slips restores them. Not a bug.
