import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// All Features — the full catalogue, grouped by what each screen is for.
///
/// Every entry here points at a route that EXISTS. A catalogue that lists screens the app
/// cannot open is worse than a shorter one: the member taps, nothing happens, and they stop
/// trusting the menu. As screens land during the Flutter port, add them here — see
/// docs/flutter-parity-plan.md for what is still outstanding.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _sections = <_Section>[
    _Section('Training', [
      _Item('Training', Icons.fitness_center, Color(0xFF4F46E5), '/training'),
      _Item("Today's Classes", Icons.bolt, Color(0xFFF59E0B), '/schedule'),
      _Item('Timetable', Icons.calendar_month, Color(0xFF0EA5E9), '/schedule'),
      _Item('Attendance', Icons.check_circle, Color(0xFF10B981), '/attendance'),
      _Item('Book a Class', Icons.add_circle, Color(0xFF14B8A6), '/book-class'),
      _Item('Scan QR', Icons.qr_code_scanner, Color(0xFF0EA5E9), '/qr-scan'),
    ]),
    _Section('Payments', [
      _Item('Fees Due', Icons.account_balance_wallet, Color(0xFFEF4444), '/payments'),
      _Item('Payment History', Icons.receipt_long, Color(0xFF14B8A6), '/payments'),
      _Item('Outstanding Invoices', Icons.description, Color(0xFF8B5CF6), '/invoices'),
      _Item('Purchase Request', Icons.shopping_bag, Color(0xFFF59E0B), '/purchase-request'),
      _Item('My Purchases', Icons.inventory_2, Color(0xFFDB2777), '/purchases'),
    ]),
    _Section('Progress', [
      _Item('Progress Report', Icons.trending_up, Color(0xFF6366F1), '/progress'),
      _Item('Belt / Rank', Icons.military_tech, Color(0xFFEAB308), '/progress'),
    ]),
    _Section('Club', [
      _Item('Events', Icons.event, Color(0xFFF97316), '/events'),
      _Item('Chat Academy', Icons.forum, Color(0xFF22C55E), '/chat'),
      _Item('Notification Settings', Icons.tune, Color(0xFF64748B), '/notification-settings'),
    ]),
    _Section('Account', [
      _Item('Profile', Icons.account_circle, Color(0xFF64748B), '/profile'),
    ]),
  ];

  /// Every route this screen can navigate to. Exposed so a test can assert each one
  /// is actually registered on the router — a dead tile here is invisible until a
  /// member taps it.
  static List<String> get catalogueRoutes =>
      [for (final s in _sections) for (final i in s.items) i.route];

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const AppHeader(
          title: 'All Features',
          subtitle: 'Quick access to everything',
          showBack: true,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg, Gaps.xxxl),
            children: [
              for (final s in _sections) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: Gaps.sm, top: Gaps.sm),
                  child: Text(s.title.toUpperCase(),
                      style: TextStyle(
                          color: c.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                ),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: Gaps.sm,
                  crossAxisSpacing: Gaps.sm,
                  childAspectRatio: 0.95,
                  children: [for (final i in s.items) _tile(context, c, i)],
                ),
                const SizedBox(height: Gaps.md),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _tile(BuildContext context, AppColors c, _Item i) => GestureDetector(
        onTap: () => context.push(i.route),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: i.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(i.icon, size: 20, color: i.color),
            ),
            const SizedBox(height: Gaps.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(i.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: c.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );
}

class _Section {
  final String title;
  final List<_Item> items;
  const _Section(this.title, this.items);
}

class _Item {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _Item(this.label, this.icon, this.color, this.route);
}
