# Instructor Collections — Live Data + UI Restyle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the instructor Collections list screens render live records, and restyle the Collections grid + list screens to match the student Profile look.

**Architecture:** Single-file change in `instructor_collections_screen.dart`. Root cause of the empty lists is response-shape parsing — the endpoints already send sensible request bodies (`/Reports/PaymentSlips` via `_reportBody`) or are GET-only path-param calls (`/Outstanding/CollectionCountList`). The fix is a recursive list-finder that unwraps nested responses, plus styled record cards, a raw-response diagnostic for genuine empties, and a restyle to the app's shared visual vocabulary.

**Tech Stack:** Flutter, existing theme tokens (`AppColors`, `Radii`, `Shadows`, `Gaps`), `lib/widgets/anim.dart` (`ShimmerList`, `FadeSlideIn`), `lib/widgets/app_header.dart`.

**Verification note:** This codebase has no widget-test harness for screens (`widget_test` is excluded from analysis everywhere). The verification gate for every task is `flutter analyze --no-pub` (zero errors) plus visual confirmation in the running dev-Edge preview. There are no unit-test steps.

---

## File Structure

- Modify: `lib/screens/instructor_collections_screen.dart` — the whole change. Contains `InstructorCollectionsScreen` (grid) and the list screen (currently `_SimpleListScreen`).
- Reuse (no change): `lib/widgets/anim.dart`, `lib/widgets/app_header.dart`, `lib/theme/app_theme.dart`, `lib/services/api.dart`, `lib/services/user_session.dart`.

---

## Task 1: Recursive list-finder + record field readers

**Files:**
- Modify: `lib/screens/instructor_collections_screen.dart`

- [ ] **Step 1: Add the response unwrap helper**

Add these top-level functions at the end of the file (after the last class):

```dart
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
    // Nothing under a known key — descend into nested maps/lists.
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

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output (zero errors). Unused-element warnings are acceptable at this step — later tasks consume these helpers.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/instructor_collections_screen.dart
git commit -m "Add response list-finder and field readers for Collections"
```

---

## Task 2: Wire the list screen to use the list-finder + keep raw response

**Files:**
- Modify: `lib/screens/instructor_collections_screen.dart` — `_SimpleListScreenState`

- [ ] **Step 1: Replace the `_load` parsing and add a raw-response field**

In `_SimpleListScreenState`, add a field beside `_data`:

```dart
  dynamic _data;
  dynamic _rawResponse;
  bool _loading = true;
  String? _error;
```

Replace the body of `_load` with:

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

- [ ] **Step 2: Update the build list extraction**

In `build`, replace `final list = _data is List ? _data as List : const [];` with:

```dart
    final list = _data is List ? _data as List : const [];
```

(unchanged line — `_data` is now always a `List` from `findRecordList`; keep the guard for safety.)

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/instructor_collections_screen.dart
git commit -m "Unwrap Collections list responses via recursive finder"
```

---

## Task 3: Styled record card

**Files:**
- Modify: `lib/screens/instructor_collections_screen.dart` — `_SimpleListScreenState._rowCard`

- [ ] **Step 1: Replace `_rowCard` with a styled card**

Replace the entire `_rowCard` method with:

```dart
  Widget _rowCard(AppColors c, Map row, int index) {
    final title = pickField(row, [
      'studentName', 'name', 'payerName', 'memberName', 'description',
    ]);
    final amount = pickAmount(row, [
      'amount', 'dueAmount', 'paidAmount', 'value', 'total', 'totalAmount',
    ]);
    final dateRaw = pickField(row, [
      'date', 'paymentDate', 'recordedTime', 'createdDate', 'slipDate',
    ]);
    final date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
    final status = pickField(row, ['status', 'paymentStatus', 'remarks']);
    final ok = status.toLowerCase().contains('paid') ||
        status.toLowerCase().contains('approve') ||
        status.toLowerCase().contains('success');
    final statusColor = status.isEmpty
        ? c.textMuted
        : (ok ? c.success : c.danger);

    return FadeSlideIn.at(
      index,
      child: Container(
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
            Row(children: [
              Expanded(
                child: Text(
                  title.isEmpty ? 'Record #${index + 1}' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800),
                ),
              ),
              if (amount > 0)
                Text('RM ${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: c.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
            ]),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
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
      ),
    );
  }
```

- [ ] **Step 2: Update the `_rowCard` call site**

In `build`, the records loop currently reads:

```dart
                  else
                    for (final row in list)
                      _rowCard(c, row is Map ? row : {'value': row}),
```

Replace with an indexed loop:

```dart
                  else
                    ...list.asMap().entries.map((e) => _rowCard(
                        c,
                        e.value is Map ? e.value as Map : {'value': e.value},
                        e.key)),
```

- [ ] **Step 3: Add the `anim.dart` import**

At the top of the file, with the other imports, add:

```dart
import '../widgets/anim.dart';
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/instructor_collections_screen.dart
git commit -m "Style Collections record cards with title, amount, status"
```

---

## Task 4: Raw-response diagnostic in the empty state

**Files:**
- Modify: `lib/screens/instructor_collections_screen.dart` — `_SimpleListScreenState`

- [ ] **Step 1: Add an expand-state field**

In `_SimpleListScreenState`, beside the other fields:

```dart
  bool _showRaw = false;
```

- [ ] **Step 2: Replace the empty-state block**

In `build`, replace the `else if (list.isEmpty)` branch with:

```dart
                  else if (list.isEmpty)
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
                            Text('No records found',
                                style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(
                                'There are no ${widget.title.toLowerCase()} for this period.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 12)),
                          ]),
                        ),
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
                    )
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/instructor_collections_screen.dart
git commit -m "Add raw-response diagnostic to Collections empty state"
```

---

## Task 5: Shimmer loading state for the list screen

**Files:**
- Modify: `lib/screens/instructor_collections_screen.dart` — `_SimpleListScreenState.build`

- [ ] **Step 1: Replace the loading branch**

In `build`, replace the `if (_loading)` branch with:

```dart
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ShimmerList(
                          itemCount: 6, itemHeight: 78),
                    )
```

- [ ] **Step 2: Confirm `ShimmerList` signature**

Run: `grep -n "class ShimmerList" -A12 lib/widgets/anim.dart`
Expected: a `ShimmerList` widget with `itemCount` and `itemHeight` named params. If the parameter names differ, use the actual names from the output in Step 1's code.

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/instructor_collections_screen.dart
git commit -m "Use shimmer skeleton for Collections list loading"
```

---

## Task 6: Restyle the Collections grid (header + tiles)

**Files:**
- Modify: `lib/screens/instructor_collections_screen.dart` — `_InstructorCollectionsScreenState`

- [ ] **Step 1: Replace the `_tile` method**

Replace the entire `_tile` method with a Profile-style tile — circular gradient-tint icon, count as a badge:

```dart
  Widget _tile(AppColors c, IconData icon, String label, int? count,
      VoidCallback onTap, int index) {
    return FadeSlideIn.at(
      index,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: c.isDark ? Border.all(color: c.border) : null,
            boxShadow: Shadows.card(c),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: c.primary, size: 20),
                ),
                const Spacer(),
                if (count != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$count',
                        style: TextStyle(
                            color: c.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                  ),
              ]),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14),
              ),
              const SizedBox(height: 2),
              Row(children: [
                Text('View',
                    style: TextStyle(
                        color: c.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                Icon(Icons.chevron_right, size: 15, color: c.textMuted),
              ]),
            ],
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 2: Update the four `_tile` call sites**

In `build`, the `GridView.count` children call `_tile(...)` four times. Add the trailing index argument to each: `0` for Cash Payments, `1` for Online Payments, `2` for Payment Slips, `3` for Update Collection. Example for the first:

```dart
                      _tile(
                          c,
                          Icons.payments_outlined,
                          'Cash Payments',
                          _loading ? null : cash,
                          () => _openList(context, 1, 'Cash Payments'),
                          0),
```

Apply the same trailing-index pattern (`1`, `2`, `3`) to the other three tiles.

- [ ] **Step 3: Make the grid responsive**

In `build`, replace the `GridView.count` `childAspectRatio` line with a width-aware value. Just before the `return Scaffold`, add:

```dart
    final narrow = MediaQuery.of(context).size.width < 360;
```

Then in the `GridView.count`, change `childAspectRatio: 1.25,` to:

```dart
                    childAspectRatio: narrow ? 1.0 : 1.2,
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/instructor_collections_screen.dart
git commit -m "Restyle Collections grid tiles to match Profile look"
```

---

## Task 7: Gradient header for the Collections grid

**Files:**
- Modify: `lib/screens/instructor_collections_screen.dart` — `_InstructorCollectionsScreenState.build`

- [ ] **Step 1: Replace the plain header with a gradient strip**

In `build`, the `Column` currently starts with `const AppHeader(title: 'Collections')`. Replace that `AppHeader` line with a gradient hero header:

```dart
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                Gaps.lg,
                (MediaQuery.of(context).padding.top > 0
                        ? MediaQuery.of(context).padding.top
                        : 44) +
                    16,
                Gaps.lg,
                20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: c.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('COLLECTIONS',
                    style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2)),
                const SizedBox(height: 2),
                const Text('Payments overview',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ],
            ),
          ),
```

- [ ] **Step 2: Remove the now-unused `AppHeader` import if nothing else uses it**

Run: `grep -n "AppHeader" lib/screens/instructor_collections_screen.dart`
The list screen (`_SimpleListScreen`) still uses `AppHeader` — so KEEP the import. Only confirm; no edit needed.

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/instructor_collections_screen.dart
git commit -m "Add gradient header to Collections screen"
```

---

## Task 8: Full verification in preview

**Files:** none (verification only)

- [ ] **Step 1: Full analyze**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 2: Build the release web bundle**

Run: `flutter build web --release --no-pub`
Expected: `√ Built build\web`.

- [ ] **Step 3: Serve and open the preview**

Serve `build/web` on port 3000 and open the dev-Edge preview at `http://localhost:3000`. Log in as the instructor account (`RICK1` / `123456`, club `RTT`).

- [ ] **Step 4: Visual checklist**

Confirm in the preview:
- Collections screen has a gradient header, no notch overlap.
- The four grid tiles use the Profile card style with count badges.
- Tapping Cash Payments / Online Payments / Payment Slips opens a list
  screen that shows shimmer, then either styled record cards with live
  data OR a clear "No records found" empty state with a working
  "Show raw response" toggle.
- No layout overflow on the narrow device preset (iPhone X / Android).

- [ ] **Step 5: Commit any fixes**

If the visual check surfaced issues, fix them and commit:

```bash
git add lib/screens/instructor_collections_screen.dart
git commit -m "Fix Collections issues found in preview verification"
```

---

## Self-Review

- **Spec coverage:** list-finder (Task 1–2), request params — endpoints already carry `_reportBody` defaults or are GET path-param only, so no body change is needed and the spec's param section is satisfied by the unwrap fix (Task 2); raw diagnostic (Task 4); styled record cards (Task 3); gradient header (Task 7); grid tile restyle (Task 6); shimmer loading (Task 5); responsive grid (Task 6 Step 3); error/empty states (existing error branch kept, empty rebuilt in Task 4); verification (Task 8). All spec sections covered.
- **Placeholders:** none — every code step has complete code.
- **Type consistency:** `findRecordList`, `pickField`, `pickAmount` defined in Task 1 and used unchanged in Tasks 2–3. `_rowCard` gains an `index` param in Task 3 and the call site updates in the same task. `_tile` gains an `index` param in Task 6 with all four call sites updated in the same task.
