import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/app_header.dart';

class InstructorSettingsScreen extends StatefulWidget {
  const InstructorSettingsScreen({super.key});

  @override
  State<InstructorSettingsScreen> createState() =>
      _InstructorSettingsScreenState();
}

class _InstructorSettingsScreenState extends State<InstructorSettingsScreen> {
  Future<void> _openProfile() async {
    final c = context.appColors;
    final info = UserSession.instance.myInfo ?? <String, dynamic>{};
    final entries = info.entries.toList();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: ListView(controller: ctrl, children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Profile',
                style: TextStyle(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Text('No profile data.',
                  style: TextStyle(color: c.textSecondary))
            else
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 130,
                      child: Text(e.key,
                          style: TextStyle(
                              color: c.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ),
                    Expanded(
                      child: Text(e.value?.toString() ?? '',
                          style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                  ]),
                ),
          ]),
        ),
      ),
    );
  }

  Future<void> _openSwitchBranch() async {
    final c = context.appColors;
    final session = UserSession.instance;
    final clubCode =
        (session.authData?['clubCode'] ?? session.authData?['clubcode'] ?? '')
            .toString();
    if (clubCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No club code on file.')),
      );
      return;
    }
    List<Map<String, dynamic>> branches = const [];
    try {
      final resp = await Api.accountGetBranchesByClubCode(clubCode);
      final list = (resp is List)
          ? resp
          : (resp is Map && resp['data'] is List
              ? resp['data'] as List
              : const []);
      branches = list
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } catch (e) {
      debugPrint('GetBranchesByClubCode failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Icon(Icons.swap_horiz, color: c.primary, size: 18),
              const SizedBox(width: 8),
              Text('Switch Branch',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ]),
          ),
          const SizedBox(height: 10),
          if (branches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No branches available.',
                  style: TextStyle(color: c.textSecondary)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: branches.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: c.border),
                itemBuilder: (_, i) {
                  final b = branches[i];
                  final id = (b['id'] as num?)?.toInt() ?? 0;
                  return ListTile(
                    title: Text((b['text'] ?? '').toString(),
                        style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await Api.accountChangeClub(
                            <String, dynamic>{'branchId': id});
                        if (!mounted) return;
                        await UserSession.instance.refresh();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Branch switched')),
                        );
                      } catch (e) {
                        debugPrint('ChangeClub failed: $e');
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    },
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _openHelpDesk() async {
    final c = context.appColors;
    final subj = TextEditingController();
    final body = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help Desk'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: subj,
              decoration: const InputDecoration(labelText: 'Subject')),
          const SizedBox(height: 8),
          TextField(
              controller: body,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Message')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await Api.profileSend2ClubHelpDesk(<String, dynamic>{
                  'subject': subj.text,
                  'message': body.text,
                });
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sent to help desk')),
                );
              } catch (e) {
                debugPrint('HelpDesk failed: $e');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
        backgroundColor: c.surface,
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'D-Clix Instructor',
      applicationVersion: UserSession.currentAppVersion,
      applicationLegalese: '© Club Management',
    );
  }

  void _logout() {
    UserSession.instance.logout();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = context.watch<ThemeProvider>();
    final session = context.watch<UserSession>();
    final name = session.displayName.isNotEmpty ? session.displayName : 'Instructor';
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const AppHeader(title: 'Settings'),
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.lg, 100),
              children: [
                Container(
                  padding: const EdgeInsets.all(Gaps.md),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: c.border),
                    boxShadow: Shadows.card(c),
                  ),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.person, color: c.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15)),
                          Text(session.clubDisplayName,
                              style: TextStyle(
                                  color: c.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: Gaps.md),
                _row(c, Icons.person_outline, 'Profile', _openProfile),
                _row(c, Icons.swap_horiz, 'Switch Branch', _openSwitchBranch),
                _row(
                    c,
                    theme.isDark ? Icons.light_mode : Icons.dark_mode,
                    theme.isDark ? 'Light Mode' : 'Dark Mode',
                    theme.toggle),
                _row(c, Icons.support_agent, 'Help Desk', _openHelpDesk),
                _row(c, Icons.info_outline, 'About', _showAbout),
                const SizedBox(height: Gaps.md),
                _row(c, Icons.logout, 'Logout', _logout, danger: true),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _row(AppColors c, IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Gaps.md, vertical: Gaps.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: c.border),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: danger
                    ? c.danger.withOpacity(0.12)
                    : c.surfaceAlt,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon,
                  color: danger ? c.danger : c.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: danger ? c.danger : c.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: danger ? c.danger : c.textMuted),
          ]),
        ),
      ),
    );
  }
}
