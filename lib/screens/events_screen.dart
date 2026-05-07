import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  int tab = 0;
  static const _tabs = ['Upcoming', 'Registered', 'Certificates'];

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final liveOffers = session.myOffers.whereType<Map>().toList();
    final liveNews = session.myNews.whereType<Map>().toList();
    final filtered = tab == 1 ? kEvents.where((e) => e.registered).toList() : kEvents;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const AppHeader(title: 'Events & Competition', showBack: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.xl, 12, Gaps.xl, 12),
          child: Row(children: List.generate(_tabs.length, (i) {
            final active = tab == i;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < _tabs.length - 1 ? 8 : 0),
                child: InkWell(
                  onTap: () => setState(() => tab = i),
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? c.primary : c.surface,
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: active ? c.primary : c.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(_tabs[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : c.textSecondary)),
                  ),
                ),
              ),
            );
          })),
        ),
        Expanded(
          child: tab != 2
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 40),
                  children: [
                    if (liveOffers.isNotEmpty || liveNews.isNotEmpty)
                      _liveOffersCard(c, liveOffers, liveNews),
                    if (liveOffers.isNotEmpty || liveNews.isNotEmpty)
                      const SizedBox(height: 16),
                    if (filtered.isEmpty)
                      _emptyState(c, Icons.event_busy, 'No events found', 'Try another tab or check back later.')
                    else
                      ...filtered.map((e) => _eventCard(c, e)),
                  ],
                )
              : (kCertificates.isEmpty
                  ? _emptyState(c, Icons.workspace_premium, 'No certificates yet', 'Your certificates will appear here after events.')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(Gaps.xl, 0, Gaps.xl, 40),
                      children: kCertificates.map((cert) => _certCard(c, cert)).toList(),
                    )),
        ),
      ]),
    );
  }

  Widget _liveOffersCard(AppColors c, List<Map> offers, List<Map> news) {
    String stripHtml(String s) =>
        s.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&nbsp;', ' ').trim();
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 4),
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
            Text(
              'LIVE · Offers (${offers.length}) · News (${news.length})',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1),
            ),
          ]),
          const SizedBox(height: 10),
          ...offers.take(3).map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${o['name'] ?? ''}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    Text(stripHtml('${o['description'] ?? ''}'),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ],
                ),
              )),
          ...news.take(2).map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${n['name'] ?? n['title'] ?? ''}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    Text(stripHtml('${n['description'] ?? ''}'),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _emptyState(AppColors c, IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gaps.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, boxShadow: Shadows.card(c)),
              child: Icon(icon, color: c.textMuted, size: 28),
            ),
            const SizedBox(height: 14),
            Text(title, style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _eventCard(AppColors c, event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CachedNetworkImage(imageUrl: event.image, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(color: c.surfaceAlt)),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0x000F172A), Color(0xCC0F172A)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 14, left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(10)),
              child: Text(event.category.toString().toUpperCase(), style: TextStyle(color: c.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ),
          if (event.registered)
            Positioned(
              top: 14, right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: c.success, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.check_circle, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text('REGISTERED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ]),
              ),
            ),
          Positioned(
            bottom: 14, right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(Radii.md)),
              child: Column(children: [
                Text('${event.countdown}', style: TextStyle(color: c.primary, fontSize: 22, fontWeight: FontWeight.w800)),
                const Text('DAYS TO GO', style: TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ]),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.textPrimary)),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: c.textSecondary),
                const SizedBox(width: 4),
                Text(event.date, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.location_on_outlined, size: 14, color: c.textSecondary),
                const SizedBox(width: 4),
                Text(event.location, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
              ]),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              width: double.infinity,
              decoration: BoxDecoration(color: event.registered ? c.success : c.primary, borderRadius: BorderRadius.circular(Radii.md)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(event.registered ? Icons.check : Icons.flash_on, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(event.registered ? 'View Details' : 'Register Now', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _certCard(AppColors c, cert) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: c.isDark ? Border.all(color: c.border) : null,
          boxShadow: Shadows.card(c),
        ),
        child: Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: c.isDark ? const [Color(0xFF3F2410), Color(0xFF2D1A0A)] : const [Color(0xFFFEF3C7), Color(0xFFFDE68A)]),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(Icons.workspace_premium, size: 22, color: c.isDark ? const Color(0xFFFDBA74) : const Color(0xFF92400E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cert.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary)),
              const SizedBox(height: 3),
              Text('Issued by ${cert.issuer} · ${cert.date}', style: TextStyle(fontSize: 11, color: c.textSecondary)),
            ]),
          ),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
            child: Icon(Icons.download, size: 18, color: c.primary),
          ),
        ]),
      );
}
