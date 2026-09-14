import 'package:flutter/material.dart';

import '../services/rn_api.dart';
import '../theme/app_theme.dart';
import '../theme/ion.dart';
import '../widgets/rn_kit.dart';
import '../widgets/use_api.dart';

/// Port of `frontend/app/purchases.tsx` (Expo v2.11.1).
///
/// Backed by `/Reports/PurchaseRequests`, which is scoped to the caller's token. A request
/// appears here only once its payment has landed, because paying IS how a request is raised.
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> with UseApi<PurchasesScreen> {
  final _range = RnApi.defaultRange();
  late final _data =
      useApi(() => RnApi.purchaseRequests({'fromDate': _range.fromDate, 'toDate': _range.toDate}));

  @override
  void initState() {
    super.initState();
    _data;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final rows = _data.data ?? const <Map<String, dynamic>>[];
    String first(Map p, List<String> keys) {
      for (final k in keys) {
        final v = '${p[k] ?? ''}'.trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    return Scaffold(
      backgroundColor: c.background,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        RnHeader(
          title: 'My Purchases',
          horizontal: Gaps.lg,
          trailing: RnCircleButton(icon: Ion.refreshOutline, iconSize: 20, iconColor: c.primary, onPress: _data.reload),
        ),
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            onRefresh: _data.reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.xl, Gaps.xl, 60),
              children: [
                if (_data.loading) const RnSpinner(vertical: 30),
                if (_data.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_data.error!, style: TextStyle(color: c.danger, fontSize: 13)),
                  ),
                if (!_data.loading && rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(children: [
                      Icon(Ion.bagHandleOutline, size: 44, color: c.textMuted),
                      const SizedBox(height: 16),
                      Text('No purchase requests',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                      const SizedBox(height: 6),
                      Text('Your purchase history will appear here',
                          style: TextStyle(fontSize: 13, color: c.textSecondary)),
                    ]),
                  ),
                for (final p in rows)
                  Builder(builder: (context) {
                    final title = first(p, ['itemName', 'productName', 'name', 'description', 'invoiceDescription']);
                    final status = first(p, ['status', 'paymentStatus']);
                    final date = fmtDateGB(first(p, ['requestDate', 'date', 'invoiceDate']));
                    final amt = p['amount'] ?? p['totalAmount'] ?? p['dueAmount'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: Gaps.sm),
                      padding: const EdgeInsets.all(Gaps.md),
                      decoration: rnCard(c),
                      child: Row(children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                          child: Icon(Ion.bagHandle, size: 18, color: c.primary),
                        ),
                        const SizedBox(width: Gaps.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(title.isEmpty ? 'Purchase' : title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                            const SizedBox(height: 2),
                            Text('$date${status.isNotEmpty ? ' · $status' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: c.textSecondary)),
                          ]),
                        ),
                        if (amt != null) ...[
                          const SizedBox(width: Gaps.sm),
                          Text('RM ${localeNum(RnApi.number(amt))}',
                              maxLines: 1,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary)),
                        ],
                      ]),
                    );
                  }),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
