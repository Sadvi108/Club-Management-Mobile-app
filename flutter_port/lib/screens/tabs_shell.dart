import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class TabsShell extends StatelessWidget {
  final Widget child;
  final String location;
  const TabsShell({super.key, required this.child, required this.location});

  static const _routes = ['/home', '/training', '/schedule', '/payments', '/profile'];

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
      floatingActionButton: Container(
        margin: const EdgeInsets.only(top: 30),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.background, width: 4),
          boxShadow: Shadows.strong(c),
        ),
        child: FloatingActionButton(
          heroTag: 'qrFab',
          onPressed: () => context.push('/qr-scan'),
          backgroundColor: c.primary,
          child: Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: c.gradient),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.qr_code_2, size: 28, color: Colors.white),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: c.surface,
        elevation: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _tab(context, 0, idx, Icons.home_outlined, Icons.home, 'Home', '/home'),
            _tab(context, 1, idx, Icons.fitness_center_outlined, Icons.fitness_center, 'Training', '/training'),
            const SizedBox(width: 60), // notch space
            _tab(context, 2, idx, Icons.calendar_month_outlined, Icons.calendar_month, 'Schedule', '/schedule'),
            _tab(context, 3, idx, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Payments', '/payments'),
            _tab(context, 4, idx, Icons.person_outline, Icons.person, 'Profile', '/profile'),
          ],
        ),
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
