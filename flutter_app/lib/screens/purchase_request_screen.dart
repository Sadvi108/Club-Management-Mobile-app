import 'package:flutter/material.dart';

import '../services/boost_payment.dart';
import '../services/purchase_service.dart';
import '../services/response_utils.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/gradient_button.dart';
import 'payment/bcpg_webview_screen.dart';

/// New Purchase Request — browse the academy catalogue and order.
///
/// There is no "create purchase request" route: the order is raised by PAYING for it, with
/// the lines carried in `purchaseItems` on `/Bcpg/PayInvoices`. So "Proceed to pay" is the
/// submit button, and the request only exists once the payment lands.
class PurchaseRequestScreen extends StatefulWidget {
  const PurchaseRequestScreen({super.key});

  @override
  State<PurchaseRequestScreen> createState() => _PurchaseRequestScreenState();
}

class _PurchaseRequestScreenState extends State<PurchaseRequestScreen> {
  bool _loading = true;
  bool _paying = false;
  String? _error;
  List<PurchaseProduct> _catalogue = const [];

  /// productId -> quantity. Absent means zero.
  final Map<int, int> _qty = {};

  /// Kept so the text cursor does not jump to the start on every keystroke.
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await PurchaseService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _catalogue = rows;
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

  TextEditingController _ctrl(int productId) =>
      _controllers.putIfAbsent(productId, () => TextEditingController());

  void _setQty(int productId, String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    setState(() {
      final n = int.tryParse(digits) ?? 0;
      if (n <= 0) {
        _qty.remove(productId);
      } else {
        _qty[productId] = n;
      }
    });
  }

  String _fmtRM(double v) => 'RM ${v.toStringAsFixed(2)}';

  void _toast(String msg, {int seconds = 4}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: Duration(seconds: seconds)));
  }

  Future<void> _proceed() async {
    final lines = basketLines(_qty, _catalogue);
    if (lines.isEmpty) {
      _toast('Enter a quantity for at least one item.');
      return;
    }
    final total = basketTotal(_qty, _catalogue);
    final count = lines.fold<int>(0, (sum, l) => sum + l.qty);

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm purchase'),
        content: Text('$count item(s) - ${_fmtRM(total)}\n\n'
            'You will be taken to the payment gateway. Your order is created once the '
            'payment goes through.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed to pay')),
        ],
      ),
    );
    if (go != true || !mounted) return;

    setState(() => _paying = true);
    final session = UserSession.instance;
    session.startPaymentLock();

    // Row count BEFORE paying. The gateway link usually carries a checkout token rather
    // than a reference VerifyPayment accepts, so this before/after count is the signal
    // that actually proves the order was raised.
    int? baseline;
    try {
      baseline = await PurchaseService.countRequests();
    } catch (_) {
      // Inconclusive rather than wrong: confirm() will report `unknown` instead of
      // claiming a purchase succeeded on the strength of a count it never took.
      baseline = null;
    }

    PaymentStart start;
    try {
      start = await BoostPayment.start(PaymentIntent(purchaseItems: lines));
    } catch (e) {
      session.clearPaymentLock();
      if (!mounted) return;
      setState(() => _paying = false);
      _toast(friendlyError(e), seconds: 6);
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => BcpgWebViewScreen(
          paymentUrl: start.url,
          referenceId: start.referenceId ?? '',
          returnUrlNeedle: 'bcpg_redirect',
        ),
      ),
    );

    session.clearPaymentLock();
    if (!mounted) return;

    final result = await BoostPayment.confirm(
      referenceId: start.referenceId,
      purchaseBaseline: baseline,
      fetchPurchaseCount: PurchaseService.countRequests,
    );

    if (!mounted) return;
    setState(() {
      _paying = false;
      // Only clear the basket on a CONFIRMED purchase. Wiping it on `unknown` would leave
      // a member who was never charged with nothing to retry and no record of what they
      // had picked.
      if (result.outcome == PaymentOutcome.paid) {
        _qty.clear();
        for (final ctrl in _controllers.values) {
          ctrl.clear();
        }
      }
    });
    _toast(result.message, seconds: 6);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final total = basketTotal(_qty, _catalogue);
    final selected = _qty.values.where((n) => n > 0).length;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const AppHeader(title: 'New Purchase Request', showBack: true),
        Expanded(child: _body(c)),
        if (!_loading && _error == null && _catalogue.isNotEmpty)
          _footer(c, total, selected),
      ]),
    );
  }

  Widget _body(AppColors c) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(40),
          children: [
            Icon(Icons.error_outline, size: 40, color: c.danger),
            const SizedBox(height: Gaps.sm),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.danger, fontSize: 14)),
            const SizedBox(height: Gaps.md),
            Center(child: TextButton(onPressed: _load, child: const Text('Try again'))),
          ],
        ),
      );
    }
    if (_catalogue.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 80),
          children: [
            Icon(Icons.shopping_cart_outlined, size: 44, color: c.textMuted),
            const SizedBox(height: Gaps.sm),
            Text('No products available.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg, Gaps.lg),
        itemCount: _catalogue.length,
        itemBuilder: (_, i) => _productCard(c, _catalogue[i]),
      ),
    );
  }

  Widget _productCard(AppColors c, PurchaseProduct p) {
    final n = _qty[p.productId] ?? 0;
    final lineTotal = double.parse((p.price * n).toStringAsFixed(2));

    return Container(
      margin: const EdgeInsets.only(bottom: Gaps.md),
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
            child: Text('Type: ${p.category.isEmpty ? "-" : p.category}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Text('Price: ${_fmtRM(p.price)}',
              style:
                  TextStyle(color: c.primary, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: Gaps.sm),
        Text('Item: ${p.name.isEmpty ? "-" : p.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: Gaps.md),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          SizedBox(
            width: 120,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _fieldLabel(c, 'QTY'),
              TextField(
                controller: _ctrl(p.productId),
                keyboardType: TextInputType.number,
                enabled: !_paying,
                onChanged: (v) => _setQty(p.productId, v),
                style: TextStyle(
                    color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: c.textMuted),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  filled: true,
                  fillColor: c.surface,
                  enabledBorder: _pill(c.border),
                  focusedBorder: _pill(c.primary),
                  disabledBorder: _pill(c.border),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _fieldLabel(c, 'TOTAL'),
              Container(
                height: 46,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.xxl),
                  border: Border.all(color: c.border),
                ),
                child: Text(_fmtRM(lineTotal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _fieldLabel(AppColors c, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(
                color: c.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );

  OutlineInputBorder _pill(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.xxl),
        borderSide: BorderSide(color: color),
      );

  Widget _footer(AppColors c, double total, int selected) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          Gaps.lg, Gaps.md, Gaps.lg, MediaQuery.of(context).padding.bottom + Gaps.md),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (selected > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: Gaps.sm),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('$selected item type(s)',
                  style: TextStyle(color: c.textSecondary, fontSize: 13)),
              Text(_fmtRM(total),
                  style: TextStyle(
                      color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
          ),
        GradientButton(
          label: 'Proceed to pay',
          trailingIcon: Icons.shopping_bag_outlined,
          loading: _paying,
          onPressed: _paying ? null : _proceed,
        ),
      ]),
    );
  }
}
