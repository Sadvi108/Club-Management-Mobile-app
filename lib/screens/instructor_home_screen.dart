import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/notification_bell.dart';
import '../widgets/pressable.dart';

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
            padding: EdgeInsets.fromLTRB(
                Gaps.lg,
                (MediaQuery.of(context).padding.top > 0 ? 0.0 : 44.0) +
                    Gaps.lg,
                Gaps.lg,
                100),
            children: [
              _headerRow(c, name, clubName, session),
              const SizedBox(height: Gaps.lg),
              _notificationsStrip(c, session),
              const SizedBox(height: Gaps.lg),
              _quickAccessHeader(c, context),
              const SizedBox(height: Gaps.md),
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
    // White-card hero — same premium treatment as the student home:
    // gradient avatar ring, greeting, club chip, brand-mark tile, bell.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xxl),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Row(
        children: [
          // Gradient-ring avatar (club logo / initial).
          Container(
            width: 54, height: 54,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: c.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: c.primary.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
                border: Border.all(color: c.surface, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: pic.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: pic,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _initialAvatar(c, initial),
                    )
                  : _initialAvatar(c, initial),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome,',
                    style: TextStyle(
                        color: c.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2)),
                if (clubName.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.primary.withOpacity(0.28)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.shield_moon_outlined,
                          size: 11, color: c.primaryDark),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(clubName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: c.primaryDark)),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const NotificationBell(),
        ],
      ),
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
    // On-brand orange accent (design system: never blue/purple).
    final accent = c.primary;
    final invoiceCount = session.invoiceCount;
    final due = session.dueAmount;
    return Container(
      padding: const EdgeInsets.all(Gaps.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2D1A0A), const Color(0xFF3F2410)]
              : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: accent.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(isDark ? 0.12 : 0.08),
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
          // Both badges show /Reports/HomePageStats — the instructor's
          // personal-due summary. The API does not expose per-invoice
          // rows for that aggregate, so the rows are non-tappable.
          // The full branch outstanding list is still reachable via
          // Reports tab -> Outstanding Report.
          _notifRow(
            c,
            '#$invoiceCount invoices are due',
            icon: Icons.attach_money,
            iconBg: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF16A34A),
          ),
          const SizedBox(height: 6),
          _notifRow(
            c,
            'RM ${due.toStringAsFixed(2)} total due amt',
            icon: Icons.credit_card,
            iconBg: const Color(0xFFFFECEC),
            iconColor: const Color(0xFFDC2626),
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
          if (onTap != null)
            Icon(Icons.north_east, color: c.primary, size: 15),
        ]),
      ),
    );
  }

  /// Single source of truth for the Quick Access tiles. The on-screen
  /// 3x3 grid renders the first 9; "See all" opens the full list.
  List<_ActionTile> _buildTiles() {
    // Each tile carries its own accent so the grid reads at a glance rather
    // than as identical orange chips.
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
    return <_ActionTile>[
      _ActionTile(Icons.alarm, 'Training Time', amber,
          () => context.push('/instructor/reports/training-time')),
      _ActionTile(Icons.directions_run, 'Activities', teal,
          () => context.push('/instructor/reports/activity')),
      _ActionTile(Icons.assignment_turned_in_outlined, 'Update Attendance', green,
          () => context.push('/instructor/qr-scan')),
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
    ];
  }

  Widget _actionGrid(AppColors c) {
    final tiles = _buildTiles();
    // First 9 tiles in the visible 3x3 grid. The rest surface via the
    // "See all" sheet — matches the student home Quick Access pattern.
    final visible = tiles.take(9).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: visible.length,
      itemBuilder: (_, i) => _tile(c, visible[i]),
    );
  }

  /// Student-home-style section header for the Quick Access grid.
  Widget _quickAccessHeader(AppColors c, BuildContext ctx) {
    return Row(children: [
      Text('Quick Access',
          style: TextStyle(
              color: c.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
      const Spacer(),
      InkWell(
        onTap: () => _openMoreSheet(ctx),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(children: [
            Text('See all',
                style: TextStyle(
                    color: c.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, color: c.primary, size: 16),
          ]),
        ),
      ),
    ]);
  }

  Widget _tile(AppColors c, _ActionTile t) {
    return Pressable(
      onTap: t.onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: c.isDark ? Border.all(color: c.border) : null,
          boxShadow: Shadows.card(c),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: t.color.withOpacity(c.isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(t.icon, size: 22, color: t.color),
            ),
            const SizedBox(height: 8),
            Text(
              t.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMoreSheet(BuildContext context) {
    final c = context.appColors;
    final tiles = _buildTiles();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Text('Quick Access',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
              const Spacer(),
              InkWell(
                onTap: () => Navigator.pop(ctx),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32, height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: c.surfaceAlt, shape: BoxShape.circle),
                  child: Icon(Icons.close,
                      color: c.textSecondary, size: 18),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.builder(
                controller: scrollCtrl,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemCount: tiles.length,
                itemBuilder: (_, i) => InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    tiles[i].onTap();
                  },
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: _tile(c, tiles[i]),
                ),
              ),
            ),
          ]),
        ),
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
