import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/app_header.dart';
import '../widgets/list_search.dart';

/// Polished, dedicated screen for unpaid invoices.
///
/// Renders each invoice as its own card straight from
/// `session.outstandingList`, so the data is visible even if the
/// aggregate count/sum getters miss a field. Hits `/Outstanding/Fetch`
/// directly on init for an immediate live refresh.
class OutstandingInvoicesScreen extends StatefulWidget {
  const OutstandingInvoicesScreen({super.key});

  @override
  State<OutstandingInvoicesScreen> createState() => _OutstandingInvoicesScreenState();
}

class _OutstandingInvoicesScreenState extends State<OutstandingInvoicesScreen> {
  bool _refreshing = false;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _centerFilter;
  String? _txTypeFilter;
  String? _periodFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Apply free-text + filter chips to the invoice list.
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> rows) {
    final q = _query.trim().toLowerCase();
    return rows.where((r) {
      if (q.isNotEmpty) {
        const searchKeys = [
          'studentName', 'icNo', 'invoiceId', 'invoiceDescription',
          'period', 'grade', 'centerName',
        ];
        final hit = searchKeys.any(
            (k) => r[k] != null && r[k].toString().toLowerCase().contains(q));
        if (!hit) return false;
      }
      if (_centerFilter != null &&
          _centerFilter!.isNotEmpty &&
          r['centerName']?.toString() != _centerFilter) return false;
      if (_txTypeFilter != null &&
          _txTypeFilter!.isNotEmpty &&
          r['transactionType']?.toString() != _txTypeFilter) return false;
      if (_periodFilter != null &&
          _periodFilter!.isNotEmpty &&
          r['period']?.toString() != _periodFilter) return false;
      return true;
    }).toList();
  }

  List<String> _uniq(List<Map<String, dynamic>> rows, String key) {
    final s = <String>{};
    for (final r in rows) {
      final v = r[key]?.toString().trim();
      if (v != null && v.isNotEmpty) s.add(v);
    }
    final list = s.toList()..sort();
    return list;
  }

  @override
  void initState() {
    super.initState();
    // Re-pull on entry so the data is always fresh.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      // Try a few candidate bodies so any expected filter shape works.
      for (final body in const [
        <String, dynamic>{},
        {'sCenterId': 0, 'tCenterId': 0, 'eCenterId': 0, 'tTimeId': 0},
        {'reportType': 0, 'sourceKeyId': 0},
      ]) {
        try {
          final resp = await Api.outstandingFetch(body);
          UserSession.instance.outstandingRaw = resp;
          final list = UserSession.findList(resp);
          if (list != null) {
            UserSession.instance.outstandingList = list;
            if (list.isNotEmpty) break;
          }
        } catch (e) {
          UserSession.instance.outstandingError = e.toString();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
        UserSession.instance.touch();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final raw = session.outstandingForCurrentStudent;
    final invoices = raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    final visible = _applyFilters(invoices);
    final total = _sum(visible);
    final count = visible.length;
    final centers = _uniq(invoices, 'centerName');
    final txTypes = _uniq(invoices, 'transactionType');
    final periods = _uniq(invoices, 'period');

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const AppHeader(
            title: 'My Invoices',
            showBack: true,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: c.primary,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.lg, 120),
                children: [
                  _heroCard(c, total, count),
                  if (invoices.length > 3) ...[
                    const SizedBox(height: 14),
                    ListSearchBar(
                      hint: 'Search by student, IC, period, invoice ID…',
                      controller: _searchCtrl,
                      onSearch: (v) => setState(() => _query = v),
                      resultCount: visible.length,
                      totalCount: invoices.length,
                      filters: [
                        if (centers.isNotEmpty)
                          ListFilter(
                            label: 'Center',
                            options: centers,
                            selected: _centerFilter,
                            onSelected: (v) =>
                                setState(() => _centerFilter = v),
                          ),
                        if (txTypes.isNotEmpty)
                          ListFilter(
                            label: 'Type',
                            options: txTypes,
                            selected: _txTypeFilter,
                            onSelected: (v) =>
                                setState(() => _txTypeFilter = v),
                          ),
                        if (periods.isNotEmpty)
                          ListFilter(
                            label: 'Period',
                            options: periods,
                            selected: _periodFilter,
                            onSelected: (v) =>
                                setState(() => _periodFilter = v),
                          ),
                      ],
                      onClearAll: () => setState(() {
                        _query = '';
                        _centerFilter = null;
                        _txTypeFilter = null;
                        _periodFilter = null;
                      }),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_refreshing)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator(color: c.primary)),
                    )
                  else if (invoices.isEmpty)
                    _emptyState(c, session)
                  else if (visible.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        'No invoices match your filters. Tap Reset.',
                        style: TextStyle(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    ..._invoiceCards(c, visible),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _heroCard(AppColors c, num total, int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: c.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Radii.xxl),
        boxShadow: Shadows.strong(c),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.receipt_long, color: Color(0xFFFFF7ED), size: 18),
          SizedBox(width: 6),
          Text('OUTSTANDING TOTAL',
              style: TextStyle(
                  color: Color(0xFFFFF7ED),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 10),
        AnimatedCount(
          total,
          prefix: 'RM ',
          decimals: 2,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1),
        ),
        const SizedBox(height: 4),
        Text(
          count == 0 ? 'No unpaid invoices' : '$count unpaid invoice${count == 1 ? "" : "s"}',
          style: const TextStyle(
              color: Color(0xCCFFFFFF), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        Row(children: [
          if (count > 0)
            Expanded(
              child: InkWell(
                onTap: () => context.go('/payments'),
                borderRadius: BorderRadius.circular(Radii.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.lock, size: 14, color: c.primary),
                    const SizedBox(width: 6),
                    Text('Pay Now',
                        style: TextStyle(
                            color: c.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                  ]),
                ),
              ),
            ),
          if (count > 0) const SizedBox(width: 10),
          InkWell(
            onTap: _refresh,
            borderRadius: BorderRadius.circular(Radii.md),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 18),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _emptyState(AppColors c, UserSession session) {
    final hasError = session.outstandingError != null;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: c.border),
      ),
      child: Column(children: [
        Icon(
          hasError ? Icons.cloud_off_outlined : Icons.check_circle_outline,
          size: 56,
          color: hasError ? c.danger : c.success,
        ),
        const SizedBox(height: 14),
        Text(
          hasError ? 'Could not load invoices' : 'All clear!',
          style: TextStyle(
              color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          hasError
              ? 'Tap "Diagnose" in the top-right to see what the API returned.'
              : 'You have no unpaid invoices.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh now'),
          onPressed: _refresh,
        ),
      ]),
    );
  }

  List<Widget> _invoiceCards(AppColors c, List<Map<String, dynamic>> invoices) {
    return invoices
        .asMap()
        .entries
        .map((e) => FadeSlideIn.at(
              e.key.clamp(0, 8),
              offsetY: 16,
              child: _invoiceCard(c, e.key, e.value),
            ))
        .toList();
  }

  Widget _invoiceCard(AppColors c, int index, Map<String, dynamic> inv) {
    final title = _pick(inv,
        ['invoiceDescription', 'invoiceName', 'description', 'particulars', 'name', 'invoiceTitle', 'item', 'feeType']);
    final studentName = _pick(inv, ['studentName', 'name', 'memberName']);
    final period = _pick(inv, ['period', 'invoicePeriod', 'month']);
    final invoiceNo = _pick(inv, ['invoiceNo', 'invoiceNumber', 'invNo', 'docNo', 'refNo', 'invoiceId', 'id']);
    final dueDate = _pick(inv,
        ['dueDate', 'invoiceDate', 'date', 'paymentDue', 'expiryDate', 'due_date']);
    final amount = _readAmount(inv);
    final overdue = _isOverdue(dueDate);
    final initials = _initialFromTitle(title);
    return InkWell(
      onTap: () => _showInvoiceDetail(c, inv, index),
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
        boxShadow: Shadows.card(c),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: overdue
                    ? [c.danger.withOpacity(0.18), c.danger.withOpacity(0.28)]
                    : [c.primary.withOpacity(0.14), c.primary.withOpacity(0.24)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: overdue ? c.danger : c.primary,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    title.isEmpty ? 'Invoice #${index + 1}' : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (overdue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('OVERDUE',
                        style: TextStyle(
                            color: c.danger,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6)),
                  ),
              ]),
              if (studentName.isNotEmpty || period.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  [studentName, period].where((s) => s.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 4),
              Wrap(
                spacing: 12, runSpacing: 4,
                children: [
                  if (invoiceNo.isNotEmpty)
                    _miniMeta(c, Icons.tag, invoiceNo),
                  if (dueDate.isNotEmpty)
                    _miniMeta(c, Icons.event, dueDate),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text(
                  'RM ${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: overdue ? c.danger : c.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text('View details',
                    style: TextStyle(
                        color: c.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
                Icon(Icons.chevron_right, size: 16, color: c.textMuted),
              ]),
            ]),
          ),
        ]),
      ),
      ),
    );
  }

  /// Bottom-sheet detail view for one invoice — shows every meaningful
  /// field from the live /Outstanding/Fetch row.
  void _showInvoiceDetail(AppColors c, Map<String, dynamic> inv, int index) {
    final title = _pick(inv,
        ['invoiceName', 'description', 'particulars', 'name', 'invoiceTitle', 'item', 'feeType']);
    final invoiceNo = _pick(inv,
        ['invoiceNo', 'invoiceNumber', 'invNo', 'docNo', 'refNo', 'id']);
    final dueDate = _pick(inv,
        ['dueDate', 'invoiceDate', 'date', 'paymentDue', 'expiryDate', 'due_date']);
    final student = _pick(inv, ['studentName', 'name', 'memberName']);
    final amount = _readAmount(inv);
    final overdue = _isOverdue(dueDate);

    // Any remaining non-empty fields not already shown above.
    const shown = {
      'invoiceName', 'description', 'particulars', 'name', 'invoiceTitle',
      'item', 'feeType', 'invoiceNo', 'invoiceNumber', 'invNo', 'docNo',
      'refNo', 'id', 'dueDate', 'invoiceDate', 'date', 'paymentDue',
      'expiryDate', 'due_date', 'studentName', 'memberName',
    };
    final extras = <MapEntry<String, String>>[];
    inv.forEach((k, v) {
      if (shown.contains(k)) return;
      final s = (v ?? '').toString().trim();
      if (s.isEmpty || s == 'null' || s == '0' || s == '0.0') return;
      extras.add(MapEntry(_humanizeKey(k), s));
    });

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 120,
              child: Text(label,
                  style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
        ),
        padding: EdgeInsets.fromLTRB(
            22, 14, 22, 28 + MediaQuery.of(ctx).padding.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(title.isEmpty ? 'Invoice #${index + 1}' : title,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Row(children: [
                Text('RM ${amount.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: overdue ? c.danger : c.primary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900)),
                const SizedBox(width: 10),
                if (overdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('OVERDUE',
                        style: TextStyle(
                            color: c.danger,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
              ]),
              const SizedBox(height: 14),
              Divider(color: c.border, height: 1),
              const SizedBox(height: 6),
              if (invoiceNo.isNotEmpty) row('Invoice No.', invoiceNo),
              if (dueDate.isNotEmpty) row('Due date', dueDate),
              if (student.isNotEmpty) row('Student', student),
              ...extras.map((e) => row(e.key, e.value)),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  ctx.go('/payments');
                },
                borderRadius: BorderRadius.circular(Radii.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: c.gradient),
                    borderRadius: BorderRadius.circular(Radii.md),
                    boxShadow: Shadows.strong(c),
                  ),
                  child: const Text('Pay this invoice',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "studentName" → "Student name", "amountDue" → "Amount due".
  String _humanizeKey(String k) {
    final spaced = k.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    if (spaced.isEmpty) return spaced;
    return spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
  }

  Widget _miniMeta(AppColors c, IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: c.textMuted),
      const SizedBox(width: 4),
      Text(text,
          style: TextStyle(
              color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }

  // ---- helpers ----

  static String _pick(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '';
  }

  static String _initialFromTitle(String t) {
    if (t.isEmpty) return '#';
    final parts = t.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  static bool _isOverdue(String s) {
    if (s.isEmpty) return false;
    try {
      final d = DateTime.parse(s);
      return d.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  static num _readAmount(Map row) {
    const exactKeys = [
      'dueAmount', 'dueAmt', 'amount', 'amountDue', 'outstandingAmount',
      'outstandingAmt', 'balance', 'totalAmount', 'totalDue', 'value',
      'invoiceAmount', 'amtDue'
    ];
    for (final k in exactKeys) {
      final n = _toNum(row[k]);
      if (n != null) return n;
    }
    for (final entry in row.entries) {
      final key = entry.key.toString().toLowerCase();
      if (key.contains('amount') ||
          key.contains('amt') ||
          key.contains('balance') ||
          (key.contains('due') && !key.contains('date'))) {
        final n = _toNum(entry.value);
        if (n != null) return n;
      }
    }
    return 0;
  }

  static num? _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String && v.isNotEmpty) {
      final cleaned = v.replaceAll(RegExp(r'[^\d.\-]'), '');
      if (cleaned.isEmpty) return null;
      return num.tryParse(cleaned);
    }
    return null;
  }

  static num _sum(List<Map<String, dynamic>> rows) {
    num t = 0;
    for (final r in rows) {
      t += _readAmount(r);
    }
    return t;
  }
}
