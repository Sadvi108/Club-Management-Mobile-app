import '../services/live_refresh.dart';
import '../theme/app_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// Club news and offers are HomePageStats content. Competitions have their own route.
class EventsScreen extends StatefulWidget {
  final String initialTab;
  const EventsScreen({super.key, this.initialTab = 'events'});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with LiveRefreshMixin<EventsScreen> {
  @override
  bool get canLiveRefresh => !UserSession.instance.loading;
  @override
  Future<void> refreshLiveData() =>
      UserSession.instance.refresh(background: true);

  late bool _offers;
  @override
  void initState() {
    super.initState();
    _offers = widget.initialTab == 'offers';
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab)
      _offers = widget.initialTab == 'offers';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final rows =
        (_offers ? session.myOffers : session.myNews).whereType<Map>().toList();
    return Scaffold(
        body: Column(children: [
      const AppHeader(title: 'Events & Offers', showBack: true),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: [
            for (final item in const [
              (false, 'Events', AppIcons.event_outlined),
              (true, 'Offers', AppIcons.sell_outlined)
            ])
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor:
                                  _offers == item.$1 ? c.primary : c.surfaceAlt,
                              foregroundColor: _offers == item.$1
                                  ? Colors.white
                                  : c.textSecondary),
                          onPressed: () => setState(() => _offers = item.$1),
                          icon: Icon(item.$3, size: 16),
                          label: Text(item.$2)))),
          ])),
      Expanded(
          child: RefreshIndicator(
              onRefresh: session.refresh,
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (session.loading)
                      const Center(child: CircularProgressIndicator()),
                    if (session.homeStats == null &&
                        session.homeStatsError != null)
                      Column(children: [
                        const Text('Could not load club updates.'),
                        TextButton(
                            onPressed: session.refresh,
                            child: const Text('Retry')),
                      ])
                    else if (!session.loading && rows.isEmpty)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(children: [
                            Icon(
                                _offers
                                    ? AppIcons.sell_outlined
                                    : AppIcons.event_outlined,
                                size: 48,
                                color: c.textMuted),
                            const SizedBox(height: 14),
                            Text(
                                _offers
                                    ? 'Special Offers'
                                    : 'Club Events & News',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary)),
                            const SizedBox(height: 8),
                            Text(
                                _offers
                                    ? 'No promotional offers available right now.'
                                    : 'No upcoming club events or news announcements posted right now.',
                                textAlign: TextAlign.center),
                          ])),
                    for (final row in rows) _card(context, row),
                  ]))),
    ]));
  }

  Widget _card(BuildContext context, Map row) {
    final c = context.appColors;
    final files = row['attachments'] ?? row['previewImages'];
    final url = files is List && files.isNotEmpty && files.first is Map
        ? '${files.first['documentUrl'] ?? ''}'
        : '${row['imageUrl'] ?? ''}';
    return Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: InkWell(
            onTap: _offers
                ? () => context.push(
                    '/offer/${Uri.encodeComponent('${row['code'] ?? ''}')}')
                : null,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (url.isNotEmpty)
                CachedNetworkImage(
                    imageUrl: url,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => SizedBox(
                        height: 100,
                        child: Center(
                            child: Icon(Icons.image_outlined,
                                color: c.textMuted)))),
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${row['title'] ?? row['name'] ?? (_offers ? 'Club offer' : 'Club Event')}',
                            style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                            '${row['description'] ?? row['content'] ?? ''}'
                                .replaceAll(RegExp(r'<[^>]*>'), ''),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.textSecondary, fontSize: 13)),
                        if (_offers)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text('View Offer',
                                  style: TextStyle(
                                      color: c.primary,
                                      fontWeight: FontWeight.w700))),
                      ])),
            ])));
  }
}
