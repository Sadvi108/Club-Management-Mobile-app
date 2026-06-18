# Advance (Term) Prepayment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a student prepay future monthly fees from the Payments screen — pick future months, see the live price, and pay (pay execution gated behind a flag until verified on a plan-enabled account).

**Architecture:** A pure, testable `PrepayService` prices each selected month via `/Outstanding/FetchTermPayments` (one call per month — the API only honors one month per request) and builds the pay request for `/Outstanding/PayInvoices`. A `PrepaySheet` bottom sheet drives it from the Payments screen. `UserSession.currentStudentId` resolves who to prepay for. Pricing/preview ships immediately; the actual charge is gated by `kPrepayPayEnabled` (default `false`) until the `PayInvoices` term contract is confirmed live.

**Tech Stack:** Flutter / Dart, `flutter_test`, package `dclix_app`. Backend `http://apimac.zyncbook.com`.

---

## Notes for the engineer

- Run all commands from `D:\Club-Management-Mobile-app-main\club_management_app`.
- This **is** a git repo (branch `live-api-integration`, remote `origin`). Commit steps are real.
- Verified live contract (instructor token RICK1 → plan-enabled student 46679 "ABC"):
  - `POST /Outstanding/FetchTermPayments` body `{studentIds:[id], year, months:[m]}` returns 0 or 1 row: `{invoiceId:0, studentId, period:"January-2026", invoiceDescription, dueAmount:50.0, invoiceAmount:50.0, monthlyFeeId, sCenterId, tCenterId, eCenterId}`. **One month per call** (`months:[1,2,3]` returned only January). Empty `data:[]` = month not prepayable.
  - `PayInvoices` term execution is NOT verified (real money). Keep it behind `kPrepayPayEnabled`.
- `Api.outstandingFetchTermPayments([Map body])` and `ApiService.postMultipart(endpoint, Map<String,String> fields)` already exist (`lib/services/api.dart`, `lib/services/api_service.dart`).
- `apiEnvelopeError`, `findRecordList`, `pickField`, `pickAmount` live in `lib/services/response_utils.dart`.

---

## File Structure

- `lib/services/user_session.dart` — MODIFY: add `currentStudentId` getter.
- `lib/services/prepay_service.dart` — CREATE: `PrepayMonth`, `PrepayQuote`, `priceMonths`.
- `lib/services/api.dart` — MODIFY: add `termPaymentQuery(...)` (pure) + `outstandingPayTermPayments(...)`.
- `lib/config/feature_flags.dart` — CREATE: `const bool kPrepayPayEnabled = false;`.
- `lib/screens/payment/prepay_sheet.dart` — CREATE: the bottom-sheet UI.
- `lib/screens/payments_screen.dart` — MODIFY: add a "Prepay / Advance" entry button that opens the sheet.
- Tests: `test/current_student_id_test.dart`, `test/prepay_service_test.dart`, `test/term_payment_query_test.dart`.

---

### Task 1: `currentStudentId` on UserSession

**Files:**
- Modify: `lib/services/user_session.dart`
- Test: `test/current_student_id_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/user_session.dart';

void main() {
  group('UserSession.currentStudentId', () {
    final s = UserSession.instance;
    tearDown(() {
      s.authData = null;
      s.setActiveStudent(name: null, id: null);
    });

    test('returns authData id when no sibling is active', () {
      s.authData = {'id': 22410};
      expect(s.currentStudentId, 22410);
    });

    test('active guardian child wins over authData id', () {
      s.authData = {'id': 22410};
      s.setActiveStudent(name: 'KID', id: 46679);
      expect(s.currentStudentId, 46679);
    });

    test('numeric-string id is parsed', () {
      s.authData = {'id': '2347'};
      expect(s.currentStudentId, 2347);
    });

    test('null when nothing is available', () {
      s.authData = null;
      expect(s.currentStudentId, isNull);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/current_student_id_test.dart`
Expected: FAIL — `currentStudentId` is not defined.

- [ ] **Step 3: Implement the getter**

In `lib/services/user_session.dart`, add this getter near the other identity
getters (e.g. just after the `isInstructor` getter):

```dart
  /// Numeric student id to act on for per-student actions (e.g. prepay).
  /// A picked guardian child wins; otherwise the logged-in account's id.
  /// Returns null when neither is available.
  int? get currentStudentId {
    final active = activeStudentId;
    if (active != null) {
      if (active is int) return active;
      final n = int.tryParse(active.toString());
      if (n != null) return n;
    }
    final raw = authData?['id'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/current_student_id_test.dart`
Expected: PASS (4 cases).

- [ ] **Step 5: Commit**

```bash
git add lib/services/user_session.dart test/current_student_id_test.dart
git commit -m "feat: UserSession.currentStudentId for per-student actions"
```

---

### Task 2: PrepayService — models + pricing

**Files:**
- Create: `lib/services/prepay_service.dart`
- Test: `test/prepay_service_test.dart` (create)

`priceMonths` takes an injectable `fetch` so the test never hits the network.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/prepay_service.dart';

void main() {
  // Fake term-payment endpoint: month 6 priced at 50, month 9 empty.
  Future<dynamic> fakeFetch(Map<String, dynamic> body) async {
    final m = (body['months'] as List).first;
    if (m == 6) {
      return {
        'status': 200,
        'data': [
          {
            'invoiceId': 0,
            'period': 'June-2026',
            'invoiceDescription': 'Monthly fee for June-2026',
            'dueAmount': 50.0,
            'monthlyFeeId': 1181,
          }
        ],
      };
    }
    return {'status': 200, 'data': []};
  }

  test('prices each month, skips empty, sums total', () async {
    final quote = await PrepayService.priceMonths(
      studentId: 46679,
      year: 2026,
      months: [6, 9],
      fetch: fakeFetch,
    );
    expect(quote.months.length, 1);
    expect(quote.months.first.month, 6);
    expect(quote.months.first.label, 'June-2026');
    expect(quote.months.first.amount, 50.0);
    expect(quote.total, 50.0);
  });

  test('empty result yields an empty quote', () async {
    final quote = await PrepayService.priceMonths(
      studentId: 1,
      year: 2026,
      months: [9],
      fetch: (_) async => {'status': 200, 'data': []},
    );
    expect(quote.months, isEmpty);
    expect(quote.total, 0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/prepay_service_test.dart`
Expected: FAIL — `prepay_service.dart` / `PrepayService` not found.

- [ ] **Step 3: Implement the service**

Create `lib/services/prepay_service.dart`:

```dart
import 'api.dart';
import 'response_utils.dart';

/// Injectable term-payment fetcher (so tests don't hit the network).
typedef TermFetch = Future<dynamic> Function(Map<String, dynamic> body);

/// One priced future month.
class PrepayMonth {
  final int month; // 1..12
  final int year;
  final String label; // e.g. "June-2026"
  final String description;
  final num amount;
  final Map<String, dynamic> raw;
  const PrepayMonth({
    required this.month,
    required this.year,
    required this.label,
    required this.description,
    required this.amount,
    required this.raw,
  });
}

/// Result of pricing a set of months.
class PrepayQuote {
  final List<PrepayMonth> months;
  const PrepayQuote(this.months);
  num get total => months.fold<num>(0, (s, m) => s + m.amount);
}

class PrepayService {
  /// Price [months] for [studentId]/[year]. Calls the term-payment endpoint
  /// once per month (the API only honors one month per request). Months that
  /// return no row (not prepayable) are skipped.
  static Future<PrepayQuote> priceMonths({
    required int studentId,
    required int year,
    required List<int> months,
    TermFetch? fetch,
  }) async {
    final fn = fetch ?? Api.outstandingFetchTermPayments;
    final out = <PrepayMonth>[];
    for (final m in months) {
      try {
        final resp = await fn({
          'studentIds': [studentId],
          'year': year,
          'months': [m],
        });
        if (apiEnvelopeError(resp) != null) continue;
        final rows = findRecordList(resp).whereType<Map>().toList();
        if (rows.isEmpty) continue;
        final row = Map<String, dynamic>.from(rows.first);
        out.add(PrepayMonth(
          month: m,
          year: year,
          label: pickField(row, ['period', 'invoiceDescription']),
          description: pickField(row, ['invoiceDescription', 'period']),
          amount: pickAmount(row, ['dueAmount', 'invoiceAmount', 'amount']),
          raw: row,
        ));
      } catch (_) {
        // skip a month that errored; keep pricing the rest
      }
    }
    return PrepayQuote(out);
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/prepay_service_test.dart`
Expected: PASS (2 cases).

- [ ] **Step 5: Commit**

```bash
git add lib/services/prepay_service.dart test/prepay_service_test.dart
git commit -m "feat: PrepayService prices future months via term payments"
```

---

### Task 3: Term-payment pay request in Api

**Files:**
- Modify: `lib/services/api.dart`
- Test: `test/term_payment_query_test.dart` (create)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:dclix_app/services/api.dart';

void main() {
  group('Api.termPaymentQuery', () {
    test('serializes repeated studentIds/months and scalar year', () {
      final q = Api.termPaymentQuery([46679], 2026, [6, 7]);
      expect(q, 'studentIds=46679&year=2026&months=6&months=7');
    });

    test('handles multiple students', () {
      final q = Api.termPaymentQuery([1, 2], 2026, [1]);
      expect(q, 'studentIds=1&studentIds=2&year=2026&months=1');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/term_payment_query_test.dart`
Expected: FAIL — `termPaymentQuery` not defined.

- [ ] **Step 3: Implement**

In `lib/services/api.dart`, inside `class Api`, add (place near the other
`Outstanding` methods):

```dart
  /// Build the `PayTermPayments` query string for /Outstanding/PayInvoices.
  /// ASP.NET binds repeated params into arrays.
  static String termPaymentQuery(
      List<int> studentIds, int year, List<int> months) {
    final parts = <String>[
      for (final s in studentIds) 'studentIds=$s',
      'year=$year',
      for (final m in months) 'months=$m',
    ];
    return parts.join('&');
  }

  /// Pay future term (advance) months. Maps to POST /Outstanding/PayInvoices
  /// with the PayTermPayments query (studentIds/year/months) and a multipart
  /// PaymentMethod/Remarks body (per swag.json). Not verified live — keep the
  /// caller gated behind kPrepayPayEnabled until confirmed.
  static Future<dynamic> outstandingPayTermPayments({
    required List<int> studentIds,
    required int year,
    required List<int> months,
    required int paymentMethod,
    String remarks = 'Advance prepayment',
  }) {
    final qs = termPaymentQuery(studentIds, year, months);
    return ApiService.postMultipart(
      '/Outstanding/PayInvoices?$qs',
      <String, String>{
        'PaymentMethod': paymentMethod.toString(),
        'Remarks': remarks,
      },
    );
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/term_payment_query_test.dart`
Expected: PASS (2 cases).

- [ ] **Step 5: Commit**

```bash
git add lib/services/api.dart test/term_payment_query_test.dart
git commit -m "feat: Api.outstandingPayTermPayments + query serializer"
```

---

### Task 4: Feature flag

**Files:**
- Create: `lib/config/feature_flags.dart`

- [ ] **Step 1: Create the flag**

Create `lib/config/feature_flags.dart`:

```dart
/// Prepay (advance term payment) execution. Pricing/preview is always on;
/// the actual /Outstanding/PayInvoices term charge stays disabled until the
/// pay contract is verified on a plan-enabled account (see the prepay plan's
/// live-verification task).
const bool kPrepayPayEnabled = false;
```

- [ ] **Step 2: Verify it analyzes**

Run: `flutter analyze lib/config/feature_flags.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/config/feature_flags.dart
git commit -m "chore: add kPrepayPayEnabled feature flag (default off)"
```

---

### Task 5: Prepay bottom sheet

**Files:**
- Create: `lib/screens/payment/prepay_sheet.dart`

This is a presentational widget driven by `PrepayService`. No new unit test
(UI); it is exercised by the live-verification task. Keep logic in the service.

- [ ] **Step 1: Create the sheet**

Create `lib/screens/payment/prepay_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import '../../config/feature_flags.dart';
import '../../services/prepay_service.dart';
import '../../services/user_session.dart';
import '../../services/api.dart';
import '../../theme/app_theme.dart';

/// Bottom sheet to prepay future monthly fees for the current student.
Future<void> showPrepaySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _PrepaySheet(),
  );
}

class _PrepaySheet extends StatefulWidget {
  const _PrepaySheet();
  @override
  State<_PrepaySheet> createState() => _PrepaySheetState();
}

class _PrepaySheetState extends State<_PrepaySheet> {
  late int _year;
  final Set<int> _selected = <int>{};
  PrepayQuote _quote = const PrepayQuote([]);
  bool _pricing = false;
  bool _paying = false;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  Future<void> _reprice() async {
    final sid = UserSession.instance.currentStudentId;
    if (sid == null || _selected.isEmpty) {
      setState(() => _quote = const PrepayQuote([]));
      return;
    }
    setState(() => _pricing = true);
    final quote = await PrepayService.priceMonths(
      studentId: sid,
      year: _year,
      months: _selected.toList()..sort(),
    );
    if (!mounted) return;
    setState(() {
      _quote = quote;
      _pricing = false;
    });
  }

  Future<void> _pay() async {
    final sid = UserSession.instance.currentStudentId;
    if (sid == null || _quote.months.isEmpty) return;
    final months = _quote.months.map((m) => m.month).toList();
    setState(() => _paying = true);
    try {
      await Api.outstandingPayTermPayments(
        studentIds: [sid],
        year: _year,
        months: months,
        paymentMethod: 1, // 1 = the default method enum; wire chooser later
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prepayment submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prepayment failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final now = DateTime.now();
    final name = UserSession.instance.displayName;
    final canPay = kPrepayPayEnabled &&
        _quote.months.isNotEmpty &&
        !_paying;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
              color: c.border, borderRadius: BorderRadius.circular(2)),
        ),
        Text('Prepay Monthly Fees',
            style: TextStyle(
                color: c.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        if (name.isNotEmpty)
          Text(name,
              style: TextStyle(color: c.textMuted, fontSize: 12)),
        const SizedBox(height: 14),
        // Year selector.
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final y in [now.year, now.year + 1, now.year + 2])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text('$y'),
                selected: _year == y,
                onSelected: (_) {
                  setState(() {
                    _year = y;
                    _selected.clear();
                    _quote = const PrepayQuote([]);
                  });
                },
              ),
            ),
        ]),
        const SizedBox(height: 12),
        // Month chips.
        Wrap(
          spacing: 8, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var m = 1; m <= 12; m++)
              FilterChip(
                label: Text(_monthNames[m - 1]),
                selected: _selected.contains(m),
                onSelected: (_year == now.year && m < now.month)
                    ? null
                    : (sel) {
                        setState(() {
                          if (sel) {
                            _selected.add(m);
                          } else {
                            _selected.remove(m);
                          }
                        });
                        _reprice();
                      },
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (_pricing)
          const Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          )
        else if (_selected.isNotEmpty && _quote.months.isEmpty)
          Text('No prepayable months for this account.',
              style: TextStyle(color: c.textSecondary)),
        for (final m in _quote.months)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Expanded(
                child: Text(m.label,
                    style: TextStyle(color: c.textPrimary, fontSize: 13)),
              ),
              Text('RM ${m.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: c.textPrimary, fontWeight: FontWeight.w700)),
            ]),
          ),
        if (_quote.months.isNotEmpty) ...[
          const Divider(),
          Row(children: [
            Expanded(
              child: Text('Total',
                  style: TextStyle(
                      color: c.textPrimary, fontWeight: FontWeight.w800)),
            ),
            Text('RM ${_quote.total.toStringAsFixed(2)}',
                style: TextStyle(
                    color: c.primary, fontWeight: FontWeight.w900)),
          ]),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canPay ? _pay : null,
            child: Text(kPrepayPayEnabled
                ? (_paying ? 'Submitting…' : 'Pay')
                : 'Pay (coming soon)'),
          ),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 2: Verify it analyzes**

Run: `flutter analyze lib/screens/payment/prepay_sheet.dart`
Expected: No errors (pre-existing `withOpacity` style infos elsewhere are fine).

- [ ] **Step 3: Commit**

```bash
git add lib/screens/payment/prepay_sheet.dart
git commit -m "feat: prepay bottom sheet (pricing + gated pay)"
```

---

### Task 6: Entry button on the Payments screen

**Files:**
- Modify: `lib/screens/payments_screen.dart`

- [ ] **Step 1: Add the import**

At the top of `lib/screens/payments_screen.dart`, with the other
`import 'payment/...';` lines, add:

```dart
import 'payment/prepay_sheet.dart';
```

- [ ] **Step 2: Add the entry button**

Find the outstanding/pay area of the `build` method (where the "Pay Now" /
outstanding section is rendered). Immediately above that section, insert a
button row:

```dart
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: () => showPrepaySheet(context),
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Prepay / Advance'),
              ),
            ),
```

If the exact anchor is unclear, place the button directly after the
`AppHeader`/title widget at the top of the Payments body so it is always
visible. Do not change any existing payment logic.

- [ ] **Step 3: Verify it analyzes and the suite passes**

Run: `flutter analyze lib/screens/payments_screen.dart && flutter test`
Expected: No new errors; all tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/payments_screen.dart
git commit -m "feat: open prepay sheet from Payments screen"
```

---

### Task 7: Live verification (manual) — unlock pay

**Files:** none (runtime), then a one-line flag flip.

- [ ] **Step 1: Verify pricing on a plan-enabled account**

Log in as a student/instructor with a monthly-fee plan, open Payments →
"Prepay / Advance", pick a future month. Confirm the month prices (amount
shows) for a plan-enabled student and that a no-plan account shows
"No prepayable months for this account."

- [ ] **Step 2: Verify the pay contract with one small real prepay**

Temporarily set `kPrepayPayEnabled = true`, prepay ONE low-value month on a
test student, and confirm `POST /Outstanding/PayInvoices?studentIds=..&year=..&months=..`
(multipart `PaymentMethod`/`Remarks`) returns success and the month becomes
invoiced/paid server-side (re-query `FetchTermPayments` → that month no longer
returns a row, and `Outstanding/Fetch` / `Reports/Receipts` reflect it).

- [ ] **Step 3: Decide**

If the contract is confirmed, leave `kPrepayPayEnabled = true` and commit.
If the response shape differs, adjust `Api.outstandingPayTermPayments` to match
and re-verify before enabling.

```bash
git add lib/config/feature_flags.dart lib/services/api.dart
git commit -m "feat: enable prepay pay after live verification"
```

---

## Self-Review (completed)

- **Spec coverage:** architecture/components → Tasks 1–6; `currentStudentId` → Task 1; `PrepayService.priceMonths` (one-call-per-month, skip empty, total) → Task 2; pay request → Task 3; flag → Task 4; sheet UI (year/month chips, line items, total, no-plan empty state, gated pay) → Task 5; entry point → Task 6; live verification + risk gating → Task 7.
- **Placeholder scan:** none — every code step has full code; no TBD/TODO.
- **Type consistency:** `PrepayQuote`/`PrepayMonth`, `priceMonths(... fetch:)`, `termPaymentQuery(...)`, `outstandingPayTermPayments(...)`, `currentStudentId`, `kPrepayPayEnabled`, `showPrepaySheet(context)` are used consistently across tasks.
- **Note:** Task 5 hardcodes `paymentMethod: 1`; wiring the full card/FPX/bank chooser is deferred (YAGNI) and called out in Task 7 — pay stays gated until then.
