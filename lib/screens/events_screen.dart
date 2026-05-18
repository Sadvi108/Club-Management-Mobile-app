import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// Events & Competition — fully live-data screen.
///
/// Sources merged:
///   • /Reports/TournamentSummary — primary upcoming events
///   • /Reports/Activity         — academy activities / one-off events
///   • UserSession.myOffers      — surfaced offers from HomePageStats
///   • UserSession.myNews        — surfaced news from HomePageStats
///   • /Reports/GradingSchedule  — past grades shown as "certificates"
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int tab = 0;
  static const _tabs = ['Upcoming', 'Registered', 'Certificates'];

  bool _loading = false;
  List<Map<String, dynamic>> _events = const [];
  List<Map<String, dynamic>> _certs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _safeRows(Api.reportsTournamentSummary),
        _safeRows(Api.reportsActivity),
        _safeRows(Api.reportsGradingSchedule),
      ]);
      final tournaments = results[0];
      final activities  = results[1];
      final grading     = results[2];

      // Merge tournaments + activities into one event list.
      final merged = <Map<String, dynamic>>[
        ...tournaments.map((m) => {...m, '_kind': 'tournament'}),
        ...activities.map((m) => {...m, '_kind': 'activity'}),
      ];
      // De-dupe by id/name when present.
      final seen = <String>{};
      _events = merged.where((m) {
        final key = (m['id'] ?? m['name'] ?? m['title'] ?? '').toString();
        if (key.isEmpty) return true;
        if (seen.contains(key)) return false;
        seen.add(key);
        return true;
      }).toList();

      // Past grades → certificate cards, scoped to the active student.
      final now = DateTime.now();
      final scopedGrading = UserSession.instance
          .filterByActiveStudent(grading)
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m));
      _certs = scopedGrading.where((m) {
        final d = _parseDate(_pick(m, ['date', 'gradingDate', 'examDate'], ''));
        return d != null && d.isBefore(now);
      }).toList();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _safeRows(
      Future<dynamic> Function([Map<String, dynamic>]) fn) async {
    try {
      final resp = await fn(const {});
      final list = UserSession.findList(resp) ?? const [];
      return list
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e) {
      debugPrint('events fetch failed: $e');
      return const [];
    }
  }

  static String _pick(Map<String, dynamic> m, List<String> keys, String fallback) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return fallback;
  }

  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static int _daysTo(DateTime? d) {
    if (d == null) return 0;
    final diff = d.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  static bool _readRegistered(Map<String, dynamic> m) {
    final v = m['registered'] ?? m['isRegistered'] ?? m['status'];
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    return s == 'true' || s == '1' || s.contains('registered');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final liveOffers = session.myOffers.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    final liveNews   = session.myNews.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    final filtered = tab == 1 ? _events.where(_readRegistered).toList() : _events;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const AppHeader(title: 'Events & Competition', showBack: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.xl, 12, Gaps.xl, 12),
          child: Row(children: List.generate(_tabs.length, (i) {
            final active = tab == i;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < _tabs.length - 1 ? 8 : 0),
                child: InkWell(
                  onTap: () => setState(() => tab = i),
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? c.primary : c.surface,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: active ? c.primary : c.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(_tabs[i],
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : c.textSecondary)),
                  ),
                ),
              ),
            );
          })),
        ),
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            onRefresh: _load,
            child: tab != 2
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 40),
                    children: [
                      if (_loading) _loadingRow(c),
                      if (liveOffers.isNotEmpty || liveNews.isNotEmpty) ...[
                        _liveOffersCard(c, liveOffers, liveNews),
                        const SizedBox(height: 16),
                      ],
                      if (!_loading && filtered.isEmpty)
                        _emptyState(c, Icons.event_busy, 'No upcoming events',
                            'Tournaments and activities will appear here when scheduled.')
                      else
                        ...filtered.map((e) => _eventCard(c, e)),
                    ],
                  )
                : (_certs.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
                        children: [
                          const SizedBox(height: 40),
                          _emptyState(c, Icons.workspace_premium, 'No certificates yet',
                              'Your past grading certificates will show up here.'),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 40),
                        children: _certs.map((cert) => _certCard(c, cert)).toList(),
                      )),
          ),
        ),
      ]),
    );
  }

  Widget _loadingRow(AppColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
          ),
          const SizedBox(width: 8),
          Text('Loading events…',
              style: TextStyle(fontSize: 12, color: c.textSecondary)),
        ]),
      );

  Widget _liveOffersCard(
      AppColors c, List<Map<String, dynamic>> offers, List<Map<String, dynamic>> news) {
    String stripHtml(String s) =>
        s.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&nbsp;', ' ').trim();
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 4),
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
              'LIVE · Offers (${offers.length}) · News (${news.length})',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: c.primary,
                  letterSpacing: 1),
            ),
          ]),
          const SizedBox(height: 10),
          ...offers.take(3).map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_pick(o, ['name', 'title'], ''),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary)),
                    Text(stripHtml(_pick(o, ['description', 'value'], '')),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ],
                ),
              )),
          ...news.take(2).map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_pick(n, ['name', 'title'], ''),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary)),
                    Text(stripHtml(_pick(n, ['description', 'value'], '')),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _emptyState(AppColors c, IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gaps.xl, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: c.surface,
                  shape: BoxShape.circle,
                  boxShadow: Shadows.card(c)),
              child: Icon(icon, color: c.textMuted, size: 28),
            ),
            const SizedBox(height: 14),
            Text(title,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _eventCard(AppColors c, Map<String, dynamic> event) {
    final title    = _pick(event, ['title', 'name', 'eventName', 'tournamentName'], 'Event');
    final dateStr  = _pick(event, ['date', 'eventDate', 'startDate', 'tournamentDate'], '');
    final location = _pick(event, ['location', 'venue', 'place', 'address'], '');
    final imageUrl = _pick(event, ['image', 'imageUrl', 'banner', 'pic'], '');
    final category = _pick(event,
        ['category', 'type', 'tournamentType', 'activityType'],
        (event['_kind'] ?? 'event').toString());
    final registered = _readRegistered(event);
    final countdown  = _daysTo(_parseDate(dateStr));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          SizedBox(
            height: 160,
            width: double.infinity,
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _heroPlaceholder(c),
                  )
                : _heroPlaceholder(c),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x000F172A), Color(0xCC0F172A)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(category.toUpperCase(),
                  style: TextStyle(
                      color: c.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
            ),
          ),
          if (registered)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: c.success, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.check_circle, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text('REGISTERED',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ]),
              ),
            ),
          if (countdown > 0)
            Positioned(
              bottom: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(Radii.md)),
                child: Column(children: [
                  Text('$countdown',
                      style: TextStyle(
                          color: c.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800)),
                  const Text('DAYS TO GO',
                      style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                ]),
              ),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (dateStr.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 14, color: c.textSecondary),
                      const SizedBox(width: 4),
                      Text(dateStr,
                          style: TextStyle(
                              fontSize: 11,
                              color: c.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ]),
                  if (location.isNotEmpty)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: c.textSecondary),
                      const SizedBox(width: 4),
                      Text(location,
                          style: TextStyle(
                              fontSize: 11,
                              color: c.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ]),
                ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: registered ? c.success : c.primary,
                  borderRadius: BorderRadius.circular(Radii.md)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(registered ? Icons.check : Icons.flash_on,
                    color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(registered ? 'View Details' : 'Register Now',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _heroPlaceholder(AppColors c) => Container(
        color: c.surfaceAlt,
        alignment: Alignment.center,
        child: Icon(Icons.image_outlined, color: c.textMuted, size: 32),
      );

  Widget _certCard(AppColors c, Map<String, dynamic> cert) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: c.isDark ? Border.all(color: c.border) : null,
          boxShadow: Shadows.card(c),
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: c.isDark
                      ? const [Color(0xFF3F2410), Color(0xFF2D1A0A)]
                      : const [Color(0xFFFEF3C7), Color(0xFFFDE68A)]),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(Icons.workspace_premium,
                size: 22,
                color: c.isDark
                    ? const Color(0xFFFDBA74)
                    : const Color(0xFF92400E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _pick(cert,
                    ['title', 'gradeName', 'beltName', 'name', 'description'],
                    'Grading'),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(
                'Issued by ${_pick(cert, ['issuer', 'examCenter', 'centerName'], 'Academy')} · ${_pick(cert, ['date', 'gradingDate', 'examDate'], '')}',
                style: TextStyle(fontSize: 11, color: c.textSecondary),
              ),
            ]),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
            child: Icon(Icons.download, size: 18, color: c.primary),
          ),
        ]),
      );
}
