import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/rn_api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../theme/ion.dart';
import '../widgets/rn_kit.dart';
import '../widgets/use_api.dart';

String? firstImage(Map e) {
  for (final key in ['attachments', 'previewImages']) {
    final list = e[key];
    if (list is List && list.isNotEmpty && list.first is Map) {
      final url = '${(list.first as Map)['documentUrl'] ?? ''}';
      if (url.isNotEmpty) return url;
    }
  }
  final raw = '${e['imageUrl'] ?? ''}';
  return raw.isEmpty ? null : raw;
}

/// Port of `frontend/app/events.tsx` (Expo v2.11.1) — Events and Offers from HomePageStats.
class EventsScreen extends StatefulWidget {
  final String initialTab;
  const EventsScreen({super.key, this.initialTab = 'events'});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with UseApi<EventsScreen> {
  late int _tab = widget.initialTab == 'offers' ? 1 : 0;
  late final _stats = useApi(RnApi.homePageStats, initial: UserSession.instance.homeStats);

  @override
  void initState() {
    super.initState();
    _stats;
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) _tab = widget.initialTab == 'offers' ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final user = context.watch<UserSession>().authData ?? const <String, dynamic>{};
    final clubName = '${user['clubName'] ?? ''}'.isEmpty ? 'Academy' : '${user['clubName']}';
    final offers = ((_stats.data?['myoffers'] as List?) ?? const []).whereType<Map>().toList();
    final news = ((_stats.data?['mynews'] as List?) ?? const []).whereType<Map>().toList();

    Widget empty(IconData icon, String title, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(children: [
            Icon(icon, size: 48, color: c.textMuted),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 6),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 13, height: 18 / 13)),
          ]),
        );

    Widget card({
      required Map e,
      required String pill,
      required String title,
      required String desc,
      required int descLines,
      required String meta,
      required bool alwaysImage,
      VoidCallback? onTap,
    }) {
      final img = firstImage(e);
      final content = Container(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        decoration: rnCard(c, radius: Radii.xl, shadow: Shadows.card(c)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (img != null || alwaysImage)
            SizedBox(
              height: 160,
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: c.surfaceAlt),
                if (img != null)
                  CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_, __, ___) => const SizedBox()),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x000F172A), Color(0xCC0F172A)],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xF2FFFFFF), borderRadius: BorderRadius.circular(10)),
                    child: Text(pill,
                        style: TextStyle(color: c.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(desc,
                    maxLines: descLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textSecondary, height: 17 / 12)),
              ],
              const SizedBox(height: 10),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 4, children: [
                Icon(Ion.calendarOutline, size: 14, color: c.textSecondary),
                Text(meta, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                Icon(Ion.businessOutline, size: 14, color: c.textSecondary),
                Text(clubName, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ]),
      );
      return onTap == null ? content : Touchable(activeOpacity: 0.92, onPress: onTap, child: content);
    }

    String squash(dynamic v) => '${v ?? ''}'.replaceAll(RegExp(r'\s+'), ' ').trim();

    final children = <Widget>[];
    if (_stats.loading) children.add(const RnSpinner());
    if (_tab == 0) {
      if (!_stats.loading && news.isEmpty) {
        children.add(empty(Ion.calendarOutline, 'Club Events & News',
            'No upcoming club events or news announcements posted right now. Check back soon for club activities and updates!'));
      }
      for (final e in news) {
        final date = fmtDateGB(e['eventDate'] ?? e['createdDate'] ?? e['date']);
        children.add(card(
          e: e,
          pill: 'EVENT',
          title: '${e['title'] ?? e['name'] ?? ''}'.isEmpty ? 'Club Event' : '${e['title'] ?? e['name']}',
          desc: squash(e['description'] ?? e['content']),
          descLines: 4,
          meta: date.isEmpty ? 'Upcoming' : date,
          alwaysImage: false,
        ));
      }
    } else {
      if (!_stats.loading && offers.isEmpty) {
        children.add(empty(Ion.pricetagOutline, 'Special Offers', 'No promotional offers available right now.'));
      }
      for (final e in offers) {
        final code = '${e['code'] ?? ''}';
        children.add(card(
          e: e,
          pill: (code.isEmpty ? 'OFFER' : code).toUpperCase(),
          title: '${e['name'] ?? e['title'] ?? ''}',
          desc: squash(e['description']),
          descLines: 3,
          meta: 'Valid till ${fmtDateGB(e['expiryDate'])}',
          alwaysImage: true,
          onTap: () => context.push('/offer/${Uri.encodeComponent(code)}'),
        ));
      }
    }

    return Scaffold(
      backgroundColor: c.background,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const RnHeader(title: 'Events & Offers', horizontal: Gaps.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.xl, vertical: 12),
          child: Row(children: [
            for (final (i, t) in const ['Events', 'Offers'].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Touchable(
                  onPress: () => setState(() => _tab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _tab == i ? c.primary : c.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(i == 0 ? Ion.calendarOutline : Ion.pricetagsOutline,
                          size: 16, color: _tab == i ? Colors.white : c.textSecondary),
                      const SizedBox(width: 6),
                      Text(t,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _tab == i ? Colors.white : c.textSecondary)),
                    ]),
                  ),
                ),
              ),
            ],
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            onRefresh: _stats.reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.xl, Gaps.xl, 120),
              children: children,
            ),
          ),
        ),
      ]),
    );
  }
}
