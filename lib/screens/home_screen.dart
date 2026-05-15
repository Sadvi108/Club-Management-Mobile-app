import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/api_diagnostic_sheet.dart';
import '../widgets/notification_bell.dart';
import '../widgets/pressable.dart';
import '../widgets/responsive_body.dart';
import '../widgets/white_card_hero.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Warm tints from the D-Clix 2026 design system
  static const _peach100 = Color(0xFFFFF7ED);
  static const _peach200 = Color(0xFFFED7AA);
  static const _amber900 = Color(0xFF9A3412);
  static const _amber950 = Color(0xFF7C2D12);
  // Dark-mode-safe variants — same warm hue, AA contrast on dark surfaces.
  static const _peachDarkBg     = Color(0xFF2A1A0F);
  static const _peachDarkBorder = Color(0xFF5C3A1A);
  static const _peachDarkText   = Color(0xFFFDBA74);
  static const _peachDarkTextStrong = Color(0xFFFED7AA);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    // Live "Today's Class" booking — first row from session.todayBookings
    // (already loaded from /ClassBooking/NextBookings). Null when none.
    final Map<String, dynamic>? todayBooking =
        session.todayBookings.isNotEmpty ? session.todayBookings.first : null;
    // Never fall back to a mock name — if the API didn't return one, show
    // a neutral placeholder so it's obvious something needs to be fixed.
    final liveName = session.displayName.isNotEmpty ? session.displayName : 'Student';
    final liveMembership = session.clubName.isNotEmpty ? session.clubName : '';
    final livePhoto = session.studentPhoto.isNotEmpty ? session.studentPhoto : '';
    final liveBelt = session.currentGrade.isNotEmpty ? session.currentGrade : '';
    final liveDue = session.dueAmount > 0
        ? 'RM ${session.dueAmount.toStringAsFixed(2)}'
        : 'RM 0.00';
    final liveDueLabel = session.invoiceCount > 0
        ? '${session.invoiceCount} invoice(s) outstanding'
            '${session.earliestDueDate.isNotEmpty ? " · due ${session.earliestDueDate}" : ""}'
        : (session.earliestDueDate.isNotEmpty
            ? 'Due ${session.earliestDueDate}'
            : 'No invoices outstanding');
    return Container(
      color: c.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: ResponsiveBody(child: Column(
          children: [
            if (session.hasNewerVersion)
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(Gaps.xl, MediaQuery.of(context).padding.top + 8, Gaps.xl, 10),
                color: c.primary,
                child: Row(children: [
                  const Icon(Icons.system_update, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'New version available (${session.latestStoreVersion})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => UserSession.instance.dismissStoreVersionBanner(),
                  ),
                ]),
              ),
            // ─── White-card hero (D-Clix 2026 design) ──────────────────────
            WhiteCardHero(
              padding: EdgeInsets.fromLTRB(
                  Gaps.xl, MediaQuery.of(context).padding.top + 8, Gaps.xl, 24),
              child: Column(children: [
                Row(children: [
                  // 52×52 avatar with brand gradient ring
                  Container(
                    width: 52, height: 52,
                    padding: const EdgeInsets.all(2),
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
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: _peach100,
                      backgroundImage: livePhoto.isNotEmpty
                          ? CachedNetworkImageProvider(livePhoto)
                          : null,
                      child: livePhoto.isNotEmpty
                          ? null
                          : Text(
                              liveName.isNotEmpty
                                  ? liveName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  color: c.primaryDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Greeting + Gold Member chip
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello,',
                            style: TextStyle(
                                color: c.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3)),
                        Text(
                          liveName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2),
                        ),
                        if (liveMembership.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _peach100,
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(color: _peach200),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.star,
                                  size: 11, color: _amber900),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  liveMembership,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: _amber900,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3),
                                ),
                              ),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 36×36 brand mark tile
                  Container(
                    width: 36, height: 36,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _peach200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(kLogoAssetPath, fit: BoxFit.cover),
                    ),
                  ),
                  // 42×42 bell on warm tint with live unread badge
                  NotificationBell(
                    backgroundColor: _peach100,
                    borderColor: _peach200,
                    iconColor: c.primaryDark,
                    iconSize: 20,
                  ),
                ]),
                const SizedBox(height: 22),
                // Warm stat strip (dark-mode-aware tones)
                Builder(builder: (ctx) {
                  final dark = c.isDark;
                  final bg = dark ? _peachDarkBg : _peach100;
                  final br = dark ? _peachDarkBorder : _peach200;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(Radii.lg),
                      border: Border.all(color: br),
                    ),
                    child: Row(children: [
                      _warmStatCell(ctx,
                        session.attendancePercentage.isNotEmpty
                            ? '${session.attendancePercentage}%'
                            : '—',
                        'Attendance',
                      ),
                      Container(width: 1, color: br),
                      _warmStatCell(ctx,
                        liveBelt.isNotEmpty ? liveBelt.split(' ').first : '—',
                        'Current Belt',
                      ),
                      Container(width: 1, color: br),
                      _warmStatCell(ctx, '${session.unreadNotifications}', 'Unread'),
                    ]),
                  );
                }),
              ]),
            ),

            // Top quick bar (overlapping)
            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: Gaps.xl),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: c.surface, borderRadius: BorderRadius.circular(Radii.xl),
                  border: c.isDark ? Border.all(color: c.border) : null,
                  boxShadow: Shadows.card(c),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _quickTop(c, Icons.check_circle_outline, 'Attendance', () => context.push('/attendance')),
                  _quickTop(c, Icons.calendar_month_outlined, 'Timetable', () => context.go('/schedule')),
                  _quickTop(c, Icons.badge_outlined, 'Virtual ID', () => context.go('/profile')),
                  _quickTop(c, Icons.person_outline, 'Profile', () => context.go('/profile')),
                ]),
              ),
            ),

            // Fees due
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
              child: Pressable(
                onTap: () => context.go('/payments'),
                borderRadius: BorderRadius.circular(Radii.xl),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: c.isDark ? const [Color(0xFF2D1A0A), Color(0xFF3F2410)] : const [Color(0xFFFEF3C7), Color(0xFFFED7AA)]),
                    borderRadius: BorderRadius.circular(Radii.xl),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text('FEES DUE', style: TextStyle(color: c.isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => ApiDiagnosticSheet.open(context),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (c.isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412)).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.info_outline, size: 11, color: c.isDark ? const Color(0xFFFED7AA) : const Color(0xFF7C2D12)),
                                  const SizedBox(width: 3),
                                  Text('Diagnose', style: TextStyle(color: c.isDark ? const Color(0xFFFED7AA) : const Color(0xFF7C2D12), fontSize: 9, fontWeight: FontWeight.w800)),
                                ]),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 2),
                          Text(liveDue, style: TextStyle(color: c.isDark ? const Color(0xFFFED7AA) : const Color(0xFF7C2D12), fontSize: 24, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(liveDueLabel, style: TextStyle(color: c.isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412), fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(Radii.md)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [
                        Text('Pay Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 18),
            _invoicesPreview(c, session, context),
            const SizedBox(height: 20),
            _sectionHead(c, "Today's Class", 'See all', () => context.go('/schedule')),
            _buildTodayClassCard(c, context, todayBooking),

            const SizedBox(height: 20),
            _sectionHead(c, 'Quick Access', 'See all', () => _openQuickAccessSheet(context)),
            _buildQuickAccessGrid(c, context),
            const SizedBox(height: 22),
            _sectionHead(c, 'My Training', 'See all', () => context.go('/schedule')),
            _buildMyTrainingCarousel(c, session, context),
            const SizedBox(height: 22),
            _yourInfoCard(c, session),
          ],
        )),
      ),
    );
  }

  // ─── Quick Access (3 × 3 grid — 9 tiles visible) ────────────────────────
  //
  // Shows the first 9 entries from [kQuickCards]. The remaining tiles
  // (Competition, Chat Academy, More, etc.) appear when the user taps
  // "See all" — wired up via [_openQuickAccessSheet].
  Widget _buildQuickAccessGrid(AppColors c, BuildContext ctx) {
    const maxVisible = 9; // 3 × 3
    final visible = kQuickCards.take(maxVisible).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visible.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemBuilder: (_, i) => _quickAccessTile(c, ctx, visible[i]),
      ),
    );
  }

  Widget _quickAccessTile(AppColors c, BuildContext ctx, dynamic q) {
    return Pressable(
      onTap: () => ctx.push(q.route as String),
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
                color: (q.color as Color).withOpacity(c.isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(q.icon as IconData, size: 22, color: q.color as Color),
            ),
            const SizedBox(height: 8),
            Text(
              q.label as String,
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

  /// Full list of quick-access tiles in a bottom sheet, opened from the
  /// "See all" link beside the Quick Access section header.
  void _openQuickAccessSheet(BuildContext ctx) {
    final c = ctx.appColors;
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: ListView(controller: scroll, children: [
            Center(child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: c.border, borderRadius: BorderRadius.circular(2)),
            )),
            Text('Quick Access',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: kQuickCards.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (_, i) {
                final q = kQuickCards[i];
                return InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    ctx.push(q.route);
                  },
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(Radii.lg),
                      border: Border.all(color: c.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: q.color.withOpacity(0.14),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(q.icon, size: 22, color: q.color),
                        ),
                        const SizedBox(height: 8),
                        Text(q.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: c.textPrimary,
                                fontWeight: FontWeight.w700,
                                height: 1.25)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ─── My Training carousel (live from session.myInfo) ───────────────────
  Widget _buildMyTrainingCarousel(AppColors c, UserSession session, BuildContext ctx) {
    // Build one or more program cards from the live myInfo payload.
    // If multiple programs exist (some APIs return a list), each becomes
    // its own card. Otherwise fall back to a single composite card from
    // the top-level fields.
    final programs = _liveTrainingPrograms(session);
    if (programs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.xl),
            border: Border.all(color: c.border),
          ),
          child: Row(children: [
            Icon(Icons.fitness_center_outlined, size: 20, color: c.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No active training programs.',
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      );
    }
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
        itemCount: programs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _trainingCard(c, programs[i]),
      ),
    );
  }

  /// Build a list of training-program records from `session.myInfo`.
  ///
  /// Supports both response shapes:
  ///   • `myInfo['programs'] = [{sport, trainer, level, progress, color}, …]`
  ///   • single program inferred from top-level fields
  ///     (`tCenterName` / `instructorName` / `currentGrade` / `attendance%`)
  List<Map<String, dynamic>> _liveTrainingPrograms(UserSession session) {
    final result = <Map<String, dynamic>>[];
    final info = session.myInfo ?? const <String, dynamic>{};

    // Shape A: explicit programs list
    final maybeList = info['programs'] ?? info['classes'] ?? info['trainingPrograms'];
    if (maybeList is List) {
      for (final p in maybeList) {
        if (p is Map) {
          result.add({
            'sport':    (p['sport'] ?? p['name'] ?? p['title'] ?? 'Training').toString(),
            'trainer':  (p['trainer'] ?? p['instructorName'] ?? p['coach'] ?? '').toString(),
            'level':    (p['level'] ?? p['belt'] ?? p['grade'] ?? '').toString(),
            'progress': _num(p['progress'] ?? p['progressPercent'] ?? p['attendance'] ?? 0).toInt(),
            'color':    _programColor(p['color']?.toString() ?? p['sport']?.toString() ?? ''),
          });
        }
      }
    }

    // Shape B: derive a single program from top-level fields
    if (result.isEmpty) {
      final sport = session.tCenterName.isNotEmpty
          ? session.tCenterName
          : (info['sport']?.toString() ?? '');
      final trainer = session.instructorName;
      final level = session.currentGrade;
      final progressStr = session.attendancePercentage;
      final progress = num.tryParse(
              progressStr.replaceAll(RegExp(r'[^\d.]'), ''))?.toInt() ??
          0;
      if (sport.isNotEmpty || trainer.isNotEmpty || level.isNotEmpty) {
        result.add({
          'sport':    sport.isNotEmpty ? sport : 'Training',
          'trainer':  trainer,
          'level':    level,
          'progress': progress,
          'color':    _programColor(sport),
        });
      }
    }

    return result;
  }

  static num _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    return 0;
  }

  /// Choose a per-sport accent color (falls back to brand orange).
  static Color _programColor(String key) {
    final k = key.toLowerCase();
    if (k.contains('karate')) return const Color(0xFF6366F1); // indigo
    if (k.contains('boxing')) return const Color(0xFFEF4444); // red
    if (k.contains('taekwondo')) return const Color(0xFF0EA5E9); // sky
    if (k.contains('judo')) return const Color(0xFF10B981); // emerald
    if (k.contains('mma') || k.contains('mixed')) return const Color(0xFF8B5CF6); // violet
    if (k.contains('jiu') || k.contains('bjj')) return const Color(0xFFEAB308); // yellow
    return const Color(0xFFF97316); // primary
  }

  Widget _trainingCard(AppColors c, Map<String, dynamic> p) {
    final color = p['color'] as Color;
    final sport = (p['sport'] as String);
    final trainer = (p['trainer'] as String);
    final level = (p['level'] as String);
    final progress = (p['progress'] as int).clamp(0, 100);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        boxShadow: Shadows.card(c),
        border: c.isDark ? Border.all(color: c.border) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.fitness_center, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sport,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  if (trainer.isNotEmpty)
                    Text(trainer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (level.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(level,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3)),
              ),
          ]),
          const Spacer(),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(children: [
              Container(height: 6, color: c.borderLight),
              FractionallySizedBox(
                widthFactor: progress / 100.0,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: c.gradient),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text('Progress',
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$progress%',
                style: TextStyle(
                    color: c.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ]),
        ],
      ),
    );
  }

  /// Per D-Clix 2026 spec — amber text on peach background. In dark mode
  /// we swap to a desaturated warm pair so the AA contrast still holds.
  Widget _warmStatCell(BuildContext ctx, String value, String label) {
    final dark = Theme.of(ctx).brightness == Brightness.dark;
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: dark ? _peachDarkTextStrong : _amber950,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(),
            style: TextStyle(
                color: dark ? _peachDarkText : _amber900,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _quickTop(AppColors c, IconData icon, String label, VoidCallback onTap) => SizedBox(
        width: 72,
        child: InkWell(
          onTap: onTap,
          child: Column(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: c.primary),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: c.textPrimary, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  /// Today's Class card — renders from a single live booking row
  /// (`session.todayBookings.first`) or shows an empty-state when none.
  Widget _buildTodayClassCard(AppColors c, BuildContext ctx, Map<String, dynamic>? row) {
    if (row == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: c.isDark ? Border.all(color: c.border) : null,
            boxShadow: Shadows.card(c),
          ),
          child: Row(children: [
            Icon(Icons.hotel_outlined, color: c.textMuted, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No classes today — enjoy the rest day.',
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      );
    }
    final title = _pickStr(row,
        ['title', 'name', 'sessionName', 'className', 'programName'], 'Session');
    final trainer = _pickStr(row,
        ['trainer', 'instructorName', 'coach', 'instructor', 'sensei'], '');
    final duration = _pickStr(row, ['duration', 'durationMin', 'lengthMin'], '');
    final timeLabel = _pickStr(row,
        ['time', 'timeLabel', 'startTimeLabel'],
        _timeFromDateString(_pickStr(row,
            ['date', 'bookingDate', 'startTime', 'sessionTime', 'classDate'], '')));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
      child: Pressable(
        onTap: () => ctx.go('/schedule'),
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: c.isDark ? Border.all(color: c.border) : null,
            boxShadow: Shadows.card(c),
          ),
          child: Row(children: [
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                  color: c.primary, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [if (timeLabel.isNotEmpty) timeLabel,
                     if (duration.isNotEmpty) '$duration min'].join(' · '),
                    style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  if (trainer.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('with $trainer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 11)),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.sm)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.qr_code_2, size: 14, color: c.primary),
                const SizedBox(width: 4),
                Text('Check In',
                    style: TextStyle(
                        color: c.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  static String _pickStr(Map<String, dynamic> m, List<String> keys, String fallback) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return fallback;
  }

  static String _timeFromDateString(String s) {
    if (s.isEmpty) return '';
    final d = DateTime.tryParse(s);
    if (d == null) return '';
    final h = d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final hh12 = ((h % 12) == 0 ? 12 : (h % 12)).toString();
    final ampm = h < 12 ? 'AM' : 'PM';
    return '$hh12:$m $ampm';
  }

  /// Compact invoice preview — pulls straight from
  /// `session.outstandingList` so individual invoices are visible even
  /// if my homeStats parser misses the aggregate fields. Tap "View All"
  /// to open the full polished invoices screen.
  Widget _invoicesPreview(AppColors c, UserSession session, BuildContext ctx) {
    final raw = session.outstandingList ?? const [];
    final rows = raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    final total = _sumInvoices(rows);
    final preview = rows.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.xl),
          border: c.isDark ? Border.all(color: c.border) : null,
          boxShadow: Shadows.card(c),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header strip
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.primary.withOpacity(0.10), c.primary.withOpacity(0.04)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: c.gradient),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.receipt_long,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('My Invoices',
                      style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  Text(
                    rows.isEmpty
                        ? 'No outstanding invoices'
                        : '${rows.length} invoice${rows.length == 1 ? "" : "s"} · RM ${total.toStringAsFixed(2)}',
                    style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
              TextButton(
                onPressed: () => ctx.push('/invoices'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('View All',
                      style: TextStyle(
                          color: c.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                  Icon(Icons.arrow_forward, color: c.primary, size: 14),
                ]),
              ),
            ]),
          ),
          // Body: either a few invoice rows OR a "you're good" empty state
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Row(children: [
                Icon(Icons.check_circle_outline, color: c.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You\'re all paid up. Pull-to-refresh on this screen to recheck.',
                    style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            )
          else
            ...preview.asMap().entries.map((e) => _previewRow(c, e.key, e.value, e.key == preview.length - 1 && rows.length <= preview.length)),
          if (rows.length > preview.length)
            InkWell(
              onTap: () => ctx.push('/invoices'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: c.surfaceAlt.withOpacity(0.5),
                alignment: Alignment.center,
                child: Text(
                  '+ ${rows.length - preview.length} more invoice${rows.length - preview.length == 1 ? "" : "s"}',
                  style: TextStyle(
                      color: c.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _previewRow(AppColors c, int i, Map<String, dynamic> inv, bool isLast) {
    final title = _pickField(inv,
        ['invoiceName', 'description', 'particulars', 'name', 'invoiceTitle', 'item', 'feeType']);
    final dueDate = _pickField(inv,
        ['dueDate', 'invoiceDate', 'date', 'paymentDue', 'expiryDate']);
    final amount = _invoiceAmount(inv);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border.withOpacity(0.5))),
            ),
      child: Row(children: [
        Container(
          width: 6, height: 36,
          decoration: BoxDecoration(
            color: c.primary.withOpacity(0.7),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.isEmpty ? 'Invoice #${i + 1}' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            if (dueDate.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Due $dueDate',
                  style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600)),
            ],
          ]),
        ),
        Text('RM ${amount.toStringAsFixed(2)}',
            style: TextStyle(
                color: c.primary, fontSize: 14, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  static String _pickField(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '';
  }

  static num _invoiceAmount(Map<String, dynamic> m) {
    for (final k in const ['dueAmount', 'amount', 'amountDue', 'outstandingAmount',
        'balance', 'totalAmount', 'value', 'invoiceAmount']) {
      final v = m[k];
      if (v is num) return v;
      if (v is String) {
        final n = num.tryParse(v.replaceAll(RegExp(r'[^\d.\-]'), ''));
        if (n != null) return n;
      }
    }
    for (final entry in m.entries) {
      final k = entry.key.toString().toLowerCase();
      if (k.contains('amount') || k.contains('amt') ||
          (k.contains('due') && !k.contains('date'))) {
        final v = entry.value;
        if (v is num) return v;
        if (v is String) {
          final n = num.tryParse(v.replaceAll(RegExp(r'[^\d.\-]'), ''));
          if (n != null) return n;
        }
      }
    }
    return 0;
  }

  static num _sumInvoices(List<Map<String, dynamic>> rows) {
    num t = 0;
    for (final r in rows) t += _invoiceAmount(r);
    return t;
  }

  /// "Your info" card — mirrors the production student-home layout
  /// (orange header band + table of key/value rows). All fields pull
  /// from `session.myInfo` so the card auto-populates from the API.
  Widget _yourInfoCard(AppColors c, UserSession session) {
    final info = session.myInfo ?? const <String, dynamic>{};
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = info[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    final rows = <List<String>>[
      ['Registration No', pick(['registrationNo', 'registrationNumber', 'regNo'])],
      ['Student Code', pick(['studentCode', 'code', 'studentNo'])],
      ['Training Centre', pick(['tCenterName', 'trainingCenter', 'trainingCentre', 'tcName'])],
      ['Training Time', pick(['trainingTme', 'trainingTime', 'tTime'])],
      ['Exam Center', pick(['examCenterName', 'eCenterName', 'examCentre', 'examCenter'])],
      ['Instructor Name', pick(['instructorName', 'trainer', 'sensei'])],
    ];
    final visible = rows.where((r) => r[1].isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Gaps.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Orange header band
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: c.gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(children: [
            const Icon(Icons.badge_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text('Your info',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3)),
          ]),
        ),
        // Body table
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: List.generate(visible.length, (i) {
              final r = visible[i];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: i == visible.length - 1
                    ? null
                    : BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: c.border.withOpacity(0.5)),
                        ),
                      ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 130,
                    child: Text(r[0],
                        style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ),
                  Text(':  ',
                      style: TextStyle(
                          color: c.textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  Expanded(
                    child: Text(r[1],
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.35)),
                  ),
                ]),
              );
            }),
          ),
        ),
      ]),
    );
  }

  Widget _sectionHead(AppColors c, String title, String? linkText, VoidCallback? onLink) => Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            if (linkText != null)
              InkWell(onTap: onLink, child: Text(linkText, style: TextStyle(color: c.primary, fontSize: 12, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}
