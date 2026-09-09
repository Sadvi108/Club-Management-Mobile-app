import 'package:flutter/material.dart';

import '../services/api.dart';
import '../services/class_booking.dart';
import '../services/response_utils.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/gradient_button.dart';

/// Book a class.
///
/// Work down the screen: centre → instructor → month → session → date.
///
/// The server does very little checking here (see lib/services/class_booking.dart): the
/// timetable it returns is weekly and month-independent, `classLimit` is capacity rather
/// than availability, and BookNow accepts both duplicates and a date whose weekday does not
/// match the slot. So the date choice and the duplicate guard live in the app, and the
/// student picks the date rather than having one computed behind their back.
class BookClassScreen extends StatefulWidget {
  const BookClassScreen({super.key});

  @override
  State<BookClassScreen> createState() => _BookClassScreenState();
}

class _BookClassScreenState extends State<BookClassScreen> {
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  List<Map<String, dynamic>> _centers = [];
  List<Map<String, dynamic>> _instructors = [];
  List<Map<String, dynamic>> _slots = [];
  List<dynamic> _bookings = [];
  String? _packageType;

  int _centerId = 0;
  int _instructorId = 0;
  int _monthOffset = 0; // 0 = this month, 1 = next
  int? _slotId;
  String? _date;

  bool _loading = true;
  bool _slotsLoading = false;
  bool _booking = false;
  String? _error;

  DateTime get _month => DateTime(DateTime.now().year, DateTime.now().month + _monthOffset);

  @override
  void initState() {
    super.initState();
    _loadPickers();
  }

  List<Map<String, dynamic>> _rows(dynamic res) => findRecordList(res)
      .whereType<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .toList();

  int _idOf(Map m) {
    final v = m['id'] ?? m['value'];
    return v is int ? v : int.tryParse('$v') ?? 0;
  }

  String _textOf(Map m) =>
      (m['text'] ?? m['name'] ?? m['value'] ?? '').toString().trim();

  Future<void> _loadPickers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        Api.listingTrainingCenters(),
        Api.listingInstructors(),
        Api.classBookingGetBookings(),
      ]);
      final centers = _rows(results[0]);
      final instructors = _rows(results[1]);
      if (!mounted) return;
      setState(() {
        _centers = centers;
        _instructors = instructors;
        _bookings = findRecordList(results[2]);
        _centerId = centers.isNotEmpty ? _idOf(centers.first) : 0;
        _instructorId = instructors.isNotEmpty ? _idOf(instructors.first) : 0;
        _loading = false;
      });
      await _loadPackage();
      await _loadSlots();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadPackage() async {
    final studentId = UserSession.instance.currentStudentId;
    if (studentId == null) return;
    try {
      final res = await Api.classBookingPackageInfo(studentId);
      final data = unwrapData(res);
      if (!mounted) return;
      setState(() => _packageType =
          (data is Map ? data['packageType'] : null)?.toString());
    } catch (_) {
      // The package only decorates the request; a failure must not block booking.
    }
  }

  Future<void> _loadSlots() async {
    if (_centerId == 0 || _instructorId == 0) {
      setState(() => _slots = []);
      return;
    }
    setState(() {
      _slotsLoading = true;
      // Any change to the picker invalidates the current selection.
      _slotId = null;
      _date = null;
    });
    try {
      final res = await Api.classBookingTrainingTimeWithDateAndInstructor(
        month: _month.month,
        year: _month.year,
        tCenterId: _centerId,
        instructorId: _instructorId,
      );
      if (!mounted) return;
      setState(() {
        _slots = _rows(res);
        _slotsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _slots = [];
        _slotsLoading = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _refreshBookings() async {
    try {
      final res = await Api.classBookingGetBookings();
      if (!mounted) return;
      setState(() => _bookings = findRecordList(res));
    } catch (_) {/* the list is a nicety; booking already succeeded */}
  }

  Map<String, dynamic>? get _chosenSlot {
    if (_slotId == null) return null;
    for (final s in _slots) {
      if (_idOf(s) == _slotId) return s;
    }
    return null;
  }

  List<DateTime> get _dateOptions {
    final slot = _chosenSlot;
    if (slot == null) return const [];
    return datesForDayOfWeek(
        (slot['dayOfWeek'] ?? '').toString(), _month.month, _month.year);
  }

  void _selectSlot(int id) {
    setState(() {
      _slotId = id;
      final slot = _chosenSlot;
      final opts = slot == null
          ? <DateTime>[]
          : datesForDayOfWeek(
              (slot['dayOfWeek'] ?? '').toString(), _month.month, _month.year);
      // Default to a date they have not already booked, so the first tap is actionable.
      _date = preferredDate(opts, takenDates(_bookings, id));
    });
  }

  Future<void> _confirm() async {
    final slot = _chosenSlot;
    final studentId = UserSession.instance.currentStudentId;
    if (slot == null || studentId == null || _booking) return;

    if (_date == null) {
      _toast('Choose which date you want to attend this class.');
      return;
    }
    // BookNow will happily create a second identical booking — this is the only guard.
    if (isAlreadyBooked(_bookings, _idOf(slot), _date!)) {
      _toast('You have already booked this class on that date. Pick another date.');
      return;
    }

    setState(() => _booking = true);
    try {
      await Api.classBookingBookNow(bookNowBody(
        tCenterId: _centerId,
        instructorId: _instructorId,
        studentId: studentId,
        timeId: _idOf(slot),
        date: _date!,
        slotName: (slot['name'] ?? '').toString(),
        packageType: _packageType,
        centerName: (slot['centerName'] ?? '').toString(),
        instructorName: (slot['instructorName'] ?? '').toString(),
      ));
      if (!mounted) return;
      final booked = _date!;
      setState(() {
        _slotId = null;
        _date = null;
        _booking = false;
      });
      await _refreshBookings();
      if (!mounted) return;
      _toast('Class booked for ${_prettyDate(booked)}.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      _toast('Booking failed: ${friendlyError(e)}');
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));

  String _prettyDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${wd[d.weekday - 1]} ${d.day} ${_monthNames[d.month - 1].substring(0, 3)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      color: c.background,
      child: Column(children: [
        const AppHeader(title: 'Book a Class', showBack: true),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadPickers,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.md, Gaps.xl, Gaps.xxxl),
                    children: [
                      if (_error != null) _errorBanner(c, _error!),
                      _label(c, 'TRAINING CENTER'),
                      _chips(c, _centers, _centerId, (id) {
                        setState(() => _centerId = id);
                        _loadSlots();
                      }),
                      const SizedBox(height: Gaps.lg),
                      _label(c, 'INSTRUCTOR'),
                      _chips(c, _instructors, _instructorId, (id) {
                        setState(() => _instructorId = id);
                        _loadSlots();
                      }),
                      const SizedBox(height: Gaps.lg),
                      _label(c, 'MONTH'),
                      _monthChips(c),
                      const SizedBox(height: Gaps.xl),
                      _label(c,
                          'AVAILABLE SESSIONS · ${_monthNames[_month.month - 1]} ${_month.year}'),
                      _sessions(c),
                      if (_chosenSlot != null) ...[
                        const SizedBox(height: Gaps.xl),
                        _label(c, 'PICK A DATE'),
                        _dates(c),
                      ],
                      const SizedBox(height: Gaps.xl),
                      _label(c, 'MY BOOKINGS'),
                      _myBookings(c),
                    ],
                  ),
                ),
        ),
        _bottomBar(c),
      ]),
    );
  }

  Widget _errorBanner(AppColors c, String msg) => Container(
        margin: const EdgeInsets.only(bottom: Gaps.lg),
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.danger.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, size: 18, color: c.danger),
          const SizedBox(width: Gaps.sm),
          Expanded(child: Text(msg, style: TextStyle(color: c.textPrimary, fontSize: 12.5))),
        ]),
      );

  Widget _label(AppColors c, String t) => Padding(
        padding: const EdgeInsets.only(bottom: Gaps.sm),
        child: Text(t,
            style: TextStyle(
                color: c.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      );

  Widget _chips(AppColors c, List<Map<String, dynamic>> rows, int selected,
      ValueChanged<int> onTap) {
    if (rows.isEmpty) {
      return Text('None available', style: TextStyle(color: c.textSecondary, fontSize: 13));
    }
    return Wrap(
      spacing: Gaps.sm,
      runSpacing: Gaps.sm,
      children: rows.map((r) {
        final id = _idOf(r);
        final on = id == selected;
        return GestureDetector(
          onTap: () => onTap(id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: on ? c.primary : c.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(_textOf(r),
                style: TextStyle(
                    color: on ? Colors.white : c.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
        );
      }).toList(),
    );
  }

  Widget _monthChips(AppColors c) {
    final now = DateTime.now();
    return Row(
      children: List.generate(2, (i) {
        final m = DateTime(now.year, now.month + i);
        final on = _monthOffset == i;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 0 ? Gaps.sm : 0),
            child: GestureDetector(
              onTap: () {
                setState(() => _monthOffset = i);
                _loadSlots();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? c.primary : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_monthNames[m.month - 1],
                    style: TextStyle(
                        color: on ? Colors.white : c.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _sessions(AppColors c) {
    if (_slotsLoading) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: Gaps.xl),
          child: Center(child: CircularProgressIndicator()));
    }
    if (_slots.isEmpty) {
      return _empty(c, Icons.event_busy, 'No sessions here',
          'Try another centre, instructor or month.');
    }
    return Column(
      children: _slots.map((s) {
        final id = _idOf(s);
        final on = id == _slotId;
        return GestureDetector(
          onTap: () => _selectSlot(id),
          child: Container(
            margin: const EdgeInsets.only(bottom: Gaps.sm),
            padding: const EdgeInsets.all(Gaps.md),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? c.primary : c.border, width: on ? 1.6 : 1),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((s['name'] ?? '').toString(),
                      style: TextStyle(
                          color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    [
                      (s['centerName'] ?? '').toString(),
                      (s['instructorName'] ?? '').toString(),
                    ].where((x) => x.isNotEmpty).join(' · '),
                    style: TextStyle(color: c.textSecondary, fontSize: 11.5),
                  ),
                ]),
              ),
              Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 20, color: on ? c.primary : c.textMuted),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _dates(AppColors c) {
    final opts = _dateOptions;
    if (opts.isEmpty) {
      return Text('No remaining dates for this session this month.',
          style: TextStyle(color: c.textSecondary, fontSize: 12.5));
    }
    final taken = takenDates(_bookings, _slotId ?? 0);
    return Wrap(
      spacing: Gaps.sm,
      runSpacing: Gaps.sm,
      children: opts.map((d) {
        final iso = isoDate(d);
        final on = iso == _date;
        final already = taken.contains(iso);
        return GestureDetector(
          onTap: () => setState(() => _date = iso),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: on ? c.primary : c.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: already ? Border.all(color: c.warning, width: 1.2) : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_prettyDate(iso),
                  style: TextStyle(
                      color: on ? Colors.white : c.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              if (already) ...[
                const SizedBox(width: 5),
                Icon(Icons.check_circle, size: 13, color: on ? Colors.white : c.warning),
              ],
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _myBookings(AppColors c) {
    final rows = sortBookings(_bookings);
    if (rows.isEmpty) {
      return _empty(c, Icons.event_note, 'No bookings yet',
          'Sessions you book will appear here.');
    }
    final today = DateTime.now();
    return Column(
      children: rows.take(12).map((b) {
        final d = DateTime.tryParse((b['trainingDate'] ?? '').toString());
        final past = d != null && d.isBefore(DateTime(today.year, today.month, today.day));
        return Container(
          margin: const EdgeInsets.only(bottom: Gaps.sm),
          padding: const EdgeInsets.all(Gaps.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(children: [
            Icon(past ? Icons.history : Icons.event_available,
                size: 18, color: past ? c.textMuted : c.success),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((b['name'] ?? 'Class').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(d == null ? '' : _prettyDate(isoDate(d)),
                    style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
              ]),
            ),
            Text((b['status'] ?? (past ? 'Done' : 'Booked')).toString(),
                style: TextStyle(
                    color: past ? c.textMuted : c.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _empty(AppColors c, IconData icon, String title, String sub) => Container(
        padding: const EdgeInsets.symmetric(vertical: Gaps.xxl),
        alignment: Alignment.center,
        child: Column(children: [
          Icon(icon, size: 34, color: c.textMuted),
          const SizedBox(height: Gaps.sm),
          Text(title,
              style: TextStyle(
                  color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: c.textSecondary, fontSize: 12)),
        ]),
      );

  Widget _bottomBar(AppColors c) {
    final slot = _chosenSlot;
    final ready = slot != null && _date != null;
    final dup = ready && isAlreadyBooked(_bookings, _idOf(slot), _date!);
    return Container(
      padding: EdgeInsets.fromLTRB(
          Gaps.xl, Gaps.md, Gaps.xl, Gaps.md + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (dup)
          Padding(
            padding: const EdgeInsets.only(bottom: Gaps.sm),
            child: Text('Already booked on that date — pick another.',
                style: TextStyle(color: c.warning, fontSize: 12)),
          ),
        GradientButton(
          label: ready ? 'Confirm booking' : 'Select a session',
          loading: _booking,
          onPressed: ready && !dup ? _confirm : null,
        ),
      ]),
    );
  }
}
