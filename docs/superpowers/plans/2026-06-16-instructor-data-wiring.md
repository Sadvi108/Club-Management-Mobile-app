# Instructor Data Wiring Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make instructor accounts load their data by fixing how the app detects an instructor and by preserving the login club code.

**Architecture:** Both bugs live in `lib/services/user_session.dart`. The app gates every instructor behavior (routing, data loading, report scoping) on one getter `isInstructor`, currently keyed to `userType == 2`. The live server authenticates instructors as `userType == 0` (and rejects `2`), so instructors are misclassified as students and see blank screens. Fix the getter to treat non-student (`!= 3`) as instructor. Separately, the instructor auth payload omits `clubCode`, so persist the code the user typed at login so Switch Branch works.

**Tech Stack:** Flutter / Dart, `flutter_test`, package name `dclix_app`. Backend `http://apimac.zyncbook.com`.

---

## Notes for the engineer

- **This is NOT a git repository** (`git init` has not been run). The commit steps below are written as normal git commits. Either run `git init` once before starting, or treat each "Commit" step as a save checkpoint and skip it. Do not let a missing git repo block progress.
- Run all commands from the Flutter project root: `D:\Club-Management-Mobile-app-main\club_management_app`.
- `UserSession` is a singleton exposed as `UserSession.instance`. `authData` is a public mutable `Map<String, dynamic>?` field, so a unit test can assign it directly. The `isInstructor` getter only reads `authData` — no network or plugins involved, so it runs under plain `flutter test`.
- Verified live facts this plan depends on: student/parent auth returns `data.userType == 3`; instructor auth returns `data.userType == 0`; sending `userType: 2` returns HTTP 400. Enum `UserType` in `swag.json` is `{0, 2, 3}`.

---

## File Structure

- `lib/services/user_session.dart` — MODIFY
  - `isInstructor` getter (line ~772): change detection logic + update stale doc comment.
  - `login()` method (line ~896, just after `authData = data;`): persist the entered `clubCode` into `authData`.
- `test/is_instructor_test.dart` — CREATE
  - Unit test for the `isInstructor` truth table.

No other files change. `instructor_settings_screen.dart` already reads `clubCode` first in `_resolveClubCode()`, and routing/loading/scoping already key off `isInstructor`, so they inherit the fix.

---

### Task 1: Fix instructor detection (`isInstructor`)

**Files:**
- Test: `test/is_instructor_test.dart` (create)
- Modify: `lib/services/user_session.dart` (the `isInstructor` getter, ~line 770-772)

- [ ] **Step 1: Write the failing test**

Create `test/is_instructor_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/user_session.dart';

void main() {
  group('UserSession.isInstructor', () {
    final session = UserSession.instance;

    tearDown(() => session.authData = null);

    test('userType 0 (live instructor) → true', () {
      session.authData = {'userType': 0};
      expect(session.isInstructor, isTrue);
    });

    test('userType 2 (legacy instructor) → true', () {
      session.authData = {'userType': 2};
      expect(session.isInstructor, isTrue);
    });

    test('userType 3 (student / parent) → false', () {
      session.authData = {'userType': 3};
      expect(session.isInstructor, isFalse);
    });

    test('no authData (logged out) → false', () {
      session.authData = null;
      expect(session.isInstructor, isFalse);
    });

    test('userType as numeric string is tolerated', () {
      session.authData = {'userType': '0'};
      expect(session.isInstructor, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/is_instructor_test.dart`
Expected: FAIL. With the current getter (`== 2`), the `userType 0 → true` and `userType '0'` cases fail (current code returns false for `0`).

- [ ] **Step 3: Write the implementation**

In `lib/services/user_session.dart`, replace the current getter and its comment:

```dart
  /// True when the authenticated user is an instructor.
  /// The Authenticate response sets `userType == 2` for instructors.
  bool get isInstructor => ((authData?['userType'] as num?)?.toInt() ?? 0) == 2;
```

with:

```dart
  /// True when the authenticated user is an instructor.
  ///
  /// Verified against the live API: student/parent accounts authenticate as
  /// `userType == 3`; instructors authenticate as `userType == 0` (the server
  /// rejects `2` at login with HTTP 400). `UserType` enum is {0, 2, 3}, so any
  /// logged-in non-student is an instructor. The `2` branch is kept defensively
  /// even though it never reaches the client today.
  bool get isInstructor {
    final raw = authData?['userType'];
    final ut = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
    if (ut == null) return false; // logged out / unknown
    return ut != 3;               // 3 = student/parent; 0 (and 2) = instructor
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/is_instructor_test.dart`
Expected: PASS (all 5 cases).

- [ ] **Step 5: Run the full suite to check for regressions**

Run: `flutter test`
Expected: PASS. Existing tests (`attendance_outcome_test`, `qr_content_test`, `receipt_pdf_test`, `widget_test`) are unaffected.

- [ ] **Step 6: Commit**

```bash
git add test/is_instructor_test.dart lib/services/user_session.dart
git commit -m "fix: detect instructor by userType != 3 (live API uses 0, not 2)"
```

---

### Task 2: Persist login club code for instructor Switch Branch

**Files:**
- Modify: `lib/services/user_session.dart` (`login()`, just after `authData = data;`)

There is no unit test for this step: `login()` performs a network call and writes
SharedPreferences, so it is verified live in Task 3. Keep the change minimal and
exact.

- [ ] **Step 1: Add the club-code persistence**

In `lib/services/user_session.dart`, inside `login()`, locate:

```dart
      ApiService.setToken(token);
      authData = data;
      debugPrint('🔐 AuthData keys: ${data.keys.toList()}');
      await _persistAuth();
```

Insert the club-code line immediately after `authData = data;`:

```dart
      ApiService.setToken(token);
      authData = data;
      // Instructor auth payload omits clubCode/clubList; keep the code the
      // user entered at login so Switch Branch (and ChangeClub) can resolve it.
      if (clubCode != null && clubCode.isNotEmpty) {
        authData!['clubCode'] = clubCode;
      }
      debugPrint('🔐 AuthData keys: ${data.keys.toList()}');
      await _persistAuth();
```

Note: `clubCode` is already a parameter of `login()` and `_persistAuth()` runs
after this line, so the value is saved for cold-restart automatically.

- [ ] **Step 2: Static-analyze the change**

Run: `flutter analyze lib/services/user_session.dart`
Expected: No new errors or warnings introduced by this change.

- [ ] **Step 3: Commit**

```bash
git add lib/services/user_session.dart
git commit -m "fix: persist instructor login clubCode for Switch Branch"
```

---

### Task 3: Live verification (manual)

**Files:** none (runtime verification).

- [ ] **Step 1: Launch the app**

Run: `flutter run` (pick an available device/emulator).

- [ ] **Step 2: Instructor login**

Log in with the Instructor toggle: Club Code `RTT`, branch `KCP`, Id `929645`,
password `22222`.

Expected:
- Lands on the **instructor** home (`/instructor/home`), not the student home.
- Notifications strip shows `#5 invoices are due` and `RM 450.00 total due amt`.
- "Latest Updates" lists the MyClubStats rows (e.g. Active Students, Training
  Time List, Upcoming Grading) — 9 rows.
- Settings → Profile sheet shows Name, Registration No, Role = Instructor, Club.
- Open a Quick-Access report (e.g. **Receipt**) → records populate.
- Settings → **Switch Branch** → opens the RTT branch list (no "No club code on
  file." message).

- [ ] **Step 3: Student regression check**

Log out, log in as student: Student/Parent toggle, Id `Aunty1`, password `1234`.

Expected: lands on the student home (`/home`) and behaves as before.

- [ ] **Step 4: Done**

If both logins behave as expected, the fix is verified end to end.

---

## Self-Review (completed)

- **Spec coverage:** Primary fix → Task 1; secondary fix → Task 2; testing
  section → Task 1 unit cases + Task 3 manual/regression. Out-of-scope items are
  untouched (login `userType: 0` unchanged; no endpoint/body/parse edits).
- **Placeholder scan:** none — every step has exact code, paths, and commands.
- **Type consistency:** `isInstructor` returns `bool` everywhere; `authData` typed
  `Map<String, dynamic>?`; `clubCode` is the existing `String?` `login()` param.
