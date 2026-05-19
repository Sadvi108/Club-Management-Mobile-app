# Instructor Report Filters — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development or executing-plans. Steps use `- [ ]`.

**Goal:** Give each instructor report drill-down its own correct API call and the specific filters the report needs (training/exam center, date range, status dropdowns, name/IC search). Fix the Training Time report (wired to the wrong endpoint) and add the missing Contribution report.

**Architecture:** A per-report `ReportSpec` (which filters to show + how to fetch + how to read a row's status). `InstructorReportListScreen` is rewritten to render a filter bar from the spec, build the request body / re-fetch on Apply, and apply client-side status filtering for fields the API has no parameter for. Date range and center IDs go into the `ReportRequestViewModel` body (server-side); status/payment-mode/active filters are client-side on the returned rows. Server fact (from swag.json): every `/Reports/*` POST takes `{sCenterId,tCenterId,eCenterId,tTimeId,sourceKeyId,reportType,fromDate,toDate}`; `/Reports/StudentDetails` also takes `studentName,studentIcNo`.

**Tech Stack:** Flutter, existing theme tokens, `lib/services/response_utils.dart` (`findRecordList`, `pickField`, `pickAmount`), `lib/widgets/anim.dart`.

**Verification:** No screen test harness. Gate per task = `flutter analyze --no-pub` (zero errors in `lib/`) + release web build succeeds.

---

## File Structure

- Create: `lib/screens/instructor_reports/report_spec.dart` — `RFilter` enum, `ReportQuery`, `ReportSpec`, `kReportSpecs` map keyed by route slug, body builder.
- Rewrite: `lib/screens/instructor_report_list_screen.dart` — consumes a `ReportSpec`, renders the filter bar, fetches, filters, renders styled cards. Keeps the existing `findRecordList` + styled-card + raw-diagnostic behaviour.
- Modify: `lib/router/app_router.dart` — `_reportRoute` resolves a `ReportSpec` by slug; add the `contribution` route.
- Modify: `lib/screens/instructor_reports_screen.dart` — add the Contribution tile.

---

## Task 1: Report spec module

**Files:**
- Create: `lib/screens/instructor_reports/report_spec.dart`

- [ ] **Step 1: Create the file**

```dart
import '../../services/api.dart';

/// A filter control a report can show.
enum RFilter { trainingCenter, examCenter, dateRange, status, nameText, icText }

/// User-chosen filter values for a report.
class ReportQuery {
  int tCenterId;
  int eCenterId;
  DateTime? fromDate;
  DateTime? toDate;
  String name;
  String ic;
  String? status;

  ReportQuery({
    this.tCenterId = 0,
    this.eCenterId = 0,
    this.fromDate,
    this.toDate,
    this.name = '',
    this.ic = '',
    this.status,
  });
}

typedef SpecFetch = Future<dynamic> Function(ReportQuery q);
typedef RowStatus = String Function(Map row);

/// Per-report configuration.
class ReportSpec {
  final String title;
  final List<RFilter> filters;
  final SpecFetch fetch;
  final List<String> statusOptions;
  final RowStatus? rowStatus;
  final String statusLabel;
  final bool trainingTimeMode;

  const ReportSpec({
    required this.title,
    required this.fetch,
    this.filters = const [],
    this.statusOptions = const [],
    this.rowStatus,
    this.statusLabel = 'Status',
    this.trainingTimeMode = false,
  });
}

/// Build the `/Reports/*` request body from the chosen filters. Only
/// non-default values are sent; `Api._reportBody` fills the rest.
Map<String, dynamic> reportBody(ReportQuery q) {
  final m = <String, dynamic>{};
  if (q.tCenterId != 0) m['tCenterId'] = q.tCenterId;
  if (q.eCenterId != 0) m['eCenterId'] = q.eCenterId;
  if (q.fromDate != null) m['fromDate'] = q.fromDate!.toIso8601String();
  if (q.toDate != null) m['toDate'] = q.toDate!.toIso8601String();
  return m;
}

/// Specs keyed by the route slug (last path segment of the report route).
/// Routes not present here fall back to a no-filter spec built in the
/// router from a bare fetcher.
final Map<String, ReportSpec> kReportSpecs = {
  'student-list': ReportSpec(
    title: 'Student List',
    filters: const [
      RFilter.trainingCenter,
      RFilter.status,
      RFilter.nameText,
      RFilter.icText,
    ],
    statusLabel: 'Status',
    statusOptions: const ['Active', 'Inactive'],
    rowStatus: (r) {
      final a = r['isActive'];
      if (a is bool) return a ? 'Active' : 'Inactive';
      final s = (r['status'] ?? r['activeStatus'] ?? r['studentStatus'] ?? '')
          .toString()
          .toLowerCase();
      if (s.contains('inactive')) return 'Inactive';
      if (s.contains('active')) return 'Active';
      return '';
    },
    fetch: (q) {
      final b = reportBody(q);
      if (q.name.isNotEmpty) b['studentName'] = q.name;
      if (q.ic.isNotEmpty) b['studentIcNo'] = q.ic;
      return Api.reportsStudentDetails(b);
    },
  ),
  'training-time': ReportSpec(
    title: 'Training Time',
    filters: const [RFilter.trainingCenter],
    trainingTimeMode: true,
    fetch: (q) => q.tCenterId == 0
        ? Future<dynamic>.value(const <dynamic>[])
        : Api.listingTrainingTimeByTcId(q.tCenterId),
  ),
  'grading-schedule': ReportSpec(
    title: 'Grading Schedule',
    filters: const [RFilter.examCenter, RFilter.dateRange],
    fetch: (q) => Api.reportsGradingSchedule(reportBody(q)),
  ),
  'grading-past': ReportSpec(
    title: 'Grading Past',
    filters: const [RFilter.examCenter, RFilter.dateRange],
    fetch: (q) => Api.reportsGradingSchedule(reportBody(q)),
  ),
  'receipt': ReportSpec(
    title: 'Receipt',
    filters: const [RFilter.trainingCenter, RFilter.dateRange, RFilter.status],
    statusLabel: 'Payment mode',
    statusOptions: const ['Cash', 'Online', 'Bank Transfer', 'Cheque'],
    rowStatus: (r) =>
        (r['paymentMode'] ?? r['mode'] ?? r['paymentType'] ?? '').toString(),
    fetch: (q) => Api.reportsReceipts(reportBody(q)),
  ),
  'attendance': ReportSpec(
    title: 'Attendance Report',
    filters: const [RFilter.dateRange],
    fetch: (q) => Api.reportsAttendance(reportBody(q)),
  ),
  'purchase-request': ReportSpec(
    title: 'Purchase Request',
    filters: const [RFilter.trainingCenter, RFilter.status],
    statusLabel: 'Action status',
    statusOptions: const ['Pending', 'Approved', 'Rejected'],
    rowStatus: (r) =>
        (r['actionStatus'] ?? r['status'] ?? r['approvalStatus'] ?? '')
            .toString(),
    fetch: (q) => Api.reportsPurchaseRequests(reportBody(q)),
  ),
  'payment-slip': ReportSpec(
    title: 'Payment Slip',
    filters: const [RFilter.trainingCenter, RFilter.status],
    statusLabel: 'Action status',
    statusOptions: const ['Pending', 'Approved', 'Rejected'],
    rowStatus: (r) =>
        (r['actionStatus'] ?? r['status'] ?? r['approvalStatus'] ?? '')
            .toString(),
    fetch: (q) => Api.reportsPaymentSlips(reportBody(q)),
  ),
  'reimbursement': ReportSpec(
    title: 'Reimbursement',
    filters: const [RFilter.dateRange, RFilter.status],
    statusLabel: 'Status',
    statusOptions: const ['Reimbursed', 'Not Reimbursed'],
    rowStatus: (r) {
      final v = r['isReimbursed'] ?? r['reimbursed'];
      if (v is bool) return v ? 'Reimbursed' : 'Not Reimbursed';
      final s = (r['status'] ?? r['reimbursementStatus'] ?? '')
          .toString()
          .toLowerCase();
      if (s.contains('not')) return 'Not Reimbursed';
      if (s.contains('reimburs')) return 'Reimbursed';
      return '';
    },
    fetch: (q) => Api.reportsReimbursement(reportBody(q)),
  ),
  'contribution': ReportSpec(
    title: 'Contribution',
    filters: const [RFilter.dateRange],
    fetch: (q) => Api.reportsContribution(reportBody(q)),
  ),
};
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze --no-pub lib/screens/instructor_reports/report_spec.dart 2>&1 | grep -E " error "`
Expected: no output. (Unused warnings fine — consumed in Task 2.)

- [ ] **Step 3: Commit**

```bash
git add lib/screens/instructor_reports/report_spec.dart
git commit -m "Add per-report ReportSpec config for instructor reports"
```

---

## Task 2: Rewrite the report list screen to consume ReportSpec

**Files:**
- Rewrite: `lib/screens/instructor_report_list_screen.dart`

- [ ] **Step 1: Replace the whole file**

```dart
import 'package:flutter/material.dart';

import '../services/response_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/app_header.dart';
import 'instructor_reports/report_spec.dart';

/// Centre option for a dropdown — id + display label.
class _Centre {
  final int id;
  final String label;
  const _Centre(this.id, this.label);
}

/// Generic instructor report drill-down. Renders the filter bar described
/// by [spec], fetches via [spec.fetch], applies client-side status
/// filtering, and renders styled record cards.
class InstructorReportListScreen extends StatefulWidget {
  final ReportSpec spec;
  const InstructorReportListScreen({super.key, required this.spec});

  @override
  State<InstructorReportListScreen> createState() =>
      _InstructorReportListScreenState();
}

class _InstructorReportListScreenState
    extends State<InstructorReportListScreen> {
  final _query = ReportQuery();
  final _nameCtrl = TextEditingController();
  final _icCtrl = TextEditingController();

  List<dynamic> _data = const [];
  dynamic _rawResponse;
  bool _loading = false;
  bool _showRaw = false;
  String? _error;

  List<_Centre> _trainingCentres = const [];
  List<_Centre> _examCentres = const [];

  ReportSpec get _spec => widget.spec;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _icCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Load dropdown option sources the spec needs, then the first fetch.
    final futures = <Future<void>>[];
    if (_spec.filters.contains(RFilter.trainingCenter)) {
      futures.add(_loadCentres(true));
    }
    if (_spec.filters.contains(RFilter.examCenter)) {
      futures.add(_loadCentres(false));
    }
    if (futures.isNotEmpty) await Future.wait(futures);
    if (!mounted) return;
    // Training-time mode needs a centre chosen first — don't auto-fetch.
    if (!_spec.trainingTimeMode) _load();
  }

  Future<void> _loadCentres(bool training) async {
    try {
      final resp = training
          ? await ApiCentres.training()
          : await ApiCentres.exam();
      final rows = findRecordList(resp).whereType<Map>();
      final list = <_Centre>[const _Centre(0, 'All centres')];
      for (final r in rows) {
        final id = (r['id'] ?? r['centerId'] ?? r['tCenterId'] ??
                r['eCenterId'] ?? r['value'] ?? 0);
        final idInt = id is int
            ? id
            : int.tryParse(id.toString()) ?? 0;
        final label = pickField(r, [
          'name', 'centerName', 'tCenterName', 'eCenterName', 'text',
        ]);
        if (idInt != 0 && label.isNotEmpty) {
          list.add(_Centre(idInt, label));
        }
      }
      if (!mounted) return;
      setState(() {
        if (training) {
          _trainingCentres = list;
        } else {
          _examCentres = list;
        }
      });
    } catch (e) {
      debugPrint('centre load failed: $e');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _query.name = _nameCtrl.text.trim();
      _query.ic = _icCtrl.text.trim();
      final resp = await _spec.fetch(_query);
      _rawResponse = resp;
      setState(() => _data = findRecordList(resp));
    } catch (e) {
      debugPrint('${_spec.title} failed: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Rows after client-side status filtering.
  List<Map<String, dynamic>> _visibleRows() {
    final rows = _data
        .map((e) => e is Map
            ? Map<String, dynamic>.from(e)
            : <String, dynamic>{'value': e})
        .toList();
    final status = _query.status;
    if (status == null || status.isEmpty || _spec.rowStatus == null) {
      return rows;
    }
    final want = status.toLowerCase();
    return rows.where((r) {
      final s = _spec.rowStatus!(r).toLowerCase();
      return s.contains(want) || want.contains(s) && s.isNotEmpty;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final rows = _loading ? const <Map<String, dynamic>>[] : _visibleRows();
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          AppHeader(title: _spec.title, showBack: true),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: c.primary,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.lg, 24),
                children: [
                  if (_spec.filters.isNotEmpty) _filterBar(c),
                  const SizedBox(height: Gaps.sm),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: ShimmerList(count: 7, rowHeight: 72),
                    )
                  else if (_error != null)
                    _errorCard(c)
                  else if (_spec.trainingTimeMode && _query.tCenterId == 0)
                    _promptCard(c, 'Select a training center above to see its '
                        'weekly time table.')
                  else if (rows.isEmpty)
                    _emptyCard(c)
                  else
                    for (final entry in rows.asMap().entries)
                      FadeSlideIn.at(
                        entry.key.clamp(0, 8),
                        offsetY: 14,
                        child: _spec.trainingTimeMode
                            ? _trainingTimeCard(c, entry.value)
                            : _rowCard(c, entry.value),
                      ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Filter bar ────────────────────────────────────────────────────────
  Widget _filterBar(AppColors c) {
    final children = <Widget>[];
    for (final f in _spec.filters) {
      switch (f) {
        case RFilter.trainingCenter:
          children.add(_centreDropdown(c, 'Training center',
              _trainingCentres, _query.tCenterId,
              (v) => setState(() => _query.tCenterId = v)));
          break;
        case RFilter.examCenter:
          children.add(_centreDropdown(c, 'Exam center',
              _examCentres, _query.eCenterId,
              (v) => setState(() => _query.eCenterId = v)));
          break;
        case RFilter.dateRange:
          children.add(_dateRow(c));
          break;
        case RFilter.status:
          children.add(_statusDropdown(c));
          break;
        case RFilter.nameText:
          children.add(_textField(c, 'Name', _nameCtrl));
          break;
        case RFilter.icText:
          children.add(_textField(c, 'IC No.', _icCtrl));
          break;
      }
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final w in children)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: w,
            ),
          InkWell(
            onTap: _load,
            borderRadius: BorderRadius.circular(Radii.md),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: c.gradient),
                borderRadius: BorderRadius.circular(Radii.md),
                boxShadow: Shadows.strong(c),
              ),
              child: const Text('Apply filters',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(AppColors c, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(t,
            style: TextStyle(
                color: c.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
      );

  Widget _shell(AppColors c, Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.border),
        ),
        child: child,
      );

  Widget _centreDropdown(AppColors c, String label, List<_Centre> centres,
      int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(c, label),
        _shell(
          c,
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: centres.any((e) => e.id == value) ? value : 0,
              hint: Text(centres.isEmpty ? 'Loading…' : 'All centres',
                  style: TextStyle(color: c.textMuted, fontSize: 13)),
              items: centres
                  .map((e) => DropdownMenuItem<int>(
                        value: e.id,
                        child: Text(e.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.textPrimary, fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => onChanged(v ?? 0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusDropdown(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(c, _spec.statusLabel),
        _shell(
          c,
          DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              isExpanded: true,
              value: _query.status,
              hint: Text('Any',
                  style: TextStyle(color: c.textMuted, fontSize: 13)),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Any',
                      style: TextStyle(color: c.textPrimary, fontSize: 13)),
                ),
                for (final o in _spec.statusOptions)
                  DropdownMenuItem<String?>(
                    value: o,
                    child: Text(o,
                        style:
                            TextStyle(color: c.textPrimary, fontSize: 13)),
                  ),
              ],
              onChanged: (v) => setState(() => _query.status = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateRow(AppColors c) {
    return Row(children: [
      Expanded(child: _dateField(c, 'From', _query.fromDate, (d) {
        setState(() => _query.fromDate = d);
      })),
      const SizedBox(width: 10),
      Expanded(child: _dateField(c, 'To', _query.toDate, (d) {
        setState(() => _query.toDate = d);
      })),
    ]);
  }

  Widget _dateField(
      AppColors c, String label, DateTime? value, ValueChanged<DateTime> onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(c, label),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 2),
            );
            if (picked != null) onPick(picked);
          },
          borderRadius: BorderRadius.circular(Radii.md),
          child: _shell(
            c,
            SizedBox(
              height: 44,
              child: Row(children: [
                Icon(Icons.event, size: 15, color: c.textMuted),
                const SizedBox(width: 8),
                Text(
                  value == null
                      ? 'Any'
                      : value.toIso8601String().substring(0, 10),
                  style: TextStyle(
                      color: value == null ? c.textMuted : c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _textField(AppColors c, String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(c, label),
        _shell(
          c,
          TextField(
            controller: ctrl,
            style: TextStyle(color: c.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: 'Any',
              hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ─── State cards ───────────────────────────────────────────────────────
  Widget _errorCard(AppColors c) => Container(
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.border),
        ),
        child: Text("Couldn't load: $_error",
            style: TextStyle(color: c.danger, fontWeight: FontWeight.w600)),
      );

  Widget _promptCard(AppColors c, String msg) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: c.isDark ? Border.all(color: c.border) : null,
          boxShadow: Shadows.card(c),
        ),
        child: Column(children: [
          Icon(Icons.tune, size: 36, color: c.textMuted),
          const SizedBox(height: 10),
          Text(msg,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.4)),
        ]),
      );

  Widget _emptyCard(AppColors c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: c.isDark ? Border.all(color: c.border) : null,
              boxShadow: Shadows.card(c),
            ),
            child: Column(children: [
              Icon(Icons.inbox_outlined, size: 40, color: c.textMuted),
              const SizedBox(height: 10),
              Text('No records found',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Adjust the filters above and tap Apply.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: c.textSecondary, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() => _showRaw = !_showRaw),
            child: Text(_showRaw ? 'Hide raw response' : 'Show raw response',
                style: TextStyle(color: c.textMuted, fontSize: 12)),
          ),
          if (_showRaw)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: c.border),
              ),
              child: SelectableText(
                _rawResponse?.toString() ?? 'No response captured',
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace'),
              ),
            ),
        ],
      );

  // ─── Record cards ──────────────────────────────────────────────────────
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
      'actionStatus', 'status',
    ]);
    final s = status.toLowerCase();
    final ok = s.contains('paid') ||
        s.contains('present') ||
        s.contains('approve') ||
        s.contains('active') ||
        s.contains('success') ||
        s.contains('pass') ||
        s.contains('reimbursed');
    final statusColor =
        status.isEmpty ? c.textMuted : (ok ? c.success : c.danger);

    const shown = {
      'name', 'studentName', 'instructorName', 'tcName', 'centerName',
      'description', 'invoiceDescription', 'text', 'title', 'amount',
      'dueAmount', 'paidAmount', 'totalAmount', 'value', 'total', 'date',
      'paymentDate', 'examDate', 'recordedTime', 'createdDate', 'dueDate',
      'paymentStatus', 'examStatus', 'attendanceType', 'transactionType',
      'actionStatus', 'status',
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
              child: Text(title.isEmpty ? 'Record' : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
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

  /// Training-time rows: emphasise day + time window.
  Widget _trainingTimeCard(AppColors c, Map<String, dynamic> row) {
    final day = pickField(row, ['day', 'dayName', 'weekday', 'trainingDay']);
    final from = pickField(row, ['fromTime', 'startTime', 'timeFrom', 'start']);
    final to = pickField(row, ['toTime', 'endTime', 'timeTo', 'end']);
    final label = pickField(row, [
      'name', 'text', 'description', 'tTimeName', 'sessionName',
    ]);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: c.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            (day.isEmpty ? '?' : day.substring(0, day.length.clamp(0, 3)))
                .toUpperCase(),
            style: TextStyle(
                color: c.primary,
                fontSize: 12,
                fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(day.isEmpty ? (label.isEmpty ? 'Session' : label) : day,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              if (from.isNotEmpty || to.isNotEmpty)
                Text(
                  [from, to].where((x) => x.isNotEmpty).join(' – '),
                  style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              if (day.isNotEmpty && label.isNotEmpty)
                Text(label,
                    style: TextStyle(
                        color: c.textMuted, fontSize: 11.5)),
            ],
          ),
        ),
      ]),
    );
  }

  String _humanizeKey(String k) {
    final spaced = k.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    if (spaced.isEmpty) return spaced;
    return spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
  }
}

/// Thin wrapper so the screen does not import Api directly for centres.
class ApiCentres {
  static Future<dynamic> training() => _ApiCentresImpl.training();
  static Future<dynamic> exam() => _ApiCentresImpl.exam();
}
```

- [ ] **Step 2: Add the centre-source implementation**

The screen must not duplicate `Api`. Add this import at the top of the file (with the other imports):

```dart
import '../services/api.dart';
```

Then replace the `ApiCentres` class at the bottom of the file with:

```dart
/// Centre option sources for the filter dropdowns.
class ApiCentres {
  static Future<dynamic> training() => Api.listingTrainingCenters();
  static Future<dynamic> exam() => Api.reportsExamCenters();
}
```

(Delete the `_ApiCentresImpl` reference from Step 1 — it does not exist; the
`ApiCentres` class above is the complete, correct version.)

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output. (Will fail until Task 3 updates the router — the old `InstructorReportListScreen(title:, fetcher:)` constructor calls no longer match. That is expected; proceed to Task 3, then re-run.)

- [ ] **Step 4: Commit**

```bash
git add lib/screens/instructor_report_list_screen.dart
git commit -m "Rewrite instructor report screen with per-report filter bar"
```

---

## Task 3: Wire the router to ReportSpec + add Contribution route

**Files:**
- Modify: `lib/router/app_router.dart`

- [ ] **Step 1: Add the import**

With the other imports at the top of `app_router.dart`:

```dart
import '../screens/instructor_reports/report_spec.dart';
```

- [ ] **Step 2: Replace the `_reportRoute` helper**

The current helper is:

```dart
GoRoute _reportRoute(String path, String title, ReportFetcher fetcher) =>
    GoRoute(
      path: path,
      pageBuilder: (_, state) => _fadeThrough(
        state.pageKey,
        InstructorReportListScreen(title: title, fetcher: fetcher),
      ),
    );
```

Replace it with a slug-based version. The slug is the last path segment;
if `kReportSpecs` has it, use that spec; otherwise build a no-filter spec
from the bare fetcher:

```dart
GoRoute _reportRoute(String path, String title, ReportFetcher fetcher) {
  final slug = path.split('/').last;
  final spec = kReportSpecs[slug] ??
      ReportSpec(title: title, fetch: (_) => fetcher());
  return GoRoute(
    path: path,
    pageBuilder: (_, state) => _fadeThrough(
      state.pageKey,
      InstructorReportListScreen(spec: spec),
    ),
  );
}
```

`ReportFetcher` is the existing `typedef Future<dynamic> Function()`. If it
is currently defined in `instructor_report_list_screen.dart` and no longer
exported after the rewrite, add this typedef near the top of
`app_router.dart` instead:

```dart
typedef ReportFetcher = Future<dynamic> Function();
```

(Check: after Task 2 the screen file no longer declares `ReportFetcher`.
So add the typedef to `app_router.dart`.)

- [ ] **Step 3: Add the Contribution route**

Immediately after the `reimbursement` `_reportRoute(...)` line, add:

```dart
    _reportRoute('/instructor/reports/contribution', 'Contribution',
        Api.reportsContribution),
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 5: Commit**

```bash
git add lib/router/app_router.dart
git commit -m "Route instructor reports through ReportSpec; add Contribution"
```

---

## Task 4: Add the Contribution tile to the Reports menu

**Files:**
- Modify: `lib/screens/instructor_reports_screen.dart`

- [ ] **Step 1: Add the tile**

In the `_items` list, after the `'Purchase Request'` entry, add:

```dart
    _ReportItem(Icons.volunteer_activism,   'Contribution',       '/instructor/reports/contribution'),
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze --no-pub 2>&1 | grep -E " error " | grep -v widget_test`
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/instructor_reports_screen.dart
git commit -m "Add Contribution tile to instructor Reports menu"
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

```bash
git add -A
git commit -m "Fix issues found in report-filters build verification"
```

---

## Self-Review

- **Spec coverage:** Student List — training-center + status(Active/Inactive) + name + IC (server name/IC, client status). Training Time — training-center dropdown, dedicated time-table card, special "pick a center" prompt, fixed to `listingTrainingTimeByTcId`. Grading Schedule + Grading Past — exam-center + date range. Receipt — training-center + date range + payment-mode. Attendance — date range, fetches on Apply. Purchase Request + Payment Slip — training-center + action-status dropdown (Pending/Approved/Rejected). Reimbursement — date range + Reimbursed/Not Reimbursed. Contribution — new route + tile + date range. All ten covered.
- **Placeholders:** none. Task 2 Step 1 intentionally includes a stub `ApiCentres` that Step 2 replaces with the real one — Step 2 explicitly says to delete the `_ApiCentresImpl` reference and use the complete class. Flagged inline.
- **Type consistency:** `ReportSpec`, `ReportQuery`, `RFilter`, `reportBody`, `kReportSpecs` defined in Task 1, consumed in Tasks 2–3. `InstructorReportListScreen` constructor changes from `(title, fetcher)` to `(spec)` in Task 2; the only call site (`_reportRoute`) updates in Task 3. `ReportFetcher` typedef relocated to `app_router.dart` in Task 3 Step 2.
