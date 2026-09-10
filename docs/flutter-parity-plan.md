# Flutter parity plan

Goal: `flutter_app/` reaches feature and design parity with the Expo app in `frontend/`,
including every API and the Boost payment gateway, and becomes the shipping app.

## Where the two stand (audited 2026-09-10)

| | `flutter_app/` | `frontend/` (Expo) |
|---|---|---|
| Code | 22.5k lines, 77 Dart files | 15.1k lines, 54 screens |
| Tests | **212 passing** | none |
| Last real work | 2026-06-24 | 2026-09-10 |
| Toolchain | Flutter 3.41.7 — `pub get`, `analyze` (0 errors), `build web`, `test` all pass | Expo SDK 54 |

The Flutter app is NOT a mock: it has the full API service layer, student and instructor
screens, PDF receipts and QR scanning. The gap is roughly the last three months of Expo
work, plus one architectural correction.

## 1. Boost gateway — must be re-architected, not ported

`lib/services/bcpg_service.dart` talks **directly** to `stage-api.boostconnect.biz` using
HMAC-SHA256 with the **merchant secret compiled into the app**. Its own header comment
says: *"The merchant secret SHIPS INSIDE THE APK. Anyone decompiling the APK can extract it
and forge requests."*

The Expo app instead calls the backend's `/Bcpg/*` routes, so the server holds the secret.
Replace the direct client with those routes:

- `POST /Bcpg/PayInvoices` — JSON `{invoiceIds, payTermPayments, purchaseItems}` → gateway URL
- `GET /Bcpg/VerifyPayment/{ref}`, `/Bcpg/Callback`, `/Bcpg/Redirect`
- prod does not deploy `/Bcpg` (404s), so those four routes go to the UAT host while auth
  and everything else stay on prod — see `docs/ARCHITECTURE.md`
- confirm by reconciliation, never assume success

## 2. Missing endpoints (21)

```
/Account/ApproveStudent          /Account/RejectStudent
/Account/GetBranchesByClubCode   /Listing/DropdownListByType
/Listing/StudentListByTcId       /Listing/TrainingTimeByTcId
/ClassBooking/GetBookings        /ClassBooking/PackageInfo
/ClassBooking/TrainingTimeWithDateAndInstructor
/Outstanding/CollectionCountList /Outstanding/UpdateCollectionCount
/Outstanding/PayInvoices (PayTermPayments / PurchaseItems variants)
/Profile/NotificationDetails     /Profile/UpdateNotification2Read
/Reports/OnlineSubmissions       /Reports/OnlineSubmissionDetails
/Bcpg/PayInvoices  /Bcpg/VerifyPayment  /Bcpg/Redirect
```

Flutter references 85 endpoints overall — it already covers instructor reporting more
broadly than Expo does.

## 3. Screens — DONE (updated 2026-09-10, second pass)

Every student- and instructor-facing screen in the Expo app now has a Flutter equivalent.

| Area | Screens | Status |
|---|---|---|
| Booking | `book-class` | done |
| Payments | `purchase-request`, `purchases` | done |
| Messaging | `chat`, `chat-thread`, `helpdesk`, `notifications` | done |
| Alerts | `notification-settings` + the notification service | done |
| Club | `competition`, `offers`, `offer-detail` | done |
| Account | `edit-profile`, `student-details` | done |
| Navigation | `more` (feature catalogue) | done |
| Onboarding | `user-guide` (11 pages) | done, without screenshots |
| Student reports | the `r-*` set | covered by the instructor report routes (20 registered) |

Route names differ in two places, deliberately: Expo's `chat-thread` is
`/notification/:groupId` here, and `offer-detail` is `/offer/:code`.

### Deliberately NOT built

| Screen | Why |
|---|---|
| `autopay`, `autopay-setup` | Club.Api has no recurring-payment routes. The Expo screen is a disclosed UI shell that renders sample data behind a "Preview only" banner. Porting it would add a second place to maintain a promise the backend cannot keep. The user guide's Auto Pay claims were corrected for the same reason. |
| `new-student`, `student-particulars` | The online-submission approval routes 404 on both prod and UAT. Expo ships an "awaiting backend" state; there is nothing to port until the endpoints exist. |

### Screenshots

The Expo guide bundles a capture per page. Those are captures of the Expo UI, so they were
not carried over — a picture of a different app is worse than no picture. Add Flutter
captures when there are real ones.

### Dead-link guard

`test/navigation_targets_test.dart` walks the router tree and asserts that every entry in
the More catalogue, the home quick-access grid and the instructor report list resolves to a
registered route. Nothing in the type system connects those four lists, and a renamed route
compiles clean and fails only under a member's thumb.

## 4. Notifications — build from scratch

Flutter has a notification bell and a detail screen, but none of the 2026-09 system:
poll + local alerts, bundled chime, Android channels with frozen sound, per-category
mutes, quiet hours that DEFER rather than discard, and the settings screen.
Port the logic from `frontend/src/notifications/` (it is well covered by tests there).

## 5. Security parity

Carry over the fixes made on 2026-09-09/10, and do not regress them:

- no credentials in source — dev prefill via `--dart-define`, never committed
- bearer token in secure storage only, never duplicated into plain prefs
- raw server/SQL errors must not reach the UI (see `innerErrorMessage` in `http.ts`)
- remove the compiled-in Boost merchant secret (item 1)

## 6. Branding + release

- app icon, splash and Android notification icon from `frontend/assets/branding/`
- app id `com.dclix.clubapp` (Flutter currently `com.example.club_management_app`)
- a `build-flutter-apk` workflow alongside the existing Expo one

## Suggested order

1. Foundation: verify live login, app id, branding
2. Security parity (§5) + Boost re-architecture (§1)
3. Missing endpoints (§2)
4. Screens by value: booking → chat/notifications → autopay/purchases → more → guide
5. Flutter APK workflow, then retire `frontend/`
