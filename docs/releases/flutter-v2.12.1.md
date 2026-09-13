Flutter 2.12.1 (build 19), package `com.dclix.clubapp`. This release includes the React Native v2.11.1 parity work and foreground API refresh fixes.

- Open chats and notification lists update from the server every five seconds while the app is active. Refreshes detect changed message content even when the unread count stays unchanged.
- Visible data screens refresh every 15 seconds, on app resume and after returning from an action. Confirmed attendance, booking and payment writes trigger refresh; payment selections and message drafts are preserved.
- QR attendance reports success only when the API explicitly confirms it. Selecting a class time is not a completed check-in.
- Local notification delivery retries after denied permission or delivery failure; the first message in an initially empty inbox is no longer lost. Notification taps open chat or the Auto Pay reminder page.
- Updated Flutter screens, light/dark themes, navigation, schedules, collections, purchase/payment flows and guide images based on the latest React Native tag.

**Verification and limits**

Automated checks: 297 tests passed; three opt-in live/credential tests skipped. Static analysis has no errors or warnings. Authenticated read checks passed for 75 of 78 account/endpoint combinations across two student accounts and one instructor account. `/Outstanding/FetchTranxCharges` returned an error envelope for all three accounts; the UI reports unavailable history rather than showing an empty result.

This is **foreground REST polling, not instant background push**. The inspected production and UAT Swagger APIs expose no device-token registration or message-stream contract, and no Firebase/APNs configuration was supplied. Android's background fallback has a minimum requested interval of 15 minutes and OS-controlled execution. Force-stopped apps do not receive this work.

No physical Android camera scan, live message send or attendance write was performed. Online payment remains blocked by the UAT server certificate configuration. New-student approval routes still require backend deployment. See `docs/realtime-verification.md` for the check matrix and remaining backend work.

**Installation:** The APK is a release-mode **debug-signed test build**. It is not a production-signed upgrade; its key may differ from earlier downloads. Preserve needed local app data before replacing an existing installation. A compatible production update requires the original signing keystore. The attached SHA-256 file verifies the downloaded bytes.
