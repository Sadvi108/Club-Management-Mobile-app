# Instructor Reports — Live Data + Styled Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the 18 instructor report drill-down screens render live records reliably and as styled cards instead of raw key/value dumps.

**Architecture:** Root cause is `instructor_report_list_screen.dart` — it unwraps only a top-level `data` key, so nested API responses resolve empty, and `_rowCard` prints the first 4 raw map entries. Fix: reuse the proven recursive list-finder (already written for Collections in `instructor_collections_screen.dart`) by extracting it to a shared util, wire the report screen through it, render a smart generic styled card, and add a raw-response diagnostic for genuine empties.

**Tech Stack:** Flutter, existing theme tokens, `lib/widgets/anim.dart`.

**Verification:** No widget-test harness for screens. Gate per task = `flutter analyze --no-pub` (zero errors in `lib/`) plus the release web build succeeding.

---

## File Structure

- Create: `lib/services/response_utils.dart` — shared `findRecordList`, `pickField`, `pickAmount`. (Currently these live as private top-level functions in `instructor_collections_screen.dart`.)
- Modify: `lib/screens/instructor_collections_screen.dart` — delete its local copies, import the shared util.
- Modify: `lib/screens/instructor_report_list_screen.dart` — recursive unwrap, raw-response capture, styled card, raw diagnostic.

---

## Task 1: Extract shared response utilities

**Files:**
- Create: `lib/services/response_utils.dart`
- Modify: `lib/screens/instructor_collections_screen.dart`

- [ ] **Step 1: Create the shared util file**

Create `lib/services/response_utils.dart` with exactly:

```dart
/// Shared helpers for turning varied API JSON responses into a clean
/// list of record maps and reading fields out of them.

/// Recursively locate the first List of records in an API response.
/// Handles `{data: [...]}`, `{data: {rows: [...]}}`, bare lists, etc.
List<dynamic> findRecordList(dynamic resp) {
  if (resp is List) return resp;
  if (resp is Map) {
    const keys = [
      'data', 'items', 'rows', 'results', 'value', 'records',
      'collections', 'slips', 'list', 'payments',
    ];
    for (final k in keys) {
      final v = resp[k];
      if (v is List) return v;
    }
    for (final v in resp.values) {
      if (v is List) return v;
      if (v is Map) {
        final nested = findRecordList(v);
        if (nested.isNotEmpty) return nested;
      }
    }
  }
  return const [];
}

/// First non-empty string value across a set of candidate keys.
String pickField(Map row, List<String> keys) {
  for (final k in keys) {
    final v = row[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty && s != 'null') return s;
  }
  return '';
}

/// First numeric value across a set of candidate keys.
num pickAmount(Map row, List<String> keys) {
  for (final k in keys) {
    final v = row[k];
    if (v is num) return v;
    if (v is String) {
      final n = num.tryParse(v.replaceAll(RegExp(r'[^\d.\-]'), ''));
      if (n != null) return n;
    }
  }
  return 0;
}
```

- [ ] **Step 2: Point Collections at the shared util**

In `lib/screens/instructor_collections_screen.dart`:
- Add import near the other imports: `import '../services/response_utils.dart';`
- Delete the three top-level functions `findRecordList`, `pickField`, `pickAmount` that currently sit at the end of the file (they are now in the shared util). Leave every call site unchanged — the names resolve via the import.

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add lib/services/response_utils.dart lib/screens/instructor_collections_screen.dart
git commit -m "Extract shared API response utilities"
```

---

## Task 2: Wire the report screen through the recursive finder

**Files:**
- Modify: `lib/screens/instructor_report_list_screen.dart`

- [ ] **Step 1: Add the import**

At the top, with the other imports:

```dart
import '../services/response_utils.dart';
```

- [ ] **Step 2: Add a raw-response field**

In `_InstructorReportListScreenState`, beside `_data`:

```dart
  dynamic _data;
  dynamic _rawResponse;
  bool _loading = true;
  String? _error;
```

- [ ] **Step 3: Replace `_load` body**

```dart
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await widget.fetcher();
      _rawResponse = resp;
      setState(() => _data = findRecordList(resp));
    } catch (e) {
      debugPrint('${widget.title} failed: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
```

- [ ] **Step 4: Simplify `_rows`**

`_data` is now always a `List` from `findRecordList`. Replace `_rows` with:

```dart
  List<Map<String, dynamic>> _rows() {
    final d = _data;
    if (d is! List) return const [];
    return d
        .map((e) => e is Map
            ? Map<String, dynamic>.from(e)
            : <String, dynamic>{'value': e})
        .toList();
  }
```

- [ ] **Step 5: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/instructor_report_list_screen.dart
git commit -m "Unwrap instructor report responses via recursive finder"
```

---

## Task 3: Styled generic record card

**Files:**
- Modify: `lib/screens/instructor_report_list_screen.dart` — `_rowCard`

- [ ] **Step 1: Replace `_rowCard`**

Reports are heterogeneous (student lists, attendance, receipts, grading, tournaments). The card picks a title, an optional amount, an optional date, an optional status pill, and shows up to three remaining non-empty fields as compact label/value lines.

```dart
  Widget _rowCard(AppColors c, Map<String, dynamic> row) {
    final title = pickField(row, [
      'name', 'studentName', 'instructorName', 'tcName', 'centerName',
      'description', 'invoiceDescription', 'text', 'title',
    ]);
    final amount = pickAmount(row, [
      'amount', 'dueAmount', 'paidAmount', 'totalAmount', 'value', 'total',
    ]);
    final dateRaw = pickField(row, [
      'date', 'paymentDate', 'examDate', 'recordedTime', 'createdDate',
      'dueDate',
    ]);
    final date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
    final status = pickField(row, [
      'paymentStatus', 'examStatus', 'attendanceType', 'transactionType',
      'status',
    ]);
    final ok = () {
      final s = status.toLowerCase();
      return s.contains('paid') ||
          s.contains('present') ||
          s.contains('approve') ||
          s.contains('active') ||
          s.contains('success') ||
          s.contains('pass');
    }();
    final statusColor =
        status.isEmpty ? c.textMuted : (ok ? c.success : c.danger);

    // Up to three extra fields not already surfaced above.
    const shown = {
      'name', 'studentName', 'instructorName', 'tcName', 'centerName',
      'description', 'invoiceDescription', 'text', 'title', 'amount',
      'dueAmount', 'paidAmount', 'totalAmount', 'value', 'total', 'date',
      'paymentDate', 'examDate', 'recordedTime', 'createdDate', 'dueDate',
      'paymentStatus', 'examStatus', 'attendanceType', 'transactionType',
      'status',
    };
    final extras = <MapEntry<String, String>>[];
    for (final e in row.entries) {
      if (shown.contains(e.key)) continue;
      final v = (e.value ?? '').toString().trim();
      if (v.isEmpty || v == 'null') continue;
      extras.add(MapEntry(_humanizeKey(e.key), v));
      if (extras.length == 3) break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Text(
                title.isEmpty ? 'Record' : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800),
              ),
            ),
            if (amount > 0) ...[
              const SizedBox(width: 8),
              Text('RM ${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: c.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900)),
            ],
          ]),
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final ex in extras)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(ex.key,
                          style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: Text(ex.value,
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
          ],
          if (date.isNotEmpty || status.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (date.isNotEmpty) ...[
                Icon(Icons.event, size: 13, color: c.textMuted),
                const SizedBox(width: 5),
                Text(date,
                    style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
              ],
              const Spacer(),
              if (status.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800)),
                ),
            ]),
          ],
        ],
      ),
    );
  }

  /// "studentName" -> "Student name".
  String _humanizeKey(String k) {
    final spaced = k.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    if (spaced.isEmpty) return spaced;
    return spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
  }
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/instructor_report_list_screen.dart
git commit -m "Style instructor report cards with title, amount, status"
```

---

## Task 4: Raw-response diagnostic for empty reports

**Files:**
- Modify: `lib/screens/instructor_report_list_screen.dart`

- [ ] **Step 1: Add an expand-state field**

In `_InstructorReportListScreenState`, beside the other fields:

```dart
  bool _showRaw = false;
```

- [ ] **Step 2: Replace the empty-state branch**

In `build`, the `else if (visible.isEmpty)` branch currently renders a single
`Container` with "No records." Replace that whole `else if (visible.isEmpty)`
branch with:

```dart
                  else if (visible.isEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 32, horizontal: 16),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(Radii.lg),
                            border: c.isDark
                                ? Border.all(color: c.border)
                                : null,
                            boxShadow: Shadows.card(c),
                          ),
                          child: Column(children: [
                            Icon(Icons.inbox_outlined,
                                size: 40, color: c.textMuted),
                            const SizedBox(height: 10),
                            Text(
                                allRows.isEmpty
                                    ? 'No records found'
                                    : 'No matches',
                                style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(
                                allRows.isEmpty
                                    ? 'There is no ${widget.title.toLowerCase()} data to show.'
                                    : 'Adjust filters or clear the search.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: c.textSecondary, fontSize: 12)),
                          ]),
                        ),
                        if (allRows.isEmpty) ...[
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () =>
                                setState(() => _showRaw = !_showRaw),
                            child: Text(
                                _showRaw
                                    ? 'Hide raw response'
                                    : 'Show raw response',
                                style: TextStyle(
                                    color: c.textMuted, fontSize: 12)),
                          ),
                          if (_showRaw)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: c.surfaceAlt,
                                borderRadius:
                                    BorderRadius.circular(Radii.md),
                                border: Border.all(color: c.border),
                              ),
                              child: SelectableText(
                                _rawResponse?.toString() ??
                                    'No response captured',
                                style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 11,
                                    fontFamily: 'monospace'),
                              ),
                            ),
                        ],
                      ],
                    )
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/instructor_report_list_screen.dart
git commit -m "Add raw-response diagnostic to empty instructor reports"
```

---

## Task 5: Build verification

**Files:** none.

- [ ] **Step 1: Full analyze**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 2: Release web build**

Run: `flutter build web --release --no-pub`
Expected: `√ Built build\web`.

- [ ] **Step 3: Commit any fixes**

If the build surfaced issues, fix and commit:

```bash
git add -A
git commit -m "Fix issues found in instructor reports build verification"
```

---

## Self-Review

- **Spec coverage:** recursive unwrap (Task 2), styled cards (Task 3), raw
  diagnostic (Task 4), shared util extracted to remove duplication (Task 1),
  build verification (Task 5). The "scattered raw key/value" complaint is
  resolved by Task 3; the "not pulling live data" complaint is resolved by
  Task 2's recursive finder handling nested response shapes.
- **Placeholders:** none — every code step has complete code.
- **Type consistency:** `findRecordList`, `pickField`, `pickAmount` defined
  once in Task 1's `response_utils.dart`, imported by both screens.
  `_humanizeKey` defined in Task 3 and used only within `_rowCard` in the
  same file. `_rawResponse` and `_showRaw` fields added in Tasks 2 and 4
  before their use sites.
