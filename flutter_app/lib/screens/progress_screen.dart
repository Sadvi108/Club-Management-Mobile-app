import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/rn_api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../theme/ion.dart';
import '../widgets/rn_kit.dart';
import '../widgets/use_api.dart';

const _belts = [
  (name: 'White', color: Color(0xFFE5E7EB)),
  (name: 'Yellow', color: Color(0xFFFDE68A)),
  (name: 'Orange', color: Color(0xFFFED7AA)),
  (name: 'Green', color: Color(0xFF86EFAC)),
  (name: 'Blue', color: Color(0xFF93C5FD)),
  (name: 'Purple', color: Color(0xFFC4B5FD)),
  (name: 'Brown', color: Color(0xFFD6D3D1)),
  (name: 'Black', color: Color(0xFF1F2937)),
];

/// Port of `frontend/app/progress.tsx` (Expo v2.11.1).
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with UseApi<ProgressScreen> {
  final _range = RnApi.defaultRange();
  late final _info = useApi(RnApi.myInfo);
  late final _grading =
      useApi(() => RnApi.gradingSchedule({'fromDate': _range.fromDate, 'toDate': _range.toDate}));
  late final _att = useApi(() => RnApi.attendanceReport({'fromDate': _range.fromDate, 'toDate': _range.toDate}));

  @override
  void initState() {
    super.initState();
    _info;
    _grading;
    _att;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final user = session.authData ?? const <String, dynamic>{};

    final infoGrade = '${_info.data?['currentGrade'] ?? ''}';
    final grade = infoGrade.isNotEmpty
        ? infoGrade
        : ('${user['currentGrade'] ?? ''}'.isNotEmpty ? '${user['currentGrade']}' : '—');
    final beltName = (RegExp(r'\(([^)]+)\)').firstMatch(grade)?.group(1) ?? '—').trim();
    // A belt outside the list is unknown (-1), never silently White.
    final currentIdx = _belts.indexWhere((b) => b.name.toLowerCase() == beltName.toLowerCase());
    final nextBelt = currentIdx < 0 || currentIdx >= _belts.length - 1 ? null : _belts[currentIdx + 1];

    final records = session.scopedRows(_att.data).whereType<Map>().toList();
    final present =
        records.where((r) => RegExp('present', caseSensitive: false).hasMatch('${r['attendanceType'] ?? ''}')).length;
    final pct = records.isEmpty ? 0 : (present / records.length * 100).round();

    // Upcoming exams only (undated rows stay), soonest first.
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day);
    DateTime? at(dynamic iso) => DateTime.tryParse('${iso ?? ''}');
    final gradeRows = (_grading.data ?? const <Map<String, dynamic>>[]).where((g) {
      final t = at(g['examDate']);
      return t == null || !t.isBefore(cutoff);
    }).toList()
      ..sort((a, b) => (at(a['examDate']) ?? DateTime(0)).compareTo(at(b['examDate']) ?? DateTime(0)));

    Widget section(String t) => Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 10),
          child: Text(t, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
        );

    Widget commentCard({required IconData icon, required Widget child, VoidCallback? onTap}) {
      final card = Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: rnCard(c),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ]),
      );
      return onTap == null ? card : Touchable(activeOpacity: 0.8, onPress: onTap, child: card);
    }

    TextStyle commentTxt() => TextStyle(fontSize: 13, color: c.textPrimary, fontWeight: FontWeight.w500, height: 18 / 13);
    TextStyle commentMeta() => TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600);

    return Scaffold(
      backgroundColor: c.background,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const RnHeader(title: 'Progress', horizontal: Gaps.lg),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.xl, Gaps.xl, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(Radii.xxl),
                  boxShadow: Shadows.strong(c),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('CURRENT GRADE',
                          style: TextStyle(
                              color: Color(0xFFFFF7ED), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                      const SizedBox(height: 4),
                      Text(beltName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1)),
                      Text(grade,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12)),
                    ]),
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(color: Color(0x2EFFFFFF), shape: BoxShape.circle),
                    child: const Icon(Ion.ribbon, size: 48, color: Color(0xE6FFFFFF)),
                  ),
                ]),
              ),

              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(18),
                decoration: rnCard(c, radius: Radii.xl),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text('Belt Journey',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                  ),
                  SizedBox(
                    height: 32,
                    child: Row(children: [
                      for (var i = 0; i < _belts.length; i++)
                        Expanded(
                          flex: i < _belts.length - 1 ? 1 : 0,
                          child: Row(children: [
                            Builder(builder: (context) {
                              final done = i < currentIdx;
                              final current = i == currentIdx;
                              return Container(
                                width: current ? 32 : 26,
                                height: current ? 32 : 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: current ? c.primary : _belts[i].color,
                                  border: current ? Border.all(color: c.primary, width: 2) : null,
                                ),
                                child: done
                                    ? const Icon(Ion.checkmark, size: 12, color: Color(0xFF0F172A))
                                    : current
                                        ? const Icon(Ion.star, size: 14, color: Colors.white)
                                        : null,
                              );
                            }),
                            if (i < _belts.length - 1)
                              Expanded(
                                child: Container(height: 2, color: i < currentIdx ? c.primary : c.border),
                              ),
                          ]),
                        ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      for (var i = 0; i < _belts.length; i++)
                        SizedBox(
                          width: 26,
                          child: Text(_belts[i].name[0],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: i == currentIdx ? c.primary : c.textSecondary,
                                  fontWeight: i == currentIdx ? FontWeight.w800 : FontWeight.w600)),
                        ),
                    ]),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.only(top: 14),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: c.borderLight))),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('CURRENT BELT',
                              style: TextStyle(
                                  fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(beltName, style: TextStyle(fontSize: 15, color: c.textPrimary, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('NEXT BELT',
                              style: TextStyle(
                                  fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text(nextBelt?.name ?? '—',
                              style: TextStyle(fontSize: 15, color: c.textPrimary, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),

              section('Training Activity'),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: rnCard(c, radius: Radii.xl),
                child: Row(children: [
                  for (final s in [
                    (n: '$present', l: 'Present', accent: false),
                    (n: '${records.length}', l: 'Total', accent: false),
                    (n: '$pct%', l: 'Rate', accent: true),
                  ])
                    Expanded(
                      child: Column(children: [
                        Text(s.n,
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800, color: s.accent ? c.primary : c.textPrimary)),
                        const SizedBox(height: 2),
                        Text(s.l, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                ]),
              ),

              section('Upcoming Grading'),
              if (_grading.loading) const RnSpinner(vertical: 16),
              // A failed fetch is not an empty schedule.
              if (!_grading.loading && _grading.error != null)
                commentCard(
                  icon: Ion.cloudOfflineOutline,
                  onTap: _grading.reload,
                  child: Text("Couldn't load the grading schedule — tap to try again.", style: commentTxt()),
                ),
              if (!_grading.loading && _grading.error == null && gradeRows.isEmpty)
                commentCard(
                  icon: Ion.calendarOutline,
                  child: Text(
                      'No upcoming grading scheduled. Your academy will notify you when the next exam is set.',
                      style: commentTxt()),
                ),
              for (final g in gradeRows)
                commentCard(
                  icon: Ion.school,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${g['ecName'] ?? ''}'.trim().isEmpty ? 'Grading exam' : '${g['ecName']}'.trim(),
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: commentTxt()),
                    const SizedBox(height: 6),
                    Text(
                        () {
                          final parts = [fmtDateGB(g['examDate']), '${g['examTime'] ?? ''}']
                              .where((s) => s.isNotEmpty)
                              .join(' · ');
                          return parts.isEmpty ? 'Date to be confirmed' : parts;
                        }(),
                        maxLines: 1,
                        style: commentMeta()),
                    if ('${g['closingDate'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Registration closes ${fmtDateGB(g['closingDate'])}', maxLines: 1, style: commentMeta()),
                    ],
                  ]),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}
