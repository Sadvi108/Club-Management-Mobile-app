import '../theme/app_icons.dart';
import 'package:flutter/material.dart';

import '../data/guide_content.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// User Guide — swipeable pages, no network.
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
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic);
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
          subtitle: 'Feature ${_page + 1} of ${kGuideSteps.length}',
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

  Future<void> _contents() async {
    var query = '';
    var category = 'All';
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
          builder: (context, update) => Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .82,
                  child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          const Expanded(
                              child: Text('All features',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold))),
                          IconButton(
                              tooltip: 'Close contents',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close)),
                        ])),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          decoration: const InputDecoration(
                              labelText: 'Search features or instructions',
                              prefixIcon: Icon(Icons.search)),
                          onChanged: (value) =>
                              update(() => query = value.toLowerCase().trim()),
                        )),
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            for (final label in [
                              'All',
                              ...kGuideSteps.map((s) => s.category).toSet()
                            ])
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: ChoiceChip(
                                    label: Text(label),
                                    selected: category == label,
                                    onSelected: (_) =>
                                        update(() => category = label),
                                  )),
                          ]),
                        )),
                    Expanded(child: Builder(builder: (context) {
                      final matches = kGuideSteps
                          .asMap()
                          .entries
                          .where((e) =>
                              (category == 'All' ||
                                  e.value.category == category) &&
                              ('${e.value.title} ${e.value.intro} ${e.value.details.map((d) => '${d.title} ${d.text}').join(' ')}')
                                  .toLowerCase()
                                  .contains(query))
                          .toList();
                      if (matches.isEmpty)
                        return const Center(
                            child: Text(
                                'No matching features. Try another search.'));
                      return ListView.builder(
                          itemCount: matches.length,
                          itemBuilder: (_, i) {
                            final entry = matches[i];
                            return ListTile(
                                leading: Icon(entry.value.icon),
                                title: Text(entry.value.title),
                                subtitle: Text(entry.value.category),
                                selected: _page == entry.key,
                                onTap: () => Navigator.pop(context, entry.key));
                          });
                    })),
                  ]),
                ),
              )),
    );
    if (selected != null && mounted) _go(selected);
  }

  Widget _progress(AppColors c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: Text(kGuideSteps[_page].category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textSecondary))),
            TextButton.icon(
                onPressed: _contents,
                icon: const Icon(Icons.search),
                label: const Text('All features')),
          ]),
          LinearProgressIndicator(
              value: (_page + 1) / kGuideSteps.length,
              color: c.primary,
              backgroundColor: c.border),
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
                      color: c.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: Gaps.md),
          Text(s.intro,
              style: TextStyle(
                  color: c.textSecondary, fontSize: 14, height: 1.55)),
          if (s.shot.isNotEmpty) _shot(c, s.shot),
          const SizedBox(height: Gaps.lg),
          for (final d in s.details) _detail(c, d),
          if (s.note.isNotEmpty) _note(c, s.note),
          if (s.tips.isNotEmpty) _tips(c, s.tips),
        ],
      );

  void _openShot(String asset) => showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
            child: Scaffold(
          appBar: AppBar(
              title: const Text('Screen preview'),
              leading: IconButton(
                  tooltip: 'Close screen preview',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context))),
          body: Column(children: [
            const Padding(
                padding: EdgeInsets.all(12),
                child:
                    Text('Example data • Pinch to zoom and drag to explore')),
            Expanded(
                child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    child: Center(
                        child: Image.asset(asset, fit: BoxFit.contain)))),
          ]),
        )),
      );

  Widget _shot(AppColors c, String asset) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(children: [
          InkWell(
            onTap: () => _openShot(asset),
            borderRadius: BorderRadius.circular(Radii.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: Border.all(color: c.border)),
              child: Image.asset(asset,
                  height: 280,
                  fit: BoxFit.contain,
                  semanticLabel: 'Example screen. Tap to enlarge',
                  errorBuilder: (_, __, ___) => const SizedBox(
                      height: 120,
                      child:
                          Center(child: Text('Screen preview unavailable')))),
            ),
          ),
          TextButton.icon(
              onPressed: () => _openShot(asset),
              icon: const Icon(Icons.zoom_in),
              label: const Text('View full screen • Example data')),
        ]),
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
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: Gaps.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.title,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(d.text,
                  style: TextStyle(
                      color: c.textSecondary, fontSize: 13.5, height: 1.5)),
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
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lightbulb_outline, size: 15, color: c.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t,
                      style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.5,
                          height: 1.45)),
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
            icon: const Icon(AppIcons.chevron_left),
            label: const Text('Back'),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: last
                ? () => Navigator.of(context).maybePop()
                : () => _go(_page + 1),
            icon: Icon(last ? AppIcons.check : AppIcons.chevron_right),
            label: Text(last ? 'Done' : 'Next'),
            style: FilledButton.styleFrom(
                backgroundColor: c.primary, minimumSize: const Size(0, 48)),
          ),
        ]),
      );
}
