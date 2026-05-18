import 'package:flutter/material.dart';

import '../services/api.dart';
import '../theme/app_theme.dart';
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
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const AppHeader(title: 'Collections'),
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
                    childAspectRatio: 1.25,
                    children: [
                      _tile(
                          c,
                          Icons.payments_outlined,
                          'Cash Payments',
                          _loading ? null : cash,
                          () => _openList(context, 1, 'Cash Payments')),
                      _tile(
                          c,
                          Icons.credit_card,
                          'Online Payments',
                          _loading ? null : online,
                          () => _openList(context, 2, 'Online Payments')),
                      _tile(
                          c,
                          Icons.receipt_long,
                          'Payment Slips',
                          _loading ? null : slip,
                          () => _openPaymentSlips(context)),
                      _tile(
                          c,
                          Icons.tune,
                          'Update Collection',
                          null,
                          () => _openUpdateSheet(context)),
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
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
          boxShadow: Shadows.card(c),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: c.primary, size: 20),
            ),
            const Spacer(),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Text(
                  count != null ? '$label ($count)' : label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: c.textMuted),
            ]),
          ],
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
      final resp = await widget.fetcher();
      final data =
          resp is Map && resp.containsKey('data') ? resp['data'] : resp;
      setState(() => _data = data);
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
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child: CircularProgressIndicator(color: c.primary)),
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
                    Container(
                      padding: const EdgeInsets.all(Gaps.md),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: c.border),
                      ),
                      child: Text('No records.',
                          style: TextStyle(
                              color: c.textSecondary,
                              fontWeight: FontWeight.w600)),
                    )
                  else
                    for (final row in list)
                      _rowCard(c, row is Map ? row : {'value': row}),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _rowCard(AppColors c, Map row) {
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
                    width: 110,
                    child: Text(e.key.toString(),
                        style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: Text(e.value?.toString() ?? '',
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
        ],
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
