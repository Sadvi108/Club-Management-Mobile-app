import 'package:flutter/material.dart';

import '../services/api.dart';
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
        // Reports/{Exam,Student}Centers return lowercase `centername`;
        // Listing endpoints return `text`; Reports/TrainingCenters `name`.
        final label = pickField(r, [
          'name', 'centerName', 'centername', 'tCenterName', 'eCenterName',
          'sCenterName', 'text',
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
    // Exact match — rowStatus getters return normalized values
    // ('Active'/'Inactive', 'Pending'/'Approved'/'Rejected', etc).
    // A substring test would wrongly match 'Active' against 'inactive'.
    final want = status.toLowerCase();
    return rows.where((r) {
      return _spec.rowStatus!(r).toLowerCase() == want;
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
                            : (_spec.onRowTap != null
                                ? InkWell(
                                    onTap: () => _spec.onRowTap!(
                                        context, entry.value),
                                    borderRadius:
                                        BorderRadius.circular(Radii.lg),
                                    child: _rowCard(c, entry.value),
                                  )
                                : _rowCard(c, entry.value)),
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
  // Candidate keys for each rendered slot. The server is inconsistent across
  // reports (camelCase here, lowercase there: `centerName` vs `centername`,
  // `receiptAmount`, `ecName`, `invoiceDate`…), so each list is broad and the
  // matching set below keeps these keys out of the "extras" block.
  static const _titleKeys = [
    'name', 'studentName', 'instructorName', 'tcName', 'centerName',
    'centername', 'ecName', 'eCenterName', 'tCenterName', 'sCenterName',
    'tournamentName', 'category', 'event', 'ageGroup',
    'description', 'invoiceDescription', 'text', 'title',
  ];
  static const _amountKeys = [
    'amount', 'dueAmount', 'paidAmount', 'totalAmount', 'receiptAmount',
    'invoiceAmount', 'feeAmount', 'value', 'total',
  ];
  static const _dateKeys = [
    'date', 'paymentDate', 'examDate', 'receiptDate', 'invoiceDate',
    'closingDate', 'gradingDate', 'recordedTime', 'createdDate', 'dueDate',
  ];
  static const _statusKeys = [
    'paymentStatus', 'examStatus', 'attendanceType', 'transactionType',
    'actionStatus', 'status',
  ];

  Widget _rowCard(AppColors c, Map<String, dynamic> row) {
    var title = pickField(row, _titleKeys);
    // Some reports have no name field (e.g. Tournament Summary rows are keyed
    // by gender/category). Fall back to a categorical label so the card isn't
    // a bare "Record"; remember the key so it isn't also shown as an "extra".
    String? fallbackTitleKey;
    if (title.isEmpty) {
      for (final k in const ['gender', 'category', 'ageGroup', 'event', 'grade']) {
        final v = (row[k] ?? '').toString().trim();
        if (v.isNotEmpty && v != 'null') {
          title = v;
          fallbackTitleKey = k;
          break;
        }
      }
    }
    final amount = pickAmount(row, _amountKeys);
    final dateRaw = pickField(row, _dateKeys);
    final date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
    final status = pickField(row, _statusKeys);
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

    final shown = {
      ..._titleKeys, ..._amountKeys, ..._dateKeys, ..._statusKeys,
    };
    final extras = <MapEntry<String, String>>[];
    for (final e in row.entries) {
      if (shown.contains(e.key) || e.key == fallbackTitleKey) continue;
      if (_isNoiseKey(e.key)) continue; // internal ids — not user-facing
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

  /// Internal identifiers that shouldn't be surfaced as a card "extra"
  /// (e.g. `id`, `resultId`, `studentId`, `tCenterId`, `sno`).
  static bool _isNoiseKey(String k) {
    final l = k.toLowerCase();
    if (l == 'sno' || l == 'srno' || l == 'slno' || l == 'rowid') return true;
    return l.endsWith('id'); // id, resultId, studentId, invoiceId, shortid…
  }

  String _humanizeKey(String k) {
    final spaced = k.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    if (spaced.isEmpty) return spaced;
    return spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
  }
}

/// Centre option sources for the filter dropdowns.
class ApiCentres {
  static Future<dynamic> training() => Api.listingTrainingCenters();
  static Future<dynamic> exam() => Api.reportsExamCenters();
}
