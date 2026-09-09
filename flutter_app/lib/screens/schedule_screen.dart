import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/filter_sheet.dart';

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

  // ─── Live 7-day strip + per-day bookings ────────────────────────────────
  /// Today through today+6, used to drive the day-picker strip.
  List<DateTime> get _days7 {
    final start = DateTime.now();
    return List.generate(7, (i) => DateTime(start.year, start.month, start.day + i));
  }

  static const _weekday = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  /// Current month + year label for the header (e.g. "Jun 2026").
  String _monthYearLabel() {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _bookingDate(Map row) {
    for (final k in ['date', 'bookingDate', 'startTime', 'classDate',
                      'sessionDate', 'time', 'sessionTime']) {
      final v = row[k];
      if (v == null) continue;
      if (v is DateTime) return v;
      final s = v.toString();
      if (s.isEmpty) continue;
      final parsed = DateTime.tryParse(s);
      if (parsed != null) return parsed;
    }
    return null;
  }

  List<Map<String, dynamic>> _bookingsForDay(DateTime d) {
    final src = (_liveBookings != null && _liveBookings!.isNotEmpty)
        ? _liveBookings
        : _allBookings;
    if (src == null) return const [];
    final out = <Map<String, dynamic>>[];
    for (final row in src) {
      if (row is! Map) continue;
      final bd = _bookingDate(row);
      if (bd != null && _isSameDay(bd, d)) {
        out.add(Map<String, dynamic>.from(row));
      }
    }
    return out;
  }

  String _pick(Map<String, dynamic> m, List<String> keys, [String fallback = '']) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final days = _days7;
    if (active >= days.length) active = 0;
    final selectedDay = days[active];
    final sessions = _bookingsForDay(selectedDay);
    return Stack(children: [
      Container(
      color: c.background,
      child: Column(
        children: [
          AppHeader(
            title: 'Schedule',
            subtitle: _monthYearLabel(),
            trailing: AppIconButton(
              icon: Icons.tune,
              onPressed: () async {
                final r = await showFilterSheet(context);
                if (r != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Filter applied: ${r.values.where((v) => v != null).length} field(s)')),
                  );
                }
              },
              backgroundColor: c.surfaceAlt,
              foregroundColor: c.primary,
            ),
          ),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Gaps.xl, vertical: 10),
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final d = days[i];
                final isActive = i == active;
                final hasSessions = _bookingsForDay(d).isNotEmpty;
                final dayLabel = _weekday[d.weekday - 1];
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
                        Text(dayLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isActive
                                    ? Colors.white.withOpacity(0.85)
                                    : c.textSecondary,
                                letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text('${d.day}',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isActive ? Colors.white : c.textPrimary)),
                        if (hasSessions) ...[
                          const SizedBox(height: 6),
                          Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: isActive ? Colors.white : c.primary,
                                  borderRadius: BorderRadius.circular(2))),
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
                    sessions.isEmpty
                        ? 'Rest Day'
                        : '${sessions.length} session${sessions.length > 1 ? 's' : ''} scheduled',
                    style: TextStyle(color: c.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                if (sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(children: [
                      Icon(Icons.hotel, size: 40, color: c.textMuted),
                      const SizedBox(height: 12),
                      Text('No classes scheduled',
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Recovery is part of the journey',
                          style:
                              TextStyle(fontSize: 12, color: c.textSecondary)),
                    ]),
                  ),
                ...sessions.map((s) => _liveSessionCard(c, s)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    ),
    Positioned(
      right: 18,
      bottom: 100,
      child: FloatingActionButton.extended(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/book-class'),
        icon: const Icon(Icons.add),
        label: const Text('Book a class', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    ),
    ]);
  }

  Widget _liveSessionCard(AppColors c, Map<String, dynamic> row) {
    final title = _pick(row,
        ['title', 'name', 'sessionName', 'className', 'programName', 'subject'],
        'Session');
    final trainer = _pick(row,
        ['trainer', 'instructorName', 'coach', 'instructor', 'sensei'],
        '');
    final duration = _pick(row,
        ['duration', 'durationMin', 'lengthMin'],
        '');
    // Time label: prefer raw HH:mm from date if present.
    String timeLabel = _pick(row, ['time', 'timeLabel', 'startTimeLabel'], '');
    final ampm = _pick(row, ['ampm', 'meridiem'], '');
    if (timeLabel.isEmpty) {
      final dt = _bookingDate(row);
      if (dt != null) {
        final h = dt.hour;
        final m = dt.minute.toString().padLeft(2, '0');
        final hh12 = ((h % 12) == 0 ? 12 : (h % 12)).toString();
        timeLabel = '$hh12:$m';
      }
    }
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
              Text(timeLabel.isEmpty ? '—' : timeLabel,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary)),
              if (ampm.isNotEmpty)
                Text(ampm,
                    style: TextStyle(
                        fontSize: 10,
                        color: c.textSecondary,
                        fontWeight: FontWeight.w700)),
            ]),
          ),
          Container(
              width: 4,
              height: 60,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: c.primary, borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
                const SizedBox(height: 6),
                Row(children: [
                  if (duration.isNotEmpty) ...[
                    Icon(Icons.access_time, size: 12, color: c.textSecondary),
                    const SizedBox(width: 4),
                    Text('$duration min',
                        style: TextStyle(
                            fontSize: 11,
                            color: c.textSecondary,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 10),
                  ],
                  if (trainer.isNotEmpty) ...[
                    Icon(Icons.person_outline, size: 12, color: c.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text(trainer,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: c.textSecondary,
                                fontWeight: FontWeight.w500))),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
          Text('Loading bookings…', style: TextStyle(fontSize: 12, color: c.textSecondary)),
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
            Icon(Icons.event_available, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text(
              'Upcoming Bookings (${bookings.length})',
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
            Icon(Icons.calendar_month, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text('All Bookings (${all.length})',
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

}
