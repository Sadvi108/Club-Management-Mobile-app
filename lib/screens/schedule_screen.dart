import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/user_session.dart';
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
            subtitle: 'Feb 2026 · Week 4',
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
                // Holidays — awaiting holidays endpoint; mock placeholder kept intentionally.
                _holidaysCard(c),
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
        onPressed: _openBookClassSheet,
        icon: const Icon(Icons.add),
        label: const Text('Book a class', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    ),
    ]);
  }

  Future<void> _openBookClassSheet() async {
    final c = context.appColors;
    List<dynamic>? centers;
    List<dynamic>? instructors;
    try {
      final r1 = await Api.listingTrainingCenters();
      centers = r1 is List ? r1 : (r1 is Map && r1['data'] is List ? r1['data'] as List : <dynamic>[]);
      final r2 = await Api.listingInstructors();
      instructors = r2 is List ? r2 : (r2 is Map && r2['data'] is List ? r2['data'] as List : <dynamic>[]);
    } catch (e) {
      debugPrint('book class load failed: $e');
    }
    if (!mounted) return;

    final now = DateTime.now();
    dynamic centerId;
    dynamic instructorId;
    int month = now.month;
    int year = now.year;
    int packageTypeId = 1;
    dynamic packageId;
    List<dynamic>? packages;
    String? availability;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xxl)),
            ),
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 14),
                Text('Book a class', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary)),
                const SizedBox(height: 12),
                _bookDropdown(c, 'Training Center', centers, centerId, (v) => setSheet(() => centerId = v)),
                _bookDropdown(c, 'Instructor', instructors, instructorId, (v) => setSheet(() => instructorId = v)),
                Row(children: [
                  Expanded(child: _bookNumField(c, 'Month', month.toString(), (v) {
                    final n = int.tryParse(v);
                    if (n != null) setSheet(() => month = n);
                  })),
                  const SizedBox(width: 10),
                  Expanded(child: _bookNumField(c, 'Year', year.toString(), (v) {
                    final n = int.tryParse(v);
                    if (n != null) setSheet(() => year = n);
                  })),
                ]),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    if (centerId == null || instructorId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pick a center & instructor first')),
                      );
                      return;
                    }
                    try {
                      await Api.classBookingTrainingTimeWithDateAndInstructor(
                        month: month, year: year, tCenterId: centerId, instructorId: instructorId);
                      await Api.classBookingBookingsByInstructor(
                        instructorId: instructorId, month: month, year: year);
                      final r = await Api.classBookingSessionOrPackages(packageTypeId);
                      final list = r is List ? r : (r is Map && r['data'] is List ? r['data'] as List : <dynamic>[]);
                      final session = UserSession.instance;
                      final sid = session.authData?['studentId'] ?? session.authData?['id'] ?? 0;
                      String avail = '';
                      try {
                        final p = await Api.classBookingPackageInfo(sid);
                        avail = p?.toString() ?? '';
                      } catch (_) {}
                      setSheet(() {
                        packages = list;
                        availability = avail;
                      });
                    } catch (e) {
                      debugPrint('Book class load step failed: $e');
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load failed: $e')));
                    }
                  },
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: c.primary)),
                    child: Text('Load slots & packages', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
                if (packages != null) ...[
                  const SizedBox(height: 10),
                  Text('Packages', style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _bookDropdown(c, 'Package', packages, packageId, (v) async {
                    setSheet(() => packageId = v);
                    final session = UserSession.instance;
                    final sid = session.authData?['studentId'] ?? session.authData?['id'] ?? 0;
                    try {
                      final r = await Api.classBookingBookingCountByPackageSession(
                        packageTypeId: packageTypeId, packageId: v, studentId: sid, month: month, year: year);
                      setSheet(() => availability = r?.toString());
                    } catch (e) {
                      debugPrint('BookingCountByPackageSession failed: $e');
                    }
                  }),
                  if (availability != null && availability!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Availability: $availability', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                    ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final session = UserSession.instance;
                    final sid = session.authData?['studentId'] ?? session.authData?['id'];
                    try {
                      await Api.classBookingBookNow(<String, dynamic>{
                        'tCenterId': centerId,
                        'instructorId': instructorId,
                        'month': month,
                        'year': year,
                        'packageTypeId': packageTypeId,
                        'packageId': packageId,
                        'studentId': sid,
                      });
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking confirmed')));
                      _loadBookings();
                    } catch (e) {
                      debugPrint('BookNow failed: $e');
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
                    }
                  },
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: c.gradient), borderRadius: BorderRadius.circular(Radii.md), boxShadow: Shadows.strong(c)),
                    child: const Text('Confirm booking', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _bookDropdown(AppColors c, String label, List<dynamic>? items, dynamic value, ValueChanged<dynamic> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md), border: Border.all(color: c.border)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<dynamic>(
              isExpanded: true,
              value: value,
              hint: Text(items == null ? 'Loading…' : 'Select', style: TextStyle(color: c.textMuted, fontSize: 13)),
              items: (items ?? const <dynamic>[]).map((e) {
                final m = e is Map ? e : <dynamic, dynamic>{};
                final id = m['id'] ?? m['code'] ?? m['value'] ?? e;
                final name = (m['name'] ?? m['text'] ?? m['title'] ?? e).toString();
                return DropdownMenuItem<dynamic>(value: id, child: Text(name, style: TextStyle(color: c.textPrimary, fontSize: 13)));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _bookNumField(AppColors c, String label, String initial, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: initial),
          keyboardType: TextInputType.number,
          onChanged: onChanged,
        ),
      ]),
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

  /// Renders a session card from a live `/ClassBooking/*` row. Field
  /// lookups use multi-key fallback because the swag response shape isn't
  /// strictly typed.
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
