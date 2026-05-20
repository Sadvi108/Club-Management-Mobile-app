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
    final session = UserSession.instance;
    final raw = <String, dynamic>{
      ...?session.myInfo,
    };
    const skip = {'accessToken', 'refreshToken', 'userType', 'clubList', 'branchList', 'password'};
    final entries = raw.entries
        .where((e) => !skip.contains(e.key) && e.value != null && e.value.toString().isNotEmpty)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.92,
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
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('My Profile',
                style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 16),
            if (entries.isEmpty)
              Text('No profile data.', style: TextStyle(color: c.textSecondary))
            else
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        _humanizeKey(e.key),
                        style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value?.toString() ?? '',
                        style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
          ]),
        ),
      ),
    );
  }

  static String _humanizeKey(String key) {
    final spaced = key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[0]}');
    final result = spaced[0].toUpperCase() + spaced.substring(1);
    return result
        .replaceAll('T Center', 'Training Center')
        .replaceAll('S Center', 'Student Center')
        .replaceAll('Hand Phone', 'Phone')
        .replaceAll('I C ', 'IC ')
        .replaceAll('Tme', 'Time')
        .trim();
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
                  final label = (b['text'] ?? '').toString();
                  return ListTile(
                    title: Text(label,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await UserSession.instance
                          .switchBranch(id, clubCode: clubCode);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Switched to $label'
                            : 'Failed: ${UserSession.instance.error ?? "unknown"}'),
                      ));
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
                // Hero profile card with gradient
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: c.gradient,
                    ),
                    borderRadius: BorderRadius.circular(Radii.xl),
                    boxShadow: Shadows.strong(c),
                  ),
                  child: Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'I',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_user,
                                    size: 11, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(session.clubDisplayName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: Gaps.lg),
                _sectionLabel(c, 'Account'),
                _row(c, Icons.person_outline, 'Profile', _openProfile),
                _row(c, Icons.swap_horiz, 'Switch Branch', _openSwitchBranch),
                const SizedBox(height: Gaps.md),
                _sectionLabel(c, 'Preferences'),
                _themeToggleRow(c, theme),
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

  Widget _sectionLabel(AppColors c, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 0, 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: c.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );

  /// Dark/Light mode row with a Switch — matches the student Profile
  /// theme toggle (icon + title + subtitle + Switch).
  Widget _themeToggleRow(AppColors c, ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
        boxShadow: c.isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: c.surfaceAlt, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(
              theme.isDark ? Icons.dark_mode : Icons.light_mode,
              color: c.primary,
              size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(theme.isDark ? 'Dark Mode' : 'Light Mode',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(theme.isDark ? 'Orange & black' : 'Orange & white',
                  style: TextStyle(
                      color: c.textSecondary, fontSize: 11)),
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
              horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: c.border),
            boxShadow: c.isDark ? null : [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: danger
                    ? LinearGradient(
                        colors: [c.danger.withOpacity(0.18), c.danger.withOpacity(0.28)])
                    : LinearGradient(
                        colors: [c.primary.withOpacity(0.14), c.primary.withOpacity(0.24)]),
                borderRadius: BorderRadius.circular(11),
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
