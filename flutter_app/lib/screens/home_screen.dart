import '../services/live_refresh.dart';
import '../theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/student_switcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with LiveRefreshMixin<HomeScreen> {
  @override
  bool get canLiveRefresh => !UserSession.instance.loading;
  @override
  Future<void> refreshLiveData() =>
      UserSession.instance.refresh(background: true);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final statsFailed =
        session.homeStats == null && session.homeStatsError != null;
    final waiting = session.loading && session.homeStats == null;
    final due = session.dueAmount;
    final dueLabel = due.toStringAsFixed(due == due.roundToDouble() ? 0 : 2);
    final grade = session.currentGrade
        .replaceFirst(RegExp(r'Grade\s*', caseSensitive: false), '')
        .split(' ')
        .first;
    Widget stat(String number, String label) => Expanded(
            child: Column(children: [
          Text(number.isEmpty ? '—' : number,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(
                  color: Color(0xD9FFFFFF), fontSize: 10, letterSpacing: .5)),
        ]));
    final stats = Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(18)),
        child: waiting
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : statsFailed
                ? InkWell(
                    onTap: session.refresh,
                    child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text("Couldn't load · tap to retry",
                            style: TextStyle(color: Colors.white))))
                : Row(children: [
                    stat('${session.invoiceCount}', 'Invoices'),
                    Container(
                        width: 1, height: 34, color: const Color(0x40FFFFFF)),
                    stat(grade, 'Current Grade'),
                    Container(
                        width: 1, height: 34, color: const Color(0x40FFFFFF)),
                    stat(dueLabel, 'Due (RM)')
                  ]));
    final trainingTime = (session.myInfo?['trainingTme'] ?? '')
        .toString()
        .split(RegExp(r'\r?\n'))
        .where((s) => s.trim().isNotEmpty)
        .firstOrNull;
    return ColoredBox(
        color: c.background,
        child: RefreshIndicator(
            onRefresh: session.refresh,
            child: ListView(
                padding: EdgeInsets.only(
                    bottom: 100 + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (session.hasNewerVersion)
                    MaterialBanner(
                        content: Text(
                            'New version available (${session.latestStoreVersion})'),
                        actions: [
                          TextButton(
                              onPressed: session.dismissStoreVersionBanner,
                              child: const Text('Dismiss'))
                        ]),
                  DashboardHeader(
                      session: session,
                      stats: stats,
                      onAvatarTap: () => showStudentSwitcher(context)),
                  Transform.translate(
                      offset: const Offset(0, -20),
                      child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 16),
                          decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: Shadows.shade(c),
                              border: c.isDark
                                  ? Border.all(color: c.border)
                                  : null),
                          child: Row(children: [
                            for (final item in const [
                              (
                                'Training',
                                AppIcons.fitness_center,
                                '/training'
                              ),
                              (
                                'Attendance',
                                AppIcons.check_circle_outline,
                                '/attendance'
                              ),
                              (
                                'Timetable',
                                AppIcons.calendar_month_outlined,
                                '/schedule'
                              ),
                              (
                                'Virtual ID',
                                AppIcons.badge_outlined,
                                '/profile'
                              ),
                              (
                                'Profile',
                                AppIcons.account_circle_outlined,
                                '/profile'
                              ),
                            ])
                              Expanded(
                                  child: InkWell(
                                      onTap: () => context.push(item.$3),
                                      child: Column(children: [
                                        Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                                color: c.surfaceAlt,
                                                shape: BoxShape.circle),
                                            child: Icon(item.$2,
                                                size: 22, color: c.primary)),
                                        const SizedBox(height: 6),
                                        FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(item.$1,
                                                style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: c.textPrimary))),
                                      ]))),
                          ]))),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: InkWell(
                          onTap: () => context.go('/payments'),
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  gradient: LinearGradient(
                                      colors: c.isDark
                                          ? const [
                                              Color(0xFF2D1A0A),
                                              Color(0xFF3F2410)
                                            ]
                                          : const [
                                              Color(0xFFFEF3C7),
                                              Color(0xFFFED7AA)
                                            ])),
                              child: Row(children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('FEES DUE',
                                          style: TextStyle(
                                              color: c.isDark
                                                  ? const Color(0xFFFDBA74)
                                                  : const Color(0xFF9A3412),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                      if (waiting)
                                        const CircularProgressIndicator()
                                      else
                                        Text(
                                            statsFailed
                                                ? 'Unavailable'
                                                : 'RM ${dueLabel}',
                                            style: TextStyle(
                                                color: c.isDark
                                                    ? const Color(0xFFFED7AA)
                                                    : const Color(0xFF7C2D12),
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800)),
                                      Text(
                                          statsFailed
                                              ? 'Open payments to retry'
                                              : '${session.invoiceCount} invoice${session.invoiceCount == 1 ? '' : 's'} pending',
                                          style: TextStyle(
                                              color: c.isDark
                                                  ? const Color(0xFFFDBA74)
                                                  : const Color(0xFF9A3412),
                                              fontSize: 11)),
                                    ])),
                                const SizedBox(width: 8),
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                        color: c.primary,
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    child: const Row(children: [
                                      Text('Pay Now',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700)),
                                      SizedBox(width: 6),
                                      Icon(AppIcons.arrow_forward,
                                          color: Colors.white, size: 14)
                                    ])),
                              ])))),
                  const DashboardSection("Today's Class",
                      link: 'See all', route: '/schedule'),
                  Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: Shadows.soft(c)),
                      child: Row(children: [
                        Container(
                            width: 4,
                            height: 50,
                            decoration: BoxDecoration(
                                color: c.primary,
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  trainingTime ??
                                      (session.loading
                                          ? 'Loading…'
                                          : 'No training time set'),
                                  style: TextStyle(
                                      fontSize: 11, color: c.textSecondary)),
                              Text(
                                  session.tCenterName.isEmpty
                                      ? 'Training Center'
                                      : session.tCenterName,
                                  style: TextStyle(
                                      fontSize: 15,
                                      color: c.textPrimary,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  'with ${session.myInfo?['instructorName'] ?? 'your instructor'}',
                                  style: TextStyle(
                                      fontSize: 11, color: c.textSecondary)),
                            ])),
                        const SizedBox(width: 6),
                        TextButton(
                            onPressed: () => context.push('/qr-scan'),
                            style: TextButton.styleFrom(
                                backgroundColor: c.surfaceAlt),
                            child: const Text('Check In',
                                style: TextStyle(fontSize: 11))),
                      ])),
                  const DashboardSection('Quick Access'),
                  const DashboardGrid(items: kQuickCards),
                  if (session.myOffers.isNotEmpty) ...[
                    const DashboardSection('Featured Offers',
                        link: 'View all', route: '/events?tab=offers'),
                    SizedBox(
                        height: 180,
                        child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: session.myOffers.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) {
                              final offer = session.myOffers[i] as Map;
                              final attachments = offer['attachments'] ??
                                  offer['previewImages'];
                              final url = attachments is List &&
                                      attachments.isNotEmpty &&
                                      attachments.first is Map
                                  ? (attachments.first['documentUrl'] ?? '')
                                      .toString()
                                  : '';
                              return InkWell(
                                  onTap: () => context.push(
                                      '/offer/${Uri.encodeComponent('${offer['code'] ?? ''}')}'),
                                  child: Container(
                                      width: MediaQuery.sizeOf(context).width -
                                          (session.myOffers.length > 1
                                              ? 76
                                              : 40),
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                          color: c.surfaceAlt,
                                          borderRadius:
                                              BorderRadius.circular(22)),
                                      child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            if (url.isNotEmpty)
                                              CachedNetworkImage(
                                                  imageUrl: url,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) =>
                                                      const SizedBox()),
                                            const DecoratedBox(
                                                decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                  Color(0x0D0F172A),
                                                  Color(0xD90F172A)
                                                ]))),
                                            Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      const Text('MEMBER OFFER',
                                                          style: TextStyle(
                                                              color: Color(
                                                                  0xFFFDBA74),
                                                              fontSize: 10,
                                                              letterSpacing:
                                                                  1.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700)),
                                                      Text(
                                                          '${offer['name'] ?? offer['title'] ?? 'Club offer'}',
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800)),
                                                      Text(
                                                          '${offer['code'] ?? ''}',
                                                          style: const TextStyle(
                                                              color: Color(
                                                                  0xD9FFFFFF),
                                                              fontSize: 11)),
                                                    ])),
                                          ])));
                            })),
                  ],
                ])));
  }
}
