import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable orange-gradient primary CTA (mirrors the Sign In button).
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final EdgeInsets padding;

  const GradientButton({
    super.key,
    required this.label,
    this.trailingIcon,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Ink(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: Shadows.strong(c),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5)),
            if (trailingIcon != null) ...[
              const SizedBox(width: 10),
              Container(
                width: 26, height: 26,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(trailingIcon, size: 14, color: c.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
