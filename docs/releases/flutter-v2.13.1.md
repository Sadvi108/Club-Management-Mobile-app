D-CLIX Flutter **2.13.1 (build 22)** includes the latest React Native parity screens from main and a complete offline user guide.

### User guide

- **57 feature pages**, each with a screenshot and numbered instructions.
- Searchable All features contents, with Student, Instructor and Instructor reports sections.
- Full-screen image viewing with pinch-to-zoom. Example records and QR payloads are fictional.
- Coverage includes sign-in, Home, training, QR attendance, booking, payments and receipts, reminders, profile, messages, purchases, events/offers, instructor collections and every instructor report route.
- Corrected outdated instructions about password resets, session restoration, notifications and backend-dependent features.
- Fixed the guide’s Next-button layout and a deferred-loading issue that prevented several instructor reports from opening correctly.

### Install this version

Download **dclix-flutter-2.13.1-build22.apk**, install it, and open **D-CLIX Flutter**. The login screen shows **2.13.1 (build 22)**.

This release uses a separate Android package, `com.dclix.clubapp.flutter`, and a persistent release signing key. It installs alongside legacy Expo/Flutter APKs, whose signing keys may differ. Local settings and outgoing chat history from the old package are not migrated. Your club records load after sign-in. Fresh installations and app updates require explicit sign-in; valid same-build sessions can be restored after server validation.

Future APKs for this Flutter package must use the same signing key. The attached SHA-256 file verifies the downloaded APK bytes.

### Verification and remaining limits

The guide covers every user-facing app route, including collection details. Automated checks exercise every guide page, search, screenshot zoom, session restoration and deferred report loading. Screenshots are generated from the actual Flutter screens using sample data, not production member records.

Local validation: **306 tests passed, 3 skipped**; analysis reported no errors or warnings (64 informational diagnostics). All 57 guide screenshots were verified inside the signed APK, whose package and version are `com.dclix.clubapp.flutter`, `2.13.1`, build `22`.

This release does not add instant closed-app push. Foreground messages use REST refresh; Android background polling has a minimum requested interval of 15 minutes and can be delayed or stopped by the OS. Backend push-token/stream support and Firebase/APNs configuration remain unavailable. Payment gateway certificate issues and undeployed new-student approval endpoints also remain backend limitations. No live message, payment or attendance writes were made for this release, and no physical Android camera scan was verified. See `docs/realtime-verification.md` for earlier API checks and limits.
