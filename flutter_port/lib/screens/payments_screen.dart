import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String selectedMethod = 'card';

  void _openPayModal() {
    final c = context.appColors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 36),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Text('Complete Payment', style: TextStyle(color: c.textPrimary, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            Text('Choose payment method', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Text('RM ${kStudent.nextPayment.amount.toString()}', style: TextStyle(color: c.primary, fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...kPayMethods.map((m) {
              final active = selectedMethod == m.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => setModal(() => selectedMethod = m.id),
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: active ? c.primary : c.border),
                      color: active ? c.surfaceAlt : Colors.transparent,
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: active ? c.primary : c.surfaceAlt, shape: BoxShape.circle),
                        child: Icon(m.icon, size: 18, color: active ? Colors.white : c.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(m.label, style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
                      Icon(active ? Icons.radio_button_checked : Icons.radio_button_off, color: active ? c.primary : c.textMuted),
                    ]),
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                Navigator.of(ctx).pop();
                final method = kPayMethods.firstWhere((m) => m.id == selectedMethod).label;
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Payment Successful'),
                      content: Text('RM ${kStudent.nextPayment.amount} paid via $method'),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                    ),
                  );
                });
              },
              borderRadius: BorderRadius.circular(Radii.md),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: c.gradient),
                  borderRadius: BorderRadius.circular(Radii.md),
                  boxShadow: Shadows.strong(c),
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.lock, color: Colors.white, size: 14),
                  SizedBox(width: 8),
                  Text('Confirm & Pay Securely', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: c.textSecondary, fontSize: 13)),
              ),
            ),
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      color: c.background,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gaps.xl, 10, Gaps.xl, 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Fees & Payments', style: TextStyle(color: c.textPrimary, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                  child: Icon(Icons.download, color: c.primary, size: 20),
                ),
              ]),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 140),
          sliver: SliverList.list(children: [
            // Due card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(Radii.xxl),
                boxShadow: Shadows.strong(c),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [
                  Icon(Icons.error_outline, color: Color(0xFFFFF7ED), size: 18),
                  SizedBox(width: 6),
                  Text('NEXT PAYMENT DUE', style: TextStyle(color: Color(0xFFFFF7ED), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ]),
                const SizedBox(height: 8),
                Text('RM ${kStudent.nextPayment.amount.toString()}', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 2),
                Text(kStudent.nextPayment.label, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('Due by ${kStudent.nextPayment.dueDate}', style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12)),
                const SizedBox(height: 18),
                InkWell(
                  onTap: _openPayModal,
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Radii.md)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Pay Now', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: c.primary, size: 16),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            Text('Quick Pay', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Row(children: [
              _pkgCard(c, Icons.calendar_month, c.primary, 'Monthly', 'RM 480'),
              const SizedBox(width: 10),
              _pkgCard(c, Icons.calendar_today, c.primaryDark, 'Quarterly', 'RM 1,300'),
              const SizedBox(width: 10),
              _pkgCard(c, Icons.emoji_events, c.warning, 'Tournament', 'RM 150'),
            ]),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Payment History', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                Text('Export', style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 14),
            ...kPayments.map((p) => _histRow(c, p)),
          ]),
        ),
      ]),
    );
  }

  Widget _pkgCard(AppColors c, IconData icon, Color tint, String l, String a) => Expanded(
        child: Container(
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
              Icon(icon, size: 22, color: tint),
              const SizedBox(height: 10),
              Text(l, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(a, style: TextStyle(fontSize: 15, color: c.textPrimary, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );

  Widget _histRow(AppColors c, payment) => Container(
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
            width: 36, height: 36,
            decoration: BoxDecoration(color: c.isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5), shape: BoxShape.circle),
            child: Icon(Icons.check, size: 18, color: c.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 2),
                Text('${payment.date} · ${payment.method}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('RM ${payment.amount}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.download, size: 12, color: c.primary),
                const SizedBox(width: 3),
                Text('Receipt', style: TextStyle(color: c.primary, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ],
          ),
        ]),
      );
}
