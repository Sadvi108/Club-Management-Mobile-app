import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/mock_data.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_icon_button.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});
  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  List<dynamic>? _centers;
  List<dynamic>? _instructors;
  List<dynamic>? _times;
  Object? _selectedCenterId;
  bool _loading = false;
  bool _timesLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
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
    return Container(
      color: c.background,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AppHeader(
              title: 'My Training',
              subtitle: '3 active programs',
              trailing: AppIconButton(
                icon: Icons.tune,
                onPressed: () {},
                backgroundColor: c.surfaceAlt,
                foregroundColor: c.primary,
              ),
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
                    RichText(text: const TextSpan(
                      children: [
                        TextSpan(text: '12 ', style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1)),
                        TextSpan(text: 'days', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 16, fontWeight: FontWeight.w500)),
                      ],
                    )),
                    const SizedBox(height: 4),
                    const Text('You\'re on fire! Don\'t break the chain.', style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 12)),
                    const SizedBox(height: 16),
                    Row(children: [
                      _heroStat('24', 'Classes'),
                      const SizedBox(width: 12),
                      _heroStat('18h', 'Trained'),
                      const SizedBox(width: 12),
                      _heroStat('3', 'Sports'),
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
              ...kPrograms.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _programCard(context, c, p),
                  )),
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
