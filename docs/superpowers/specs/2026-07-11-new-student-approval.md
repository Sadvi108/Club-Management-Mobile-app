# New Student (Online Submission) Approval — mobile feature + backend contract
2026-07-11 · branch `feat/payments-phase1`

Mobile version of the web portal's **Student Online Submission List** (instructor approves/rejects
pending online student registrations). Built and shipped in the app behind an **"Awaiting backend"**
state — it goes live the moment the mobile API (`apimac.zyncbook.com`) exposes the four endpoints
below. **No dummy data is used** anywhere; the screens fetch real endpoints and show the honest
awaiting-backend panel on 404.

## Why this is gated
The mobile API swagger (authoritative, 69 endpoints) has **no** online-submission/approval route —
verified by direct probing (every candidate path 404s; a known route 401s). That feature lives only
in the separate web admin portal (`maclubsystem.com`, server-rendered, cookie-auth, not a REST API
the app can call). So the mobile app needs these endpoints added to its own backend.

## Mobile side (done)
- `app/new-student.tsx` — pending list; per-row Particulars / Reject / Approve; reachable from the
  instructor Home "New Student" tile.
- `app/student-particulars.tsx` — full particulars (Registration / Training / Guardian / Fees), name
  in header, blocks Approve until the required(*) fields are present.
- `src/api/endpoints.ts` — `onlineSubmissions`, `onlineSubmissionDetail`, `approveSubmission`,
  `rejectSubmission`. `src/api/types.ts` — `OnlineSubmissionRow`, `OnlineSubmissionDetail`,
  `ApproveSubmissionRequest`.

## Backend contract needed (adjust paths to taste — update the 4 lines in endpoints.ts to match)
All authenticated (instructor bearer token), scoped to the instructor's club/branch server-side.

### 1. List pending — `GET /Reports/OnlineSubmissions`
Response: `data: OnlineSubmissionRow[]`
```
{ id, sNo, studentName, gender, isOldStudent, uniformRequested,
  guardianName, contactNo, presentGrade, schoolName, trainingCentre,
  submissionDate, status }   // status: "Pending" | "Approved" | "Rejected"
```
`id` is the submission id used by the next three calls.

### 2. Particulars — `GET /Reports/OnlineSubmissionDetails/{id}`
Response: `data: OnlineSubmissionDetail` — everything in row 1 plus:
```
regNo, icNo, dateOfBirth, examCentre, studentCentre, schoolWorkplace,
addressLine1..4, state, city, postcode, guardianOccupation, emailAddress,
classCommencementDate, feeType, packageSession, registrationYear, material,
healthRemarks, religion, trainingDay, trainingTime, outstandingAmount, qrCode,
// resolved ids for the approve call:
trainingCentreId, studentCentreId, examCentreId, presentGradeId, feeTypeId
```

### 3. Approve — `POST /Account/ApproveStudent`
Body: `ApproveSubmissionRequest`
```
{ id, trainingCentreId, studentCentreId, examCentreId, presentGradeId,
  feeTypeId, registrationYear }
```
Server enforces the required fields, creates the student, and (per the web portal) sends the auto
WhatsApp with the parent login. Response: `StringApiResponse` (message / new student id).

### 4. Reject — `POST /Account/RejectStudent`
Body: `{ id, remarks }`. Response: `StringApiResponse`.

## Notes for the backend
- The web form makes Training Centre, Student Centre, Present Grade, Fee Type mandatory before
  approve — the mobile UI mirrors that and disables Approve until they're set, but the server must be
  the source of truth (reject the approve if any required id is missing).
- If dropdown editing (changing centre/grade/fee before approve) is required on mobile too, expose
  the option lists (the app already has `Listing/TrainingCenters`, `StudentCenters`,
  `DropdownListByType`) and extend the approve body — the current UI approves with the submission's
  resolved defaults.
