import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

class InstructorReportsScreen extends StatelessWidget {
  const InstructorReportsScreen({super.key});

  static const _items = <_ReportItem>[
    _ReportItem(
        Icons.location_city, 'Student Centers', '/instructor/reports/student-centers'),
    _ReportItem(Icons.fitness_center, 'Training Centers',
        '/instructor/reports/training-centers'),
    _ReportItem(Icons.assignment, 'Exam Centers',
        '/instructor/reports/exam-centers'),
    _ReportItem(Icons.people_alt, 'Student List',
        '/instructor/reports/student-list'),
    _ReportItem(Icons.alarm, 'Training Time',
        '/instructor/reports/training-time'),
    _ReportItem(Icons.school, 'Grading Schedule',
        '/instructor/reports/grading-schedule'),
    _ReportItem(Icons.warning_amber, 'Outstanding Report',
        '/instructor/reports/outstanding'),
    _ReportItem(Icons.fact_check, 'Attendance Report',
        '/instructor/reports/attendance'),
    _ReportItem(Icons.receipt_long, 'Receipt',
        '/instructor/reports/receipt'),
    _ReportItem(Icons.history_edu, 'Grading Past',
        '/instructor/reports/grading-past'),
    _ReportItem(Icons.shopping_cart_outlined, 'Purchase Request',
        '/instructor/reports/purchase-request'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const AppHeader(title: 'Reports'),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.lg, 100),
              itemBuilder: (_, i) => _row(context, c, _items[i]),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: _items.length,
            ),
          ),
        ]),
      ),
    );
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
          border: Border.all(color: c.border),
          boxShadow: Shadows.card(c),
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
          Icon(Icons.chevron_right, size: 20, color: c.textMuted),
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
