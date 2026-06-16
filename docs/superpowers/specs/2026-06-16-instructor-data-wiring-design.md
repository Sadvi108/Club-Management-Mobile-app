# Instructor Data Wiring Fix — Design

Date: 2026-06-16
Status: Approved
App: `dclix_app` (Flutter), backend `http://apimac.zyncbook.com`

## Problem

Every instructor screen renders blank — profile sheet, home badges, Latest
Updates, news, and all Quick-Access reports. Student/parent login works.

## Root Cause (verified against live API)

The app identifies an instructor with a single getter:

```dart
// lib/services/user_session.dart:772 (current)
bool get isInstructor => ((authData?['userType'] as num?)?.toInt() ?? 0) == 2;
```

Live `/Account/Authenticate` evidence:

| Login                                  | HTTP | `data.userType` |
|----------------------------------------|------|-----------------|
| Student `Aunty1` (sent `userType:3`)   | 200  | `3`             |
| Instructor `929645` (sent `userType:2`)| 400  | — (rejected)    |
| Instructor `929645` (sent `userType:0`)| 200  | `0`             |

`UserType` enum in `swag.json` = `{0, 2, 3}`. The server **rejects `2`** at
login and authenticates an instructor as **`userType: 0`**; `3` is
student/parent. The app's getter only treats `2` as instructor, so a real
instructor (`0`) fails the check.

Misclassification cascades:

- Login routes to student `/home` (`login_screen.dart:172`); `splash_screen`
  and the `app_router` `/instructor` guard do the same.
- `_loadAll()` runs student-only branches (StudentAddtnlInfo, ClassBooking,
  GradingSchedule) against an instructor account.
- `scopeToSelf()` filters branch-wide report data down to the instructor's own
  name → every list empties.

Net effect: instructor sees a student shell fed by student-scoped logic →
everything blank.

The instructor token itself is fine. With it, all endpoints return rich data:
`HomePageStats` (`invoiceCount:5`, `dueAmount:450.00`), `MyClubStats` (9 rows),
`Reports/Receipts`, `Reports/GradingSchedule`, `Outstanding/Fetch` (branch-wide).

## Fix

### 1. Instructor detection (primary — unblocks everything)

`lib/services/user_session.dart:772`:

```dart
bool get isInstructor {
  final ut = (authData?['userType'] as num?)?.toInt();
  if (ut == null) return false;   // logged out / unknown
  return ut != 3;                 // 3 = student/parent; 0 (and 2) = instructor
}
```

Rationale: student/parent is `3` (confirmed); instructor is non-3. `2` never
reaches the client (rejected at login) but `!= 3` covers it harmlessly. The
null guard prevents a false positive before login. Update the stale doc comment
above the getter (it claims the response sets `userType == 2`).

This one change re-routes the instructor to `/instructor/home` and flips
`_loadAll` and `scopeToSelf` to instructor behavior, restoring profile, home
badges, Latest Updates, news, and all reports together.

### 2. Switch Branch for instructors (secondary)

The instructor auth payload omits `clubList` and `clubCode` (only `clubId`).
`_resolveClubCode()` (`instructor_settings_screen.dart:150`) returns `''` →
Switch Branch shows "No club code on file." The club code the instructor typed
at login is discarded.

Persist it in `login()`, right after `authData = data;`:

```dart
// Instructor auth payload omits clubCode/clubList; keep the entered code
// so Switch Branch (and ChangeClub) have it.
if (clubCode != null && clubCode.isNotEmpty) {
  authData!['clubCode'] = clubCode;
}
```

`_resolveClubCode()` checks `clubCode` first → resolves. `switchBranch()`
already forwards `clubCode`. No UI change.

## Out of Scope (do NOT change)

- Login `userType: 0` — correct, proven; changing it breaks instructor auth.
- Request bodies / endpoints / response parsing — all return data.
- Sparse profile fields (empty gender/phone) — genuinely empty server data.

## Testing

- **Manual (live):** instructor login `RTT / 929645 / KCP` → lands on
  `/instructor/home`; badges show `5 invoices` / `RM 450.00`; Latest Updates
  shows 9 rows; Receipt report populates; Switch Branch opens the branch list.
- **Regression:** student login (`Aunty1`, userType 3) still routes to `/home`
  and works.
- **Unit:** `isInstructor` truth table — `0→true, 2→true, 3→false, null→false`.

## Footprint

Two files: `lib/services/user_session.dart`, plus persistence of `clubCode` in
the same file's `login()`. ~10 lines total. `instructor_settings_screen.dart`
unchanged (already reads `clubCode`).
