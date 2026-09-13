import '../services/live_refresh.dart';
import '../theme/app_icons.dart';
import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/response_utils.dart';
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
    extends State<InstructorCollectionsScreen>
    with LiveRefreshMixin<InstructorCollectionsScreen> {
  @override
  bool get canLiveRefresh => !_loading && !_updating;
  @override
  Future<void> refreshLiveData() => _load();

  Map<String, dynamic>? _counts;
  bool _loading = true;
  bool _updating = false;
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
          : (resp is Map
              ? Map<String, dynamic>.from(resp)
              : <String, dynamic>{});
      if (mounted) setState(() => _counts = data);
    } catch (e) {
      debugPrint('CollectionCount failed: $e');
      if (mounted) setState(() => _error = e.toString());
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
          const AppHeader(
              title: 'Collections',
              subtitle: 'Track payments received across your club'),
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
                      child: Text(friendlyError(_error),
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
                          AppIcons.payments_outlined,
                          'Cash Payments',
                          (_loading && !liveRefreshing) || _error != null
                              ? null
                              : cash,
                          () => _openList(context, 1, 'Cash Payments'),
                          0),
                      _tile(
                          c,
                          AppIcons.credit_card,
                          'Online Payments',
                          (_loading && !liveRefreshing) || _error != null
                              ? null
                              : online,
                          () => _openList(context, 2, 'Online Payments'),
                          1),
                      _tile(
                          c,
                          AppIcons.receipt_long,
                          'Payment Slips',
                          (_loading && !liveRefreshing) || _error != null
                              ? null
                              : slip,
                          // dbt count comes from CollectionCount; its records
                          // live in CollectionCountList(3) (paymentMethod=DBT),
                          // not /Reports/PaymentSlips (a different, empty list)
                          // — so the count and the drill-down agree.
                          () => _openList(context, 3, 'Payment Slips'),
                          2),
                      _tile(
                          c,
                          AppIcons.autorenew,
                          _updating ? 'Updating…' : 'Update Collection',
                          null,
                          _updateCollections,
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
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                width: 50,
                height: 50,
                decoration:
                    BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                child: Icon(icon, color: c.primary, size: 24)),
            const SizedBox(height: 12),
            Text(count == null ? label : '$label ($count)',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ]),
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

  Future<void> _updateCollections() async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      for (final type in [1, 2, 3]) {
        await Api.outstandingUpdateCollectionCount(type);
      }
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collection counts refreshed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }
}

class _SimpleListScreen extends StatefulWidget {
  final String title;
  final Future<dynamic> Function() fetcher;
  const _SimpleListScreen({required this.title, required this.fetcher});

  @override
  State<_SimpleListScreen> createState() => _SimpleListScreenState();
}

class _SimpleListScreenState extends State<_SimpleListScreen>
    with LiveRefreshMixin<_SimpleListScreen> {
  @override
  bool get canLiveRefresh => !_loading;
  @override
  Future<void> refreshLiveData() => _load();

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
      if (mounted) setState(() => _data = findRecordList(resp));
    } catch (e) {
      debugPrint('${widget.title} failed: $e');
      if (mounted) setState(() => _error = e.toString());
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
                padding:
                    const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.lg, 24),
                children: [
                  if ((_loading && !liveRefreshing))
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
                            border:
                                c.isDark ? Border.all(color: c.border) : null,
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
                                    color: c.textSecondary, fontSize: 12)),
                          ]),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => setState(() => _showRaw = !_showRaw),
                          child: Text(
                              _showRaw
                                  ? 'Hide raw response'
                                  : 'Show raw response',
                              style:
                                  TextStyle(color: c.textMuted, fontSize: 12)),
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
      'studentName',
      'name',
      'payerName',
      'memberName',
      'description',
    ]);
    final amount = pickAmount(row, [
      'amount',
      'dueAmount',
      'paidAmount',
      'value',
      'total',
      'totalAmount',
    ]);
    final dateRaw = pickField(row, [
      'date',
      'paymentDate',
      'recordedTime',
      'createdDate',
      'slipDate',
    ]);
    final date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
    final status = pickField(row, ['status', 'paymentStatus', 'remarks']);
    final ok = status.toLowerCase().contains('paid') ||
        status.toLowerCase().contains('approve') ||
        status.toLowerCase().contains('success');
    final statusColor =
        status.isEmpty ? c.textMuted : (ok ? c.success : c.danger);

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
                  Icon(AppIcons.event, size: 13, color: c.textMuted),
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
      ),
    );
  }
}
