# UAT / Boost payment gateway integration — 2026-07-28

Target: `https://apimacuat.zyncbook.com` (Swagger `Club.Api` v1).
App: `frontend/` (Expo Router). Branch `feat/payments-phase1`.

---

## 1. UAT vs production — what actually changed

Diffed both `swagger/v1/swagger.json` documents.

| | Production `http://apimac.zyncbook.com` | UAT `https://apimacuat.zyncbook.com` |
|---|---|---|
| Paths | 69 | **73** |
| Schemas | identical | identical + 2 new |

The management claim ("all endpoints are same and only URL change") is **correct**. The only
differences are four new Boost routes and their two request models:

```
POST /Bcpg/PayInvoices              RequestBcpgPayViewModel  → StringApiResponse (gateway URL in `data`)
POST /Bcpg/Callback                 BcpgCallbackViewModel    → "OK"
GET  /Bcpg/Redirect                 ?uuid&referenceId&status&amount&currency&description&signature → 302
GET  /Bcpg/VerifyPayment/{referenceId} → bare { "status": "..." }  (NOT the usual envelope)
```

No other path was added, removed, or changed shape. Every existing schema is byte-identical.

### Request models

```jsonc
// RequestBcpgPayViewModel  (application/json — NOT multipart like /Outstanding/PayInvoices)
{
  "invoiceIds": [1483816],
  "payTermPayments": { "studentIds": [35842], "year": 2026, "months": [8, 9] } | null,
  "purchaseItems": [ /* PurchaseRequestLineViewModel */ ] | null
}

// BcpgCallbackViewModel (server-to-server, the app never sends this)
{ "referenceId": "...", "status": "...", "uuid": "...", "amount": 0.0 }
```

Notably better than the legacy route: `payTermPayments` is a **body** field here, where
`/Outstanding/PayInvoices` bound it from the query string (which never worked — see the
2026-07-03 advance-payment findings).

### Auth

`/Bcpg/PayInvoices` and `/Bcpg/VerifyPayment` require the bearer token (401 without).
`/Bcpg/Redirect` and `/Bcpg/Callback` are anonymous.

---

## 2. What was wired in the app

| File | Change |
|---|---|
| `src/api/config.ts` | Environment registry (`prod` / `uat` / optional `custom`), runtime switch persisted to `dclix.apiEnv.v1`, `getApiBaseUrl()`. Default from `EXPO_PUBLIC_API_ENV`. |
| `src/api/auth.tsx` | Restores the environment **before** the session; `apiEnv` + `switchApiEnv()` on the auth context (switching drops the session — a token is only valid on its own server). |
| `src/api/http.ts` | Base URL is now resolved per request. **Surfaces in-envelope errors**: the backend answers HTTP 200 with `{ status: 400, meta: { error } }`, which the JSON paths previously swallowed. |
| `src/api/types.ts` | `BcpgPayRequest`, `BcpgVerifyResult`, `BcpgRedirectParams`, `PurchaseRequestLine`, `OnlinePaymentResult`. |
| `src/api/endpoints.ts` | `bcpgPayInvoices`, `bcpgVerifyPayment`, `extractReferenceId`, and `startOnlinePayment()` — prefers `/Bcpg`, falls back to the legacy multipart route on 404/405 so **one build works against both servers**. |
| `app/(tabs)/payments.tsx` | Boost method → `/Bcpg/PayInvoices`; verifies via `VerifyPayment` on return when the gateway URL carries a `referenceId`; term-payment context now carries `studentIds/year/months`. |
| `app/pay-dues.tsx` | Same gateway selection + verification. |
| `app/login.tsx` | **Server** chips (PROD / UAT) with the active origin shown underneath. |
| `scripts/cors-proxy.js` | HTTPS upstreams, per-environment `/@key` path prefix (no restart to switch), internal redirect following, and self-signed-certificate tolerance (dev only). |
| `plugins/withUatCertificate.js` | Android network security config trusting the UAT certificate **for that host only** (see blocker 2). |

Method routing:

- **Boost e-wallet** → `POST /Bcpg/PayInvoices`
- **Online (FPX / Card)** → legacy `POST /Outstanding/PayInvoices` `PaymentMethod=2`
- **Direct Bank-In** → legacy `PaymentMethod=1` + `files` slip (unchanged, still works on UAT)

---

## 3. Verification (live, 2026-07-28)

Web preview running against UAT through the proxy, signed in as a real UAT student:

- `POST /@uat/Account/Authenticate` → 200, session restored, role routing correct
- 10 screens loaded live UAT data with zero failures: home, profile, schedule, notifications,
  student details, purchases, pay-dues, chat, attendance, progress
- Payments tab listed 8 live pending invoices (RM 320)
- Pay sheet → **Boost** → Proceed → `POST /@uat/Bcpg/PayInvoices` fired, error surfaced in the UI
- Pay sheet → **Online** → Proceed → `POST /@uat/Outstanding/PayInvoices?PayTermPayments=false&PurchaseItems=false` fired
- Server switch to **PROD** → session dropped → login as the production demo student → every
  call moved to `/@prod/...`, 200 across the board
- `tsc --noEmit` clean

Production has no `/Bcpg` routes (verified 404 on both), so the fallback in
`startOnlinePayment` is what keeps production working from the same build.

---

## 4. Blockers — backend-owned, app cannot fix

### 4.1 The Boost gateway call fails server-side (blocks all online payment on UAT)

Every request with a non-empty `invoiceIds` returns:

```json
{"status":400,"meta":{"code":400,
 "error":"The JSON value could not be converted to System.String. Path: $.status | LineNumber: 0 | BytePositionInLine: 58."}}
```

Reproduced with:
- two different students and their own real invoice ids
- a nonexistent invoice id (`999999999`) — same error, so it fails **before** invoice validation
- `payTermPayments` / `purchaseItems` present, absent, and null
- **and on the legacy route too**: `POST /Outstanding/PayInvoices` with `PaymentMethod=2` on UAT
  returns the identical error, so both online paths now go through the same gateway helper

`{"invoiceIds":[]}` returns the ordinary `"Invalid Request"`, which confirms the request itself
is being accepted and the failure is downstream.

Reading: the API calls the payment gateway, gets JSON back whose `status` field is **not a
string** (a number, most likely an error response), and its deserialisation model declares
`status` as `string`. Either the gateway is rejecting the merchant credentials on UAT, or the
response model needs `status` typed to match. No gateway URL is ever produced, so there is
nothing for the app to open. **Bank-In (`PaymentMethod=1`) is unaffected and works.**

### 4.2 UAT TLS certificate is invalid

```
subject = C=CH, L=Schaffhausen, O=Plesk, CN=Plesk, emailAddress=info@plesk.com
issuer  = (same — self-signed)
valid   = 17 Apr 2026 → 17 Apr 2027
```

It is the stock Plesk self-signed certificate: wrong common name, no SAN for
`apimacuat.zyncbook.com`, not chained to any public CA. Consequences:

- browsers refuse the origin outright (`SEC_E_UNTRUSTED_ROOT`)
- Android throws `CertPathValidatorException` — an APK cannot reach UAT at all
- iOS refuses under ATS, and unlike Android there is no in-app way around it
- plain `http://` is not an escape: the host 301-redirects to `https://`

Fix is one click in Plesk (issue a Let's Encrypt certificate for the host). Until then:
the dev proxy tolerates it for the web preview, and `plugins/withUatCertificate.js` trusts it
for that one hostname on Android. Both are testing accommodations and should be removed once a
real certificate is installed — neither is acceptable in a shipped app, and iOS stays blocked.

### 4.3 `GET /Bcpg/Redirect` 500s without a token

```
System.InvalidOperationException: Unable to resolve service for type 'Club.Api.ViewModels.AppTenant'
while attempting to activate 'Club.Api.Controllers.BcpgController'.
```

The route is anonymous, but the controller's constructor needs a tenant that is only registered
for authenticated requests. This is the URL the gateway sends the **user's browser** to after
payment — a browser will never carry the bearer token, so the return leg always 500s. With a
token it works and 302s to `/Payment/Completed/Failed`.

### 4.4 `PaymentMethod=3` settles an invoice with no gateway

While probing the `PaymentMethod` enum on UAT, `PaymentMethod=3` returned `200` and immediately
marked the invoice paid — it created **receipt #10100033, RM 85.00, "Cash"** against student
`DARSHANMUTHU` for July-2026, with no payment taken. UAT data, reversible by an admin, but worth
knowing: an authenticated client can mark its own invoices paid as cash. Should be
instructor/admin-only server-side.

---

## 5. Release checklist

1. Backend installs a valid certificate on `apimacuat.zyncbook.com` → drop
   `plugins/withUatCertificate.js` and the proxy's `rejectUnauthorized: false`.
2. Backend fixes the gateway response deserialisation (4.1) → re-run the Boost payment end to end
   and confirm the returned URL, then confirm `referenceId` is present in it so
   `extractReferenceId()` can drive `VerifyPayment`. **The verification-on-return path is coded
   but has never seen a real gateway URL** — it is defensive, and skips silently rather than
   guessing when no reference is found.
3. Backend fixes `/Bcpg/Redirect` (4.3) and confirms the return URL the gateway is configured with.
4. Before a production release: set `EXPO_PUBLIC_API_ENV=prod` (or change `DEFAULT_ENV` in
   `src/api/config.ts`) — this build defaults to **UAT**.
