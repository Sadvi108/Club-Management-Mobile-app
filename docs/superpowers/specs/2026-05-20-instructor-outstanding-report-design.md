# Instructor Outstanding Report — backend gap, no client work

Date: 2026-05-20
Status: Blocked on backend (user decision)

## Context

Home Notifications badge on the instructor account shows
`HomePageStats.invoiceCount / HomePageStats.dueAmount` — server-precomputed
per-instructor totals. For `GMHaffiz` that is `1 / RM 10`; for `RICK1` on the
same branch it is `3 / RM 290`.

Tapping into the Reports → Outstanding Report screen opens a list driven by
`/Outstanding/Fetch`. The list does not match the badge — it shows the same
7-row branch-level set (RM 600) for every instructor on that branch.

## Live probe (instructor `GMHaffiz` / `12345`, club `RTT`, branch `KCP/1128`)

| Endpoint | Body | Result |
|---|---|---|
| `/Reports/HomePageStats` | — | `{invoiceCount: 1, dueAmount: 10.0}` |
| `/Outstanding/Fetch` | `{}` | 7 rows / RM 600 — branch students |
| `/Outstanding/Fetch` | `studentId: 2175` (user id) | `data: []` |
| `/Outstanding/Fetch` | `icNo: "800303105151"` | `data: []` |
| `/Outstanding/Fetch` | `studentName: "GM Haffiz"` | `data: []` |
| `/Outstanding/Fetch` | `instructorId: 2175` (off-schema) | same 7 rows (field ignored) |
| `/Outstanding/Fetch` | `tCenterId: 1638` | 645 rows — entire centre history |
| `/Outstanding/FetchTermPayments` | `{}` | empty (no `data` key) |
| `/Account/Authenticate` `userType: 3` | — | `404 — Account not found` (no student-mode) |

`/Outstanding/Fetch` with an empty body returns the **same** 7-row Pending /
May-2026 set for both `GMHaffiz` and `RICK1`. The endpoint is branch-scoped
for instructors; no parameter narrows it to the per-instructor scope that
HomePageStats reports.

## Conclusion

`/Reports/HomePageStats` is the only source that reports the per-instructor
totals (1/10, 3/290). It is a **summary** only — there is no list endpoint
that returns the underlying per-invoice rows for that aggregate.

A client-side heuristic (filter Outstanding rows by `centerName` ∈ the
instructor's schedule centres from `/Reports/StudentDetails`) gives
RICK1 = 1 row, GMHaffiz = 2 rows — neither matches HomePageStats.
The match is server-side logic we cannot reproduce.

## Decision (chosen by user)

Backend must add or expose a per-instructor endpoint. No client change
until that endpoint exists.

### What to request from the backend

One of:

- Make `/Outstanding/Fetch` accept and honour an `instructorId` filter (or
  scope server-side from the instructor token), so the returned `data` array
  matches the `HomePageStats.invoiceCount / dueAmount` for that instructor.
- Add a new endpoint, e.g. `POST /Outstanding/FetchForInstructor`, that
  returns the per-invoice rows behind the HomePageStats per-instructor
  summary. Same response shape as `/Outstanding/Fetch` so the existing
  parser handles it unchanged.

Response shape that already parses correctly:

```json
{"status":200,"data":[
  {"studentId":..,"studentName":"..","icNo":"..","dueAmount":..,
   "paymentStatus":"Pending","invoiceDate":"..","centerName":"..",
   "period":"..","transactionType":"..","invoiceId":..}
]}
```

### When the endpoint exists — the app change is small (~10 lines)

1. `lib/services/api.dart` — wrap the new endpoint (if a new one is added),
   or no wrapper change if `/Outstanding/Fetch` itself is fixed.
2. `lib/router/app_router.dart` — the `/instructor/reports/outstanding`
   route's fetcher: swap `Api.outstandingFetch` for the new wrapper / pass
   the instructor scope.
3. No changes needed to `instructor_report_list_screen.dart` — the generic
   render + filter bar handles whatever rows arrive.

## Current status

No app code changes are pending. The instructor home badge is correct
(reads `HomePageStats`). The Outstanding Report list is correctly wired to
the only available endpoint — that endpoint is just branch-scoped, not
instructor-scoped. Reopen this spec for the ~10-line wiring change when the
backend endpoint is available.
