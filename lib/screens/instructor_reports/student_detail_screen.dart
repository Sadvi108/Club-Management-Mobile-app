import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../services/response_utils.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anim.dart';
import '../../widgets/app_header.dart';

/// Per-student detail for instructors. The `student` map comes from the
/// Student List report row — at minimum it carries `studentId`, `name`,
/// `registrationNo`, plus optional pre-aggregated stats. This screen
/// pulls live outstanding invoices and recent receipts for that student
/// by filtering `/Outstanding/Fetch` and `/Reports/Receipts` on
/// `studentId` / `icNo` / `name`.
class InstructorStudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;
  const InstructorStudentDetailScreen({super.key, required this.student});

  @override
  State<InstructorStudentDetailScreen> createState() =>
      _InstructorStudentDetailScreenState();
}

class _InstructorStudentDetailScreenState
    extends State<InstructorStudentDetailScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _outstanding = const [];
  List<Map<String, dynamic>> _receipts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _name => (widget.student['name'] ?? '').toString();
  String get _regNo => (widget.student['registrationNo'] ?? '').toString();
  String get _studentIdStr =>
      (widget.student['studentId'] ?? widget.student['id'] ?? '')
          .toString()
          .trim();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        Api.outstandingFetch(),
        Api.reportsReceipts(const <String, dynamic>{}),
      ]);
      final os = findRecordList(results[0])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .where(_matches)
          .toList();
      final rc = findRecordList(results[1])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .where(_matchesReceipt)
          .toList();
      if (!mounted) return;
      setState(() {
        _outstanding = os;
        _receipts = rc;
      });
    } catch (e) {
      debugPrint('student detail load failed: $e');
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matches(Map<String, dynamic> r) {
    final sid = _studentIdStr;
    if (sid.isNotEmpty &&
        (r['studentId'] ?? '').toString().trim() == sid) {
      return true;
    }
    final nm = _name.toLowerCase();
    if (nm.isNotEmpty &&
        (r['studentName'] ?? r['name'] ?? '')
            .toString()
            .toLowerCase() ==
            nm) {
      return true;
    }
    return false;
  }

  bool _matchesReceipt(Map<String, dynamic> r) {
    // Receipts rows use `name` + `icNo`. We don't have icNo here, so match
    // on name (case-insensitive). regNo is a separate concept.
    final nm = _name.toLowerCase();
    if (nm.isEmpty) return false;
    return (r['name'] ?? '').toString().toLowerCase() == nm;
  }

  num _totalDue() {
    num t = 0;
    for (final r in _outstanding) {
      final v = r['dueAmount'];
      if (v is num) t += v;
      if (v is String) {
        t += num.tryParse(v.replaceAll(RegExp(r'[^\d.\-]'), '')) ?? 0;
      }
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          AppHeader(title: 'Student', showBack: true),
          Expanded(
            child: RefreshIndicator(
              color: c.primary,
              onRefresh: _load,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.lg, 28),
                children: [
                  _heroCard(c),
                  const SizedBox(height: 14),
                  _statsRow(c),
                  const SizedBox(height: 22),
                  _sectionHeader(c, 'Outstanding invoices',
                      _outstanding.length.toString()),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: ShimmerList(count: 3, rowHeight: 72),
                    )
                  else if (_outstanding.isEmpty)
                    _emptyTile(c, 'No outstanding invoices for this student.')
                  else
                    for (final entry in _outstanding.asMap().entries)
                      FadeSlideIn.at(entry.key.clamp(0, 8),
                          child: _invoiceCard(c, entry.value)),
                  const SizedBox(height: 22),
                  _sectionHeader(
                      c, 'Recent receipts', _receipts.length.toString()),
                  const SizedBox(height: 8),
                  if (_loading)
                    const SizedBox.shrink()
                  else if (_receipts.isEmpty)
                    _emptyTile(c, 'No receipts on file for this student.')
                  else
                    for (final entry in _receipts.take(15).toList().asMap().entries)
                      FadeSlideIn.at(entry.key.clamp(0, 8),
                          child: _receiptCard(c, entry.value)),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text("Couldn't load: $_error",
                        style: TextStyle(
                            color: c.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _heroCard(AppColors c) {
    final grade = (widget.student['grade'] ?? '').toString();
    final tcenter = (widget.student['trainingCenter'] ?? '').toString();
    final attendance =
        (widget.student['attendanceCount'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: c.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(Radii.xl),
        boxShadow: Shadows.strong(c),
      ),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: const BoxDecoration(
              color: Color(0x33FFFFFF), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            _name.isNotEmpty ? _name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_name.isEmpty ? 'Student' : _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              if (_regNo.isNotEmpty)
                Text(_regNo,
                    style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              if (tcenter.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    const Icon(Icons.fitness_center,
                        size: 12, color: Color(0xCCFFFFFF)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(tcenter,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xCCFFFFFF), fontSize: 11)),
                    ),
                  ]),
                ),
              if (grade.isNotEmpty || attendance.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    if (grade.isNotEmpty) ...[
                      const Icon(Icons.workspace_premium,
                          size: 12, color: Color(0xCCFFFFFF)),
                      const SizedBox(width: 4),
                      Text(grade,
                          style: const TextStyle(
                              color: Color(0xCCFFFFFF), fontSize: 11)),
                      const SizedBox(width: 10),
                    ],
                    if (attendance.isNotEmpty &&
                        attendance != '0' &&
                        attendance != 'null') ...[
                      const Icon(Icons.check_circle,
                          size: 12, color: Color(0xCCFFFFFF)),
                      const SizedBox(width: 4),
                      Text('$attendance classes',
                          style: const TextStyle(
                              color: Color(0xCCFFFFFF), fontSize: 11)),
                    ],
                  ]),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _statsRow(AppColors c) {
    final due = _totalDue();
    final inv = _outstanding.length;
    final rec = _receipts.length;
    Widget tile(IconData icon, String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: c.isDark ? Border.all(color: c.border) : null,
              boxShadow: Shadows.card(c),
            ),
            child: Column(children: [
              Icon(icon, color: c.primary, size: 18),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        );
    return Row(children: [
      tile(Icons.credit_card, 'RM ${due.toStringAsFixed(2)}', 'Total due'),
      const SizedBox(width: 10),
      tile(Icons.receipt_long_outlined, '$inv', 'Invoices'),
      const SizedBox(width: 10),
      tile(Icons.payments_outlined, '$rec', 'Receipts'),
    ]);
  }

  Widget _sectionHeader(AppColors c, String title, String badge) {
    return Row(children: [
      Text(title,
          style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: c.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(badge,
            style: TextStyle(
                color: c.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900)),
      ),
    ]);
  }

  Widget _emptyTile(AppColors c, String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Row(children: [
        Icon(Icons.inbox_outlined, size: 20, color: c.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _invoiceCard(AppColors c, Map<String, dynamic> r) {
    final desc = pickField(r, [
      'invoiceDescription', 'description', 'particulars', 'invoiceName',
    ]);
    final amt = pickAmount(r, ['dueAmount', 'amount', 'invoiceAmount']);
    final status = pickField(r, ['paymentStatus', 'status']);
    final ok = status.toLowerCase().contains('paid');
    final statusColor =
        status.isEmpty ? c.textMuted : (ok ? c.success : c.danger);
    final due = pickField(r, ['dueDate', 'invoiceDate']);
    final dueShort = due.length >= 10 ? due.substring(0, 10) : due;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(desc.isEmpty ? 'Invoice' : desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800)),
          ),
          Text('RM ${amt.toStringAsFixed(2)}',
              style: TextStyle(
                  color: c.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          if (dueShort.isNotEmpty) ...[
            Icon(Icons.event, size: 12, color: c.textMuted),
            const SizedBox(width: 4),
            Text(dueShort,
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ],
          const Spacer(),
          if (status.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(status,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
        ]),
      ]),
    );
  }

  Widget _receiptCard(AppColors c, Map<String, dynamic> r) {
    final no = pickField(r, ['receiptNo', 'docNo', 'refNo']);
    final amt = pickAmount(r, ['receiptAmount', 'amount', 'paidAmount']);
    final date = pickField(r, ['receiptDate', 'paymentDate', 'date']);
    final dateShort = date.length >= 10 ? date.substring(0, 10) : date;
    final method = pickField(r, ['paymentMethod', 'mode']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Receipt ${no.isEmpty ? '' : '#$no'}',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800)),
          ),
          Text('RM ${amt.toStringAsFixed(2)}',
              style: TextStyle(
                  color: c.success,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
        ]),
        if (dateShort.isNotEmpty || method.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            if (dateShort.isNotEmpty) ...[
              Icon(Icons.event, size: 12, color: c.textMuted),
              const SizedBox(width: 4),
              Text(dateShort,
                  style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600)),
            ],
            const Spacer(),
            if (method.isNotEmpty)
              Flexible(
                child: Text(method,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
        ],
      ]),
    );
  }
}
