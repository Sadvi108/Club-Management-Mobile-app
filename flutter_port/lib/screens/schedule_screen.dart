import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int active = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final day = kSchedule[active];
    return Container(
      color: c.background,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gaps.xl, 10, Gaps.xl, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Schedule', style: TextStyle(color: c.textPrimary, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Text('Feb 2026 · Week 4', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                    ],
                  ),
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                    child: Icon(Icons.swap_horiz, color: c.primary, size: 20),
                  ),
                ],
              ),
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
