import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../services/api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/filter_sheet.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  List<dynamic>? _grading;
  List<dynamic>? _activity;
  List<dynamic>? _tournament;
  List<dynamic>? _contribution;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<List<dynamic>?> _safe(Future<dynamic> Function() fn) async {
    try {
      final r = await fn();
      if (r is List) return r;
      if (r is Map && r['data'] is List) return r['data'] as List;
      return null;
    } catch (e) {
      debugPrint('progress fetch failed: $e');
      return null;
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _safe(Api.reportsGradingSchedule).then((v) => _grading = v),
      _safe(Api.reportsActivity).then((v) => _activity = v),
      _safe(Api.reportsTournamentSummary).then((v) => _tournament = v),
      _safe(Api.reportsContribution).then((v) => _contribution = v),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final liveBelt = session.currentGrade.isNotEmpty ? session.currentGrade : kStudent.belt;
    final liveStats = (session.clubStats ?? const []).whereType<Map>().toList();
    final addtnl = session.studentAddtnlInfo;
    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: AppHeader(
            title: 'Progress',
            showBack: true,
            trailing: AppIconButton(
              icon: Icons.tune,
              onPressed: () => showFilterSheet(context),
              backgroundColor: c.surfaceAlt,
              foregroundColor: c.primary,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 40),
          sliver: SliverList.list(children: [
            if (_loading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)),
                  const SizedBox(width: 8),
                  Text('Loading live progress…', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ]),
              ),
            // Fitness card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(Radii.xxl),
                boxShadow: Shadows.strong(c),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('FITNESS SCORE', style: TextStyle(color: Color(0xFFFFF7ED), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    RichText(text: TextSpan(children: [
                      TextSpan(text: '${kStudent.fitness}', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1)),
                      const TextSpan(text: '/100', style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 18, fontWeight: FontWeight.w600)),
                    ])),
                    const Text('Excellent shape — keep the momentum', style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 12)),
                  ]),
                ),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                  child: const Icon(Icons.fitness_center, size: 40, color: Color(0xE6FFFFFF)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            if (liveStats.isNotEmpty || addtnl != null) ...[
              _liveSnapshot(c, liveStats, addtnl),
              const SizedBox(height: 16),
            ],
            // Belt Journey
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: c.isDark ? Border.all(color: c.border) : null,
                boxShadow: Shadows.card(c),
              ),
              child: Column(children: [
                Row(children: [
                  Text('Belt Journey', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  for (int i = 0; i < kBelts.length; i++) ...[
                    _beltDot(kBelts[i], c),
                    if (i < kBelts.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: kBelts[i].done ? c.primary : c.border,
                        ),
                      ),
                  ]
                ]),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: kBelts.map((b) => SizedBox(
                        width: 26,
                        child: Text(b.name[0], textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: b.current ? c.primary : c.textSecondary, fontWeight: b.current ? FontWeight.w800 : FontWeight.w600)),
                      )).toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.borderLight))),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('CURRENT BELT', style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(liveBelt, style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('NEXT EXAM', style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('15 Apr 2026', style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            Text('Skill Breakdown', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: c.isDark ? Border.all(color: c.border) : null,
                boxShadow: Shadows.card(c),
              ),
              child: Column(
                children: kSkills.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        SizedBox(width: 80, child: Text(s.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary))),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: s.value / 100,
                              minHeight: 10,
                              backgroundColor: c.surfaceAlt,
                              valueColor: AlwaysStoppedAnimation(s.color),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(width: 30, child: Text('${s.value}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: s.color))),
                      ]),
                    )).toList(),
              ),
            ),
            const SizedBox(height: 22),
            Text('Achievement Badges', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: kAchievements.map((a) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: c.isDark ? Border.all(color: c.border) : null,
                          boxShadow: Shadows.card(c),
                        ),
                        child: Column(children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(color: a.color.withOpacity(c.isDark ? 0.2 : 0.12), shape: BoxShape.circle),
                            child: Icon(a.icon, size: 22, color: a.color),
                          ),
                          const SizedBox(height: 6),
                          Text(a.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: c.textPrimary, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  )).toList(),
            ),
            const SizedBox(height: 22),
            Text('Trainer Feedback', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...kTrainerComments.map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: c.isDark ? Border.all(color: c.border) : null,
                    boxShadow: Shadows.card(c),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                      child: Icon(Icons.chat_bubble_outline, size: 16, color: c.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('“${t.comment}”', style: TextStyle(fontSize: 13, color: c.textPrimary, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic, height: 1.4)),
                        const SizedBox(height: 6),
                        Text('— ${t.trainer} · ${t.date}', style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                )),
            const SizedBox(height: 22),
            if ((_grading ?? const []).isNotEmpty)
              _liveListCard(c, 'Grading Schedule', Icons.school, _grading!),
            if ((_grading ?? const []).isNotEmpty) const SizedBox(height: 12),
            if ((_activity ?? const []).isNotEmpty)
              _liveListCard(c, 'Activity', Icons.local_activity, _activity!),
            if ((_activity ?? const []).isNotEmpty) const SizedBox(height: 12),
            if ((_tournament ?? const []).isNotEmpty)
              _liveListCard(c, 'Tournament Summary', Icons.emoji_events, _tournament!),
            if ((_tournament ?? const []).isNotEmpty) const SizedBox(height: 12),
            if ((_contribution ?? const []).isNotEmpty)
              _liveListCard(c, 'Contribution', Icons.volunteer_activism, _contribution!),
          ]),
        ),
      ]),
    );
  }

  Widget _liveListCard(AppColors c, String title, IconData icon, List<dynamic> rows) {
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
            Icon(icon, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text('LIVE · $title (${rows.length})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          ...rows.take(8).map((r) {
            final m = r is Map ? r : <dynamic, dynamic>{};
            final t = (m['text'] ?? m['name'] ?? m['title'] ?? m['description'] ?? r).toString();
            final v = (m['value'] ?? m['date'] ?? '').toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text(t, style: TextStyle(fontSize: 12, color: c.textSecondary))),
                if (v.isNotEmpty)
                  Text(v, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _liveSnapshot(AppColors c, List<Map> stats, Map<String, dynamic>? addtnl) {
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
            Text('LIVE · Progress Snapshot',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          ]),
          const SizedBox(height: 10),
          if (addtnl != null) ...[
            _kvRow(c, 'Height', '${addtnl['height'] ?? '-'} cm'),
            _kvRow(c, 'School', '${addtnl['schoolname'] ?? '-'}'),
            _kvRow(c, 'Health', '${addtnl['healthstatus'] ?? '-'}'),
            const SizedBox(height: 8),
          ],
          ...stats.take(6).map((s) => _kvRow(c, '${s['text'] ?? ''}', '${s['value'] ?? ''}')),
        ],
      ),
    );
  }

  Widget _kvRow(AppColors c, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: TextStyle(fontSize: 12, color: c.textSecondary))),
          Text(v, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textPrimary)),
        ]),
      );

  Widget _beltDot(belt, AppColors c) {
    if (belt.current) {
      return Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle, border: Border.all(color: c.primary, width: 2)),
        child: const Icon(Icons.star, size: 14, color: Colors.white),
      );
    }
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(color: belt.color as Color, shape: BoxShape.circle),
      child: belt.done ? const Icon(Icons.check, size: 12, color: Color(0xFF0F172A)) : null,
    );
  }
}
