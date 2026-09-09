# Class booking — API contract and app wiring, 2026-07-29

Probed live on `https://apimacuat.zyncbook.com` as student `the student test account` (id 35842,
club 68, centre 1945 "SMK KK2").

---

## 1. Endpoints

| Route | Notes |
|---|---|
| `GET /Listing/TrainingCenters` | 9 centres for this club. |
| `GET /Listing/Instructors` | 2 for this club: 2240 Master MSV, 3052 Master Z. |
| `GET /ClassBooking/TrainingTimeWithDateAndInstructor/{m}/{y}/{tCenterId}/{instructorId}` | The weekly timetable for that pair. |
| `GET /ClassBooking/PackageInfo/{studentId}` | `{packageType, packageId, packageName, noOfClasses}`. |
| `POST /ClassBooking/BookNow` | `BookClassViewModel` → `{ id }`. |
| `GET /ClassBooking/GetBookings?studentId=` | All bookings, past and future. |
| `GET /ClassBooking/NextBookings` | **Always `[]`** — see below. |
| `GET /ClassBooking/SessionOrPackages/{typeId}` | Package catalogue. typeId 1 → "PACKAGE 10", "monthly50"; every other typeId → "3 month 500". |
| `GET /ClassBooking/BookingCountByPackageSession/{packageTypeId}/{packageId}/{studentId}/{m}/{y}` | `[]` for this student. |

## 2. Findings that changed the app

### 2.1 `classLimit` is not availability — the app was hiding a bookable class

`TrainingTimeWithDateAndInstructor` for centre 1945 + instructor 2240 returns two slots:

```
id 2926  18:00 To 19:00 (Monday)    classLimit 1
id 2923  18:00 To 20:30 (Friday)    classLimit 0
```

`book-class.tsx` treated `classLimit <= 0` as **Full** and disabled the row. Booking slot 2923
directly returned `200 {"id":3280}` and the booking appears in `GetBookings`, so 0 does not mean
full — it is the class's configured capacity, and `0` means no limit. The value also did not move
after the booking, so it is not seats-remaining either.

**Half the timetable was unbookable in the app for no reason.** Now: never disabled, and a
`classLimit > 0` is shown as "max N".

### 2.2 The month in the path does nothing

July, August and September return byte-identical rows. These are recurring weekly slots; the
calendar date is entirely the app's business.

### 2.3 `BookNow` validates almost nothing

| request | result |
|---|---|
| Friday slot 2923 on Friday 2026-08-07 | `200 {"id":3280}` |
| **the exact same booking again** | `200 {"id":3281}` — duplicate created |
| Friday slot 2923 on **Tuesday** 2026-08-11 | `200 {"id":3282}` — weekday not checked |
| `timeSlots: []` | `400 "Invalid Request"` |

So the date and the duplicate check have to be enforced client-side. Previously the app computed
the date itself (`nextDateForDow`: first matching weekday from today) and the student never saw
or chose it — and near a month boundary that walk could roll into the following month while the
UI still said July.

Now: the app lists every matching weekday left in the selected month as date chips, preselects
the first one the student hasn't already booked, marks the taken ones "booked", and blocks
Confirm on a duplicate.

### 2.4 `NextBookings` is unusable

Returns `[]` even with booking 3280 dated 2026-08-07 sitting in `GetBookings`. The app derives
upcoming-vs-past from `GetBookings` instead, showing upcoming first (soonest first) and past ones
dimmed.

### 2.5 Instructor default

Defaulting to the first instructor in the list is a coin flip: at centre 1945, Master MSV (2240)
has a timetable and Master Z (3052) returns `[]`. `Profile/MyInfo` carries `instructorId` /
`instructorName`, so the app now defaults to the student's own instructor and the empty state
names the pair instead of saying "No bookable sessions".

### 2.6 `packageType`

Was hardcoded to `"Monthly"`. Now taken from `PackageInfo` (which returns `"Monthly"`,
`packageId 0`, `noOfClasses 0` for this student — i.e. no package assigned). `sessionId` stays 0;
the server accepts it and the `SessionOrPackages` semantics aren't pinned down.

## 3. Verified end to end

From the web preview against UAT: selected the Friday slot (the one that used to say "Full"),
month August, date chips `7 (booked) · 14 · 21 · 28`, preselection skipped the 7th, Confirm read
"Confirm · Fri 14 Aug" → "Class booked". Server side, `GetBookings` gained
`3283 · time 2923 · 2026-08-14 · Pending`. `tsc --noEmit` clean.

## 4. Backend asks

1. `BookNow` should reject a duplicate booking and a `trainingDate` whose weekday doesn't match
   the slot. The app guards both now, but any other client can create them — and 3281/3282 are
   sitting in UAT as proof.
2. `NextBookings` returns `[]` when future bookings exist.
3. There is **no cancel/delete route**, so a mistaken booking can only be removed by an admin.
   Test bookings 2721–2723 and 3280–3283 for student 35842 can be cleaned up on UAT.
4. Confirm what `classLimit` is meant to express — nothing enforces it today (booked a
   `classLimit: 0` class, and `1` never decremented).
