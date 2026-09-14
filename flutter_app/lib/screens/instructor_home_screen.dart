import '../services/live_refresh.dart';
import '../theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard_widgets.dart';

const _tiles = <QuickCard>[
  QuickCard('training-time', 'Training Time', AppIcons.schedule,
      Color(0xFFF59E0B), '/instructor/reports/training-time'),
  QuickCard('activities', 'Activities', AppIcons.monitor_heart_outlined,
      Color(0xFF10B981), '/instructor/reports/activity'),
  QuickCard('attendance', 'Class Check-In', AppIcons.check_circle_outline,
      Color(0xFF4F46E5), '/instructor/attendance'),
  QuickCard('receipt', 'Receipt', AppIcons.receipt_long_outlined,
      Color(0xFF0EA5E9), '/instructor/reports/receipt'),
  QuickCard('grading', 'Grading Schedule', AppIcons.school_outlined,
      Color(0xFF9333EA), '/instructor/reports/grading-schedule'),
  QuickCard('tournament', 'Tournament Schedule', AppIcons.emoji_events_outlined,
      Color(0xFFEF4444), '/instructor/reports/tournament'),
  QuickCard('collections', 'Collections', AppIcons.payments_outlined,
      Color(0xFFDB2777), '/instructor/collections'),
  QuickCard('invoice', 'Missing Invoice', AppIcons.description_outlined,
      Color(0xFFF97316), '/instructor/reports/outstanding'),
  QuickCard('fees', 'Fee Master', AppIcons.sell_outlined, Color(0xFF64748B),
      '/instructor/reports/fee-master'),
  QuickCard('new', 'New Student', AppIcons.person_add_outlined,
      Color(0xFF10B981), '/instructor/reports/new-student'),
  QuickCard('slip', 'Payment Slip', AppIcons.attach_file, Color(0xFF4F46E5),
      '/instructor/reports/payment-slip'),
  QuickCard('more', 'More', AppIcons.grid_view, Color(0xFF0EA5E9),
      '/instructor/reports'),
];

class InstructorHomeScreen extends StatefulWidget {
  const InstructorHomeScreen({super.key});
  @override
  State<InstructorHomeScreen> createState() => _InstructorHomeScreenState();
}

class _InstructorHomeScreenState extends State<InstructorHomeScreen>
    with LiveRefreshMixin<InstructorHomeScreen> {
  @override
  bool get canLiveRefresh => !UserSession.instance.loading;
  @override
  Future<void> refreshLiveData() =>
      UserSession.instance.refresh(background: true);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final rows = [...?session.clubStats]..sort((a, b) =>
        (int.tryParse('${a['value']}') ?? 0)
            .compareTo(int.tryParse('${b['value']}') ?? 0));
    final failed =
        session.outstandingList == null && session.outstandingError != null;
    Widget card(Widget child) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: Shadows.soft(c)),
        child: child);
    return ColoredBox(
        color: c.background,
        child: RefreshIndicator(
            onRefresh: session.refresh,
            child: ListView(
                padding: EdgeInsets.only(
                    bottom: 100 + MediaQuery.paddingOf(context).bottom),
                children: [
                  DashboardHeader(session: session, instructor: true),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: InkWell(
                          onTap: () => context.push('/invoices'),
                          child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  gradient: LinearGradient(
                                      colors: c.isDark
                                          ? const [
                                              Color(0xFF2D1A0A),
                                              Color(0xFF3F2410)
                                            ]
                                          : const [
                                              Color(0xFFFEF3C7),
                                              Color(0xFFFED7AA)
                                            ])),
                              child: Row(children: [
                                Icon(AppIcons.notifications,
                                    color: c.primary, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          failed
                                              ? "Dues couldn't be loaded"
                                              : '${session.invoiceCount} invoices are due',
                                          style: TextStyle(
                                              color: c.isDark
                                                  ? const Color(0xFFFED7AA)
                                                  : const Color(0xFF7C2D12),
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800)),
                                      Text(
                                          failed
                                              ? 'Tap to open Pay Your Dues'
                                              : 'RM ${session.dueAmount.toStringAsFixed(2)} total due amount',
                                          style: TextStyle(
                                              color: c.isDark
                                                  ? const Color(0xFFFDBA74)
                                                  : const Color(0xFF9A3412),
                                              fontSize: 11)),
                                    ])),
                                Icon(AppIcons.chevron_right, color: c.primary),
                              ])))),
                  const DashboardSection('Quick Access'),
                  const DashboardGrid(items: _tiles, columns: 3),
                  const DashboardSection('Latest Updates'),
                  card(session.loading && rows.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : rows.isEmpty
                          ? Text('No updates right now.',
                              style: TextStyle(color: c.textSecondary))
                          : Column(children: [
                              for (var i = 0; i < rows.length; i++) ...[
                                if (i > 0) Divider(color: c.border),
                                Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(children: [
                                      Expanded(
                                          child: Text(
                                              '${rows[i]['text'] ?? ''}',
                                              style: TextStyle(
                                                  color: c.textSecondary,
                                                  fontSize: 13))),
                                      Text('${rows[i]['id'] ?? ''}',
                                          style: TextStyle(
                                              color: c.primary,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800)),
                                    ])),
                              ]
                            ])),
                  const DashboardSection('Latest News'),
                  if (session.myOffers.isEmpty)
                    card(Text('No news right now.',
                        style: TextStyle(color: c.textSecondary)))
                  else
                    for (final offer in session.myOffers.take(2))
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: card(InkWell(
                              onTap: () => context.push(
                                  '/offer/${Uri.encodeComponent('${offer['code'] ?? ''}')}'),
                              child: Row(children: [
                                Icon(AppIcons.campaign_outlined,
                                    color: c.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          '${offer['name'] ?? offer['title'] ?? ''}',
                                          style: TextStyle(
                                              color: c.textPrimary,
                                              fontWeight: FontWeight.w700)),
                                      Text('${offer['code'] ?? 'NEWS'}',
                                          style: TextStyle(
                                              color: c.textMuted,
                                              fontSize: 11)),
                                    ])),
                              ])))),
                ])));
  }
}
