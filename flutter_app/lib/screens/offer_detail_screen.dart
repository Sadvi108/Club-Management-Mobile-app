import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/rn_api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../theme/ion.dart';
import '../widgets/rn_kit.dart';
import '../widgets/use_api.dart';
import 'events_screen.dart' show firstImage;

/// Port of `frontend/app/offer-detail.tsx` (Expo v2.11.1).
///
/// Offers are redeemed by showing this screen at the counter, so it doubles as the voucher.
/// It selects STRICTLY by code — falling back to another offer would present someone else's
/// terms and expiry as the member's own.
class OfferDetailScreen extends StatefulWidget {
  final String code;
  const OfferDetailScreen({super.key, required this.code});
  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> with UseApi<OfferDetailScreen> {
  // Offers only exist inside HomePageStats — refetch and select by code (ids are all 0).
  late final _stats = useApi(RnApi.homePageStats, initial: UserSession.instance.homeStats);

  @override
  void initState() {
    super.initState();
    _stats;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final user = context.watch<UserSession>().authData ?? const <String, dynamic>{};
    final offers = ((_stats.data?['myoffers'] as List?) ?? const []).whereType<Map>();
    final offer = offers.where((o) => '${o['code'] ?? ''}' == widget.code).firstOrNull;
    final img = offer == null ? null : firstImage(offer);
    final expiry = DateTime.tryParse('${offer?['expiryDate'] ?? ''}');
    final expired = expiry != null && expiry.isBefore(DateTime.now());
    final code = '${offer?['code'] ?? ''}';
    final userName = '${user['name'] ?? ''}'.trim();
    final clubName = '${user['clubName'] ?? ''}';

    return Scaffold(
      backgroundColor: c.background,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const RnHeader(title: 'Offer', horizontal: Gaps.lg),
        Expanded(
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            if (_stats.loading && offer == null) const RnSpinner(vertical: 60),
            if (_stats.error != null)
              Padding(
                padding: const EdgeInsets.all(Gaps.xl),
                child: Text(_stats.error!, style: TextStyle(color: c.danger, fontSize: 13)),
              ),
            if (!_stats.loading && offer == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 70),
                child: Column(children: [
                  Icon(Ion.pricetagOutline, size: 48, color: c.textMuted),
                  const SizedBox(height: 8),
                  Text('Offer not found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                ]),
              ),
            if (offer != null) ...[
              Container(
                height: 220,
                margin: const EdgeInsets.symmetric(horizontal: Gaps.xl),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.xl)),
                child: Stack(fit: StackFit.expand, children: [
                  if (img != null)
                    CachedNetworkImage(imageUrl: img, fit: BoxFit.cover, errorWidget: (_, __, ___) => const SizedBox()),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x000F172A), Color(0xD90F172A)],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration:
                              BoxDecoration(color: const Color(0xF2FFFFFF), borderRadius: BorderRadius.circular(10)),
                          child: Text((code.isEmpty ? 'OFFER' : code).toUpperCase(),
                              style: TextStyle(
                                  color: c.primary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                        ),
                        Text('${offer['name'] ?? offer['title'] ?? ''}',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ]),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(Gaps.xl, 16, Gaps.xl, 0),
                padding: const EdgeInsets.all(16),
                decoration: rnCard(c, radius: Radii.xl),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DETAILS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: c.textMuted)),
                  const SizedBox(height: 8),
                  Text(
                      '${offer['description'] ?? ''}'.replaceAll('\r\n', '\n').trim().isEmpty
                          ? 'No further details.'
                          : '${offer['description']}'.replaceAll('\r\n', '\n').trim(),
                      style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 20 / 13.5)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: Row(children: [
                        Icon(Ion.calendarOutline, size: 16, color: expired ? c.danger : c.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Valid till',
                                style: TextStyle(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 1),
                            Text('${fmtDateGB(offer['expiryDate'], empty: '—')}${expired ? ' (expired)' : ''}',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: expired ? c.danger : c.textPrimary)),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(children: [
                        Icon(Ion.businessOutline, size: 16, color: c.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Academy',
                                style: TextStyle(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 1),
                            Text(clubName.isEmpty ? 'Your Academy' : clubName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
                          ]),
                        ),
                      ]),
                    ),
                  ]),
                ]),
              ),
              // Redeem strip — what the shop keeper needs to see
              Container(
                margin: const EdgeInsets.fromLTRB(Gaps.xl, 16, Gaps.xl, 0),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(Radii.xl),
                ),
                child: Row(children: [
                  const Icon(Ion.qrCodeOutline, size: 28, color: Colors.white),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Show this screen to redeem',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('${userName.isEmpty ? 'Member' : userName} · $code',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
