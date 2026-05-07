import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable orange-gradient primary CTA (mirrors the Sign In button).
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  final bool loading;

  const GradientButton({
    super.key,
    required this.label,
    this.trailingIcon,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final enabled = onPressed != null && !loading;
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Ink(
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: enabled ? Shadows.strong(c) : null,
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: enabled ? 1 : 0.55,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.2)),
                if (trailingIcon != null && !loading) ...[
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
        ),
      ),
    );
  }
}
