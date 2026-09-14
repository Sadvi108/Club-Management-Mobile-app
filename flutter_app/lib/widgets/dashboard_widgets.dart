import '../theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import 'member_avatar.dart';

class DashboardHeader extends StatelessWidget {
  final UserSession session;
  final Widget? stats;
  final VoidCallback? onAvatarTap;
  final bool instructor;
  const DashboardHeader(
      {super.key,
      required this.session,
      this.stats,
      this.onAvatarTap,
      this.instructor = false});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final name = session.displayName.isEmpty
        ? (instructor ? 'Instructor' : 'Member')
        : session.displayName;
    final status =
        (session.authData?['status'] ?? session.myInfo?['status'] ?? '')
            .toString();
    final active = status.toLowerCase() != 'inactive';
    final ringColor =
        active ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5);
    Widget action(IconData icon, VoidCallback onTap) => SizedBox(
        width: 42,
        height: 42,
        child: IconButton(
            onPressed: onTap,
            style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: .22)),
            icon: Icon(icon, color: Colors.white, size: 20)));
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.paddingOf(context).top + 6, 20, instructor ? 26 : 30),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: c.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(28))),
      child: Column(children: [
        Row(children: [
          GestureDetector(
              onTap: onAvatarTap,
              child: Container(
                  padding: EdgeInsets.all(instructor ? 0 : 2.5),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: instructor
                          ? null
                          : Border.all(color: ringColor, width: 2.5)),
                  child: MemberAvatar(name: name, url: session.clubPic))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(instructor ? 'Welcome,' : 'Hello,',
                    style: const TextStyle(
                        color: Color(0xD9FFFFFF), fontSize: 12)),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.3)),
                const SizedBox(height: 4),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .22),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(AppIcons.verified_user,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Flexible(
                          child: Text(
                              session.clubDisplayName.isEmpty
                                  ? 'Member'
                                  : session.clubDisplayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFFFFF7ED),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)))
                    ])),
                if (!instructor && status.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: ringColor.withValues(alpha: .25),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.circle, color: ringColor, size: 6),
                            const SizedBox(width: 5),
                            Text(active ? 'Active' : 'Inactive',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                          ]))),
              ])),
          const SizedBox(width: 10),
          if (instructor)
            action(AppIcons.settings_outlined,
                () => context.go('/instructor/settings'))
          else
            MemberAvatar(
                name: name,
                url: session.studentPhoto,
                localPhoto: session.localPhotoB64,
                size: 36,
                radius: 10),
          const SizedBox(width: 10),
          Badge(
              isLabelVisible: session.unreadNotifications > 0,
              label: Text(session.unreadNotifications > 99
                  ? '99+'
                  : '${session.unreadNotifications}'),
              child: action(AppIcons.notifications_outlined,
                  () => context.push('/notifications'))),
        ]),
        if (stats != null) ...[const SizedBox(height: 22), stats!],
      ]),
    );
  }
}

class DashboardSection extends StatelessWidget {
  final String title;
  final String? link, route;
  const DashboardSection(this.title, {super.key, this.link, this.route});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Row(children: [
        Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.appColors.textPrimary))),
        if (link != null)
          GestureDetector(
              onTap: () => context.push(route!),
              child: Text(link!,
                  style: TextStyle(
                      color: context.appColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700))),
      ]));
}

class DashboardGrid extends StatelessWidget {
  final List<QuickCard> items;
  final int columns;
  const DashboardGrid({super.key, required this.items, this.columns = 4});
  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LayoutBuilder(
            builder: (context, constraints) => Wrap(
                spacing: 10,
                runSpacing: 14,
                children: items
                    .map((item) => SizedBox(
                          width: (constraints.maxWidth - 10 * (columns - 1)) /
                              columns,
                          child: Material(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => context.push(item.route),
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 12),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        border: c.isDark
                                            ? Border.all(color: c.border)
                                            : null),
                                    child: Column(children: [
                                      Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: item.color.withValues(
                                                  alpha:
                                                      c.isDark ? .20 : .094)),
                                          child: Icon(item.icon,
                                              color: item.color, size: 22)),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                          height: 28 *
                                              MediaQuery.textScalerOf(context)
                                                  .scale(1),
                                          child: Text(item.label,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: c.textPrimary,
                                                  fontSize: 10,
                                                  height: 1.3,
                                                  fontWeight:
                                                      FontWeight.w600))),
                                    ])),
                              )),
                        ))
                    .toList())));
  }
}
