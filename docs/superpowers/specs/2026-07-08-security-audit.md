# Security Audit — D-CLIX app + Club.Api backend
2026-07-08 · branch `feat/payments-phase1` · reviewed against the six questions asked

Scope: the app is a React Native (Expo) **client** to a third-party live backend
(`http://apimac.zyncbook.com`). Client-side issues are FIXED in this branch; server-side
issues can only be **reported to the backend owner** — the app cannot enforce them.

Legend: ✅ fixed in-app · ⚠️ backend-owned (report) · ℹ️ verified OK

---

## 1. Authorization — can users read data that isn't theirs?

⚠️ **Unauthenticated document/QR endpoints with guessable IDs (backend, HIGH).**
`GET /Utilities/ReceiptAsPDF/{clubId}/0/{invoiceId}` and `/Utilities/StudentQRCode/...`
take **integer ids and require no token**. Invoice ids are sequential (e.g. 1483816), so
anyone can enumerate them and pull other members' receipts/PDFs. Classic broken
object-level authorization (IDOR). **Fix (backend):** require the bearer token on these
routes and check the caller owns the club/invoice.
- In-app mitigation ✅: receipt/invoice PDF buttons are already hidden for inactive
  accounts, and are only ever built for the signed-in user's own rows — the app never
  enumerates ids. It cannot add auth the server doesn't require.

⚠️ **Client-supplied `studentId` in data queries (backend, HIGH).** `Outstanding/Fetch`,
`FetchTermPayments`, `ClassBooking/PackageInfo/{studentId}`, `GetBookings?studentId=`
accept a student id from the client. If the backend doesn't verify the token owns (or
parents, via siblings) that id, a modified request reads another student's fees/bookings.
**Fix (backend):** derive the subject from the token, or authorize the id against it.
- In-app: the app only ever sends the user's own id or a sibling id returned by
  `Listing/MySiblings` (itself token-scoped) — no arbitrary ids.

## 2. Rate limiting — can the API be spammed/abused?

⚠️ **Backend-owned (MEDIUM).** No throttling is observable; auth, fetch, and pay endpoints
answer unlimited requests. **Fix (backend):** per-IP + per-token rate limits, especially on
`/Account/Authenticate` (credential stuffing) and the pay endpoints.
- In-app ℹ️: no abusive client behavior — the notification poller is 60 s foreground /
  15 min background, data hooks fire once per screen with no retry loops, bulk actions are
  bounded. The client does not amplify load.

## 3. Secrets management — are keys/tokens/credentials exposed?

✅ **Demo credentials no longer ship in release builds.** `login.tsx` prefilled real working
accounts (`DARSHANMUTHU`/`1234`, instructor `929645`/`22222`) — shipped inside the public
APK. Now gated behind `__DEV__`, so release builds ship **empty** fields. (Dev/web preview
still prefills for convenience.)
✅ **`.gitignore` hardened.** Both ignore files silently failed to cover `.env`. Now all
`.env*` variants (except `.env.example`) and all signing keys/keystores
(`*.jks/.keystore/.p12/.p8/.pem/.mobileprovision`) are ignored, so a real secret can't be
committed by an accidental `git add -A`.
ℹ️ **No hardcoded secrets in source or git history.** `.env` holds only the public API URL
+ local proxy URL; `EXPO_PUBLIC_*` are inlined into the bundle by design and are not
secret. No API keys, DB creds, or keystores were ever committed. Release APK is signed with
Expo's debug keystore (installable, no secret material) — see build workflow.

## 4. Access control — can a user escalate by editing requests?

ℹ️ **Role is UI-only; no client-side trust.** `isInstructor` is derived from the login flow
and stored in the session — it only decides which tabs/screens render. Every protected call
still carries the token and must be authorized **server-side**. A user who tampers with
local storage to flip the role would see instructor screens but each instructor API call is
still gated by their token.
⚠️ **Backend must enforce per-endpoint role/ownership (HIGH).** The app's role gating is
cosmetic by design; if the backend authorizes purely by "token is valid" without checking
role/ownership per route, the tampered-role case (and item 1's id case) become real.
**Fix (backend):** authorize every route by token identity + role + object ownership.

## 5. Token security — stolen JWT / revocation?

✅ **Token moved to the OS secure store.** Was in AsyncStorage (plaintext — readable via ADB
backup, root, or another app on a compromised device). Now in `expo-secure-store` (iOS
Keychain / Android Keystore, encrypted at rest); only the non-secret user profile stays in
AsyncStorage. New `src/api/secureStore.ts`; `auth.tsx` migrates old sessions on first
launch; the background task reads the token from the secure store. Logout + any 401 wipe
the token immediately (verified).
⚠️ **Plaintext HTTP transport (backend, HIGH).** The API is `http://`, so the bearer token
and all data travel **unencrypted** — on a hostile Wi-Fi they can be sniffed and the token
replayed. Secure storage doesn't help once it's on the wire. **Fix (backend):** serve over
HTTPS/TLS; then the app should drop the cleartext-traffic allowance
(`usesCleartextTraffic`) and pin to https.
⚠️ **Revocation (backend, MEDIUM).** A stateless JWT can't be revoked before it expires. A
stolen token stays valid until expiry. **Fix (backend):** short access-token TTL + refresh
tokens, or a server-side token denylist for immediate revocation.

## 6. Resilience — can one request/query take the system down?

⚠️ **Backend-owned (MEDIUM).** Report-style endpoints accept wide date ranges and unbounded
lists; without query cost limits / pagination / timeouts a single expensive or malicious
request can exhaust the server. **Fix (backend):** enforce max date ranges, paginate large
result sets, cap query cost, and set request timeouts.
ℹ️ **Client is defensive.** The HTTP layer catches network + JSON-parse failures and unwraps
the envelope safely; data hooks surface errors instead of crashing; notification code guards
non-array responses; PDF opens are wrapped in try/catch. Malformed/empty backend responses
degrade gracefully rather than crash the app.

---

## Fixed in this branch (commit `b949d85`)
1. Bearer token → OS secure store (Keychain/Keystore) with migration + background-task read.
2. Demo login credentials gated to `__DEV__` (empty in release APKs).
3. `.gitignore` (root + frontend) now covers all `.env*` and signing keys.

## Must be fixed by the backend owner (cannot be done in the app)
1. **HTTPS/TLS** on the API (stops token sniffing) — highest priority.
2. **Auth + ownership checks** on `/Utilities/ReceiptAsPDF` and `/Utilities/StudentQRCode`
   (currently public, id-enumerable).
3. **Ownership authorization** for client-supplied `studentId` queries.
4. **Rate limiting** on auth + pay + fetch endpoints.
5. **Token revocation** (short TTL + refresh, or denylist).
6. **Query cost limits / pagination / timeouts** on report endpoints.
