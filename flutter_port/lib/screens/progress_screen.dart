import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
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
                  InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(21),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                      child: Icon(Icons.chevron_left, color: c.textPrimary),
                    ),
                  ),
                  Text('Progress', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 42),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 40),
          sliver: SliverList.list(children: [
            // Fitness card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(Radii.xxl),
                boxShadow: Shadows.strong(c),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('FITNESS SCORE', style: TextStyle(color: Color(0xFFFFF7ED), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    RichText(text: TextSpan(children: [
                      TextSpan(text: '${kStudent.fitness}', style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -1)),
                      const TextSpan(text: '/100', style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 18, fontWeight: FontWeight.w600)),
                    ])),
                    const Text('Excellent shape — keep the momentum', style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 12)),
                  ]),
                ),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                  child: const Icon(Icons.fitness_center, size: 40, color: Color(0xE6FFFFFF)),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            // Belt Journey
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: c.isDark ? Border.all(color: c.border) : null,
                boxShadow: Shadows.card(c),
              ),
              child: Column(children: [
                Row(children: [
                  Text('Belt Journey', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  for (int i = 0; i < kBelts.length; i++) ...[
                    _beltDot(kBelts[i], c),
                    if (i < kBelts.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: kBelts[i].done ? c.primary : c.border,
                        ),
                      ),
                  ]
                ]),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: kBelts.map((b) => SizedBox(
                        width: 26,
                        child: Text(b.name[0], textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: b.current ? c.primary : c.textSecondary, fontWeight: b.current ? FontWeight.w800 : FontWeight.w600)),
                      )).toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: c.borderLight))),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('CURRENT BELT', style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Text(kStudent.belt, style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('NEXT EXAM', style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('15 Apr 2026', style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 22),
            Text('Skill Breakdown', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                border: c.isDark ? Border.all(color: c.border) : null,
                boxShadow: Shadows.card(c),
              ),
              child: Column(
                children: kSkills.map((s) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        SizedBox(width: 80, child: Text(s.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary))),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: s.value / 100,
                              minHeight: 10,
                              backgroundColor: c.surfaceAlt,
                              valueColor: AlwaysStoppedAnimation(s.color),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(width: 30, child: Text('${s.value}', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: s.color))),
                      ]),
                    )).toList(),
              ),
            ),
            const SizedBox(height: 22),
            Text('Achievement Badges', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: kAchievements.map((a) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: c.isDark ? Border.all(color: c.border) : null,
                          boxShadow: Shadows.card(c),
                        ),
                        child: Column(children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(color: a.color.withOpacity(c.isDark ? 0.2 : 0.12), shape: BoxShape.circle),
                            child: Icon(a.icon, size: 22, color: a.color),
                          ),
                          const SizedBox(height: 6),
                          Text(a.title, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: c.textPrimary, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  )).toList(),
            ),
            const SizedBox(height: 22),
            Text('Trainer Feedback', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            ...kTrainerComments.map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: c.isDark ? Border.all(color: c.border) : null,
                    boxShadow: Shadows.card(c),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                      child: Icon(Icons.chat_bubble_outline, size: 16, color: c.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('“${t.comment}”', style: TextStyle(fontSize: 13, color: c.textPrimary, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic, height: 1.4)),
                        const SizedBox(height: 6),
                        Text('— ${t.trainer} · ${t.date}', style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                )),
          ]),
        ),
      ]),
    );
  }

  Widget _beltDot(belt, AppColors c) {
    if (belt.current) {
      return Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle, border: Border.all(color: c.primary, width: 2)),
        child: const Icon(Icons.star, size: 14, color: Colors.white),
      );
    }
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(color: belt.color as Color, shape: BoxShape.circle),
      child: belt.done ? const Icon(Icons.check, size: 12, color: Color(0xFF0F172A)) : null,
    );
  }
}
