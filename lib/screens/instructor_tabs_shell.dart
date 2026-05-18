import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Bottom-nav shell for instructor mode. Mirrors [TabsShell] visually but
/// with instructor-specific tabs: Home, Collections, Scan (FAB), Reports,
/// Settings.
class InstructorTabsShell extends StatelessWidget {
  final Widget child;
  final String location;
  const InstructorTabsShell(
      {super.key, required this.child, required this.location});

  static const _routes = [
    '/instructor/home',
    '/instructor/collections',
    '/instructor/reports',
    '/instructor/settings',
  ];

  int _idxFromLocation() {
    final i = _routes.indexWhere((r) => location.startsWith(r));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final idx = _idxFromLocation();
    return Scaffold(
      extendBody: true,
      body: child,
      floatingActionButton: _InstructorScannerFab(
        onTap: () => context.push('/instructor/qr-scan'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          boxShadow: c.isDark
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.06),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                    spreadRadius: -4,
                  ),
                ],
        ),
        child: SafeArea(top: false, child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          color: c.surface,
          elevation: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _tab(context, 0, idx, Icons.home_outlined, Icons.home, 'Home',
                  '/instructor/home'),
              _tab(context, 1, idx, Icons.edit_outlined, Icons.edit,
                  'Collections', '/instructor/collections'),
              const SizedBox(width: 60),
              _tab(context, 2, idx, Icons.notifications_outlined,
                  Icons.notifications, 'Reports', '/instructor/reports'),
              _tab(context, 3, idx, Icons.person_outline, Icons.person,
                  'Settings', '/instructor/settings'),
            ],
          ),
        )),
      ),
    );
  }

  Widget _tab(BuildContext ctx, int index, int current, IconData outline,
      IconData filled, String label, String route) {
    final c = ctx.appColors;
    final active = index == current;
    return Expanded(
      child: InkWell(
        onTap: () => ctx.go(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 3,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: active ? c.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Icon(active ? filled : outline,
                  size: 21, color: active ? c.primary : c.textMuted),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                      color: active ? c.primary : c.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded-square QR scanner button for the instructor portal — matches
/// the D-Clix 2026 design: soft orange gradient body, white viewfinder
/// icon, warm orange glow.
class _InstructorScannerFab extends StatelessWidget {
  final VoidCallback onTap;
  const _InstructorScannerFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      margin: const EdgeInsets.only(top: 30),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: c.gradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(color: c.background, width: 4),
              boxShadow: [
                BoxShadow(
                  color: c.primary.withOpacity(0.45),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: c.primaryDark.withOpacity(0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.qr_code_scanner,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
