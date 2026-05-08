import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../services/api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/app_icon_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _openEditSheet() async {
    final session = UserSession.instance;
    final info = session.myInfo ?? <String, dynamic>{};
    final name = TextEditingController(text: (info['name'] ?? '').toString());
    final phone = TextEditingController(text: (info['handPhone'] ?? info['phone'] ?? '').toString());
    final email = TextEditingController(text: (info['email'] ?? '').toString());
    final c = context.appColors;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text('Edit Profile', style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 8),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                try {
                  await Api.profileUpdateProfile(<String, dynamic>{
                    'name': name.text,
                    'handPhone': phone.text,
                    'email': email.text,
                  });
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated')),
                  );
                  await UserSession.instance.refresh();
                } catch (e) {
                  debugPrint('UpdateProfile failed: $e');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              },
              borderRadius: BorderRadius.circular(Radii.md),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(Radii.md)),
                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _markNotificationRead(dynamic id) async {
    if (id == null) return;
    try {
      await Api.profileUpdateNotification2Read(<String, dynamic>{'id': id, 'groupId': id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification marked read')),
        );
      }
      await UserSession.instance.refresh();
    } catch (e) {
      debugPrint('UpdateNotification2Read failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = context.watch<ThemeProvider>();
    final session = context.watch<UserSession>();
    final liveName = session.displayName.isNotEmpty ? session.displayName : kStudent.name;
    final liveId = session.registrationNo.isNotEmpty ? session.registrationNo : kStudent.id;
    final livePhoto = session.clubPic.isNotEmpty ? session.clubPic : kStudent.photo;
    final liveMembership = session.clubName.isNotEmpty ? session.clubName : kStudent.membership;
    final liveBelt = session.currentGrade.isNotEmpty ? session.currentGrade : kStudent.belt;
    final liveLevel = session.tCenterName.isNotEmpty ? session.tCenterName : kStudent.level;
    return Container(
      color: c.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          children: [
            // Gradient header
            Container(
              padding: EdgeInsets.fromLTRB(Gaps.xl, MediaQuery.of(context).padding.top + 6, Gaps.xl, 50),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(children: [
                Row(children: [
                  const Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  AppIconButton(
                    icon: Icons.edit,
                    onPressed: _openEditSheet,
                    backgroundColor: Colors.white.withOpacity(0.22),
                    foregroundColor: Colors.white,
                    size: 38,
                  ),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.6), width: 2)),
                  child: CircleAvatar(radius: 45, backgroundImage: CachedNetworkImageProvider(livePhoto)),
                ),
                const SizedBox(height: 12),
                Text(liveName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text(liveId, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(14)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.verified_user, size: 14, color: Color(0xFFFFF7ED)),
                    const SizedBox(width: 4),
                    Text(liveMembership, style: const TextStyle(color: Color(0xFFFFF7ED), fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            ),

            // Virtual ID card (overlapping)
            Transform.translate(
              offset: const Offset(0, -36),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: Gaps.xl),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: c.surface, borderRadius: BorderRadius.circular(Radii.xl),
                  border: c.isDark ? Border.all(color: c.border) : null,
                  boxShadow: Shadows.card(c),
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.asset(kLogoAssetPath, width: 22, height: 22, fit: BoxFit.cover)),
                          const SizedBox(width: 8),
                          Text('D-CLIX', style: TextStyle(color: c.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
                        ]),
                        const SizedBox(height: 8),
                        Text(liveName, style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('$liveLevel · $liveBelt', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                        const SizedBox(height: 10),
                        Row(children: List.generate(20, (i) =>
                          Padding(padding: const EdgeInsets.only(right: 2), child: Container(width: 2, height: (20 + (i * 7) % 12).toDouble(), color: c.textPrimary.withOpacity(i % 3 == 0 ? 1 : 0.6))))),
                        const SizedBox(height: 4),
                        Text(liveId, style: TextStyle(color: c.textPrimary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
                    child: Icon(Icons.qr_code_2, size: 60, color: c.primary),
                  ),
                ]),
              ),
            ),

            // Theme toggle
            Container(
              margin: const EdgeInsets.symmetric(horizontal: Gaps.xl).copyWith(top: 0),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(Radii.xl),
                border: c.isDark ? Border.all(color: c.border) : null,
                boxShadow: Shadows.card(c),
              ),
              child: Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                  child: Icon(theme.isDark ? Icons.dark_mode : Icons.light_mode, color: c.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(theme.isDark ? 'Dark Mode' : 'Light Mode', style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(theme.isDark ? 'Orange & black' : 'Orange & white', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Switch(
                  value: theme.isDark,
                  onChanged: (v) => theme.setDark(v),
                  activeColor: Colors.white,
                  activeTrackColor: c.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: c.border,
                ),
              ]),
            ),

            const SizedBox(height: 18),
            _notificationsCard(context, c, session),
            const SizedBox(height: 18),
            _logoutBtn(context, c),
            const SizedBox(height: 8),
            Text('D-Clix · v1.0.0', style: TextStyle(color: c.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _notificationsCard(BuildContext ctx, AppColors c, UserSession session) {
    final notifs = (session.notifications ?? const []).whereType<Map>().toList();
    if (notifs.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Gaps.xl),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.notifications_active, size: 16, color: c.primary),
            const SizedBox(width: 6),
            Text('LIVE · Notifications (${notifs.length})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          ...notifs.take(8).map((n) {
            final id = n['id'] ?? n['groupId'] ?? n['groupid'];
            final title = (n['text'] ?? n['title'] ?? n['name'] ?? '').toString();
            final body = (n['value'] ?? n['description'] ?? '').toString()
                .replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&nbsp;', ' ').trim();
            return InkWell(
              onTap: () => _markNotificationRead(id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  if (body.isNotEmpty)
                    Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: c.textSecondary)),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _logoutBtn(BuildContext ctx, AppColors c) => InkWell(
        onTap: () {
          UserSession.instance.logout();
          ctx.go('/login');
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.logout, color: c.danger, size: 18),
            const SizedBox(width: 8),
            Text('Logout', style: TextStyle(color: c.danger, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      );
}
