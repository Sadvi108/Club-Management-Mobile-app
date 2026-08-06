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

> **Superseded in part on 2026-07-29** — the gateway itself works. Purchases return a real
> Boost link; only the invoice and term paths fail. See §6.

### 4.1 The Boost gateway call fails server-side (invoice + term paths only — see §6)

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

---

## 6. Second pass — 2026-07-29 (re-probed live, wiring completed)

Both blockers from §4 are still live and unchanged (`/Bcpg/PayInvoices` still returns the
`$.status` deserialisation error for invoices; the host still serves the self-signed Plesk
certificate, `notAfter=17 Apr 2027`). Re-probing the route by request shape changed the
diagnosis and opened up two capabilities the app wasn't using.

### 6.1 The gateway works — the failure is the amount lookup, not the gateway

Same token, same server, four bodies:

| Body | Result |
|---|---|
| `{"invoiceIds":[]}` | `400 "Invalid Request"` (request validation) |
| `{"invoiceIds":[961685]}` — a **real** pending invoice (student 38668) | `400` `$.status` error |
| `{"invoiceIds":[],"payTermPayments":{"studentIds":[35842],"year":2026,"months":[8,9,10]}}` | `400` `$.status` error |
| `{"invoiceIds":[],"purchaseItems":[{…,"productId":259,"qty":2,"price":20,"totalAmount":40}]}` | **`200`** → `https://stage-pay.boostconnect.biz?t=2yoYIRarviWYHSfWLc0D7n` |

The purchase link is a real Boost checkout page (HTTP 200, Boost SPA). So the Boost merchant
credentials, the outbound call and the response parsing are all fine. The one thing purchase
lines have that invoices and term months don't is a **price in the request** — the invoice and
term paths have to look the amount up first, and it's that lookup whose JSON reply has a
non-string `status`. That is the code to fix, and it is much narrower than "the gateway is
broken".

Also worth knowing: a body carrying **both** a (bogus) invoice id **and** purchase lines returns
a gateway URL. The invoice is not demonstrably billed, so mixing the two silently risks a bill
that omits the invoices — `startPayment()` refuses to combine them.

### 6.2 The Boost link's `t` is not a reference

`https://stage-pay.boostconnect.biz?t=<token>` — `t` is the checkout session token.
`GET /Bcpg/VerifyPayment/2yoYIRarviWYHSfWLc0D7n` → `{"status":"NotFound"}`. The reference the
API knows only appears on the `/Bcpg/Redirect` return leg, which goes to the **browser**, not
to the app. `extractReferenceId()` therefore deliberately does not treat `t` as a reference, and
payments are confirmed by **reconciliation** instead (see 6.4).

### 6.3 What was wired this pass

| File | Change |
|---|---|
| `src/api/endpoints.ts` | `startPayment(intent)` replaces `startOnlinePayment(ids, opts)`: one intent covering `invoiceIds`, `term` and `purchaseItems`, /Bcpg preferred, legacy fallback on 404/405, and a hard refusal to mix purchases with invoices. `confirmPayment()` (see 6.4). `purchaseLine()` builds a `PurchaseRequestLineViewModel`. `extractReferenceId()` no longer guesses. |
| `src/api/types.ts` | `PaymentIntent`, `PaymentOutcome`. |
| `app/(tabs)/payments.tsx` | One online method per server — **Boost** where `/Bcpg` exists, legacy FPX/card where it doesn't (UAT's legacy online route proxies to the same Boost gateway, so offering both was offering the same payment twice). Advance Payment now allows **months with no invoice yet** on a Boost server (`payTermPayments` in the body is exactly what the legacy query flag never managed) — marked `*`, totals labelled "Est. Amt", final amount confirmed on the gateway page. Bank-in still refuses uninvoiced months, because that route bills invoice ids only. |
| `app/pay-dues.tsx` | `startPayment` + `confirmPayment`. |
| `app/purchase-request.tsx` | **Proceed to pay** now actually raises the purchase by paying for it through `/Bcpg` `purchaseItems` — the screen previously showed "Purchase request submitted" without calling anything, because no create-purchase route exists in the mobile API. On a non-Boost server it says so plainly instead. |

### 6.4 Confirming a payment without a return leg

`confirmPayment({ referenceId, invoiceIds, studentId, purchaseBaseline })`:

1. `VerifyPayment` polled up to 3× (2 s apart) — only when a genuine reference exists.
2. Reconciliation, which is what actually fires: refetch `Outstanding/Fetch` and check whether
   the invoices being paid are gone; for a purchase, whether a new `Reports/PurchaseRequests`
   row appeared.
3. Otherwise `"unknown"` with an honest message. It never claims a payment it can't evidence.

### 6.5 Verified live (web preview against UAT, student DARSHANMUTHU)

- Advance Payment lists Aug–Dec 2026 as payable with `*`; two months → "Est. Amt 160.00",
  "Pay Now · ~RM 160.00"; sheet shows Boost + Bank-In only.
- Proceed → `POST /@uat/Bcpg/PayInvoices` with the term model → the backend error is surfaced
  verbatim ("The JSON value could not be converted to System.String…"), no fake success.
- Purchase Request → Proceed to pay → real link `https://stage-pay.boostconnect.biz?t=4uinjkKM9u3hywezovTnHk`
  opened, and on return the honest "will appear under Purchase Requests once the payment is
  confirmed" (the payment was not completed).
- `tsc --noEmit` clean. No console errors.

### 6.6 The UAT certificate blocks the APK completely (why "purchases aren't available")

Reported from a device on v2.6.0: **New Purchase Request** answers "Not available on this server".
That message only shows when the app is signed in to a server without `/Bcpg` — i.e. Production.
The reason the device is on Production is that **it cannot reach UAT at all**:

```
subject = C=CH, L=Schaffhausen, O=Plesk, CN=Plesk
SAN     = (none — the extension is absent)
```

`plugins/withUatCertificate.js` fixes chain validation only. Android and iOS *also* verify the
hostname against the certificate's SAN list, and there is no SAN — `CN=Plesk` doesn't match
`apimacuat.zyncbook.com` either. So the TLS handshake is rejected before any request is sent, no
matter what the app trusts. **There is no in-app fix**; the host needs a real certificate
(Let's Encrypt, one click in Plesk).

App-side changes made in response: network failures on a `selfSignedCert` environment now say
exactly this instead of "Network error" (`src/api/http.ts`), and the purchase screen names the
server it is signed in to and how to switch (`app/purchase-request.tsx`).

### 6.7 Attendance check-in was sending the wrong `attendanceType` (fixed)

Every scan returned "Invalid QR Code". Cause was in the app, not the QR: `qr-scan.tsx` sent
`attendanceType: 0`, which the API always rejects. Probed on UAT with a real centre QR:

| body | `data.status` / message |
|---|---|
| `{"qrCode":"TC-00001945","attendanceType":0}` | `-1` Invalid QR Code |
| `{"qrCode":"TC-00001945","attendanceType":1}` | **`0` Attendance updated successfully** |
| `{"qrCode":"TC-00001945","attendanceType":2}` | `-1` Invalid Instructor details |
| `{"qrCode":"ST-00035842","attendanceType":1}` | `-1` Invalid QR Code (student QR is not a check-in code) |
| `{"qrCode":"TC-00001198","attendanceType":1}` | `1` **Select your training class time** |
| `{"qrCode":"hello-world","attendanceType":1}` | `-1` Invalid QR Code (so type 1 really does validate) |

The QR content itself was read by rendering the centre poster PDF
(`GET /Utilities/TrainingCenterQRCode/68/1945`) and decoding it: **`TC-00001945`** = `TC-` + centre
id padded to 8 digits. The student poster decodes to `ST-00035842`.

Confirmed the check-in is real: two rows appeared in `POST /Reports/Attendance` for today
("Present", SMK KK2, 15:30:23 and 15:30:47).

Fixed in `qr-scan.tsx`: sends `attendanceType: 1`, treats `status 1` by loading
`Listing/TrainingTimeByTcId/{tcid}` and re-sending the same code with the chosen `tTimeId`, and the
invalid message now tells the user which poster to scan. Verified in the web preview — `TC-00001945`
→ "Check-in Successful! SMK KK2", `TC-00001198` → the class-time step.

### 6.8 For the backend team

1. **Fix the amount lookup on the invoice/term path** (§6.1) — the gateway itself is fine.
2. `GET /Bcpg/Redirect` still 500s without a bearer (§4.3) — it is the browser return URL.
3. Install a real certificate on `apimacuat.zyncbook.com` (§4.2).
4. `purchaseItems` carries client-supplied `price`/`totalAmount`. If the server bills those
   rather than re-pricing from `productId`, a client can set its own price. Worth checking.
5. Confirm whether `invoiceIds` are billed when `purchaseItems` is also present (§6.1).

## 7. Third pass — 2026-08-06 (UAT and production share one database)

### 7.1 UAT is not a staging copy — it is a second API over the live data

Probed with a single token from `POST /Account/Authenticate` on UAT (student DARSHANMUTHU):

| Check | `apimac` (prod) | `apimacuat` (uat) |
|---|---|---|
| That UAT token on `GET /Profile/MyInfo` | `200` | `200` |
| Name / grade returned | DARSHAN MUTHUSIGAMANI · Grade 9 (White) | identical |
| `POST /Outstanding/Fetch` row count | 1 | 1 |
| Outstanding invoice id | **1542955** | **1542955** |

The token is accepted by both hosts (shared signing key) and both return the same row for the
same invoice id. So the two hosts are **two deployments of the API over one database**, not a
staging copy and a production copy.

### 7.2 Why that makes the "point the app at UAT for payments" shortcut unsafe

It is technically possible to leave the app on production and send only `/Bcpg/*` to UAT — the
token authenticates and the invoice ids match. It should not be done, because UAT's gateway is
`https://stage-pay.boostconnect.biz`, a **sandbox**. A sandbox checkout that settles against the
shared live database would mark a **real** invoice paid with no money received. Same hazard class
as §4.4 (`PaymentMethod=3` settling an invoice with no gateway).

Decision (2026-08-06, revised same day): the cross-host path **was** wired, to keep Boost in a
single production app rather than losing the feature while the backend catches up. `PROD` declares
`boostVia: "uat"` in `src/api/config.ts`, and `baseUrlFor()` in `src/api/http.ts` sends only
`/Bcpg/*` to the UAT host; auth, invoices and everything else stay on prod. On web this reuses the
existing `/@<key>` proxy route.

This is a stopgap and carries the sandbox risk above: **delete `boostVia` as soon as `/Bcpg` ships
to production.** §6.8 item 1 is still the real fix and is unchanged.

### 7.3 App state while waiting

- The login server switcher was removed; production is the only server the app uses.
  `restoreApiEnv()` now discards a persisted non-default choice so no install is stranded on a
  server it can no longer leave.
- `POST /Bcpg/PayInvoices` on production answers `404` (UAT answers `401`), which is what
  `hasBoostGateway: false` encodes in `src/api/config.ts`.
- Purchase-request explains the gateway is not deployed yet rather than telling the user to pick
  a server that no longer appears in the UI.

### 7.4 Extra note for the backend team

Because UAT writes to the live database, a sandbox gateway is currently pointed at real
financial records. Worth confirming that is intended, independently of items 1-5 in §6.8.

### 7.5 What the cross-host path does not fix

`/Bcpg` now resolves for the prod app, but Boost still cannot run on a phone: the UAT host serves a
self-signed certificate with no SAN for its own hostname, so iOS/Android refuse the connection
before any request is sent — routing a different path there changes nothing. Boost therefore works
in the **browser only** until either `/Bcpg` ships to prod or `apimacuat` gets a real certificate.
`networkErrorMessage()` in `src/api/http.ts` says exactly that when a `/Bcpg` call fails on device.
