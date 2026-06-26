import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = context.watch<ThemeProvider>();
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
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), shape: BoxShape.circle),
                    child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                  ),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.6), width: 2)),
                  child: CircleAvatar(radius: 45, backgroundImage: CachedNetworkImageProvider(kStudent.photo)),
                ),
                const SizedBox(height: 12),
                Text(kStudent.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text(kStudent.id, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(14)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.verified_user, size: 14, color: Color(0xFFFFF7ED)),
                    const SizedBox(width: 4),
                    Text('${kStudent.membership} · Since ${kStudent.joinDate}', style: const TextStyle(color: Color(0xFFFFF7ED), fontSize: 11, fontWeight: FontWeight.w700)),
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
                        Text(kStudent.name, style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text('${kStudent.level} · ${kStudent.belt}', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                        const SizedBox(height: 10),
                        Row(children: List.generate(20, (i) =>
                          Padding(padding: const EdgeInsets.only(right: 2), child: Container(width: 2, height: (20 + (i * 7) % 12).toDouble(), color: c.textPrimary.withOpacity(i % 3 == 0 ? 1 : 0.6))))),
                        const SizedBox(height: 4),
                        Text(kStudent.id, style: TextStyle(color: c.textPrimary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
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
            _logoutBtn(context, c),
            const SizedBox(height: 8),
            Text('D-Clix · v1.0.0', style: TextStyle(color: c.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _logoutBtn(BuildContext ctx, AppColors c) => InkWell(
        onTap: () => ctx.go('/login'),
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
