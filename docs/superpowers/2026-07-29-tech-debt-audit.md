# Tech debt audit — 2026-07-29

Scope: `frontend/` (12,293 lines across 50 screens + 21 modules), audited against the live UAT
API. Static analysis + ESLint + TypeScript + a live run in the web preview.

Baseline health: `tsc --noEmit` **clean**. ESLint: **1 error, 35 warnings**. No test suite exists.

---

## P0 — Broken right now

### 1. Opening any non-tab screen directly destroys the session

**Reproduced live**, three steps:

```
sign in                → localStorage: dclix.token.v1, dclix.user.v1
open /progress direct  → localStorage: (both keys gone)
                       → screen renders "0 Present / 0 Total / 0%" instead of real data
```

`AuthProvider` renders its children immediately and only `app/(tabs)/_layout.tsx` waits for
`ready`. A flat screen mounts first, its `useApi(() => api.myInfo(), [])` fires with no bearer
token, the server answers 401, and `http.ts` calls the unauthorized handler — which wipes the
stored session. The user is silently logged out and shown an empty screen.

Affects every screen that doesn't gate on `token` — 11 of them:

```
app/(tabs)/home.tsx        app/(tabs)/payments.tsx   app/(tabs)/schedule.tsx
app/(tabs)/training.tsx    app/attendance.tsx        app/events.tsx
app/notifications.tsx      app/offer-detail.tsx      app/progress.tsx
app/purchases.tsx          app/student-details.tsx
```

`book-class.tsx` and `qr-scan.tsx` already gate correctly (`token ? api.x() : …`) — the pattern
exists, it just wasn't applied everywhere.

Real-world trigger: any deep link, any browser refresh, any notification tap into a flat screen,
and every cold start on the APK where restore loses the race.

**Fix (two lines, one place):** have `AuthProvider` render nothing until `ready`, so no child can
fire a request before the token is loaded. Then the per-screen `token ?` guards become belt and
braces rather than the only defence.

Impact 5 · Risk 5 · Effort 1 → **priority 50**

### 2. Flat routes have no auth guard

`/progress`, `/attendance`, `/events`, `/purchases`, `/student-details`, `/chat`, … render for a
signed-out user instead of redirecting. Today they show empty state; the moment one of them shows
cached or partial data it becomes an information-disclosure question. Only the `(tabs)` group is
protected.

**Fix:** the same `ready`/`user` check in the root layout (or a shared `<RequireAuth>`).

Impact 3 · Risk 4 · Effort 2 → **priority 28**

### 3. `useMemo` used as an effect — setState during render

`app/(tabs)/payments.tsx:73`

```js
useMemo(() => { if (user && !activeAccount) setActiveAccount({ id: user.id, name: user.name }); }, [user]);
```

Sets state from inside render. React can warn ("cannot update a component while rendering") and
the behaviour is not guaranteed across re-renders. Should be `useEffect`.

Impact 2 · Risk 3 · Effort 1 → **priority 25**

---

## P1 — Features that still don't work, and why

| Feature | State | Blocked by |
|---|---|---|
| Pay dues / advance months via Boost | Request fires, backend 400s in its amount lookup (`$.status` deserialisation) | **Backend** |
| Any Boost payment on a phone | UAT serves a self-signed cert with **no SAN** → Android/iOS refuse the connection; app falls back to Production, which has no `/Bcpg` | **Backend** (a real certificate) |
| Boost return leg | `GET /Bcpg/Redirect` 500s without a bearer, and that URL is opened by the *browser* | **Backend** |
| New Student approval (`new-student.tsx`, `student-particulars.tsx`) | Full UI built against a proposed contract; every endpoint 404s | **Backend** (4 routes) |
| Cancel a class booking | No route exists in the mobile API | **Backend** |
| `ClassBooking/NextBookings` | Always `[]`; app derives upcoming from `GetBookings` | **Backend** |
| Bulk "mark attendance" for instructors | **Confirmed impossible on this API** (prod probe 2026-08-12, instructor RICK1, centre 3303): `/Attendance/Add`'s `qrCode` is only parsed as a CENTRE code, so the subject is always the bearer-token holder. `attendanceType: 2` with a student's `ST-` code, bare id and registration code each returned `-1 "Invalid QR Code"` — notably *not* "Invalid Instructor details", so the instructor check passed and the QR was the problem. Needs `POST /Attendance/Add` to accept `{ studentIds: int[], tTimeId, attendanceDate }` under an instructor token, plus a way to undo a mistake. Mitigated by the live register board + centre-QR display in `update-attendance.tsx`. | **Backend** (1 route) |
| Instructor viewing anyone's attendance (`r-attendance.tsx`) | **`/Reports/Attendance` is self-scoped** (prod probe 2026-08-12): instructor RICK1 gets 0 rows with *no filters at all*, while student 89623 — in that instructor's own roster for centre 1639 — sees their two "Present" rows there via their own token. The instructor Attendance Report is therefore permanently empty, and no live register board is possible. | **Backend** |
| Chat: seeing your own sent message | No endpoint returns it; app keeps a local echo | **API limit** |
| Instructor tiles **Activities**, **Fee Master** | `notify("coming soon")` | Not built (2 of 12 tiles) |

Everything else is wired to live data. Purchases, class booking, QR check-in, reports (17
screens), payments, profile edit + photo, notifications and chat all call the real API.

---

## P2 — Code debt

### Dead code

| Item | Size | Note |
|---|---|---|
| `src/mockData.ts` | ~155 of 175 lines | Only `quickCards` (nav config) is imported. `student`, `programs`, `schedule`, `payments`, `events`, `certificates`, `trainerComments`, `skills`, `achievements`, `attendanceData`, `holidays` are fake data nothing reads. Move `quickCards` to a `navigation.ts` and delete the rest — the file name alone invites someone to wire mock data back in. |
| 7 unused API methods | — | `activityReport`, `nextBookings`, `paymentCompleted`, `studentCenters`, `studentQRCodeUrl`, `trainingCenterQRCodeUrl`, `unreadNotificationCount`. (`bcpgPayInvoices`, `bcpgVerifyPayment`, `payInvoicesOnline` look unused but are called internally by `startPayment`/`confirmPayment`.) |
| `notificationDetails` | 2 lines | Never called **deliberately** — it returns other students' names and fee amounts. It should be deleted or carry a loud comment; right now nothing stops the next person calling it. |
| Unused imports | 6 | `useEffect` in payments.tsx, `ScrollView` in reportkit.tsx, `spacing` ×2, `ActivityIndicator` in chat.tsx, `useMemo` in index.tsx |

Impact 2 · Risk 2 · Effort 1 → **priority 20**

### Duplication

17 separate definitions of the same helpers (`fmtDate`, `money`/`fmtRM`, `pad`) across screens.
Formatting drifts between screens — some show `RM 1,234.00`, others `RM 1234`. One `src/ui/format.ts`
would settle it.

Impact 2 · Risk 1 · Effort 2 → **priority 12**

### Lint

1 error (`react/display-name`, `app/(tabs)/_layout.tsx:25`) and 35 warnings:

```
13  react-hooks/exhaustive-deps      ← stale-closure risk; two are in book-class.tsx
 9  @typescript-eslint/no-require-imports
 6  @typescript-eslint/no-unused-vars
 5  unused eslint-disable directives
 2  no-unused-expressions            ← payments.tsx:666,673 (`cond ? a : b` as a statement)
```

Impact 2 · Risk 3 · Effort 2 → **priority 20**

---

## P3 — Design system

`src/theme.ts` is solid: light/dark palettes, `radius`, `spacing`, `font`, `motion`, `press`,
`makeShadow`. Screens consume `useTheme()` and build styles per palette — the system is real and
followed.

Two gaps:

1. **Structural colours hardcoded** where they should be tokens — `app/(tabs)/home.tsx` uses
   `#4ADE80`/`#FCA5A5` for the status ring, `#FFF7ED` for on-gradient text, and literal gradient
   pairs. These don't follow the palette, so a theme change misses them. ~11 occurrences in
   home.tsx, 18 in `InstructorHome.tsx`, 11 in `user-guide.tsx`.
2. **Legitimate data colours** — belt colours in `progress.tsx`, tile tints in `more.tsx`/
   `mockData.ts`/`InstructorHome.tsx` — are fine as literals, but belong in one exported map
   rather than three copies.

Impact 2 · Risk 2 · Effort 2 → **priority 16**

---

## P4 — Test, dependency and infrastructure debt

- **No tests at all.** No unit tests, no component tests, no API-contract tests. Every regression
  this session (`attendanceType`, `classLimit`, the 401 race) was caught by hand. A handful of
  contract tests against the documented shapes would pay for themselves. Impact 4 · Risk 4 ·
  Effort 4 → **priority 16**
- **CI only builds the APK.** `tsc --noEmit` and `expo lint` don't run in `.github/workflows/build-apk.yml`,
  so a type error only surfaces ~20 minutes into a release build. Adding two steps is ~10 minutes
  of work. Impact 3 · Risk 3 · Effort 1 → **priority 30** (best effort-to-value ratio here)
- **Likely unused dependencies:** `@expo/ngrok`, `react-native-webview`, `expo-symbols`,
  `expo-haptics`, `react-native-dotenv`, `expo-device`. (`react-dom`, `react-native-screens`,
  `react-native-gesture-handler`, `react-native-reanimated`, `@react-navigation/*` scan as unused
  but are required transitively — do not remove.) Verify each against a build before dropping.
- **No crash/error reporting** in the shipped APK. A user-side failure is invisible unless someone
  screenshots it — which is exactly how the QR and purchase bugs reached us this week.

---

## Phased plan

**Phase 1 — half a day, do first**
1. Gate `AuthProvider` on `ready` (fixes the session wipe) and add the auth guard for flat routes.
2. `useMemo` → `useEffect` in payments.tsx.
3. Add `tsc --noEmit` + `expo lint` steps to the APK workflow.
4. Clear the 1 lint error and the 6 unused imports.

**Phase 2 — one day, alongside features**
5. Split `mockData.ts` into `src/navigation/quickCards.ts`, delete the rest.
6. Delete the 7 dead API methods; delete or hard-comment `notificationDetails`.
7. One `src/ui/format.ts`; migrate the 17 duplicated helpers.
8. Work through the 13 `exhaustive-deps` warnings (the two in `book-class.tsx` first).

**Phase 3 — as capacity allows**
9. Tokenise the structural colours in `home.tsx` / `InstructorHome.tsx` / `user-guide.tsx`; one
   shared belt/tile colour map.
10. Contract tests for the API shapes this codebase depends on.
11. Audit and drop the unused dependencies; add crash reporting.

**Not ours** — chase the backend for: the Boost amount-lookup fix, a real UAT certificate,
`/Bcpg/Redirect` without a token, the 4 New Student endpoints, a cancel-booking route, and
`NextBookings`.
