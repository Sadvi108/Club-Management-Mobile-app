import 'package:flutter/material.dart';

import '../services/response_utils.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_icon_button.dart';

/// My Purchases — the member's past purchase requests.
///
/// Backed by `/Reports/PurchaseRequests`, which is scoped to the caller's token. A request
/// appears here only once its payment has landed, because paying IS how a request is
/// raised (see [PurchaseService]).
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  bool _loading = true;
  String? _error;
  List<PurchaseRow> _rows = const [];

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
      final raw = await PurchaseService.fetchRequests();
      if (!mounted) return;
      setState(() {
        _rows = raw.map(PurchaseRow.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  String _fmtRM(double v) => 'RM ${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        AppHeader(
          title: 'My Purchases',
          showBack: true,
          trailing: AppIconButton(
            icon: Icons.refresh,
            onPressed: _loading ? null : _load,
            backgroundColor: c.surfaceAlt,
            foregroundColor: c.primary,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _body(c),
          ),
        ),
      ]),
    );
  }

  Widget _body(AppColors c) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    // Always a scrollable, so pull-to-refresh works from the error and empty states too —
    // otherwise a member who hits a transient error has no way to retry but to leave.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg, Gaps.xxxl),
      children: [
        if (_error != null) _errorCard(c, _error!),
        if (_error == null && _rows.isEmpty) _empty(c),
        for (final r in _rows) _card(c, r),
      ],
    );
  }

  Widget _errorCard(AppColors c, String msg) => Container(
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.danger.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: c.danger, size: 20),
          const SizedBox(width: Gaps.sm),
          Expanded(
            child: Text(msg, style: TextStyle(color: c.danger, fontSize: 13)),
          ),
        ]),
      );

  Widget _empty(AppColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(children: [
          Icon(Icons.shopping_bag_outlined, size: 44, color: c.textMuted),
          const SizedBox(height: Gaps.sm),
          Text('No purchase requests',
              style: TextStyle(
                  color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Your purchase history will appear here',
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
        ]),
      );

  Widget _card(AppColors c, PurchaseRow r) {
    final meta = [
      _fmtDate(r.date),
      if (r.status.isNotEmpty) r.status,
    ].where((s) => s.isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: Gaps.sm),
      padding: const EdgeInsets.all(Gaps.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
          child: Icon(Icons.shopping_bag, size: 18, color: c.primary),
        ),
        const SizedBox(width: Gaps.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            if (meta.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary, fontSize: 11)),
              ),
          ]),
        ),
        if (r.amount != null)
          Padding(
            padding: const EdgeInsets.only(left: Gaps.sm),
            child: Text(_fmtRM(r.amount!),
                style: TextStyle(
                    color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
      ]),
    );
  }
}
