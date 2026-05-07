import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) context.go('/login');
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: c.isDark
                    ? const [Color(0xFF000000), Color(0xFF0A0A0B), Color(0xFF1F1F23)]
                    : const [Color(0xFFFFFFFF), Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.2,
            child: Container(
              width: 420, height: 420,
              decoration: BoxDecoration(
                color: c.primary.withOpacity(c.isDark ? 0.18 : 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 170, height: 170,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RotationTransition(
                      turns: _ctrl,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: c.primary.withOpacity(0.18), width: 2),
                        ),
                      ),
                    ),
                    Container(
                      width: 130, height: 130,
                      decoration: BoxDecoration(
                        color: c.isDark ? const Color(0xFF17171A) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.primary, width: 3),
                        boxShadow: Shadows.strong(c),
                      ),
                      child: ClipOval(
                        child: Image.asset(kLogoAssetPath, fit: BoxFit.cover),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text('D-CLIX',
                  style: TextStyle(color: c.textPrimary, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 6)),
              const SizedBox(height: 10),
              Text('SPORTS TECHNOLOGY PLATFORM',
                  style: TextStyle(color: c.primary, fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w700)),
            ],
          ),
          Positioned(
            bottom: 56,
            child: Column(
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _dot(c.primary, 1), const SizedBox(width: 6),
                  _dot(c.primary, 0.5), const SizedBox(width: 6),
                  _dot(c.primary, 0.25),
                ]),
                const SizedBox(height: 12),
                Text('Preparing your dojo…', style: TextStyle(color: c.textSecondary, fontSize: 11, letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c, double opacity) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: c.withOpacity(opacity), shape: BoxShape.circle),
      );
}
