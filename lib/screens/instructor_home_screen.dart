import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/user_session.dart';
import '../theme/app_theme.dart';

class InstructorHomeScreen extends StatefulWidget {
  const InstructorHomeScreen({super.key});

  @override
  State<InstructorHomeScreen> createState() => _InstructorHomeScreenState();
}

class _InstructorHomeScreenState extends State<InstructorHomeScreen> {
  Future<void> _refresh() => UserSession.instance.refresh();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final name = session.displayName.isNotEmpty
        ? session.displayName
        : 'Instructor';
    final clubName = session.clubDisplayName;
    return Scaffold(
      backgroundColor: c.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: c.primary,
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.lg, Gaps.lg, 100),
            children: [
              _headerRow(c, name, clubName, session),
              const SizedBox(height: Gaps.lg),
              _notificationsStrip(c, session),
              const SizedBox(height: Gaps.lg),
              _actionGrid(c),
              const SizedBox(height: Gaps.lg),
              _latestUpdates(c, session),
              const SizedBox(height: Gaps.lg),
              _latestNewsHeader(c),
              const SizedBox(height: Gaps.sm),
              _latestNews(c, session),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerRow(
      AppColors c, String name, String clubName, UserSession session) {
    final pic = session.clubPic;
    final initial =
        (clubName.isNotEmpty ? clubName[0] : 'C').toUpperCase();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome,',
                  style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              if (clubName.isNotEmpty)
                Text('($clubName)',
                    style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: c.surface,
            shape: BoxShape.circle,
            border: Border.all(color: c.border),
            boxShadow: Shadows.card(c),
          ),
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          child: pic.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: pic,
                  fit: BoxFit.cover,
                  width: 48,
                  height: 48,
                  errorWidget: (_, __, ___) => _initialAvatar(c, initial),
                )
              : _initialAvatar(c, initial),
        ),
      ],
    );
  }

  Widget _initialAvatar(AppColors c, String initial) => Container(
        color: c.surfaceAlt,
        alignment: Alignment.center,
        child: Text(initial,
            style: TextStyle(
                color: c.primary,
                fontWeight: FontWeight.w900,
                fontSize: 16)),
      );

  Widget _notificationsStrip(AppColors c, UserSession session) {
    final tint = c.isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFEFF6FF);
    final accent = const Color(0xFF2563EB);
    final invoiceCount = session.invoiceCount;
    final due = session.dueAmount;
    return Container(
      padding: const EdgeInsets.all(Gaps.md),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.campaign_outlined, color: accent, size: 18),
            const SizedBox(width: 8),
            Text('Notifications',
                style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          _notifRow(
            c,
            '#$invoiceCount invoices are due',
            onTap: () => context.go('/instructor/reports/outstanding'),
          ),
          const SizedBox(height: 6),
          _notifRow(
            c,
            'RM ${due.toStringAsFixed(2)} total due amt',
            onTap: () => context.go('/instructor/reports/outstanding'),
          ),
        ],
      ),
    );
  }

  Widget _notifRow(AppColors c, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: c.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          Icon(Icons.chevron_right, color: c.primary, size: 18),
        ]),
      ),
    );
  }

  Widget _actionGrid(AppColors c) {
    final tiles = <_ActionTile>[
      _ActionTile(Icons.alarm, 'Training Time', () => context.push('/training')),
      _ActionTile(Icons.person_search, 'Activities',
          () => context.push('/instructor/reports/activity')),
      _ActionTile(Icons.assignment_turned_in_outlined, 'Update Attendance',
          () => context.push('/attendance')),
      _ActionTile(Icons.receipt_long, 'Receipt',
          () => context.push('/instructor/reports/receipt')),
      _ActionTile(Icons.school, 'Grading Schedule',
          () => context.push('/instructor/reports/grading-schedule')),
      _ActionTile(Icons.emoji_events, 'Tournament Schedule',
          () => context.push('/instructor/reports/tournament')),
      _ActionTile(Icons.people_alt_outlined, 'Collections',
          () => context.go('/instructor/collections')),
      _ActionTile(Icons.receipt_long_outlined, 'Missing Invoice',
          () => context.push('/instructor/reports/missing-invoice')),
      _ActionTile(Icons.savings, 'Fee Master',
          () => context.push('/instructor/reports/fee-master')),
      _ActionTile(Icons.people_alt, 'New Student',
          () => context.push('/instructor/reports/new-student')),
      _ActionTile(Icons.receipt, 'Payment Slip',
          () => context.push('/instructor/reports/payment-slip')),
      _ActionTile(Icons.apps, 'More', () => _openMoreSheet(context)),
    ];
    return Container(
      padding: const EdgeInsets.all(Gaps.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: c.border),
        boxShadow: Shadows.card(c),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 100,
        ),
        itemCount: tiles.length,
        itemBuilder: (_, i) => _tile(c, tiles[i]),
      ),
    );
  }

  Widget _tile(AppColors c, _ActionTile t) {
    return InkWell(
      onTap: t.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(t.icon, color: c.primary, size: 18),
            ),
            const SizedBox(height: 8),
            Text(t.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _openMoreSheet(BuildContext context) {
    final c = context.appColors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          Text('More options',
              style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 10),
          ListTile(
            leading: Icon(Icons.support_agent, color: c.primary),
            title: const Text('Help Desk'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/instructor/settings');
            },
          ),
          ListTile(
            leading: Icon(Icons.payments_outlined, color: c.primary),
            title: const Text('Reimbursement'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/instructor/reports/reimbursement');
            },
          ),
          ListTile(
            leading: Icon(Icons.swap_horiz, color: c.primary),
            title: const Text('Switch Branch'),
            onTap: () {
              Navigator.pop(ctx);
              context.go('/instructor/settings');
            },
          ),
        ]),
      ),
    );
  }

  Widget _latestUpdates(AppColors c, UserSession session) {
    final rows = session.clubStatsRows;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.border),
        boxShadow: Shadows.card(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.md, Gaps.md, Gaps.sm),
            child: Row(children: [
              Icon(Icons.update, color: c.primary, size: 18),
              const SizedBox(width: 8),
              Text('Latest Updates',
                  style: TextStyle(
                      color: c.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(Gaps.sm, 0, Gaps.sm, Gaps.sm),
            padding: const EdgeInsets.all(Gaps.md),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.border),
            ),
            child: rows.isEmpty
                ? Text('No updates yet.',
                    style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500))
                : Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0)
                          Divider(height: 12, color: c.border),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  (rows[i]['text'] ?? '').toString(),
                                  style: TextStyle(
                                      color: c.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ),
                            Text((rows[i]['id'] ?? 0).toString(),
                                style: TextStyle(
                                    color: c.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _latestNewsHeader(AppColors c) {
    return Text('Latest News',
        style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16));
  }

  Widget _latestNews(AppColors c, UserSession session) {
    // The instructor API leaves `mynews` empty by default — fall back to
    // `myoffers` so the section still shows live content.
    final items =
        session.myNews.isNotEmpty ? session.myNews : session.myOffers;
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.border),
        ),
        child: Text('No news yet.',
            style: TextStyle(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      );
    }
    return Column(
      children: [
        for (final n in items) _newsCard(c, n),
      ],
    );
  }

  Widget _newsCard(AppColors c, dynamic n) {
    final m = n is Map ? n : const {};
    final title = (m['title'] ?? m['header'] ?? m['name'] ?? '').toString();
    final body =
        (m['body'] ?? m['description'] ?? m['details'] ?? m['text'] ?? '')
            .toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(Gaps.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
        boxShadow: Shadows.card(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(title,
                style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}

class _ActionTile {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _ActionTile(this.icon, this.label, this.onTap);
}
