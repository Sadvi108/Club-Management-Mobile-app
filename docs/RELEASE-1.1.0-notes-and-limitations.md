# D-Clix App — Release 1.1.0 — Notes & Known Limitations

_Prepared for management review. Branch: `live-api-integration`. Version: `1.1.0+2`._

## What was fixed/added in this version

**Instructor side (was largely non-functional, now working):**
- Instructor login now loads all data (home dues/stats, profile, reports). Previously every instructor screen was blank due to a user-type detection bug.
- Switch Branch now works (was using a server endpoint that rejects instructor accounts).
- Profile, Collections, and all Quick-Access reports pull live data.

**Receipts & reports:**
- Official receipt now shows the full receipt (all line items), correctly formatted.
- Receipt payment-mode filter, report labels (Outstanding, Invoice Types), New Student report, Tournament rows, and Collections "Payment Slips" all corrected to match the live API.

**Login & errors:**
- Wrong password now shows a clear popup with the real reason.
- Network/server failures show friendly messages instead of raw technical errors.

**New feature:**
- Advance (prepay future months) — pricing/preview is live; the actual charge is intentionally disabled pending one verification step (see Limitation 5).

All changes are covered by automated tests (65 passing) and pushed to GitHub.

---

## Known limitations — require action OUTSIDE the app code

These are **not** code defects in the app. Each needs an environment, backend, or
account action that the app developer cannot perform from the code side.

### 1. The installable APK must be built on a machine with Android Studio
The release `.apk` binary cannot be produced in the current coding environment —
it has no Android SDK installed. The **app code is release-ready** (version
`1.1.0+2`). Anyone with Android Studio / the Android SDK builds it with one
command: `flutter build apk --release`. (Output: `build/app/outputs/flutter-apk/app-release.apk`.)
**Action:** build on a developer machine (or set up the SDK), then attach to a GitHub Release.

### 2. Publishing the GitHub Release needs repository authentication
Code is pushed to the branch, but creating a downloadable Release and uploading
the APK requires a signed-in GitHub account / token on the build machine.
**Action:** sign in (`gh auth login`) once, then publish the release.

### 3. The backend API uses plain HTTP, not HTTPS
The server (`apimac.zyncbook.com`) is served over **http://**, not https. The app
is configured to allow this so it works on Android, but transmitting login and
payment data over plain HTTP is a **security concern that only the backend team
can resolve** by moving the API to HTTPS.
**Action:** backend team to enable HTTPS.

### 4. The backend API sends no CORS headers (web browser only)
This affects **only** running the app inside a desktop web browser for preview.
The Android APK is **unaffected** — phones make direct calls with no CORS. If a
web version is ever needed, the **backend must add CORS headers**.
**Action:** backend team, only if a browser build is required.

### 5. Advance-payment "Pay" is gated pending one live test
The prepay screen prices future months correctly (verified against live data).
The actual payment call is built but **disabled by a flag** until it is tested
once with a small real transaction on a student who has a monthly-fee plan —
because it moves real money, it should be confirmed live before release.
**Action:** run one small prepay on a plan-enabled account, confirm it posts,
then enable the flag.

### 6. Help Desk message delivery not yet live-confirmed
The Help Desk submission was corrected to the server's expected format, but a
real test message was deliberately not sent (to avoid a junk ticket to the club).
**Action:** send one test Help Desk message to confirm it arrives.

### 7. Data that is genuinely empty (not an error)
Some reports/lists are empty for certain accounts/branches because there are no
such records on the server (e.g. a student with no bookings, a branch with no
payment slips). The app shows a friendly "no records" state — this is correct
behaviour, not a malfunction.

---

## How to build & ship the APK (for the developer with Android Studio)

```bash
cd club_management_app
flutter pub get
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk  (version 1.1.0+2)
```
Then create a GitHub Release on `Sadvi108/Club-Management-Mobile-app` and attach
the APK.
