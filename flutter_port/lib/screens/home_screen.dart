import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final today = kSchedule.firstWhere((d) => d.day == 'Mon', orElse: () => kSchedule.first);
    return Container(
      color: c.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          children: [
            // Gradient header
            Container(
              padding: EdgeInsets.fromLTRB(Gaps.xl, MediaQuery.of(context).padding.top + 8, Gaps.xl, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 26, backgroundImage: CachedNetworkImageProvider(kStudent.photo)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hello,', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                            Text(kStudent.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(10)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.verified_user, size: 12, color: Color(0xFFFFF7ED)),
                                const SizedBox(width: 4),
                                Text(kStudent.membership, style: const TextStyle(color: Color(0xFFFFF7ED), fontSize: 10, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 36, height: 36, margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset(kLogoAssetPath, fit: BoxFit.cover)),
                      ),
                      Stack(children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                        ),
                        Positioned(top: 10, right: 10, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFFDE68A), shape: BoxShape.circle, border: Border.all(color: c.primary, width: 2)))),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(Radii.lg)),
                    child: Row(children: [
                      _statCell('${kStudent.attendance}%', 'Attendance'),
                      Container(width: 1, color: Colors.white.withOpacity(0.25)),
                      _statCell(kStudent.belt.split(' ').first, 'Current Belt'),
                      Container(width: 1, color: Colors.white.withOpacity(0.25)),
                      _statCell('${kStudent.fitness}', 'Fitness'),
                    ]),
                  ),
                ],
              ),
            ),

            // Top quick bar (overlapping)
            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: Gaps.xl),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: c.surface, borderRadius: BorderRadius.circular(Radii.xl),
                  border: c.isDark ? Border.all(color: c.border) : null,
                  boxShadow: Shadows.card(c),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _quickTop(c, Icons.check_circle_outline, 'Attendance', () => context.push('/attendance')),
                  _quickTop(c, Icons.calendar_month_outlined, 'Timetable', () => context.go('/schedule')),
                  _quickTop(c, Icons.badge_outlined, 'Virtual ID', () => context.go('/profile')),
                  _quickTop(c, Icons.person_outline, 'Profile', () => context.go('/profile')),
                ]),
              ),
            ),

            // Fees due
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
              child: InkWell(
                onTap: () => context.go('/payments'),
                borderRadius: BorderRadius.circular(Radii.xl),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: c.isDark ? const [Color(0xFF2D1A0A), Color(0xFF3F2410)] : const [Color(0xFFFEF3C7), Color(0xFFFED7AA)]),
                    borderRadius: BorderRadius.circular(Radii.xl),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FEES DUE', style: TextStyle(color: c.isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text('RM ${kStudent.nextPayment.amount}', style: TextStyle(color: c.isDark ? const Color(0xFFFED7AA) : const Color(0xFF7C2D12), fontSize: 24, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('Due ${kStudent.nextPayment.dueDate}', style: TextStyle(color: c.isDark ? const Color(0xFFFDBA74) : const Color(0xFF9A3412), fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(Radii.md)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [
                        Text('Pay Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 20),
            _sectionHead(c, "Today's Class", 'See all', () => context.go('/schedule')),
            if (today.sessions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surface, borderRadius: BorderRadius.circular(Radii.lg),
                    border: c.isDark ? Border.all(color: c.border) : null,
                    boxShadow: Shadows.card(c),
                  ),
                  child: Row(children: [
                    Container(width: 4, height: 50, decoration: BoxDecoration(color: today.sessions.first.color, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${today.sessions.first.time} · ${today.sessions.first.duration}', style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(today.sessions.first.title, style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('with ${today.sessions.first.trainer}', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.sm)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.qr_code_2, size: 14, color: c.primary),
                        const SizedBox(width: 4),
                        Text('Check In', style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 11)),
                      ]),
                    ),
                  ]),
                ),
              ),

            const SizedBox(height: 20),
            _sectionHead(c, 'Quick Access', null, null),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gaps.lg),
              child: Wrap(
                spacing: 12, runSpacing: 12,
                children: kQuickCards.map((q) {
                  final size = (MediaQuery.of(context).size.width - Gaps.lg * 2 - 36) / 4;
                  return SizedBox(
                    width: size,
                    child: InkWell(
                      onTap: () => context.push(q.route),
                      borderRadius: BorderRadius.circular(Radii.lg),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.surface, borderRadius: BorderRadius.circular(Radii.lg),
                          border: c.isDark ? Border.all(color: c.border) : null,
                          boxShadow: Shadows.card(c),
                        ),
                        child: Column(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: q.color.withOpacity(c.isDark ? 0.2 : 0.1), shape: BoxShape.circle),
                            child: Icon(q.icon, size: 22, color: q.color),
                          ),
                          const SizedBox(height: 6),
                          Text(q.label, textAlign: TextAlign.center, maxLines: 2, style: TextStyle(fontSize: 10, color: c.textPrimary, fontWeight: FontWeight.w600, height: 1.3)),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCell(String value, String label) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10, letterSpacing: 0.5)),
        ]),
      );

  Widget _quickTop(AppColors c, IconData icon, String label, VoidCallback onTap) => SizedBox(
        width: 72,
        child: InkWell(
          onTap: onTap,
          child: Column(children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: c.primary),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: c.textPrimary, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _sectionHead(AppColors c, String title, String? linkText, VoidCallback? onLink) => Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            if (linkText != null)
              InkWell(onTap: onLink, child: Text(linkText, style: TextStyle(color: c.primary, fontSize: 12, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}
