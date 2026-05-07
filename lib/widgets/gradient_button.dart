import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable orange-gradient primary CTA — full-width, always visible.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  final bool loading;
  final double? height;

  const GradientButton({
    super.key,
    required this.label,
    this.trailingIcon,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    this.loading = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: c.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(Radii.lg),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: c.primary.withOpacity(0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: c.primaryDark.withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(Radii.lg),
            splashColor: Colors.white.withOpacity(0.18),
            highlightColor: Colors.white.withOpacity(0.08),
            child: Container(
              width: double.infinity,
              padding: padding,
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading) ...[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (trailingIcon != null && !loading) ...[
                    const SizedBox(width: 12),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(trailingIcon, size: 15, color: c.primary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
