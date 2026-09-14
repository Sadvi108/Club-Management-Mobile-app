# Local iOS preview — 2.12.2 (build 20)

This records the local iOS review completed before the user-guide expansion and subsequent release. The original review did not publish changes. See the 2.12.2 release notes for the later published build.

The student Home/Profile screens use the current React Native orange layout. Corrections include the status badge, whole-number fees and singular invoice wording, profile photo fallback, overlapping virtual ID spacing, and Account Status first. Login/Profile show the build number.

Fresh installations and app updates require explicit sign-in. Same-build saved sessions must pass the profile API check before routing home. Android backup/transfer rules exclude app data.

Open `flutter_app/ios/Runner.xcworkspace`, select Runner and an iPhone simulator, then Run. Alternatively run `flutter run -d <simulator-device-id> --debug` from `flutter_app`. The project and Runner target require iOS 14+. Flutter's Swift Package Manager/CocoaPods integration is configured. The scanner was upgraded to Apple's native Vision implementation for Apple Silicon simulator support. Camera/photo permission descriptions and a domain-specific exception for the existing HTTP production API are configured.

Verified: 302 Flutter tests passed, 3 opt-in live tests skipped. Analyzer reported no errors/warnings, with 149 informational diagnostics. The actual ARM64 app launched on iPhone 17 Pro / iOS 26.5, initially showed login/version 2.12.2 build 20, then authenticated the supplied student account. Live Home/Profile data and both layouts were inspected. Live screenshots remain outside the repository because they contain member data.

No messages, attendance records, or payments were submitted. This preview does not verify physical-camera scanning, Android installation behavior, or remote push. Backend limitations remain in `realtime-verification.md`.
