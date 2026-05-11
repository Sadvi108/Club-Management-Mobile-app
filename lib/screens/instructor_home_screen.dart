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
    final isDark = c.isDark;
    final accent = const Color(0xFF2563EB);
    final invoiceCount = session.invoiceCount;
    final due = session.dueAmount;
    return Container(
      padding: const EdgeInsets.all(Gaps.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFF0F9FF), const Color(0xFFEFF6FF)],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: accent.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(isDark ? 0.10 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.campaign_outlined, color: accent, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Notifications',
                style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.2)),
          ]),
          const SizedBox(height: 12),
          _notifRow(
            c,
            '#$invoiceCount invoices are due',
            icon: Icons.attach_money,
            iconBg: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF16A34A),
            onTap: () => context.go('/instructor/reports/outstanding'),
          ),
          const SizedBox(height: 6),
          _notifRow(
            c,
            'RM ${due.toStringAsFixed(2)} total due amt',
            icon: Icons.credit_card,
            iconBg: const Color(0xFFFFECEC),
            iconColor: const Color(0xFFDC2626),
            onTap: () => context.go('/instructor/reports/outstanding'),
          ),
        ],
      ),
    );
  }

  Widget _notifRow(
    AppColors c,
    String text, {
    VoidCallback? onTap,
    IconData icon = Icons.info_outline,
    Color? iconBg,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg ?? c.surfaceAlt,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor ?? c.primary, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: c.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ),
          Icon(Icons.north_east, color: c.primary, size: 15),
        ]),
      ),
    );
  }

  Widget _actionGrid(AppColors c) {
    // Each tile carries its own accent so the grid reads at a glance rather
    // than as 12 identical orange chips.
    const amber  = Color(0xFFF59E0B);
    const teal   = Color(0xFF14B8A6);
    const green  = Color(0xFF10B981);
    const lime   = Color(0xFFCA8A04);
    const indigo = Color(0xFF6366F1);
    const gold   = Color(0xFFEAB308);
    const blue   = Color(0xFF3B82F6);
    const rose   = Color(0xFFEF4444);
    const yellow = Color(0xFFFBBF24);
    const cyan   = Color(0xFF06B6D4);
    const purple = Color(0xFFA855F7);
    const orange = Color(0xFFFB923C);
    final tiles = <_ActionTile>[
      _ActionTile(Icons.alarm, 'Training Time', amber, () => context.push('/training')),
      _ActionTile(Icons.directions_run, 'Activities', teal,
          () => context.push('/instructor/reports/activity')),
      _ActionTile(Icons.assignment_turned_in_outlined, 'Update Attendance', green,
          () => context.push('/attendance')),
      _ActionTile(Icons.receipt_long, 'Receipt', lime,
          () => context.push('/instructor/reports/receipt')),
      _ActionTile(Icons.school, 'Grading Schedule', indigo,
          () => context.push('/instructor/reports/grading-schedule')),
      _ActionTile(Icons.emoji_events, 'Tournament Schedule', gold,
          () => context.push('/instructor/reports/tournament')),
      _ActionTile(Icons.people_alt_outlined, 'Collections', blue,
          () => context.go('/instructor/collections')),
      _ActionTile(Icons.receipt_long_outlined, 'Missing Invoice', rose,
          () => context.push('/instructor/reports/missing-invoice')),
      _ActionTile(Icons.savings, 'Fee Master', yellow,
          () => context.push('/instructor/reports/fee-master')),
      _ActionTile(Icons.person_add_alt_1, 'New Student', cyan,
          () => context.push('/instructor/reports/new-student')),
      _ActionTile(Icons.receipt, 'Payment Slip', purple,
          () => context.push('/instructor/reports/payment-slip')),
      _ActionTile(Icons.apps, 'More', orange, () => _openMoreSheet(context)),
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
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 104,
        ),
        itemCount: tiles.length,
        itemBuilder: (_, i) => _tile(c, tiles[i]),
      ),
    );
  }

  Widget _tile(AppColors c, _ActionTile t) {
    final bg = t.color.withOpacity(c.isDark ? 0.18 : 0.12);
    return InkWell(
      onTap: t.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bg, t.color.withOpacity(c.isDark ? 0.30 : 0.22)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: t.color.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(t.icon, color: t.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(t.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: FontWeight.w700)),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.border),
          boxShadow: Shadows.card(c),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient orange header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: Gaps.md, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: c.gradient,
                ),
              ),
              child: Row(children: [
                const Icon(Icons.trending_up_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Latest Updates',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3),
                ),
                const Spacer(),
                if (rows.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${rows.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11)),
                  ),
              ]),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(Gaps.sm),
              child: rows.isEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Gaps.md, vertical: 20),
                      child: Row(children: [
                        Icon(Icons.inbox_outlined,
                            color: c.textMuted, size: 20),
                        const SizedBox(width: 10),
                        Text('No updates yet.',
                            style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ]),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Gaps.md, vertical: 11),
                            decoration: BoxDecoration(
                              color: i.isOdd
                                  ? (c.isDark
                                      ? Colors.white.withOpacity(0.02)
                                      : c.surfaceAlt.withOpacity(0.35))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(Radii.sm),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(
                                    color: c.primary.withOpacity(0.55),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                      (rows[i]['text'] ?? '').toString(),
                                      style: TextStyle(
                                          color: c.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: c.primary.withOpacity(0.10),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statCount(rows[i]),
                                    style: TextStyle(
                                        color: c.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _statCount(Map<String, dynamic> row) {
    for (final key in ['id', 'count', 'value', 'total']) {
      final v = row[key];
      if (v != null && key != 'value') return v.toString();
    }
    return '0';
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
  final Color color;
  final VoidCallback onTap;
  _ActionTile(this.icon, this.label, this.color, this.onTap);
}
