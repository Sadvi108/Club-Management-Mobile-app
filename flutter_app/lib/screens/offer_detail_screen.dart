import '../services/live_refresh.dart';
import '../theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import 'offers_screen.dart';

/// Offer detail — this screen IS the voucher shown at the counter.
///
/// It is selected STRICTLY by code. Falling back to "the first offer" would present
/// someone else's terms and expiry as the member's own, at the moment they are trying to
/// redeem it. A code that matches nothing shows a not-found state instead.
class OfferDetailScreen extends StatefulWidget {
  final String code;
  const OfferDetailScreen({super.key, required this.code});
  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen>
    with LiveRefreshMixin<OfferDetailScreen> {
  @override
  bool get canLiveRefresh => !UserSession.instance.loading;
  @override
  Future<void> refreshLiveData() =>
      UserSession.instance.refresh(background: true);

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _fmt(DateTime? d) => d == null
      ? '-'
      : '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final offers = parseOffers(session.myOffers);
    final match = offers.where((o) => o.code == widget.code);
    final offer = match.isEmpty ? null : match.first;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const AppHeader(title: 'Offer', showBack: true),
        Expanded(
          child: offer == null
              ? _notFound(c)
              : ListView(
                  padding: const EdgeInsets.only(bottom: Gaps.xxxl),
                  children: [
                    if (offer.imageUrl.isNotEmpty)
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(offer.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                  color: c.surfaceAlt,
                                  child: Icon(AppIcons.local_offer,
                                      size: 40, color: c.textMuted),
                                )),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(Gaps.lg),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (offer.isExpired) _expiredBanner(c),
                            Text(offer.title.isEmpty ? offer.code : offer.title,
                                style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: Gaps.sm),
                            if (offer.description.isNotEmpty)
                              Text(offer.description,
                                  style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 14,
                                      height: 1.5)),
                            const SizedBox(height: Gaps.xl),
                            _voucher(c, session, offer),
                          ]),
                    ),
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _expiredBanner(AppColors c) => Container(
        margin: const EdgeInsets.only(bottom: Gaps.md),
        padding: const EdgeInsets.all(Gaps.sm),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.danger.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, size: 18, color: c.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text('This offer has expired and may not be accepted.',
                style: TextStyle(
                    color: c.danger,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  /// The strip a staff member checks: who this belongs to, its code, and until when.
  Widget _voucher(AppColors c, UserSession s, MemberOffer o) => Container(
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.border),
          boxShadow: Shadows.card(c),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _line(c, 'Member',
              s.displayName.trim().isEmpty ? '-' : s.displayName.trim()),
          Divider(height: Gaps.md, color: c.border),
          _line(c, 'Registration No',
              s.registrationNo.isEmpty ? s.studentCode : s.registrationNo),
          Divider(height: Gaps.md, color: c.border),
          _line(c, 'Offer code', o.code.isEmpty ? '-' : o.code),
          Divider(height: Gaps.md, color: c.border),
          _line(c, 'Valid until', _fmt(o.expiry)),
          const SizedBox(height: Gaps.md),
          Text('Show this screen at the counter to redeem.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: 11.5)),
        ]),
      );

  Widget _line(AppColors c, String label, String value) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value.isEmpty ? '-' : value,
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800)),
        ),
      ]);

  Widget _notFound(AppColors c) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_offer_outlined, size: 48, color: c.textMuted),
            const SizedBox(height: Gaps.sm),
            Text('This offer is no longer available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('It may have expired or been withdrawn by your club.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 13)),
          ]),
        ),
      );
}
