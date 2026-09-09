import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'app_icon_button.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;
  final VoidCallback? onBack;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // On web/preview the OS reports no notch inset (padding.top == 0),
    // so SafeArea adds nothing and the header collides with a hardware
    // notch. Add a fixed clearance only when no real inset is reported.
    final extraTop =
        MediaQuery.of(context).padding.top > 0 ? 0.0 : 44.0;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(Gaps.lg, extraTop + 10, Gaps.lg, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showBack)
              AppIconButton(
                icon: Icons.chevron_left,
                onPressed: onBack ?? () => context.pop(),
                backgroundColor: c.surfaceAlt,
                foregroundColor: c.textPrimary,
              )
            else
              const SizedBox(width: 42, height: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing! else const SizedBox(width: 42, height: 42),
          ],
        ),
      ),
    );
  }
}

