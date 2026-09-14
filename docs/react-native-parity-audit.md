# React Native → Flutter parity audit

Reference checked on 2026-09-11. The last React Native app is **v2.11.1**, commit
`5223e60c4850746511374cd51f27a6dc99249f4f` (2026-09-10). Its `frontend/package.json`
uses React Native **0.81.5**, Expo **~54.0.34**, and React **19.1.0**.

Source: [v2.11.1](https://github.com/Sadvi108/Club-Management-Mobile-app/tree/v2.11.1/frontend).
The main branch removed `frontend/` in `b592c90`; the downloaded Flutter archive matched
main `01b2179` before these corrections. The previous parity plan described the June port
and also claimed completion in several sections. It was not a reliable statement of parity.

## Corrections in this workspace

| Area | Gap found | Change |
|---|---|---|
| Theme | Different font, colors, shadows and icons | Ported both RN palettes/shadows, system typography and bundled the matching Ionicons font with its license. |
| Navigation | Different bottom bar, scan destination and missing catalogue entries | Shared frosted bar with round Scan control; separate instructor scan and Class Check-In; restored dashboard/menu links, History and Offers deep links. |
| Student home | Older dashboard hierarchy | Gradient identity header and stats, five quick actions, fee summary, class card, 13 Quick Access tiles and offer artwork. Failed stats show retry/unavailable. |
| Instructor home | Older dashboard and wrong source for dues | Original 12 colored tiles, club updates, offers/news and outstanding-invoice totals. |
| Login | Old card styling, misleading remember/reset controls, branch search reset/race | Restored original layout structure and copy, kept device session persistence, fixed search state, stale responses and Material ancestor. |
| Schedule | Only bookings displayed; ordinary weekly classes missing | Read weekly lessons from StudentDetails, supplement with bookings, ten-day selector, clear failed-request state and booking action. |
| Fees | Missing Pay / Advance Payment / History organization; ten-invoice and thirty-receipt limits | Restored segments/deep links, sibling chips that refetch with the selected student ID, stale-response guards, individual selectable invoice cards, select-all and totals; removed display limits. |
| Bank transfer | JSON submission without the required slip | Gallery attachment and multipart request with repeated InvoiceIds, payment method and image bytes. |
| Advance payment | Legacy route and misleading handling of missing quotes | Backend Boost term model for quoted future months, including invoiceId 0, with selected student IDs/year/months; checkout confirms final amount; explicit quote failures and stale-selection guards. |
| Payment completion | Partial account lookup could report paid; partially settled invoices reported unpaid; return path out of date | Require every account lookup; partial settlement is unknown with history guidance; recognize merchant `/Bcpg/Redirect`; closing checkout does not promise cancellation. |
| Class Check-In | Manual/NFC roster marking implied the token could check in other students | Match RN: centre/time/roster selection, centre QR and printable centre QR poster; clear stale roster on centre changes. |
| Reports | Different report menu; gender-only tournament totals discarded | Restore original report labels/order and gradient header; retain gender/category medal summaries; working tournament-name filtering. |
| Collections | “Update Collection” presented as incrementing a count | Refresh all three collection types and reload totals; original centered tiles and title. |
| New Student | Displayed enrolled students as pending registrations | Dedicated submissions/details/approve/reject contracts and explicit “Awaiting backend” for unavailable routes. |
| Events | Events/offers combined incorrectly | Separate Events / Offers segments and offers deep link. |
| Profile | Club picture used as missing personal photo; invalid QR image threw | Member photo sources, initials fallback and QR error state; virtual ID uses the selected student ID. |
| HTTP failures | HTTP-200 error envelopes could become empty lists; database messages visible | Inspect both status and meta.code, throw typed errors, preserve useful messages and suppress internal server details. |
| App version / access | Session checked an old version; instructor routes unguarded | Shared current version constant and authenticated/role route guards. |
| Guide evidence | Old/incorrect screenshots, missing dark-mode validation | Portable capture tool uses the real theme/fonts/shell, visible shadows and fictional API fixtures, including a sample-only QR. |

## Route mapping

These are implementation counterparts, not a claim of device-tested pixel identity. Existing
screens outside the rewrites receive the shared styling/icons and retain their existing
functional tests. React Native paths below omit `frontend/app/` and `.tsx`.

| React Native screen | Flutter screen / destination |
|---|---|
| index, login | SplashScreen, LoginScreen |
| (tabs)/home | HomeScreen / InstructorHomeScreen according to role |
| (tabs)/schedule | ScheduleScreen |
| (tabs)/training | TrainingScreen |
| (tabs)/payments | PaymentsScreen: Pay, Advance Payment, History |
| (tabs)/profile | ProfileScreen |
| (tabs)/qr, qr-scan | QrScanScreen, reached from the center Scan control |
| (tabs)/collections, collection-list | InstructorCollectionsScreen and its collection detail page |
| (tabs)/reports | InstructorReportsScreen |
| (tabs)/settings | InstructorSettingsScreen |
| attendance | AttendanceScreen |
| update-attendance | InstructorAttendanceScreen /instructor/attendance |
| book-class | BookClassScreen |
| autopay, autopay-setup | AutoPayScreen and TermPaymentScreen (reminders; see exception below) |
| chat, chat-thread | ChatScreen, ChatThreadScreen /notification/:groupId |
| notifications, notification-settings | NotificationsScreen, NotificationSettingsScreen |
| edit-profile, student-details | EditProfileScreen, StudentDetailsScreen |
| helpdesk | HelpDeskScreen |
| more, user-guide | MoreScreen, UserGuideScreen |
| events | EventsScreen with Events / Offers segments |
| offer-detail | OfferDetailScreen /offer/:code |
| competition | CompetitionScreen |
| progress | ProgressScreen |
| pay-dues | OutstandingInvoicesScreen /invoices |
| purchases, purchase-request | PurchasesScreen, PurchaseRequestScreen |
| new-student | NewStudentScreen /instructor/reports/new-student |
| student-particulars | StudentParticularsScreen /instructor/student-particulars/:id |
| r-student-centers | /instructor/reports/student-centers |
| r-training-centers | /instructor/reports/training-centers |
| r-exam-centers | /instructor/reports/exam-centers |
| r-student-list | /instructor/reports/student-list and student detail |
| r-training-schedule | /instructor/reports/training-time |
| r-grading | /instructor/reports/grading-schedule and grading-past |
| r-outstanding | /instructor/reports/outstanding |
| r-attendance | /instructor/reports/attendance |
| r-receipts | /instructor/reports/receipt |
| r-payment-slips | /instructor/reports/payment-slip |
| r-purchase-requests | /instructor/reports/purchase-request |
| r-tournament-past, r-tournament-upcoming | /instructor/reports/tournament-past and tournament-upcoming |
| r-contribution, r-reimbursement | /instructor/reports/contribution and reimbursement |

## Subsequent live refresh work

The 2.12.1+19 API refresh changes, authenticated read matrix and current release limitations are in [realtime-verification.md](realtime-verification.md). The following build/screenshot checks describe the earlier 2.12.0 parity snapshot.

## Verification and remaining limits

Completed checks on the final Dart source:

| Check | Result |
|---|---|
| `flutter test` | **286 passed, 3 opt-in tests skipped** |
| `flutter analyze --no-fatal-infos` | **0 errors, 0 warnings**; 122 informational lint/deprecation notices remain |
| Light screenshot harness | **23 passed**: 22 renders + fictional-data guard |
| Dark screenshot harness | **23 passed**: 22 renders + fictional-data guard |
| `flutter build web --release` | **Passed** (JavaScript build; existing plugins do not support the Wasm dry run) |
| `flutter build apk --release` | **Passed**, 84.5 MB; debug-signed test artifact at `flutter_app/build/app/outputs/flutter-apk/app-release.apk` |
| `flutter build apk --debug` | **Passed**; package `com.dclix.clubapp`, version `2.12.0`, versionCode `18`, minSdk `24` |

Reproduce from `flutter_app/`. Capture commands are
`flutter test tool/capture_guide_shots.dart --dart-define=CAPTURE=true`, adding
`--dart-define=DARK_CAPTURE=true` for dark mode. No server is contacted by these captures.


- Offline widget/service/navigation tests exercise weekly timetable data, failed requests,
  branch search, centre switching, invoice tabs, multipart slips, partial settlement,
  collection refresh, photo fallback, and HTTP error handling.
- Screenshot harness renders 22 screens in each theme, plus a fictional-data guard. Each
  capture rejects unresolved loading indicators and Flutter error widgets. Light guide
  captures are in `flutter_app/assets/guide/`; additional light and all dark captures are
  in `docs/parity-captures/`. These are 390×844 widget renders, not phone screenshots.
- No live member account, bank transaction, registration approval, notification delivery,
  camera scan, NFC interaction or iOS device run was performed in this task.
- A full side-by-side device comparison of every modal, report, keyboard and accessibility
  state remains necessary before claiming exact visual/behavioral parity. Flutter controls,
  some report layouts, account switching and Auto Pay remain native Flutter implementations.
- Auto Pay remains a disclosed monthly reminder with manual confirmation. RN's preview
  mandate screen does not have a recurring-debit backend to reproduce as a working feature.
- RN's Past/Upcoming tournament pages call the same date-less summary API. Their entry
  points are present here too; neither can honestly separate past from future events.
- The new-student routes are proposed contracts also used by RN. The repository's deployed
  route fixture does not contain them. An unavailable server shows “Awaiting backend”; it
  is not treated as an empty pending queue. Deployment of those routes belongs to Club.Api.
- The existing Boost UAT host is documented in RN as self-signed **and missing the host SAN**.
  The Android trust file alone does not make it usable: Dart HTTP and hostname validation
  still reject it. The backend needs a valid host certificate or production Boost routes.
  No certificate-validation bypass was added. Online checkout is not claimed live-verified.
- Android release configuration currently signs with the debug key. A production update
  needs the original app's signing key as well as versionCode 18; matching package ID and
  a higher version alone do not make an installed Expo app upgradeable.

## 2026-09-14 — every React Native screen re-ported 1:1

Branch `feat/flutter-rn-parity`, Flutter **2.13.0+21**. The reference is unchanged (Expo v2.11.1,
`5223e60`). This pass replaced the *approximated* Flutter screens with direct ports of each
`frontend/app/*.tsx` file: same layout tokens (`radius`, `spacing`, `font`, shadows), same
Ionicons glyphs, same copy, same API calls and the same edge-case handling.

### Shared primitives added

| File | React Native source | Notes |
|---|---|---|
| `lib/theme/ion.dart` | `@expo/vector-icons` Ionicons glyph map | All 1,357 glyphs, camelCase (`Ion.arrowForward`). Generated from the exact glyphmap JSON; the bundled TTF is byte-identical to Expo's. |
| `lib/widgets/rn_kit.dart` | `src/ui/{skeleton,errorstate,glass,dialogs,avatar}.tsx` | `Touchable` (TouchableOpacity), `Skeleton*`, `ErrorState`, `Glass`, `notify`/`confirmDialog`, `safeBack`, `RnHeader`, `rnCard`, JS number formatting (`localeNum`, `money2`, `jsNum`). |
| `lib/widgets/report_kit.dart` | `src/ui/reportkit.tsx` | `ScreenHeader`, `SelectField` (bottom-sheet picker), `DateField` (month calendar sheet), `ReportScaffold`, `KV`, `toISODate`. |
| `lib/widgets/use_api.dart` | `src/api/useApi.ts` | `ApiResource` + `UseApi` mixin: a failed fetch keeps the data already on screen; `reload` supersedes in-flight runs; account switches refetch. |
| `lib/services/rn_api.dart` | `src/api/endpoints.ts` | Typed mirror of the RN endpoint table; unwraps the envelope exactly as RN `http` does. |

### Screens

Student: login, home, schedule, training, payments (Pay / Advance Payment / History + the Make
Payment sheet with Boost and bank-in slip), profile (with the RN switchers), more, events &
offers, offer detail, competition, help desk, attendance, student details, progress, edit profile,
purchases, purchase request, book a class, chat, chat thread, notifications, notification
settings, QR check-in, user guide.

Instructor: home, collections + collection list, reports menu, class check-in
(`update-attendance`), new student + student particulars, pay your dues, and all fourteen `r-*`
reports (`lib/screens/instructor_reports/rn_reports.dart`). The Settings tab is the role-aware
Profile screen, as in Expo. Switch Branch stays available there as an action row.

### Kept from the earlier Flutter work, on purpose

- **Auto Pay** — Expo's screen is a placeholder shell (fixed sample data, every action a no-op).
  The Flutter reminder-based Auto Pay is real and stays.
- **Activities / Fee Master / Missing Invoice / Tournament Schedule** — "coming soon" in Expo;
  the working generic report screens are kept behind those tiles.
- **Payment lock, live refresh, secure token storage, OS notifications, background poll** —
  services that have no RN counterpart to regress to.

### Web preview

`ApiService.webApiProxy` (`--dart-define=WEB_API_PROXY=http://localhost:8082`) routes browser
calls through the same CORS proxy the Expo web preview used (`/@prod`, `/@uat` prefixes), so the
Flutter web build can be compared against the Expo web build side by side on live data.

### Verification

`flutter analyze lib test tool` — 0 errors, 0 warnings. `flutter test` — **298 passed**, 3
opt-in live tests skipped. Tests that asserted the older Flutter wording/controls were updated to
the RN wording (e.g. `Try again`, `STEP 1 OF 12`, `Offer not found`, bottom-sheet pickers).
