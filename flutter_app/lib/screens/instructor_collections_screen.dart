import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api.dart';
import '../services/response_utils.dart';
import '../services/rn_api.dart';
import '../theme/app_theme.dart';
import '../theme/ion.dart';
import '../widgets/report_kit.dart';
import '../widgets/rn_kit.dart';
import '../widgets/use_api.dart';

/// Port of `frontend/app/(tabs)/collections.tsx` (Expo v2.11.1).
class InstructorCollectionsScreen extends StatefulWidget {
  const InstructorCollectionsScreen({super.key});
  @override
  State<InstructorCollectionsScreen> createState() => _InstructorCollectionsScreenState();
}

class _InstructorCollectionsScreenState extends State<InstructorCollectionsScreen>
    with UseApi<InstructorCollectionsScreen> {
  late final _counts = useApi(RnApi.collectionCount);
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _counts;
  }

  String _fmt(dynamic n) => (_counts.loading || _updating) ? '…' : '${RnApi.number(n).toInt()}';

  /// Open a type's live detail list (typeId 1=cash, 2=online/fpx, 3=bank-in slip).
  void _openList(int typeId, String label) =>
      context.push('/instructor/collections/$typeId?label=${Uri.encodeQueryComponent(label)}');

  /// Recalc all collection counts server-side, then refresh.
  Future<void> _update() async {
    if (_updating) return;
    setState(() => _updating = true);
    try {
      await Future.wait([1, 2, 3].map((t) async {
        final r = await Api.outstandingUpdateCollectionCount(t);
        final err = apiEnvelopeError(r);
        if (err != null) throw Exception(err);
      }));
      _counts.reload();
      if (mounted) await notify(context, 'Collections updated', 'Counts refreshed from the server.');
    } catch (e) {
      if (mounted) await notify(context, 'Update failed', friendlyError(e));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final top = MediaQuery.paddingOf(context).top;
    final tabBarHeight = 62 + MediaQuery.paddingOf(context).bottom;
    final d = _counts.data ?? const <String, dynamic>{};
    final cards = <({String label, IconData icon, VoidCallback onTap})>[
      (label: 'Cash Payments (${_fmt(d['cash'])})', icon: Ion.cashOutline, onTap: () => _openList(1, 'Cash Payments')),
      (label: 'Online Payments (${_fmt(d['fpx'])})', icon: Ion.cardOutline, onTap: () => _openList(2, 'Online Payments')),
      (label: 'Payment Slips (${_fmt(d['dbt'])})', icon: Ion.documentAttachOutline, onTap: () => _openList(3, 'Payment Slips')),
      (label: _updating ? 'Updating…' : 'Update Collection', icon: Ion.syncOutline, onTap: _update),
    ];

    return ColoredBox(
      color: c.background,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(Gaps.xl, top + 8, Gaps.xl, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Collections',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: c.textPrimary)),
            const SizedBox(height: 4),
            Text('Track payments received across your club',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.textSecondary)),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            onRefresh: _counts.reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg, tabBarHeight + 24),
              children: [
                if (_counts.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gaps.lg),
                    child: ErrorState(message: _counts.error, onRetry: _counts.reload, compact: true),
                  ),
                LayoutBuilder(builder: (context, box) {
                  final w = box.maxWidth * .47;
                  return Wrap(spacing: box.maxWidth - w * 2, runSpacing: Gaps.lg, children: [
                    for (final card in cards)
                      SizedBox(
                        width: w,
                        child: Touchable(
                          activeOpacity: 0.85,
                          onPress: card.onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: Gaps.xl, horizontal: Gaps.md),
                            decoration: rnCard(c, radius: Radii.xl),
                            child: Column(children: [
                              Container(
                                width: 56,
                                height: 56,
                                margin: const EdgeInsets.only(bottom: Gaps.md),
                                decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                                child: Icon(card.icon, size: 24, color: c.primary),
                              ),
                              Text(card.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary, height: 20 / 16)),
                            ]),
                          ),
                        ),
                      ),
                  ]);
                }),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

/// Port of `frontend/app/collection-list.tsx` — the live rows behind one collection type.
class CollectionListScreen extends StatefulWidget {
  final int typeId;
  final String label;
  const CollectionListScreen({super.key, required this.typeId, required this.label});
  @override
  State<CollectionListScreen> createState() => _CollectionListScreenState();
}

class _CollectionListScreenState extends State<CollectionListScreen> with UseApi<CollectionListScreen> {
  late final _list = useApi(() => RnApi.collectionCountList(widget.typeId));

  @override
  void initState() {
    super.initState();
    _list;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    dynamic first(Map r, List<String> keys) {
      for (final k in keys) {
        final v = r[k];
        if (v != null && '$v'.trim().isNotEmpty) return v;
      }
      return null;
    }

    return ReportScaffold<Map<String, dynamic>>(
      title: widget.label,
      subtitle: 'Live collection records',
      loading: _list.loading,
      error: _list.error,
      data: _list.data,
      emptyText: 'No collections recorded yet.',
      onRefresh: _list.reload,
      renderItem: (r, _) {
        final title = first(r, ['studentName', 'name', 'icNo', 'receiptNo']) ?? 'Collection';
        final amount = first(r, ['amount', 'receiptAmount', 'paidAmount']);
        final date = first(r, ['receiptDate', 'date', 'paymentDate']);
        return RkCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: KV('', title, strong: true)),
            ]),
            if (r['icNo'] != null) KV('IC No', r['icNo']),
            if (first(r, ['transactionType', 'type']) != null) KV('Type', first(r, ['transactionType', 'type'])),
            if (r['period'] != null) KV('Period', r['period']),
            if (amount != null) KV('Amount', 'RM ${money2(RnApi.number(amount))}', strong: true),
            if (r['receiptNo'] != null) KV('Receipt No', r['receiptNo']),
            if (date != null) KV('Date', fmtDateGB(date)),
            if (r['status'] != null) KV('Status', r['status']),
            if (first(r, ['centerName', 'tcName']) != null) KV('Center', first(r, ['centerName', 'tcName'])),
          ]),
        );
      },
    );
  }
}
