import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// White-card hero — D-Clix 2026 redesign treatment.
///
/// Renders a white surface with a warm `#FED7AA` border, a soft warm shadow,
/// and a thin three-stop orange accent line at the bottom edge. Use it
/// anywhere you'd otherwise reach for a full-bleed orange gradient hero.
///
/// Example:
/// ```dart
/// WhiteCardHero(
///   padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 8, 20, 24),
///   child: Column(children: [...]),
/// )
/// ```
class WhiteCardHero extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Whether to round only the bottom corners (default — fits a top-of-screen
  /// hero) or round all four corners (use when nesting inside other content).
  final bool bottomOnly;

  const WhiteCardHero({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gaps.xl),
    this.bottomOnly = true,
  });

  static const _peach200 = Color(0xFFFED7AA);

  @override
  Widget build(BuildContext context) {
    final radius = bottomOnly
        ? const BorderRadius.vertical(bottom: Radius.circular(28))
        : BorderRadius.circular(28);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: bottomOnly
            ? const Border(
                bottom: BorderSide(color: _peach200, width: 1.5),
                left: BorderSide(color: _peach200, width: 1.5),
                right: BorderSide(color: _peach200, width: 1.5),
              )
            : Border.all(color: _peach200, width: 1.5),
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x2EF97316),
            blurRadius: 36,
            offset: Offset(0, 18),
            spreadRadius: -12,
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(padding: padding, child: child),
          // 3-stop orange accent line at the bottom edge
          Positioned(
            left: 18,
            right: 18,
            bottom: 6,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9999),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
