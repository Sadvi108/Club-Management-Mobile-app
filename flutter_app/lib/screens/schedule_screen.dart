import '../services/live_refresh.dart';
import '../theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../services/response_utils.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/gradient_button.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with LiveRefreshMixin<ScheduleScreen> {
  @override
  bool get canLiveRefresh => !_loading;
  @override
  Future<void> refreshLiveData() => _load();

  int active = 0;
  List<dynamic> _training = [], _bookings = [];
  bool _loading = true;
  String? _error;
  final _today = DateUtils.dateOnly(DateTime.now());

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
      // Weekly lessons come from StudentDetails. Bookings supplement that timetable;
      // they are not a replacement for it (many clubs never use class booking).
      final results = await Future.wait([
        Api.reportsStudentDetails(),
        Api.classBookingNextBookings(),
        Api.classBookingGetBookings(),
      ].map((future) async {
        try {
          return (await future, null);
        } catch (e) {
          return (null, e);
        }
      }));
      if (!mounted) return;
      setState(() {
        _training = findRecordList(results[0].$1);
        _bookings = [
          ...findRecordList(results[1].$1),
          ...findRecordList(results[2].$1)
        ];
        _error = results[0].$2 == null ? null : friendlyError(results[0].$2);
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = friendlyError(e);
          _loading = false;
        });
    }
  }

  List<Map> _classes(DateTime day, UserSession session) {
    final weekday = DateFormat('EEEE').format(day).toLowerCase();
    final regular = session
        .scopedRows(_training)
        .whereType<Map>()
        .where((r) => '${r['dayOfWeek'] ?? ''}'.trim().toLowerCase() == weekday)
        .toList();
    final seen = <String>{};
    final booked = session.scopedRows(_bookings).whereType<Map>().where((r) {
      final date = DateTime.tryParse(
          '${r['date'] ?? r['bookingDate'] ?? r['classDate'] ?? r['startTime'] ?? ''}');
      if (date == null || !DateUtils.isSameDay(date, day)) return false;
      final key = '${r['id'] ?? r['bookingId'] ?? r.toString()}';
      return seen.add(key);
    });
    return [...regular, ...booked];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final days = List.generate(
        10, (i) => DateTime(_today.year, _today.month, _today.day + i));
    final selected = days[active];
    final classes = _classes(selected, session);
    return ColoredBox(
        color: c.background,
        child: Column(children: [
          AppHeader(
              title: 'Schedule',
              subtitle: DateFormat('MMM yyyy').format(_today),
              trailing: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(kLogoAssetPath, width: 40, height: 40))),
          SizedBox(
              height: 108,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final on = i == active;
                    return Semantics(
                        selected: on,
                        button: true,
                        child: InkWell(
                            onTap: () => setState(() => active = i),
                            child: Container(
                                width: 62,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                    color: on ? c.primary : c.surface,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: Shadows.soft(c)),
                                child: Column(children: [
                                  Text(
                                      DateFormat('EEE')
                                          .format(days[i])
                                          .toUpperCase(),
                                      style: TextStyle(
                                          color: on
                                              ? const Color(0xD9FFFFFF)
                                              : c.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1)),
                                  Text('${days[i].day}',
                                      style: TextStyle(
                                          color:
                                              on ? Colors.white : c.textPrimary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800)),
                                  if (_classes(days[i], session).isNotEmpty)
                                    Icon(Icons.circle,
                                        size: 5,
                                        color: on ? Colors.white : c.primary),
                                ]))));
                  })),
          Expanded(
              child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        if ((_loading && !liveRefreshing))
                          const Center(child: CircularProgressIndicator())
                        else if (_error != null)
                          Column(children: [
                            Text(_error!),
                            TextButton(
                                onPressed: _load, child: const Text('Retry'))
                          ])
                        else if (classes.isEmpty)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(children: [
                                Text('Rest Day',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary)),
                                const SizedBox(height: 30),
                                Icon(AppIcons.bed_outlined,
                                    size: 44, color: c.textMuted),
                                const SizedBox(height: 16),
                                Text('No classes scheduled',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary)),
                                Text('Recovery is part of the journey',
                                    style: TextStyle(
                                        fontSize: 14, color: c.textSecondary)),
                              ]))
                        else ...[
                          Text(
                              '${classes.length} sessions · ${DateFormat('EEEE').format(selected)}',
                              style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 14),
                          for (final row in classes)
                            Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: c.surface,
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: Shadows.soft(c)),
                                child: Row(children: [
                                  SizedBox(
                                      width: 76,
                                      child: Column(children: [
                                        Text(
                                            '${row['tTimeFrom'] ?? row['timeFrom'] ?? row['time'] ?? '—'}',
                                            style: TextStyle(
                                                color: c.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700)),
                                        Text(
                                            'to ${row['tTimeTo'] ?? row['timeTo'] ?? '—'}',
                                            style: TextStyle(
                                                color: c.textSecondary,
                                                fontSize: 11)),
                                      ])),
                                  Container(
                                      width: 3,
                                      height: 48,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      color: c.primary),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(
                                            '${row['tCenterName'] ?? row['trainingCenter'] ?? row['name'] ?? 'Training'}',
                                            style: TextStyle(
                                                color: c.textPrimary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700)),
                                        Text(
                                            '${row['instructorName'] ?? 'Instructor'}',
                                            style: TextStyle(
                                                color: c.textSecondary,
                                                fontSize: 12)),
                                        if (row['currentGrade'] != null)
                                          Text('${row['currentGrade']}',
                                              style: TextStyle(
                                                  color: c.textSecondary,
                                                  fontSize: 11)),
                                      ])),
                                ])),
                        ],
                      ]))),
          Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, 90 + MediaQuery.paddingOf(context).bottom),
              child: GradientButton(
                  label: 'Book a Class',
                  trailingIcon: AppIcons.add_circle_outline,
                  onPressed: () => context.push('/book-class'))),
        ]));
  }
}
