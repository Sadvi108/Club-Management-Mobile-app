import 'package:flutter/material.dart';

import '../data/guide_content.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// User Guide — 11 pages, swipeable, no network.
///
/// Deliberately makes no API calls: the guide is linked from the sign-in screen, so it has
/// to work for someone who does not have an account yet.
class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index < 0 || index >= kGuideSteps.length) return;
    _controller.animateToPage(index,
        duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final last = _page == kGuideSteps.length - 1;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        AppHeader(
          title: 'User Guide',
          subtitle: 'Step ${_page + 1} of ${kGuideSteps.length}',
          showBack: true,
        ),
        _progress(c),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: kGuideSteps.length,
            itemBuilder: (_, i) => _page_(c, kGuideSteps[i]),
          ),
        ),
        _nav(c, last),
      ]),
    );
  }

  Widget _progress(AppColors c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.sm),
        child: Row(children: [
          for (var i = 0; i < kGuideSteps.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => _go(i),
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i <= _page ? c.primary : c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ]),
      );

  Widget _page_(AppColors c, GuideStep s) => ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg, Gaps.lg),
        children: [
          Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(s.icon, size: 24, color: c.primary),
            ),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: Text(s.title,
                  style: TextStyle(
                      color: c.textPrimary, fontSize: 21, fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: Gaps.md),
          Text(s.intro,
              style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.55)),
          const SizedBox(height: Gaps.lg),
          for (final d in s.details) _detail(c, d),
          if (s.note.isNotEmpty) _note(c, s.note),
          if (s.tips.isNotEmpty) _tips(c, s.tips),
        ],
      );

  Widget _detail(AppColors c, GuideDetail d) => Padding(
        padding: const EdgeInsets.only(bottom: Gaps.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
            child: Text('${d.n}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: Gaps.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.title,
                  style: TextStyle(
                      color: c.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(d.text,
                  style:
                      TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.5)),
            ]),
          ),
        ]),
      );

  /// The "read this or you will get it wrong" callout — warning-coloured so it reads
  /// differently from the numbered steps around it.
  Widget _note(AppColors c, String text) => Container(
        margin: const EdgeInsets.only(top: Gaps.sm, bottom: Gaps.md),
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.warning.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.priority_high, size: 18, color: c.warning),
          const SizedBox(width: Gaps.sm),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _tips(AppColors c, List<String> tips) => Container(
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TIPS',
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
          const SizedBox(height: Gaps.sm),
          for (final t in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lightbulb_outline, size: 15, color: c.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t,
                      style: TextStyle(
                          color: c.textSecondary, fontSize: 12.5, height: 1.45)),
                ),
              ]),
            ),
        ]),
      );

  Widget _nav(AppColors c, bool last) => Container(
        padding: EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.lg,
            MediaQuery.of(context).padding.bottom + Gaps.md),
        decoration: BoxDecoration(
          color: c.background,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Row(children: [
          TextButton.icon(
            onPressed: _page == 0 ? null : () => _go(_page - 1),
            icon: const Icon(Icons.chevron_left),
            label: const Text('Back'),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: last
                ? () => Navigator.of(context).maybePop()
                : () => _go(_page + 1),
            icon: Icon(last ? Icons.check : Icons.chevron_right),
            label: Text(last ? 'Done' : 'Next'),
            style: FilledButton.styleFrom(backgroundColor: c.primary),
          ),
        ]),
      );
}
