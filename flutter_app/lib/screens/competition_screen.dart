import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/response_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

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
      .where((r) => r.name.isNotEmpty)
      .toList(growable: false);
}

/// Distinct tournament names, in the order the report returned them.
List<String> tournamentNames(List<TournamentRow> rows) {
  final seen = <String>{};
  final out = <String>[];
  for (final r in rows) {
    if (seen.add(r.name)) out.add(r.name);
  }
  return out;
}

/// Competition — tournament results and medal tallies.
///
/// The Expo screen carries "Upcoming"/"Past" tabs, but TournamentSummary has no date
/// column and the tabs there filter nothing — they only change the empty-state wording.
/// A control that appears to filter and does not is a bug report waiting to happen, so
/// this ports the filter that DOES work (by tournament name) and leaves the tabs out.
class CompetitionScreen extends StatefulWidget {
  const CompetitionScreen({super.key});

  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

class _CompetitionScreenState extends State<CompetitionScreen> {
  bool _loading = true;
  String? _error;
  List<TournamentRow> _rows = const [];
  String _selectedName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Api.reportsTournamentSummary();
      if (!mounted) return;
      setState(() {
        _rows = parseTournaments(res);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final names = tournamentNames(_rows);
    final visible = _selectedName.isEmpty
        ? _rows
        : _rows.where((r) => r.name == _selectedName).toList();

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const AppHeader(
          title: 'Competition',
          subtitle: 'Tournament results and medals',
          showBack: true,
        ),
        if (names.length > 1) _filterPills(c, names),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                        Gaps.lg, Gaps.md, Gaps.lg, Gaps.xxxl),
                    children: [
                      if (_error != null) _errorBlock(c),
                      if (_error == null && visible.isEmpty) _emptyBlock(c),
                      if (visible.isNotEmpty) _totals(c, visible),
                      for (final r in visible) _card(c, r),
                    ],
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _filterPills(AppColors c, List<String> names) => SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: 4),
          children: [
            _pill(c, 'All', _selectedName.isEmpty, () => setState(() => _selectedName = '')),
            for (final n in names)
              _pill(c, n, _selectedName == n,
                  () => setState(() => _selectedName = _selectedName == n ? '' : n)),
          ],
        ),
      );

  Widget _pill(AppColors c, String label, bool active, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: Gaps.sm),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            constraints: const BoxConstraints(maxWidth: 200),
            decoration: BoxDecoration(
              color: active ? c.primary : c.surface,
              borderRadius: BorderRadius.circular(Radii.xxl),
              border: Border.all(color: active ? c.primary : c.border),
            ),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: active ? Colors.white : c.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );

  Widget _totals(AppColors c, List<TournamentRow> rows) {
    var g = 0, s = 0, b = 0, p = 0;
    for (final r in rows) {
      g += r.gold;
      s += r.silver;
      b += r.bronze;
      p += r.players;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: Gaps.md),
      padding: const EdgeInsets.all(Gaps.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _tally(c, 'Gold', g, const Color(0xFFEAB308)),
        _tally(c, 'Silver', s, const Color(0xFF94A3B8)),
        _tally(c, 'Bronze', b, const Color(0xFFB45309)),
        _tally(c, 'Entries', p, c.primary),
      ]),
    );
  }

  Widget _tally(AppColors c, String label, int value, Color color) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$value',
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11)),
      ]);

  Widget _card(AppColors c, TournamentRow r) {
    final meta = [r.ageGroup, r.gender, r.category]
        .where((s) => s.isNotEmpty)
        .join(' - ');

    return Container(
      margin: const EdgeInsets.only(bottom: Gaps.sm),
      padding: const EdgeInsets.all(Gaps.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
            child: Icon(Icons.emoji_events, size: 18, color: c.primary),
          ),
          const SizedBox(width: Gaps.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: c.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w800)),
              if (meta.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                ),
            ]),
          ),
        ]),
        if (r.medals > 0 || r.players > 0) ...[
          const SizedBox(height: Gaps.sm),
          Wrap(spacing: Gaps.sm, runSpacing: 6, children: [
            if (r.gold > 0) _chip(c, '${r.gold} gold', const Color(0xFFEAB308)),
            if (r.silver > 0) _chip(c, '${r.silver} silver', const Color(0xFF94A3B8)),
            if (r.bronze > 0) _chip(c, '${r.bronze} bronze', const Color(0xFFB45309)),
            if (r.players > 0) _chip(c, '${r.players} entered', c.primary),
          ]),
        ],
      ]),
    );
  }

  Widget _chip(AppColors c, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.xxl),
        ),
        child: Text(label,
            style:
                TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
      );

  Widget _errorBlock(AppColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          Icon(Icons.error_outline, size: 40, color: c.danger),
          const SizedBox(height: Gaps.sm),
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.danger, fontSize: 13)),
          TextButton(onPressed: _load, child: const Text('Tap to retry')),
        ]),
      );

  Widget _emptyBlock(AppColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(children: [
          Icon(Icons.military_tech_outlined, size: 48, color: c.textMuted),
          const SizedBox(height: Gaps.sm),
          Text(
              _selectedName.isEmpty
                  ? 'No competition records found.'
                  : 'No records for $_selectedName.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 14)),
        ]),
      );
}
