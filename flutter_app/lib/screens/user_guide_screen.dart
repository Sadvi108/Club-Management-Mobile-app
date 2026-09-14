import 'package:flutter/material.dart';

import '../data/guide_content.dart';
import '../theme/app_theme.dart';
import '../theme/ion.dart';
import '../widgets/rn_kit.dart';

/// Port of `frontend/app/user-guide.tsx` (Expo v2.11.1) — a paged walkthrough with real
/// screenshots of this build. No API calls: it has to work before signing in.
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

  void _go(int i) {
    final clamped = i.clamp(0, kGuideSteps.length - 1);
    _controller.animateToPage(clamped, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    setState(() => _page = clamped);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final width = MediaQuery.sizeOf(context).width;
    final bottom = MediaQuery.paddingOf(context).bottom;
    // Fixed pixel size so the 480x1039 capture is never cropped or magnified.
    final shotW = (width * 0.55).round().clamp(0, 200).toDouble();
    final shotH = (shotW * 1039 / 480).roundToDouble();
    final last = _page == kGuideSteps.length - 1;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        RnHeader(
          title: 'User Guide',
          horizontal: Gaps.lg,
          onBack: () => safeBack(context),
          trailing: Touchable(
            onPress: () => safeBack(context),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text('Skip', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: kGuideSteps.length,
            itemBuilder: (_, i) {
              final s = kGuideSteps[i];
              return ListView(
                padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 36),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: c.primary.hexA('14'), borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(s.icon, size: 14, color: c.primary),
                        const SizedBox(width: 6),
                        Text('STEP ${i + 1} OF ${kGuideSteps.length}',
                            style: TextStyle(color: c.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(s.title,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Text(s.intro, style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 19 / 13.5)),
                  const SizedBox(height: 14),
                  if (s.shot.isNotEmpty)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: c.isDark ? const Color(0xFF334155) : const Color(0xFF1F2937), width: 6),
                          boxShadow: Shadows.card(c),
                        ),
                        child: Image.asset(s.shot, width: shotW, height: shotH, fit: BoxFit.cover),
                      ),
                    ),
                  for (final d in s.details)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(top: 1),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                          child: Text('${d.n}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary)),
                            const SizedBox(height: 2),
                            Text(d.text, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 19 / 13)),
                          ]),
                        ),
                      ]),
                    ),
                  if (s.note.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 2, bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.primary.hexA('12'),
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: c.primary.hexA('40')),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Ion.alertCircle, size: 18, color: c.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s.note, style: TextStyle(fontSize: 12.5, color: c.textPrimary, height: 18 / 12.5))),
                      ]),
                    ),
                  for (final t in s.tips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Ion.bulbOutline, size: 15, color: c.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(t,
                              style: TextStyle(
                                  fontSize: 12.5, color: c.textSecondary, height: 18 / 12.5, fontStyle: FontStyle.italic)),
                        ),
                      ]),
                    ),
                ],
              );
            },
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(Gaps.xl, 10, Gaps.xl, bottom > 12 ? bottom : 12),
          decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
          child: Row(children: [
            Opacity(
              opacity: _page == 0 ? 0.4 : 1,
              child: RnCircleButton(icon: Ion.chevronBack, iconSize: 18, onPress: _page == 0 ? null : () => _go(_page - 1)),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < kGuideSteps.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                        color: i == _page ? c.primary : c.border, borderRadius: BorderRadius.circular(3)),
                  ),
                ]),
              ),
            ),
            Touchable(
              activeOpacity: 0.9,
              onPress: last ? () => safeBack(context) : () => _go(_page + 1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(gradient: LinearGradient(colors: c.gradient), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(last ? 'Got it' : 'Next',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  Icon(last ? Ion.checkmark : Ion.chevronForward, size: 16, color: Colors.white),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
