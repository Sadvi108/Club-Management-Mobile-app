# Advance (Term) Prepayment — Design

Date: 2026-06-16
Status: Approved
App: `dclix_app` (Flutter), backend `http://apimac.zyncbook.com`

## Goal

Let a student prepay future monthly fees ("advance payment") from the Payments
screen: pick future months, see the price, and pay through the existing payment
methods.

## Background / Verified Contract

The server's term-payment mechanism was probed live (instructor token RICK1
targeting plan-enabled student 46679 "ABC", `monthlyFeeId 1181`):

`POST /Outstanding/FetchTermPayments`
Request: `{ "studentIds": [<id>], "year": <yyyy>, "months": [<m>] }`
Response `data`: array of 0 or 1 row per call, e.g.
```json
{
  "transactionType": "Monthly", "invoiceId": 0, "studentId": 46679,
  "icNo": "910234146771", "studentName": "ABC",
  "invoiceAmount": 50.0, "dueAmount": 50.0,
  "period": "January-2026", "invoiceDescription": "Monthly fee for January-2026",
  "monthlyFeeId": 1181, "presentGradeId": 3395,
  "sCenterId": 2754, "tCenterId": 3118, "eCenterId": 2502
}
```

Observed facts:
- **One month per call.** `months:[1,2,3]` returned only January; `months:[2]`
  returned February; `months:[6]` returned June. So price each month in its own
  call (loop), not a single multi-month call.
- `invoiceId` is `0` — these are not-yet-invoiced future charges.
- Empty `data: []` means the month is not prepayable (already invoiced, or the
  account has no monthly-fee plan — e.g. student ROY/Aunty1 returns empty for
  every month because no plan is configured). This is normal, not an error.
- Wrong/failed envelopes arrive as HTTP 200 with `{status, meta.error}` — use
  the shared `apiEnvelopeError()` helper (see `lib/services/response_utils.dart`).

NOT verified (deliberately — real money): executing the actual `PayInvoices` term
charge. The pay request is designed from `swag.json` and gated behind a build
flag until verified live (see Risks).

## Architecture

Logic lives outside the UI so it is unit-testable.

- `lib/services/prepay_service.dart` (new) — pricing + pay-request building.
- `lib/screens/payment/prepay_sheet.dart` (new) — the bottom-sheet UI.
- `lib/services/api.dart` — add `outstandingPayTermPayments(...)`.
- `lib/services/user_session.dart` — add `currentStudentId` getter.
- `lib/screens/payments_screen.dart` — add the "Prepay / Advance" entry button;
  reuse the existing payment-method chooser/routing.

### `currentStudentId` (user_session.dart)

Returns the numeric student id to prepay for:
- the active guardian child's `studentId` (`activeStudentId`) when a sibling is
  selected, else
- `authData['id']`.

Returns `null` when neither is available (caller shows the no-plan empty state).

### prepay_service.dart

```dart
class PrepayMonth {
  final int month;        // 1..12
  final int year;
  final String label;     // period, e.g. "January-2026"
  final String description;
  final num amount;
  final Map<String, dynamic> raw; // original row (monthlyFeeId, center ids…)
}

class PrepayQuote {
  final List<PrepayMonth> months;
  num get total => months.fold<num>(0, (s, m) => s + m.amount);
}
```

- `Future<PrepayQuote> priceMonths(int studentId, int year, List<int> months)`
  - For each month: `Api.outstandingFetchTermPayments({'studentIds':[studentId],
    'year':year,'months':[m]})`.
  - Parse via `findRecordList`; take the first row if present; map to
    `PrepayMonth` (amount via `pickAmount(row, ['dueAmount','invoiceAmount',
    'amount'])`, label via `pickField(row, ['period','invoiceDescription'])`).
  - Skip months whose response is empty or whose envelope reports an error.
- `Map<String,dynamic> buildPayRequest(int studentId, int year,
  List<int> months, String paymentMethod, {String remarks})`
  - Produces the `PayTermPayments` query map `{studentIds:[id], year, months}`
    plus the `PaymentMethod`/`Remarks` fields for `outstandingPayTermPayments`.

### api.dart

```dart
/// Pay future term (advance) months. Maps to POST /Outstanding/PayInvoices
/// with the PayTermPayments query (studentIds/year/months) and a multipart
/// PaymentMethod/Remarks body (per swag.json).
static Future<dynamic> outstandingPayTermPayments({
  required List<int> studentIds,
  required int year,
  required List<int> months,
  required int paymentMethod,    // PaymentMethod enum 1|2|3
  String remarks = 'Advance prepayment',
});
```

Transport detail: `PayTermPayments` is a query object; serialize
`studentIds`/`months` as repeated query params and `year` as a scalar, and send
`PaymentMethod`/`Remarks` as multipart form fields (matches the swag shape for
`/Outstanding/PayInvoices`). A new `ApiService` helper may be added if the
existing `post`/`postMultipart` cannot express query-object + multipart together.

## Data Flow

1. User opens the sheet from Payments → "Prepay / Advance".
2. Sheet resolves `currentStudentId`; if null → no-plan empty state.
3. User selects `year` + months → `priceMonths` prices each (debounced).
4. Sheet shows line-items + total.
5. "Pay" → existing payment-method chooser:
   - card / FPX-eWallet → existing gateway path (`/Payment/Initiate` → BCPG).
   - bank transfer → manual record.
   Then `Api.outstandingPayTermPayments(...)` with the selected months.

## UI (prepay_sheet.dart)

- Bottom sheet, drag handle, title "Prepay Monthly Fees", student name sub-line.
- Year selector: current year, +1, +2 (segmented).
- Month chips Jan–Dec; past months (current year) disabled; priced chips show
  the amount; unavailable (empty) chips disabled after pricing.
- Selected line-items list + Total RM.
- Empty/no-plan state: "No prepayable months for this account."
- Pay button: disabled until ≥1 priced month; disabled when
  `kPrepayPayEnabled == false`. Confirm dialog before paying.

## Error Handling

- Reuse `apiEnvelopeError()` for HTTP-200 error envelopes.
- Per-month pricing failure → mark that chip unavailable; other months continue.
- Network / pay failure → SnackBar with the real message; all async UI guarded
  by `mounted`.

## Testing

- Unit (`prepay_service`): mocked per-month responses → assert priced list,
  total sum, empty-month skipping.
- Unit: `currentStudentId` resolution (self vs active child vs null).
- Unit: `buildPayRequest` emits the correct `studentIds/year/months` +
  `PaymentMethod/Remarks`.
- Live verification (manual): RICK1 → student 46679 pricing returns rows
  (already confirmed); then one real small prepay on a plan-enabled student to
  confirm the pay contract before enabling `kPrepayPayEnabled`.

## Risks / Out of Scope

- **Pay execution unverified.** Gated behind `kPrepayPayEnabled` (default false)
  until a live prepay confirms the `PayInvoices`+`PayTermPayments` response.
- Multi-child cart (prepay several students at once) — out of scope; guardians
  switch child first via the existing sibling picker.
- The `FetchTranxCharges` endpoint returns 400 for JSON bodies (multipart-only
  per swag) and is not used by this feature.
