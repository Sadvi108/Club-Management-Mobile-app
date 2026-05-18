# Instructor Collections — Live Data + UI Restyle

Date: 2026-05-18
Status: Approved (Approach A)

## Problem

The instructor Collections screen has two faults:

1. **Lists show no live data.** The grid tiles show counts (e.g. Payment
   Slips `(2)`) from `/Outstanding/CollectionCount`, but tapping a tile
   opens a list screen that shows "No records". The list endpoints
   (`/Reports/PaymentSlips`, `/Outstanding/CollectionCountList/{typeId}`)
   return data the screen fails to render — either called without the
   params the server expects, or returning a response shape the parser
   does not unwrap.
2. **UI is inconsistent.** The Collections grid and list screens use a
   flat dark style unlike the rest of the app (the student Profile
   uses gradient hero strips, surface cards, circular tinted icons,
   styled rows). Collections looks like a different app.

## Goal

- Connect the Collections list endpoints so live records render.
- Make any remaining empties debuggable on-device (raw-response view).
- Restyle the Collections grid and list screens to match the student
  Profile visual vocabulary. Features may differ; the look must match.
- Keep it user-friendly, smooth, responsive.

## Scope

- `lib/screens/instructor_collections_screen.dart` — the only screen file.
- Reuse existing `lib/widgets/anim.dart` (shimmer, fade-in) and theme
  tokens (`Radii`, `Shadows`, `AppColors`, `Gaps`).
- `lib/services/api.dart` — only if a needed endpoint is missing; verify
  during implementation. No speculative additions.

Out of scope: other instructor screens, new endpoints beyond what the
existing API exposes.

## Data layer

### Endpoints
- Counts: `/Outstanding/CollectionCount` → `{cash, fpx, dbt}` (already
  working — keep).
- Cash list: `/Outstanding/CollectionCountList/1`
- Online list: `/Outstanding/CollectionCountList/2`
- Payment Slips list: `/Reports/PaymentSlips`

### Request params
List fetchers pass a body where the endpoint accepts one:
`{branchId, fromDate, toDate}` covering roughly the last 12 months
(`fromDate` = today − 365 days, `toDate` = today). `branchId` comes
from `UserSession.authData`. When an endpoint ignores the body it is
harmless; when it requires one this is what unblocks the data.

### Response unwrapping
A defensive recursive list-finder (same idea as `UserSession.findList`):
walk the response, return the first `List` found under common keys
(`data`, `items`, `rows`, `results`, `value`, `records`,
`collections`, `slips`). If the top level is already a `List`, use it.
This handles nested and renamed shapes without guessing one schema.

### Diagnostics
When a list resolves empty, the empty state keeps a collapsible
"Show raw response" block printing the raw JSON. This makes a genuine
empty (no records) distinguishable from a parse miss on a real device.

## Record cards

Replace the raw 4-key dump (`_rowCard`) with a styled card per record:

- **Title** — payer / student name (`studentName`, `name`, `payerName`,
  `memberName`; fall back to `Record #n`).
- **Amount** — `RM` + value, bold, primary colour. Probes a wide key
  set (`amount`, `dueAmount`, `paidAmount`, `value`, `total`).
- **Date** — `date`, `paymentDate`, `recordedTime`, `createdDate`
  (first 10 chars).
- **Status pill** — `status`, `paymentStatus`, `remarks` when present;
  colour: success / muted / danger.
- Any field absent → that line is omitted, no blank rows.

## UI restyle (match student Profile)

- **Header** — gradient hero strip like Profile, notch-safe (the 44px
  clearance fallback already used elsewhere).
- **Grid tiles** — `surface` cards, circular gradient-tint icon,
  count as a small badge (not inline text), `Radii.lg`,
  `Shadows.card`. Same vocabulary as Profile action tiles.
- **List screen** — `AppHeader` (back), surface record cards, shimmer
  skeleton while loading (`ShimmerList` from `anim.dart`), styled
  empty state with icon + message.
- **Entrance** — `FadeSlideIn.at(index)` stagger on grid tiles and
  list cards, consistent with the rest of the app.
- **Responsive** — grid `crossAxisCount` 2; `childAspectRatio` adapts
  on narrow widths (< 360 px) so tiles never overflow. List cards are
  full-width fluid.

## Error handling

- Fetch throws → styled error card with the message + a Retry button
  (pull-to-refresh also retries).
- Empty list → styled empty state + the raw-response diagnostic.
- Loading → shimmer skeleton, never a bare spinner.

## Testing / verification

- `flutter analyze` clean.
- Release web build, load in dev-Edge preview, log in as instructor,
  open Collections → each of the four tiles.
- Confirm: counts render, lists render live records (or a clear empty
  state with raw-response showing why), styling matches Profile,
  no notch overlap, no overflow on a narrow device preset.
