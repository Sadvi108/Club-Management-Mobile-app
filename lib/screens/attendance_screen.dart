import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/app_icon_button.dart';
import '../widgets/filter_sheet.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<dynamic>? _liveAttendance;
  bool _loading = false;
  bool _marking = false;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _loading = true);
    try {
      final r = await Api.reportsAttendance();
      if (r is List) _liveAttendance = r;
      if (r is Map && r['data'] is List) _liveAttendance = r['data'] as List;
    } catch (e) {
      debugPrint('reportsAttendance failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAttendance() async {
    final session = UserSession.instance;
    final studentId = session.authData?['studentId'] ?? session.authData?['id'];
    if (studentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No student id in session')),
      );
      return;
    }
    setState(() => _marking = true);
    try {
      await Api.attendanceAdd(<String, dynamic>{
        'studentId': studentId,
        'date': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance marked')),
      );
      await _loadAttendance();
    } catch (e) {
      debugPrint('Attendance/Add failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final weeks = [0, 1, 2, 3];
    final liveNotifs = (session.notifications ?? const [])
        .where((n) => n is Map)
        .cast<Map>()
        .toList();
    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: AppHeader(
            title: 'Attendance',
            showBack: true,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              AppIconButton(
                icon: Icons.tune,
                onPressed: () => showFilterSheet(context),
                backgroundColor: c.surfaceAlt,
                foregroundColor: c.primary,
              ),
              const SizedBox(width: 6),
              AppIconButton(
                icon: Icons.qr_code_2,
                onPressed: () => context.push('/qr-scan'),
                backgroundColor: c.surfaceAlt,
                foregroundColor: c.primary,
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 40),
          sliver: SliverList.list(children: [
            // Hero card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: c.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(Radii.xxl),
                boxShadow: Shadows.strong(c),
              ),
              child: Row(children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.22),
                                width: 6))),
                    SizedBox(
                      width: 108,
                      height: 108,
                      child: CircularProgressIndicator(
                        value: kAttendance.percentage / 100,
                        strokeWidth: 6,
                        backgroundColor: Colors.transparent,
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFFFFF7ED)),
                      ),
                    ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${kAttendance.percentage}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const Text('Attended',
                          style: TextStyle(
                              color: Color(0xD9FFFFFF),
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Great Discipline!',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('Keep it above 80% to qualify for events',
                            style: TextStyle(
                                color: Color(0xE6FFFFFF), fontSize: 11)),
                        const SizedBox(height: 12),
                        Row(children: [
                          _mStat('${kAttendance.present}', 'Present'),
                          const SizedBox(width: 8),
                          _mStat('${kAttendance.total - kAttendance.present}',
                              'Missed'),
                          const SizedBox(width: 8),
                          _mStat('${kAttendance.total}', 'Total'),
                        ]),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            // Monthly calendar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: c.isDark ? Border.all(color: c.border) : null,
                boxShadow: Shadows.card(c),
              ),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Feb 2026',
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      Row(children: [
                        _legend(c.success, 'Present', c),
                        const SizedBox(width: 10),
                        _legend(c.danger, 'Missed', c),
                      ]),
                    ]),
                const SizedBox(height: 12),
                Row(
                    children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                        .map((d) => Expanded(
                            child: Text(d,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: c.textMuted,
                                    fontWeight: FontWeight.w700))))
                        .toList()),
                const SizedBox(height: 4),
                ...weeks.map((w) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: kAttendance.thisMonth
                            .sublist(w * 7, w * 7 + 7)
                            .map((d) {
                          Color bg = Colors.transparent;
                          Color txt = c.textPrimary;
                          Border? border;
                          if (d.status == AttendanceStatus.present) {
                            bg = c.success;
                            txt = Colors.white;
                          } else if (d.status == AttendanceStatus.missed) {
                            bg = c.danger;
                            txt = Colors.white;
                          } else if (d.status == AttendanceStatus.off) {
                            bg = c.surfaceAlt;
                          } else {
                            border = Border.all(color: c.border);
                            txt = c.textMuted;
                          }
                          return Expanded(
                            child: Center(
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                    color: bg,
                                    shape: BoxShape.circle,
                                    border: border),
                                alignment: Alignment.center,
                                child: Text('${d.day}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: txt,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    )),
              ]),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => context.push('/qr-scan'),
              borderRadius: BorderRadius.circular(Radii.xl),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: c.gradient),
                  borderRadius: BorderRadius.circular(Radii.xl),
                  boxShadow: Shadows.strong(c),
                ),
                child: Row(children: const [
                  Icon(Icons.qr_code_2, size: 22, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scan QR to Check In',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text("Mark attendance for today's class",
                              style: TextStyle(
                                  color: Color(0xE6FFFFFF), fontSize: 11)),
                        ]),
                  ),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _marking ? null : _markAttendance,
              borderRadius: BorderRadius.circular(Radii.md),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primary, borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: _marking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Mark Attendance Now',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              Row(children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)),
                const SizedBox(width: 8),
                Text('Loading attendance…', style: TextStyle(fontSize: 12, color: c.textSecondary)),
              ]),
            if (_liveAttendance != null && _liveAttendance!.isNotEmpty) ...[
              _liveAttendanceCard(c, _liveAttendance!),
              const SizedBox(height: 20),
            ],
            if (session.clubStats != null && session.clubStats!.isNotEmpty) ...[
              _liveStatsCard(c, session),
              const SizedBox(height: 20),
            ],
            if (liveNotifs.isNotEmpty) ...[
              _liveNotificationsCard(c, liveNotifs),
              const SizedBox(height: 20),
            ],
            Text('Missed Class History',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...kAttendance.missed.map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: c.isDark ? Border.all(color: c.border) : null,
                    boxShadow: Shadows.card(c),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: c.isDark
                              ? const Color(0xFF3F1212)
                              : const Color(0xFFFEE2E2),
                          shape: BoxShape.circle),
                      child: Icon(Icons.cancel, color: c.danger, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.className,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary)),
                            const SizedBox(height: 2),
                            Text('${m.date} · ${m.reason}',
                                style: TextStyle(
                                    fontSize: 11, color: c.textSecondary)),
                          ]),
                    ),
                  ]),
                )),
          ]),
        ),
      ]),
    );
  }

  Widget _liveAttendanceCard(AppColors c, List<dynamic> rows) {
    return Container(
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
            Text('LIVE · Attendance (${rows.length})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          ...rows.take(15).map((r) {
            final m = r is Map ? r : <dynamic, dynamic>{};
            final date = (m['date'] ?? m['attendanceDate'] ?? m['text'] ?? '').toString();
            final status = (m['status'] ?? m['value'] ?? '').toString();
            final present = status.toLowerCase().contains('present') || status == '1' || status.toLowerCase() == 'true';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(present ? Icons.check_circle : Icons.cancel,
                    size: 14, color: present ? c.success : c.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(date, style: TextStyle(fontSize: 12, color: c.textPrimary))),
                Text(status, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w700)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _liveStatsCard(AppColors c, UserSession session) {
    final stats = session.clubStats!;
    return Container(
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
            Text('LIVE · Club Stats',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          ...stats.take(6).map((s) {
            if (s is! Map) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text('${s['text'] ?? ''}', style: TextStyle(fontSize: 12, color: c.textSecondary))),
                Text('${s['value'] ?? ''}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _liveNotificationsCard(AppColors c, List<Map> notifs) {
    return Container(
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
            Icon(Icons.notifications_active, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text('LIVE · Recent Notifications',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          ...notifs.take(4).map((n) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${n['text'] ?? ''}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    Text(_stripHtml('${n['value'] ?? ''}'),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  String _stripHtml(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&nbsp;', ' ').trim();

  Widget _mStat(String n, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(Radii.sm)),
          child: Column(children: [
            Text(n,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 2),
            Text(l,
                style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 9)),
          ]),
        ),
      );

  Widget _legend(Color dot, String l, AppColors c) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: dot, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 4),
        Text(l,
            style: TextStyle(
                fontSize: 10,
                color: c.textSecondary,
                fontWeight: FontWeight.w600)),
      ]);
}
