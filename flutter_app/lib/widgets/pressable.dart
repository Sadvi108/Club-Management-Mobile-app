import 'package:flutter/material.dart';

/// A tappable wrapper that adds a subtle scale-down + ripple on press —
/// matches the D-Clix 2026 interaction spec (Quick Reference §7
/// `scale-feedback`, `state-transition`). Respects `prefers-reduced-motion`
/// via [MediaQuery.disableAnimationsOf] so accessibility settings disable
/// the scale animation cleanly.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;

  /// Lowest scale during press. 1.0 disables the animation entirely.
  final double pressedScale;

  /// Duration of the down/up tween. Spec: 150–300ms; exit slightly faster.
  final Duration duration;

  /// Use a Material InkWell ripple in addition to the scale. Default: true.
  final bool ripple;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.pressedScale = 0.97,
    this.duration = const Duration(milliseconds: 140),
    this.ripple = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final scale = (_down && !reduced) ? widget.pressedScale : 1.0;
    final child = AnimatedScale(
      scale: scale,
      duration: reduced ? Duration.zero : widget.duration,
      curve: Curves.easeOut,
      child: widget.child,
    );

    if (!widget.ripple) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: child,
      );
    }
    return Material(
      type: MaterialType.transparency,
      borderRadius: widget.borderRadius,
      child: InkWell(
        borderRadius: widget.borderRadius,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onHighlightChanged: _set,
        child: child,
      ),
    );
  }

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }
}
