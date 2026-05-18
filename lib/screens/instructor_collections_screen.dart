import 'package:flutter/material.dart';

import '../services/api.dart';
import '../theme/app_theme.dart';
import '../widgets/anim.dart';
import '../widgets/app_header.dart';

class InstructorCollectionsScreen extends StatefulWidget {
  const InstructorCollectionsScreen({super.key});

  @override
  State<InstructorCollectionsScreen> createState() =>
      _InstructorCollectionsScreenState();
}

class _InstructorCollectionsScreenState
    extends State<InstructorCollectionsScreen> {
  Map<String, dynamic>? _counts;
  bool _loading = true;
  String? _error;

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
      final resp = await Api.outstandingCollectionCount();
      final data = resp is Map && resp['data'] is Map
          ? Map<String, dynamic>.from(resp['data'] as Map)
          : (resp is Map ? Map<String, dynamic>.from(resp) : <String, dynamic>{});
      setState(() => _counts = data);
    } catch (e) {
      debugPrint('CollectionCount failed: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _readCount(List<String> keys) {
    final m = _counts;
    if (m == null) return 0;
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v.toInt();
      if (v is String) {
        final n = int.tryParse(v);
        if (n != null) return n;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // Real API returns {cash, fpx, dbt}:
    //   cash → Cash Payments, fpx → Online (FPX), dbt → Payment Slips
    final cash = _readCount(['cash', 'cashCount', 'cashPayments']);
    final online =
        _readCount(['fpx', 'online', 'onlineCount', 'onlinePayments']);
    final slip =
        _readCount(['dbt', 'paymentSlip', 'paymentSlipCount', 'slipCount']);
    final narrow = MediaQuery.of(context).size.width < 360;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: c.primary,
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.lg, 100),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gaps.md),
                      child: Text('Couldn\'t load counts: $_error',
                          style: TextStyle(
                              color: c.danger, fontWeight: FontWeight.w600)),
                    ),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: narrow ? 1.0 : 1.2,
                    children: [
                      _tile(
                          c,
                          Icons.payments_outlined,
                          'Cash Payments',
                          _loading ? null : cash,
                          () => _openList(context, 1, 'Cash Payments'),
                          0),
                      _tile(
                          c,
                          Icons.credit_card,
                          'Online Payments',
                          _loading ? null : online,
                          () => _openList(context, 2, 'Online Payments'),
                          1),
                      _tile(
                          c,
                          Icons.receipt_long,
                          'Payment Slips',
                          _loading ? null : slip,
                          () => _openPaymentSlips(context),
                          2),
                      _tile(
                          c,
                          Icons.tune,
                          'Update Collection',
                          null,
                          () => _openUpdateSheet(context),
                          3),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

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

  Future<void> _openList(BuildContext context, int typeId, String title) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SimpleListScreen(
          title: title,
          fetcher: () => Api.outstandingCollectionCountList(typeId),
        ),
      ),
    );
  }

  Future<void> _openPaymentSlips(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SimpleListScreen(
          title: 'Payment Slips',
          fetcher: () => Api.reportsPaymentSlips(),
        ),
      ),
    );
  }

  Future<void> _openUpdateSheet(BuildContext context) async {
    final c = context.appColors;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final types = const [
          {'id': 1, 'label': 'Cash Payments'},
          {'id': 2, 'label': 'Online Payments'},
          {'id': 3, 'label': 'Payment Slips'},
        ];
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Text('Update Collection',
                style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 12),
            for (final t in types)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(
                    child: Text(t['label'].toString(),
                        style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+1'),
                    onPressed: () async {
                      try {
                        await Api.outstandingUpdateCollectionCount(t['id']!);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${t['label']} +1')),
                        );
                        await _load();
                      } catch (e) {
                        debugPrint('UpdateCollectionCount failed: $e');
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    },
                  ),
                ]),
              ),
          ]),
        );
      },
    );
  }
}

class _SimpleListScreen extends StatefulWidget {
  final String title;
  final Future<dynamic> Function() fetcher;
  const _SimpleListScreen({required this.title, required this.fetcher});

  @override
  State<_SimpleListScreen> createState() => _SimpleListScreenState();
}

class _SimpleListScreenState extends State<_SimpleListScreen> {
  dynamic _data;
  dynamic _rawResponse;
  bool _loading = true;
  bool _showRaw = false;
  String? _error;

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

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final list = _data is List ? _data as List : const [];
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
                padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.lg, 24),
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: ShimmerList(count: 6, rowHeight: 78),
                    )
                  else if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(Gaps.md),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(_error!,
                          style: TextStyle(
                              color: c.danger, fontWeight: FontWeight.w600)),
                    )
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
                  else
                    ...list.asMap().entries.map((e) => _rowCard(
                        c,
                        e.value is Map ? e.value as Map : {'value': e.value},
                        e.key)),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

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
}

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
