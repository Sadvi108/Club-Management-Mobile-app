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
  bool _showRaw = false;
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
}
