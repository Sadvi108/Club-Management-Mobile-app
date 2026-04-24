import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final weeks = [0, 1, 2, 3];
    return Scaffold(
      backgroundColor: c.background,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gaps.lg, 10, Gaps.lg, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circBtn(c, Icons.chevron_left, () => context.pop()),
                  Text('Attendance', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  _circBtn(c, Icons.qr_code_2, () => context.push('/qr-scan'), tint: c.primary),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 40),
          sliver: SliverList.list(children: [
            // Hero card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(Radii.xxl),
                boxShadow: Shadows.strong(c),
              ),
              child: Row(children: [
                SizedBox(
                  width: 120, height: 120,
                  child: Stack(alignment: Alignment.center, children: [
                    Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.22), width: 6))),
                    SizedBox(
                      width: 108, height: 108,
                      child: CircularProgressIndicator(
                        value: kAttendance.percentage / 100,
                        strokeWidth: 6,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFFF7ED)),
                      ),
                    ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${kAttendance.percentage}%', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                      const Text('Attended', style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 9, fontWeight: FontWeight.w700)),
                    ]),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Great Discipline!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Keep it above 80% to qualify for events', style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 11)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _mStat('${kAttendance.present}', 'Present'),
                      const SizedBox(width: 8),
                      _mStat('${kAttendance.total - kAttendance.present}', 'Missed'),
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
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Feb 2026', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  Row(children: [
                    _legend(c.success, 'Present', c),
                    const SizedBox(width: 10),
                    _legend(c.danger, 'Missed', c),
                  ]),
                ]),
                const SizedBox(height: 12),
                Row(children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                    .map((d) => Expanded(child: Text(d, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w700))))
                    .toList()),
                const SizedBox(height: 4),
                ...weeks.map((w) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: kAttendance.thisMonth.sublist(w * 7, w * 7 + 7).map((d) {
                          Color bg = Colors.transparent;
                          Color txt = c.textPrimary;
                          Border? border;
                          switch (d.status) {
                            case AttendanceStatus.present:
                              bg = c.success; txt = Colors.white; break;
                            case AttendanceStatus.missed:
                              bg = c.danger; txt = Colors.white; break;
                            case AttendanceStatus.off:
                              bg = c.surfaceAlt; break;
                            case AttendanceStatus.future:
                              border = Border.all(color: c.border); txt = c.textMuted; break;
                          }
                          return Expanded(
                            child: Center(
                              child: Container(
                                width: 34, height: 34,
                                decoration: BoxDecoration(color: bg, shape: BoxShape.circle, border: border),
                                alignment: Alignment.center,
                                child: Text('${d.day}', style: TextStyle(fontSize: 12, color: txt, fontWeight: FontWeight.w700)),
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
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Scan QR to Check In', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text("Mark attendance for today's class", style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 11)),
                    ]),
                  ),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            Text('Missed Class History', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
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
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: c.isDark ? const Color(0xFF3F1212) : const Color(0xFFFEE2E2), shape: BoxShape.circle),
                      child: Icon(Icons.cancel, color: c.danger, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.className, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${m.date} · ${m.reason}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                      ]),
                    ),
                  ]),
                )),
          ]),
        ),
      ]),
    );
  }

  Widget _circBtn(AppColors c, IconData icon, VoidCallback onTap, {Color? tint}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
          child: Icon(icon, color: tint ?? c.textPrimary, size: 20),
        ),
      );

  Widget _mStat(String n, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(Radii.sm)),
          child: Column(children: [
            Text(n, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(l, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 9)),
          ]),
        ),
      );

  Widget _legend(Color dot, String l, AppColors c) => Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 4),
        Text(l, style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w600)),
      ]);
}
