import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../services/api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/filter_sheet.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});
  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  List<dynamic>? _centers;
  List<dynamic>? _instructors;
  List<dynamic>? _times;
  List<dynamic>? _attendance;
  Object? _selectedCenterId;
  bool _loading = false;
  bool _timesLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  /// Live training summary computed from /Reports/Attendance rows.
  /// Returns {streak, classes, percent} — all real, all per-account.
  Map<String, int> _trainingStats() {
    final rows = UserSession.instance
        .filterByActiveStudent(_attendance)
        .whereType<Map>()
        .toList();
    if (rows.isEmpty) {
      return const {'streak': 0, 'classes': 0, 'percent': 0};
    }
    bool isPresent(Map r) {
      final s = (r['attendanceType'] ?? r['status'] ?? r['value'] ?? '')
          .toString()
          .toLowerCase();
      return s.contains('present') || s == '1' || s == 'p' || s == 'yes';
    }

    final present = rows.where(isPresent).toList();
    final classes = present.length;
    final percent =
        rows.isEmpty ? 0 : ((classes / rows.length) * 100).round();

    // Streak: count consecutive calendar days (ending at the most recent
    // present record) that have a present row.
    final days = <DateTime>{};
    for (final r in present) {
      final raw = (r['recordedTime'] ?? r['date'] ?? '').toString();
      final d = DateTime.tryParse(raw);
      if (d != null) days.add(DateTime(d.year, d.month, d.day));
    }
    int streak = 0;
    if (days.isNotEmpty) {
      final sorted = days.toList()..sort((a, b) => b.compareTo(a));
      streak = 1;
      var cursor = sorted.first;
      for (var i = 1; i < sorted.length; i++) {
        if (sorted[i] == cursor.subtract(const Duration(days: 1))) {
          streak++;
          cursor = sorted[i];
        } else {
          break;
        }
      }
    }
    return {'streak': streak, 'classes': classes, 'percent': percent};
  }

  Future<List<dynamic>?> _safeList(Future<dynamic> Function() fn) async {
    try {
      final r = await fn();
      if (r is List) return r;
      if (r is Map && r['data'] is List) return r['data'] as List;
      return null;
    } catch (e) {
      debugPrint('training fetch failed: $e');
      return null;
    }
  }

  Future<void> _loadInitial() async {
    setState(() => _loading = true);
    await Future.wait([
      _safeList(Api.listingTrainingCenters).then((v) => _centers = v),
      _safeList(Api.listingInstructors).then((v) => _instructors = v),
      _safeList(() => Api.reportsAttendance(const {}))
          .then((v) => _attendance = v),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadTimesFor(Object centerId) async {
    setState(() {
      _timesLoading = true;
      _selectedCenterId = centerId;
      _times = null;
    });
    final v = await _safeList(() => Api.listingTrainingTimeByTcId(centerId));
    if (!mounted) return;
    setState(() {
      _times = v;
      _timesLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    context.watch<UserSession>(); // re-scope on student switch
    final stats = _trainingStats();
    return Container(
      color: c.background,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AppHeader(
              title: 'My Training',
              subtitle: '${stats['classes']} classes attended',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 140),
            sliver: SliverList.list(children: [
              // Weekly streak hero card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(Radii.xl),
                  boxShadow: Shadows.strong(c),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.emoji_events, color: Color(0xFFFFF7ED), size: 22),
                      SizedBox(width: 8),
                      Text('WEEKLY STREAK', style: TextStyle(color: Color(0xFFFFF7ED), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    ]),
                    const SizedBox(height: 6),
                    RichText(text: TextSpan(
                      children: [
                        TextSpan(text: '${stats['streak']} ', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1)),
                        const TextSpan(text: 'days', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 16, fontWeight: FontWeight.w500)),
                      ],
                    )),
                    const SizedBox(height: 4),
                    Text(
                      _loading
                          ? 'Loading your training record…'
                          : (stats['streak']! > 0
                              ? "You're on fire! Don't break the chain."
                              : 'Attend a class to start your streak.'),
                      style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      _heroStat('${stats['classes']}', 'Classes'),
                      const SizedBox(width: 12),
                      _heroStat('${stats['percent']}%', 'Attendance'),
                      const SizedBox(width: 12),
                      _heroStat(
                          UserSession.instance.currentGrade.isNotEmpty
                              ? UserSession.instance.currentGrade
                              : '—',
                          'Grade'),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _liveCentersCard(c),
              if (_times != null || _timesLoading) ...[
                const SizedBox(height: 12),
                _liveTimesCard(c),
              ],
              const SizedBox(height: 12),
              _liveInstructorsCard(c),
              const SizedBox(height: 20),
              Text('Enrolled Programs', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              _buildLivePrograms(c),
              // Add new program CTA
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: c.primary, style: BorderStyle.solid, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, color: c.primary, size: 22),
                    const SizedBox(width: 8),
                    Text('Add New Program', style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _liveCentersCard(AppColors c) {
    if (_loading) {
      return Row(children: [
        SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
        ),
        const SizedBox(width: 8),
        Text('Loading training centers…', style: TextStyle(fontSize: 12, color: c.textSecondary)),
      ]);
    }
    final centers = _centers;
    if (centers == null || centers.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.cloud_done, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text(
              'LIVE · Training Centers (${centers.length})',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1),
            ),
          ]),
          const SizedBox(height: 8),
          ...centers.take(8).map((tc) {
            final m = tc is Map ? tc : <dynamic, dynamic>{};
            final name = (m['text'] ?? m['name'] ?? m['value'] ?? tc).toString();
            final id = m['value'] ?? m['id'] ?? m['tcId'];
            final selected = id != null && id == _selectedCenterId;
            return InkWell(
              onTap: id == null ? null : () => _loadTimesFor(id),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      size: 14, color: selected ? c.primary : c.textMuted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(name, style: TextStyle(fontSize: 12, color: selected ? c.textPrimary : c.textSecondary))),
                ]),
              ),
            );
          }),
          if (centers.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+${centers.length - 5} more', style: TextStyle(fontSize: 11, color: c.textMuted, fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  Widget _liveInstructorsCard(AppColors c) {
    final list = _instructors;
    if (list == null || list.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.person_pin, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text('LIVE · Instructors (${list.length})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          ...list.take(6).map((i) {
            final name = i is Map ? (i['text'] ?? i['name'] ?? i['value'] ?? '').toString() : i.toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• $name', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            );
          }),
        ],
      ),
    );
  }

  Widget _liveTimesCard(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.access_time, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text('LIVE · Training Times',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          if (_timesLoading)
            Row(children: [
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)),
              const SizedBox(width: 8),
              Text('Loading…', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ])
          else if ((_times ?? const []).isEmpty)
            Text('No times for this center.', style: TextStyle(fontSize: 12, color: c.textSecondary))
          else
            ...(_times!).take(8).map((t) {
              final name = t is Map ? (t['text'] ?? t['trainingTime'] ?? t['name'] ?? t['value'] ?? '').toString() : t.toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $name', style: TextStyle(fontSize: 12, color: c.textSecondary)),
              );
            }),
        ],
      ),
    );
  }

  Widget _heroStat(String n, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(Radii.md)),
          child: Column(children: [
            Text(n, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(l, style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 10)),
          ]),
        ),
      );

  /// Renders one enrolled-program card derived from `session.myInfo`.
  /// Empty state shows when no relevant fields are returned.
  Widget _buildLivePrograms(AppColors c) {
    final session = context.watch<UserSession>();
    final info = session.myInfo ?? const <String, dynamic>{};
    final sport   = (info['sport']?.toString().trim().isNotEmpty == true)
        ? info['sport'].toString()
        : (session.tCenterName.isNotEmpty ? session.tCenterName : '');
    final trainer = session.instructorName;
    final level   = session.currentGrade;
    final pctStr  = session.attendancePercentage;
    final progress = num.tryParse(pctStr.replaceAll(RegExp(r'[^\d.]'), ''))?.toInt() ?? 0;

    if (sport.isEmpty && trainer.isEmpty && level.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.fitness_center_outlined, color: c.textMuted, size: 20),
              const SizedBox(width: 10),
              Text('No active programs yet',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Text(
              'Enrol via the academy or contact the help desk to get started.',
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.support_agent, size: 16),
              label: const Text('Help Desk'),
              onPressed: () => context.go('/profile'),
            ),
          ],
        ),
      );
    }

    final color = c.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
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
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.fitness_center, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sport.isNotEmpty ? sport : 'Training',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(level,
                      style: TextStyle(
                          color: color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800)),
                ),
            ]),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(children: [
                Container(height: 6, color: c.borderLight),
                FractionallySizedBox(
                  widthFactor: (progress / 100).clamp(0.0, 1.0),
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
              Text('Attendance',
                  style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('$progress%',
                  style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _programCard(BuildContext context, AppColors c, program) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CachedNetworkImage(imageUrl: program.image, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: c.surfaceAlt)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(program.sport, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: (program.color as Color).withOpacity(c.isDark ? 0.2 : 0.12), borderRadius: BorderRadius.circular(20)),
                      child: Text(program.level, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: program.color)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.person_outline, size: 16, color: c.textSecondary),
                  const SizedBox(width: 4),
                  Text(program.trainer, style: TextStyle(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progress to ${program.nextMilestone}', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                    Text('${program.progress}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: program.color)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: program.progress / 100,
                    backgroundColor: c.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation(program.color),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(Radii.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(Radii.md)),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.trending_up, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Upgrade Level', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
                    child: Icon(Icons.info_outline, color: c.textSecondary, size: 18),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
