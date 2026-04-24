# D-Clix — Flutter Port

Flutter version of the D-Clix sports academy mobile app, ported 1:1 from the React Native Expo codebase. All 10 screens are fully ported and ready to run — optimized for **Chrome / web** (with graceful fallback to simulated QR scan when camera access is denied).

---

## 🚀 Quick Start (Chrome / VSCode)

```bash
# 1) Prerequisites
flutter --version          # should report Flutter 3.22+ / Dart 3.3+
flutter config --enable-web
flutter doctor             # fix anything red

# 2) Create a new Flutter project shell (gives you android/, ios/, web/ folders)
cd ~/code
flutter create dclix_app
cd dclix_app

# 3) Drop in the port → copy THESE into the generated project:
#    /app/flutter_port/pubspec.yaml   →   dclix_app/pubspec.yaml   (overwrite)
#    /app/flutter_port/lib/           →   dclix_app/lib/           (replace)
#    /app/flutter_port/assets/        →   dclix_app/assets/        (create if missing)

# 4) Add the logo asset
mkdir -p assets/images
curl -L -o assets/images/logo.png \
  "https://customer-assets.emergentagent.com/job_training-portal-126/artifacts/d0r3ioz1_dclix%20logo%202026.png"

# 5) Install packages
flutter pub get

# 6) Run on Chrome
flutter run -d chrome
# or just press F5 in VSCode after selecting "Chrome (web-javascript)" as device
```

> **VSCode tip:** install the **Flutter** + **Dart** extensions, open the `dclix_app/` folder, then use the device picker in the bottom-right to pick **Chrome**, then hit ▶︎.

---

## 📱 Running on other targets

| Device | Command |
|---|---|
| Chrome | `flutter run -d chrome` |
| Android emulator | `flutter emulators --launch <id>` then `flutter run` |
| iOS simulator (macOS) | `open -a Simulator` then `flutter run` |
| Physical Android | enable USB debugging, `flutter devices`, `flutter run` |
| Physical iPhone | sign in Xcode, `flutter run` |

---

## 🗂️ Project structure

```
dclix_app/
├── pubspec.yaml                # packages: go_router, provider, mobile_scanner, shared_prefs
├── assets/images/logo.png      # D-Clix logo (copy from CDN — see step 4)
└── lib/
    ├── main.dart                      # Entry point
    ├── theme/
    │   ├── app_theme.dart             # lightColors / darkColors / gradients / tokens
    │   └── theme_provider.dart        # Provider — persists choice via shared_preferences
    ├── router/
    │   └── app_router.dart            # go_router config (splash → login → tabs → deep routes)
    ├── models/
    │   └── models.dart                # Student, Program, Session, Event, …
    ├── data/
    │   └── mock_data.dart             # Seeded mock data (same as mockData.ts)
    ├── widgets/
    │   ├── gradient_button.dart       # Reusable orange-gradient primary CTA
    │   └── stat_card.dart             # Reusable stat tile
    └── screens/
        ├── splash_screen.dart         ✅
        ├── login_screen.dart          ✅  Student / Instructor tabs + theme toggle
        ├── tabs_shell.dart            ✅  Bottom nav + center QR FAB
        ├── home_screen.dart           ✅  Dashboard with stats + Fees Due + quick grid
        ├── training_screen.dart       ✅  Weekly streak + enrolled programs
        ├── schedule_screen.dart       ✅  Day-chip header + session list + holidays
        ├── payments_screen.dart       ✅  Due card + Pay modal + history list
        ├── attendance_screen.dart     ✅  Ring % + monthly calendar + missed history
        ├── progress_screen.dart       ✅  Fitness score + belt journey + skills + feedback
        ├── events_screen.dart         ✅  Upcoming / Registered / Certificates tabs
        ├── profile_screen.dart        ✅  Virtual ID card + dark-mode switch + logout
        └── qr_scan_screen.dart        ✅  mobile_scanner + web fallback
```

**All 10 screens are live.** The stub file (`stubs.dart`) has been removed.

---

## 🎨 Theming

`ThemeProvider` (in `lib/theme/theme_provider.dart`) handles light / dark mode.

```dart
// Read palette anywhere
final c = context.appColors;

// Toggle theme
context.read<ThemeProvider>().toggle();

// Set explicitly
context.read<ThemeProvider>().setDark(true);
```

- **Light**: Orange (`#F97316`) + White — pure white surfaces, orange accents.
- **Dark**: Orange (`#FB923C`) + Black — near-black surfaces, warm orange accents.
- Choice is persisted to `shared_preferences` automatically.

---

## 📷 QR Scanner notes (Chrome-specific)

The QR screen uses `mobile_scanner ^5.2.3`. On **Chrome**:

1. When Flutter asks for camera permission, click **Allow**.
2. If the browser blocks camera (HTTP context, user denied, no device), the screen **automatically falls back** to a simulated successful scan after ~2 seconds so you can still demo the success state.
3. For real scanning on web, serve over HTTPS or `localhost` (the `flutter run -d chrome` default **is** localhost, so it works).
4. On production web deploys, add HTTPS.

On **native Android/iOS**, camera permission dialogs work as expected.

---

## 🧰 Key translations (RN → Flutter)

| React Native Expo | Flutter equivalent |
|---|---|
| `<View>` + styles | `Container` / `Column` / `Row` |
| `<TouchableOpacity>` | `InkWell` / `GestureDetector` |
| `StyleSheet.create` | Inline `TextStyle` / `BoxDecoration` |
| `<SafeAreaView>` | `SafeArea` |
| `expo-linear-gradient` | `LinearGradient` (built-in) |
| `Ionicons` | `Icons.*` (Material) |
| `expo-router` (file-based) | `go_router` (path config) |
| `useState` | `StatefulWidget` + `setState` |
| `useTheme()` / Context | `Provider.of<ThemeProvider>(context)` |
| `AsyncStorage` | `shared_preferences` |
| `expo-barcode-scanner` | `mobile_scanner` |

---

## 🛠️ Common issues

- **"Target of URI doesn't exist: package:…"**  → run `flutter pub get`.
- **Camera black on Chrome**  → allow permission in the browser URL bar (🔒 icon). The app falls back to simulated success if denied.
- **White screen on first load**  → check browser console; likely a missing asset. Re-run step 4 (logo download).
- **Fonts look wrong**  → `google_fonts` downloads on first run. If offline, bundle fonts in `pubspec.yaml`.

---

## ✅ What's already done

- 10 fully-ported screens matching RN parity
- Light/dark theme with persistence
- `go_router` navigation with bottom tabs + center FAB
- Real QR scanner with web fallback
- Currency in RM
- D-Clix branding throughout

## 🚧 Optional next steps (for you, later)

1. Replace mock data in `lib/data/mock_data.dart` with real API calls (`dio` / `http`).
2. Add Firebase / auth.
3. Add native splash config with `flutter_native_splash`.
4. Wire up push notifications (`firebase_messaging`).
