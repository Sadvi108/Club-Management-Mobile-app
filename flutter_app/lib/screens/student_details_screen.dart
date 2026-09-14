import '../services/live_refresh.dart';
import '../theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/response_utils.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// Student Details — the read-only record, as the academy holds it.
///
/// Two sources: `/Profile/MyInfo` (enrolment) and `/Profile/StudentAddtnlInfo` (school,
/// DOB, health). Editing lives in [EditProfileScreen]; this screen never writes.
class StudentDetailsScreen extends StatefulWidget {
  const StudentDetailsScreen({super.key});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen>
    with LiveRefreshMixin<StudentDetailsScreen> {
  @override
  bool get canLiveRefresh => !_loading;
  @override
  Future<void> refreshLiveData() => _load();

  bool _loading = true;
  String? _error;

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
    final session = UserSession.instance;
    try {
      // Both, independently: a missing additional-info record is common and must not
      // blank out the enrolment fields the member came here to read.
      final results = await Future.wait([
        Api.profileMyInfo().then<dynamic>((v) => v).catchError((_) => null),
        Api.profileStudentAddtnlInfo()
            .then<dynamic>((v) => v)
            .catchError((_) => null),
      ]);
      final info = unwrapData(results[0]);
      final addtnl = unwrapData(results[1]);
      if (info is Map) session.myInfo = Map<String, dynamic>.from(info);
      if (addtnl is Map) {
        session.studentAddtnlInfo = Map<String, dynamic>.from(addtnl);
      }
      if (info == null && addtnl == null) {
        throw Exception('Could not load your details.');
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Only alarm the member when there is genuinely nothing to show. This screen
        // renders from UserSession, which is usually already populated from sign-in — so
        // a failed REFRESH would otherwise put a red error above their correct, complete
        // details. On a flaky connection that reads as "my record is broken".
        _error = _hasSomethingToShow(session) ? null : friendlyError(e);
        _loading = false;
      });
    }
  }

  /// Is there already enough in the session to render a useful screen?
  bool _hasSomethingToShow(UserSession s) =>
      (s.myInfo?.isNotEmpty ?? false) ||
      (s.studentAddtnlInfo?.isNotEmpty ?? false);

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _fmtDate(String raw) {
    if (raw.trim().isEmpty) return '-';
    final d = DateTime.tryParse(raw.trim());
    if (d == null) return raw;
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
  }

  String _pick(UserSession s, List<String> keys) {
    for (final src in [s.myInfo, s.studentAddtnlInfo, s.authData]) {
      if (src == null) continue;
      for (final k in keys) {
        final v = src[k];
        if (v != null && '$v'.trim().isNotEmpty) return '$v'.trim();
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final s = context.watch<UserSession>();

    String or(String v) => v.trim().isEmpty ? '-' : v.trim();

    final fields = <({IconData icon, String label, String value})>[
      (icon: AppIcons.person_outline, label: 'Name', value: or(s.displayName)),
      (
        icon: AppIcons.badge_outlined,
        label: 'Registration No',
        value:
            or(s.registrationNo.isNotEmpty ? s.registrationNo : s.studentCode)
      ),
      (
        icon: Icons.fingerprint,
        label: 'IC No',
        value: or(_pick(s, ['icNo', 'IcNo', 'icNumber', 'nric']))
      ),
      (
        icon: AppIcons.military_tech_outlined,
        label: 'Current Grade',
        value: or(s.currentGrade)
      ),
      (
        icon: Icons.location_on_outlined,
        label: 'Training Center',
        value: or(s.tCenterName)
      ),
      (
        icon: Icons.business_outlined,
        label: 'Exam Center',
        value: or(_pick(s, ['eCenterName', 'examCenter', 'ECenterName']))
      ),
      (
        icon: AppIcons.account_circle_outlined,
        label: 'Instructor',
        value: or(s.instructorName)
      ),
      (icon: Icons.call_outlined, label: 'Phone', value: or(s.phone)),
      (
        icon: AppIcons.school_outlined,
        label: 'School',
        value: or(_pick(s, ['schoolname', 'schoolName', 'school']))
      ),
      (
        icon: Icons.calendar_today_outlined,
        label: 'Date of Birth',
        value: _fmtDate(_pick(s, ['dob', 'dateOfBirth', 'DOB', 'birthDate']))
      ),
      (
        icon: Icons.water_drop_outlined,
        label: 'Blood Type',
        value: or(_pick(s, ['bloodtype', 'bloodType', 'BloodType']))
      ),
      (
        icon: Icons.favorite_outline,
        label: 'Health Status',
        value: or(_pick(s, ['healthstatus', 'healthStatus', 'HealthStatus']))
      ),
    ];

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const AppHeader(title: 'Student Details', showBack: true),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: (_loading && !liveRefreshing)
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                        Gaps.lg, Gaps.md, Gaps.lg, Gaps.xxxl),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Gaps.md),
                          child: Text(_error!,
                              style: TextStyle(color: c.danger, fontSize: 13)),
                        ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(Radii.xl),
                          border: c.isDark ? Border.all(color: c.border) : null,
                          boxShadow: Shadows.card(c),
                        ),
                        child: Column(children: [
                          for (var i = 0; i < fields.length; i++) ...[
                            _row(c, fields[i]),
                            if (i < fields.length - 1)
                              Divider(height: 1, color: c.border),
                          ],
                        ]),
                      ),
                    ],
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _row(AppColors c, ({IconData icon, String label, String value}) f) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
            child: Icon(f.icon, size: 18, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(f.value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      );
}
