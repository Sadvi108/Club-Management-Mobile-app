import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class TabsShell extends StatelessWidget {
  final Widget child;
  final String location;
  const TabsShell({super.key, required this.child, required this.location});

  /// Bottom-tab order per D-Clix 2026 spec:
  ///   Home · Schedule · [FAB] · Progress · Profile
  static const _routes = ['/home', '/schedule', '/progress', '/profile'];

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
      floatingActionButton: _ScannerFab(
        onTap: () => context.push('/qr-scan'),
        heroTag: 'qrFab',
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
            _tab(context, 0, idx, Icons.home_outlined, Icons.home, 'Home', '/home'),
            _tab(context, 1, idx, Icons.calendar_month_outlined, Icons.calendar_month, 'Schedule', '/schedule'),
            const SizedBox(width: 60), // notch space for FAB
            _tab(context, 2, idx, Icons.trending_up_outlined, Icons.trending_up, 'Progress', '/progress'),
            _tab(context, 3, idx, Icons.person_outline, Icons.person, 'Profile', '/profile'),
          ],
        ),
        )),
      ),
    );
  }

  Widget _tab(BuildContext ctx, int index, int current, IconData outline, IconData filled, String label, String route) {
    final c = ctx.appColors;
    final active = index == current;
    return Expanded(
      child: InkWell(
        onTap: () => ctx.go(route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 3,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: active ? c.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Icon(active ? filled : outline, size: 22, color: active ? c.primary : c.textMuted),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? c.primary : c.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded-square QR scanner button matching the D-Clix 2026 design.
/// Soft orange gradient body, white viewfinder icon (corner brackets +
/// scan line), and a warm orange glow around the rounded square.
class _ScannerFab extends StatelessWidget {
  final VoidCallback onTap;
  final String heroTag;
  const _ScannerFab({required this.onTap, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      margin: const EdgeInsets.only(top: 30),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
