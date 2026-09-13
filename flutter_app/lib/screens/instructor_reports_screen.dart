import '../theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class InstructorReportsScreen extends StatelessWidget {
  const InstructorReportsScreen({super.key});

  /// Every report route this screen offers. Exposed so a test can assert each one is
  /// registered — 20 hand-written paths against a hand-written router is exactly where a
  /// typo hides until an instructor taps a tile and nothing happens.
  static List<String> get reportRoutes => [for (final i in _items) i.route];

  static const _items = <_ReportItem>[
    _ReportItem(AppIcons.ion_business_outline, 'Student Centers',
        '/instructor/reports/student-centers'),
    _ReportItem(AppIcons.ion_barbell_outline, 'Training Centers',
        '/instructor/reports/training-centers'),
    _ReportItem(AppIcons.ion_clipboard_outline, 'Exam Centers',
        '/instructor/reports/exam-centers'),
    _ReportItem(AppIcons.ion_people_outline, 'Student List',
        '/instructor/reports/student-list'),
    _ReportItem(AppIcons.ion_time_outline, 'Training Schedule',
        '/instructor/reports/training-time'),
    _ReportItem(AppIcons.ion_school_outline, 'Grading Schedule',
        '/instructor/reports/grading-schedule'),
    _ReportItem(AppIcons.ion_alert_circle_outline, 'Outstanding Report',
        '/instructor/reports/outstanding'),
    _ReportItem(AppIcons.ion_checkmark_done_circle_outline, 'Attendance Report',
        '/instructor/reports/attendance'),
    _ReportItem(AppIcons.ion_receipt_outline, 'Receipt Report',
        '/instructor/reports/receipt'),
    _ReportItem(AppIcons.ion_ribbon_outline, 'Grade Completed',
        '/instructor/reports/grading-past'),
    _ReportItem(AppIcons.ion_cart_outline, 'Purchase Requests',
        '/instructor/reports/purchase-request'),
    _ReportItem(AppIcons.ion_document_attach_outline, 'Payment Slips',
        '/instructor/reports/payment-slip'),
    _ReportItem(AppIcons.ion_trophy_outline, 'Tournaments (Past)',
        '/instructor/reports/tournament-past'),
    _ReportItem(AppIcons.ion_medal_outline, 'Upcoming Tournaments',
        '/instructor/reports/tournament-upcoming'),
    _ReportItem(AppIcons.ion_git_compare_outline, 'Contribution Report',
        '/instructor/reports/contribution'),
    _ReportItem(AppIcons.ion_cash_outline, 'Reimbursement',
        '/instructor/reports/reimbursement'),
    _ReportItem(AppIcons.ion_card_outline, 'Pay Your Dues', '/invoices'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return ColoredBox(
        color: c.background,
        child: Column(children: [
          Container(
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.paddingOf(context).top + 6, 20, 24),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: c.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(28))),
              child: Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                        color: Color(0x38FFFFFF), shape: BoxShape.circle),
                    child: const Icon(AppIcons.description,
                        color: Colors.white, size: 20)),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Reports',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 3),
                      Text('Tap a report to view details',
                          style: TextStyle(
                              color: Color(0xD9FFFFFF), fontSize: 12)),
                    ])),
              ])),
          Expanded(
              child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 110),
                  itemBuilder: (_, i) => _row(context, c, _items[i]),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: _items.length)),
        ]));
  }

  Widget _row(BuildContext context, AppColors c, _ReportItem item) {
    return InkWell(
      onTap: () => context.push(item.route),
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: Gaps.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: c.isDark ? Border.all(color: c.border) : null,
          boxShadow: Shadows.soft(c),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(item.icon, color: c.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(item.label,
                style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
          Icon(AppIcons.chevron_right, size: 20, color: c.textMuted),
        ]),
      ),
    );
  }
}

class _ReportItem {
  final IconData icon;
  final String label;
  final String route;
  const _ReportItem(this.icon, this.label, this.route);
}
