import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/response_utils.dart';
import '../theme/app_theme.dart';
import '../theme/ion.dart';
import '../widgets/rn_kit.dart';
import '../widgets/use_api.dart';

/// One row of `/Reports/TournamentSummary`.
///
/// Note what is NOT here: a date. The report returns medal tallies per tournament, age
/// group and category — nothing that says when the event was or will be.
class TournamentRow {
  final String name;
  final String ageGroup;
  final String gender;
  final String category;
  final int players;
  final int gold;
  final int silver;
  final int bronze;

  const TournamentRow({
    required this.name,
    this.ageGroup = '',
    this.gender = '',
    this.category = '',
    this.players = 0,
    this.gold = 0,
    this.silver = 0,
    this.bronze = 0,
  });

  String get title => name.isNotEmpty
      ? name
      : category.isNotEmpty
          ? category
          : gender.isNotEmpty
              ? gender
              : 'Tournament';

  int get medals => gold + silver + bronze;

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}'.trim()) ?? 0;
  }

  static String _str(dynamic v) => v == null ? '' : '$v'.trim();

  factory TournamentRow.fromJson(Map<String, dynamic> m) => TournamentRow(
        name: _str(m['name'] ?? m['Name'] ?? m['tournamentName']),
        ageGroup: _str(m['ageGroup'] ?? m['AgeGroup']),
        gender: _str(m['gender'] ?? m['Gender']),
        category: _str(m['category'] ?? m['Category']),
        players: _int(m['playerCount'] ?? m['PlayerCount']),
        gold: _int(m['medalGold'] ?? m['MedalGold']),
        silver: _int(m['medalSilver'] ?? m['MedalSilver']),
        bronze: _int(m['medalBronze'] ?? m['MedalBronze']),
      );
}

List<TournamentRow> parseTournaments(dynamic res) {
  final rows = findRecordList(res);
  return rows
      .whereType<Map>()
      .map((m) => TournamentRow.fromJson(Map<String, dynamic>.from(m)))
      .toList(growable: false);
}

/// Distinct tournament names, in the order the report returned them.
List<String> tournamentNames(List<TournamentRow> rows) {
  final seen = <String>{};
  final out = <String>[];
  for (final r in rows) {
    if (r.name.isNotEmpty && seen.add(r.name)) out.add(r.name);
  }
  return out;
}

/// Port of `frontend/app/competition.tsx` (Expo v2.11.1).
///
/// TournamentSummary has no date column, so the Upcoming/Past tabs change the wording and the
/// status badge only — exactly as in the RN app. The tournament-name filter is the real one.
class CompetitionScreen extends StatefulWidget {
  final String title;
  const CompetitionScreen({super.key, this.title = 'Competition'});

  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

class _CompetitionScreenState extends State<CompetitionScreen> with UseApi<CompetitionScreen> {
  late final _data = useApi(() async => parseTournaments(
      await Api.reportsTournamentSummary({'fromDate': null, 'toDate': null, 'reportType': null})));
  late int _tab = widget.title.toLowerCase().contains('past') ? 1 : 0;
  String _selectedName = '';

  @override
  void initState() {
    super.initState();
    _data;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final all = _data.data ?? const <TournamentRow>[];
    final names = tournamentNames(all);
    final rows = _selectedName.isEmpty ? all : all.where((r) => r.name == _selectedName).toList();
    final loading = _data.loading;
    final error = _data.error;

    Widget pill(String label, bool active, VoidCallback onTap) => Touchable(
          onPress: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: active ? c.primary.hexA('18') : c.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.xl),
              border: Border.all(color: active ? c.primary : c.border),
            ),
            child: Text(label,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? c.primary : c.textSecondary)),
          ),
        );

    Widget medal(Color color, String label, int value) => Expanded(
          child: Column(children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.hexA('20')),
              child: Text('$value', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            ),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.textSecondary)),
          ]),
        );

    Widget tag(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.sm)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: c.textSecondary),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary)),
          ]),
        );

    final children = <Widget>[];
    if (loading && _data.data == null) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: c.primary)),
          const SizedBox(height: 12),
          Text('Loading competitions...', style: TextStyle(color: c.textSecondary, fontSize: 13)),
        ]),
      ));
    }
    if (error != null && !loading) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Icon(Ion.alertCircleOutline, size: 40, color: c.danger),
          const SizedBox(height: 8),
          Text('Failed to load competition data.', style: TextStyle(color: c.danger, fontSize: 13)),
          const SizedBox(height: 12),
          Touchable(
            onPress: _data.reload,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(Radii.sm)),
              child: const Text('Tap to retry',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ]),
      ));
    }
    if (!loading && error == null && rows.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Icon(Ion.medalOutline, size: 48, color: c.textMuted),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
                _tab == 0 ? 'No upcoming competitions scheduled right now.' : 'No past competition records found.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 14)),
          ),
        ]),
      ));
    }
    if (!loading && error == null) {
      for (final t in rows) {
        children.add(Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: rnCard(c, radius: Radii.xl, shadow: Shadows.card(c)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x18DB2777)),
                  child: const Icon(Ion.medal, size: 22, color: Color(0xFFDB2777)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.name.isNotEmpty
                            ? t.name
                            : t.category.isNotEmpty
                                ? t.category
                                : t.gender.isNotEmpty
                                    ? t.gender
                                    : 'Club Competition',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
                    if (t.ageGroup.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Age Group: ${t.ageGroup}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ],
                  ]),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(8)),
                  child: Text(_tab == 0 ? 'UPCOMING' : 'COMPLETED',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 0.5)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                if (t.gender.isNotEmpty) tag(Ion.personOutline, t.gender),
                tag(Ion.peopleOutline, '${t.players} Players'),
              ]),
            ),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('MEDAL STANDINGS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: c.textMuted)),
                ),
                Row(children: [
                  medal(const Color(0xFFF59E0B), 'Gold', t.gold),
                  const SizedBox(width: 8),
                  medal(const Color(0xFF9CA3AF), 'Silver', t.silver),
                  const SizedBox(width: 8),
                  medal(const Color(0xFFB45309), 'Bronze', t.bronze),
                  const SizedBox(width: 8),
                  medal(c.primary, 'Total Players', t.players),
                ]),
              ]),
            ),
          ]),
        ));
      }
    }

    return Scaffold(
      backgroundColor: c.background,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        RnHeader(title: widget.title, horizontal: Gaps.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.xl, vertical: 10),
          child: Row(children: [
            for (final (i, t) in const ['Upcoming', 'Past'].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Touchable(
                  activeOpacity: 0.8,
                  onPress: () => setState(() => _tab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: _tab == i ? c.primary : c.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(i == 0 ? Ion.timeOutline : Ion.trophyOutline,
                          size: 16, color: _tab == i ? Colors.white : c.textSecondary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('$t Competition',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _tab == i ? Colors.white : c.textSecondary)),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
          ]),
        ),
        if (names.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Gaps.xl, vertical: 6),
              children: [
                pill('All', _selectedName.isEmpty, () => setState(() => _selectedName = '')),
                for (final n in names) ...[
                  const SizedBox(width: 8),
                  pill(n, _selectedName == n, () => setState(() => _selectedName = _selectedName == n ? '' : n)),
                ],
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            onRefresh: _data.reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.xl, Gaps.xl, 120),
              children: children,
            ),
          ),
        ),
      ]),
    );
  }
}
