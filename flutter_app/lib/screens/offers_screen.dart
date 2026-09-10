import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// A member offer, as it appears inside `/Reports/HomePageStats` under `myoffers`.
///
/// Offers have no endpoint of their own and every row's `id` is 0, so `code` is the only
/// usable identity — which is why the detail screen keys on it.
class MemberOffer {
  final String code;
  final String title;
  final String description;
  final String imageUrl;
  final DateTime? expiry;

  const MemberOffer({
    required this.code,
    this.title = '',
    this.description = '',
    this.imageUrl = '',
    this.expiry,
  });

  bool get isExpired =>
      expiry != null && expiry!.isBefore(DateTime.now());

  static String _str(dynamic v) => v == null ? '' : '$v'.trim();

  /// First attachment/preview image, whichever the payload used.
  static String _image(Map<String, dynamic> m) {
    for (final key in ['attachments', 'previewImages']) {
      final list = m[key];
      if (list is List) {
        for (final item in list) {
          if (item is Map) {
            final url = _str(item['documentUrl'] ?? item['url'] ?? item['path']);
            if (url.isNotEmpty) return UserSession.resolvePhotoUrl(url);
          }
        }
      }
    }
    return UserSession.resolvePhotoUrl(
        _str(m['imageUrl'] ?? m['image'] ?? m['bannerUrl']));
  }

  factory MemberOffer.fromJson(Map<String, dynamic> m) {
    final raw = _str(m['expiryDate'] ?? m['ExpiryDate'] ?? m['validTill']);
    return MemberOffer(
      code: _str(m['code'] ?? m['Code'] ?? m['offerCode']),
      title: _str(m['title'] ?? m['name'] ?? m['text'] ?? m['Title']),
      description: _str(m['description'] ?? m['value'] ?? m['details']),
      imageUrl: _image(m),
      expiry: raw.isEmpty ? null : DateTime.tryParse(raw),
    );
  }
}

List<MemberOffer> parseOffers(List<dynamic> raw) => raw
    .whereType<Map>()
    .map((m) => MemberOffer.fromJson(Map<String, dynamic>.from(m)))
    .where((o) => o.code.isNotEmpty || o.title.isNotEmpty)
    .toList(growable: false);

/// Offers — the member's available offers, from the home stats payload.
class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final offers = parseOffers(session.myOffers);

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const AppHeader(
          title: 'Offers',
          subtitle: 'Member deals from your club',
          showBack: true,
        ),
        Expanded(
          child: offers.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.local_offer_outlined, size: 48, color: c.textMuted),
                    const SizedBox(height: Gaps.sm),
                    Text('No offers right now.',
                        style: TextStyle(color: c.textSecondary, fontSize: 14)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      Gaps.lg, Gaps.md, Gaps.lg, Gaps.xxxl),
                  itemCount: offers.length,
                  itemBuilder: (_, i) => _card(context, c, offers[i]),
                ),
        ),
      ]),
    );
  }

  Widget _card(BuildContext context, AppColors c, MemberOffer o) => Padding(
        padding: const EdgeInsets.only(bottom: Gaps.md),
        child: GestureDetector(
          onTap: o.code.isEmpty
              ? null
              : () => context.push('/offer/${Uri.encodeComponent(o.code)}'),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: c.isDark ? Border.all(color: c.border) : null,
              boxShadow: Shadows.card(c),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (o.imageUrl.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(o.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            color: c.surfaceAlt,
                            child: Icon(Icons.local_offer,
                                size: 32, color: c.textMuted),
                          )),
                ),
              Padding(
                padding: const EdgeInsets.all(Gaps.md),
                child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(o.title.isEmpty ? o.code : o.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                    ),
                    if (o.isExpired)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(Radii.xxl),
                        ),
                        child: Text('Expired',
                            style: TextStyle(
                                color: c.danger,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                  ]),
                  if (o.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(o.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                  ],
                ]),
              ),
            ]),
          ),
        ),
      );
}
