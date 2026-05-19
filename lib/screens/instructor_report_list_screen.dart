import 'package:flutter/material.dart';

import '../services/response_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/app_header.dart';
import '../widgets/list_search.dart';

typedef ReportFetcher = Future<dynamic> Function();

/// Generic list-of-records screen used by every instructor "drill-down"
/// report route. Calls [fetcher] and renders the resulting JSON as cards.
class InstructorReportListScreen extends StatefulWidget {
  final String title;
  final ReportFetcher fetcher;

  const InstructorReportListScreen({
    super.key,
    required this.title,
    required this.fetcher,
  });

  @override
  State<InstructorReportListScreen> createState() =>
      _InstructorReportListScreenState();
}

class _InstructorReportListScreenState
    extends State<InstructorReportListScreen> {
  dynamic _data;
  dynamic _rawResponse;
  bool _loading = true;
  String? _error;

  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _centerFilter;
  String? _statusFilter;
  bool _activeOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Searchable string fields for the free-text query.
  static const _searchKeys = [
    'name', 'studentName', 'icNo', 'text', 'value', 'code',
    'instructorName', 'tcName', 'centerName', 'description',
    'receiptNo', 'invoiceId', 'invoiceDescription',
  ];

  /// Keys that look like a "training/exam center" column.
  static const _centerKeys = [
    'tCenterName', 'tcName', 'centerName', 'eCenterName',
    'sCenterName', 'trainingCenter',
  ];

  /// Keys that look like a status enum column.
  static const _statusKeys = [
    'paymentStatus', 'examStatus', 'attendanceType', 'transactionType',
    'status',
  ];

  /// Collect unique values for the given key set across all rows.
  List<String> _collect(Iterable<Map<String, dynamic>> rows, List<String> keys) {
    final set = <String>{};
    for (final r in rows) {
      for (final k in keys) {
        final v = r[k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isEmpty || s == 'null') continue;
        set.add(s);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Apply free-text query + filter chips to the raw row set.
  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> rows) {
    final q = _query.trim().toLowerCase();
    return rows.where((r) {
      if (q.isNotEmpty) {
        final hit = _searchKeys.any((k) {
          final v = r[k];
          return v != null && v.toString().toLowerCase().contains(q);
        });
        if (!hit) return false;
      }
      if (_centerFilter != null && _centerFilter!.isNotEmpty) {
        final hit = _centerKeys.any((k) =>
            r[k] != null && r[k].toString() == _centerFilter);
        if (!hit) return false;
      }
      if (_statusFilter != null && _statusFilter!.isNotEmpty) {
        final hit = _statusKeys.any((k) =>
            r[k] != null && r[k].toString() == _statusFilter);
        if (!hit) return false;
      }
      if (_activeOnly) {
        // "Active" heuristic: row has isActive=true, or status/value contains
        // "active" / "present" / "approved" / "paid", and NOT "inactive" /
        // "absent" / "pending" / "rejected".
        final hay = [
          for (final k in _statusKeys) r[k]?.toString().toLowerCase() ?? '',
          (r['isActive'] ?? '').toString().toLowerCase(),
        ].join(' ');
        final bad = hay.contains('inactive') ||
            hay.contains('absent') ||
            hay.contains('pending') ||
            hay.contains('rejected') ||
            hay.contains('cancelled');
        if (bad) return false;
        final good = hay.contains('active') ||
            hay.contains('present') ||
            hay.contains('approved') ||
            hay.contains('paid') ||
            (r['isActive'] == true);
        if (!good) return false;
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  List<Map<String, dynamic>> _rows() {
    final d = _data;
    if (d is! List) return const [];
    return d
        .map((e) => e is Map
            ? Map<String, dynamic>.from(e)
            : <String, dynamic>{'value': e})
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final allRows = _rows();
    final centerOptions = _collect(allRows, _centerKeys);
    final statusOptions = _collect(allRows, _statusKeys);
    final visible = _applyFilters(allRows);
    final hasFilterableData =
        allRows.length > 4 || centerOptions.isNotEmpty || statusOptions.isNotEmpty;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          AppHeader(title: widget.title, showBack: true),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: c.primary,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.lg, 24),
                children: [
                  if (allRows.isNotEmpty && _error == null) _liveBanner(c),
                  if (hasFilterableData && !_loading && _error == null) ...[
                    const SizedBox(height: Gaps.sm),
                    ListSearchBar(
                      hint: 'Search ${widget.title.toLowerCase()}…',
                      controller: _searchCtrl,
                      onSearch: (v) => setState(() => _query = v),
                      resultCount: visible.length,
                      totalCount: allRows.length,
                      filters: [
                        if (centerOptions.isNotEmpty)
                          ListFilter(
                            label: 'Center',
                            options: centerOptions,
                            selected: _centerFilter,
                            onSelected: (v) =>
                                setState(() => _centerFilter = v),
                          ),
                        if (statusOptions.isNotEmpty)
                          ListFilter(
                            label: 'Status',
                            options: statusOptions,
                            selected: _statusFilter,
                            onSelected: (v) =>
                                setState(() => _statusFilter = v),
                          ),
                        if (statusOptions.isNotEmpty ||
                            allRows.any((r) => r.containsKey('isActive')))
                          ListFilter.toggle(
                            label: 'Active only',
                            value: _activeOnly,
                            onChanged: (v) =>
                                setState(() => _activeOnly = v),
                          ),
                      ],
                      onClearAll: () => setState(() {
                        _query = '';
                        _centerFilter = null;
                        _statusFilter = null;
                        _activeOnly = false;
                      }),
                    ),
                  ],
                  const SizedBox(height: Gaps.sm),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: ShimmerList(count: 7, rowHeight: 72),
                    )
                  else if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(Gaps.md),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        'Couldn\'t load: $_error',
                        style: TextStyle(
                            color: c.danger, fontWeight: FontWeight.w600),
                      ),
                    )
                  else if (visible.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(Gaps.md),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        allRows.isEmpty
                            ? 'No records.'
                            : 'No matches. Adjust filters or clear search.',
                        style: TextStyle(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    for (final entry in visible.asMap().entries)
                      FadeSlideIn.at(
                        entry.key.clamp(0, 8),
                        offsetY: 14,
                        child: _rowCard(c, entry.value),
                      ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _liveBanner(AppColors c) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: Gaps.sm),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Icon(Icons.cloud_done_outlined, size: 16, color: c.primary),
          const SizedBox(width: 8),
          Text('LIVE',
              style: TextStyle(
                  color: c.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Showing latest data',
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _rowCard(AppColors c, Map<String, dynamic> row) {
    final entries = row.entries.take(4).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(Gaps.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
        boxShadow: Shadows.card(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      e.key.toString(),
                      style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value?.toString() ?? '',
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
