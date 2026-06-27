# CLAUDE.md — D-CLIX Club Management App

Expo Router React Native app for a martial-arts club, wired to the live **Club.Api**
backend (`http://apimac.zyncbook.com`). Repo is PRIVATE — keep it private (docs + prefilled
login hold test creds).

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
The CORS proxy must also run (port 8082) for browser API calls. `../start-web.js` launches both
(used by `.claude/launch.json` / the preview tool). Resize the preview to 375x812.

`frontend/.env` (gitignored) holds `EXPO_PUBLIC_API_URL` + `EXPO_PUBLIC_WEB_API_PROXY=http://localhost:8082`;
copy from `frontend/.env.example` if missing.

## Git workflow
- Branch `feat/payments-phase1` (all live-API work). `main` = old mock (unrelated history; don't force-push).
- `.git/hooks/post-commit` auto-pushes every commit. Just commit; it pushes.

## API quick reference
- Auth `POST /Account/Authenticate` (multipart? no — JSON). Bearer token. Student `DARSHANMUTHU`/`1234` (userType 3).
- Payments: `POST /Outstanding/PayInvoices` is **multipart** — `InvoiceIds` (repeated) + `PaymentMethod`
  (2=Online → returns Billplz URL; 1=Bank-In → requires `files` slip).
- Receipt/invoice PDF (public): `GET /Utilities/ReceiptAsPDF/{clubId}/0/{invoiceId}` (the id from
  Reports/Receipts is an **invoiceId** → use the 3rd slot, not paymentId, or you get a BLANK PDF).
- Profile edit + photo: `POST /Profile/UpdateProfile` multipart (PascalCase fields + `files` photo →
  returns `data` = DP url; photo then comes back as `user.profilePic`).
- Full details: `docs/superpowers/` and the project memory.

## State note
DARSHAN's demo invoices were consumed by testing Bank-In (now pending payment slips → Fees Due RM 0).
Admin rejecting the slips restores them. Not a bug.
