import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_icon_button.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int active = 0;
  List<dynamic>? _liveBookings;
  List<dynamic>? _allBookings;
  bool _bookingsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _bookingsLoading = true);
    await Future.wait([
      _safeFetch(Api.classBookingNextBookings).then((v) => _liveBookings = v),
      _safeFetch(Api.classBookingGetBookings).then((v) => _allBookings = v),
    ]);
    if (mounted) setState(() => _bookingsLoading = false);
  }

  Future<List<dynamic>?> _safeFetch(Future<dynamic> Function() fn) async {
    try {
      final resp = await fn();
      if (resp is List) return resp;
      if (resp is Map && resp['data'] is List) return resp['data'] as List;
      return null;
    } catch (e) {
      debugPrint('schedule fetch failed: $e');
      return null;
    }
  }

  Map<String, List<dynamic>> _groupBookingsByDate() {
    final result = <String, List<dynamic>>{};
    for (final b in (_allBookings ?? const <dynamic>[])) {
      if (b is! Map) continue;
      final date = (b['date'] ?? b['bookingDate'] ?? b['day'] ?? 'Unknown').toString();
      result.putIfAbsent(date, () => <dynamic>[]).add(b);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final day = kSchedule[active];
    return Container(
      color: c.background,
      child: Column(
        children: [
          AppHeader(
            title: 'Schedule',
            subtitle: 'Feb 2026 · Week 4',
            trailing: AppIconButton(
              icon: Icons.swap_horiz,
              onPressed: () {},
              backgroundColor: c.surfaceAlt,
              foregroundColor: c.primary,
            ),
          ),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Gaps.xl, vertical: 10),
              itemCount: kSchedule.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final d = kSchedule[i];
                final isActive = i == active;
                return InkWell(
                  onTap: () => setState(() => active = i),
                  borderRadius: BorderRadius.circular(Radii.lg),
                  child: Container(
                    width: 62,
                    decoration: BoxDecoration(
                      color: isActive ? c.primary : c.surface,
                      borderRadius: BorderRadius.circular(Radii.lg),
                      border: (!isActive && c.isDark) ? Border.all(color: c.border) : null,
                      boxShadow: !isActive ? Shadows.card(c) : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(d.day, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? Colors.white.withOpacity(0.85) : c.textSecondary, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(d.date, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isActive ? Colors.white : c.textPrimary)),
                        if (d.sessions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(width: 4, height: 4, decoration: BoxDecoration(color: isActive ? Colors.white : c.primary, borderRadius: BorderRadius.circular(2))),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 140),
              children: [
                _liveBookingsBanner(c),
                _liveAllBookingsCard(c),
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 14),
                  child: Text(
                    day.sessions.isEmpty ? 'Rest Day' : '${day.sessions.length} session${day.sessions.length > 1 ? 's' : ''} scheduled',
                    style: TextStyle(color: c.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                if (day.sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(children: [
                      Icon(Icons.hotel, size: 40, color: c.textMuted),
                      const SizedBox(height: 12),
                      Text('Enjoy your rest day', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Recovery is part of the journey', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ]),
                  ),
                ...day.sessions.map((s) => _sessionCard(c, s)),
                const SizedBox(height: 16),
                _holidaysCard(c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(AppColors c, Session s) {
    final parts = s.time.split(' ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Column(children: [
              Text(parts[0], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
              if (parts.length > 1) Text(parts[1], style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w700)),
            ]),
          ),
          Container(width: 4, height: 60, margin: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.access_time, size: 12, color: c.textSecondary),
                  const SizedBox(width: 4),
                  Text(s.duration, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 10),
                  Icon(Icons.person_outline, size: 12, color: c.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(child: Text(s.trainer, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _actBtn(c, 'Details', false),
                  const SizedBox(width: 8),
                  _actBtn(c, 'Remind Me', true),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actBtn(AppColors c, String l, bool filled) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: filled ? c.primary : c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.sm)),
        child: Text(l, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: filled ? Colors.white : c.textPrimary)),
      );

  Widget _liveBookingsBanner(AppColors c) {
    if (_bookingsLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: c.primary),
          ),
          const SizedBox(width: 8),
          Text('Loading live bookings…', style: TextStyle(fontSize: 12, color: c.textSecondary)),
        ]),
      );
    }
    final bookings = _liveBookings;
    if (bookings == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
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
              'LIVE · Next Bookings (${bookings.length})',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            bookings.isEmpty
                ? 'No upcoming bookings from server.'
                : bookings.take(3).map((b) {
                    if (b is Map) {
                      return '• ${b['text'] ?? b['title'] ?? b['name'] ?? b.toString()}';
                    }
                    return '• $b';
                  }).join('\n'),
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _liveAllBookingsCard(AppColors c) {
    final all = _allBookings;
    if (all == null || all.isEmpty) return const SizedBox.shrink();
    final groups = _groupBookingsByDate();
    return Container(
      margin: const EdgeInsets.only(top: 10),
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
            Text('LIVE · All Bookings (${all.length})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          ...groups.entries.take(8).map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textPrimary)),
                    ...entry.value.take(4).map((b) {
                      if (b is! Map) return const SizedBox.shrink();
                      final t = b['text'] ?? b['title'] ?? b['className'] ?? b['name'] ?? '';
                      final time = b['time'] ?? b['trainingTime'] ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: Text('• $t${time != '' ? ' · $time' : ''}',
                            style: TextStyle(fontSize: 11, color: c.textSecondary)),
                      );
                    }),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _holidaysCard(AppColors c) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.isDark ? const Color(0xFF2D1A0A) : const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: c.isDark ? const Color(0xFF3F2410) : const Color(0xFFFDE68A), shape: BoxShape.circle),
              child: Icon(Icons.wb_sunny, color: c.warning, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upcoming Holidays', style: TextStyle(color: c.isDark ? const Color(0xFFFDBA74) : const Color(0xFF92400E), fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  ...kHolidays.map((h) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• ${h.date} — ${h.name}', style: TextStyle(fontSize: 12, color: c.isDark ? const Color(0xFFFED7AA) : const Color(0xFF92400E))),
                      )),
                ],
              ),
            ),
          ],
        ),
      );
}
