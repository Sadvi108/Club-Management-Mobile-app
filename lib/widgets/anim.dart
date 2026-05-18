import 'package:flutter/material.dart';

/// App-wide motion kit.
///
/// All entrance motion eases out with an exponential curve (no bounce, no
/// elastic) and respects the platform "reduce motion" accessibility flag —
/// when set, widgets render at their final state with zero duration.
class Motion {
  Motion._();

  /// Standard entrance curve: fast start, long gentle settle.
  static const Curve enter = Curves.easeOutQuart;

  /// Standard entrance duration for a single element.
  static const Duration base = Duration(milliseconds: 480);

  /// Per-index delay used to stagger a list of siblings.
  static const Duration stagger = Duration(milliseconds: 70);
}

/// Fades + slides a child up into place once, on first build.
///
/// Use [delay] (or [index] * [Motion.stagger]) to cascade a list. The
/// widget never re-animates on rebuild, so it's safe inside [ListView].
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Vertical travel in logical pixels. Positive = slides up from below.
  final double offsetY;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.base,
    this.offsetY = 22,
  });

  /// Convenience: stagger by list position.
  factory FadeSlideIn.at(
    int index, {
    Key? key,
    required Widget child,
    double offsetY = 22,
    Duration? base,
  }) =>
      FadeSlideIn(
        key: key,
        delay: Motion.stagger * index,
        offsetY: offsetY,
        duration: base ?? Motion.base,
        child: child,
      );

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _reduced = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduced) {
      _ctrl.value = 1;
    } else if (!_ctrl.isAnimating && _ctrl.value == 0) {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = Motion.enter.transform(_ctrl.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offsetY),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Tweens an integer/double up from 0 (or the previous value) whenever the
/// target changes. Good for hero stats: due amount, invoice count, streaks.
class AnimatedCount extends StatelessWidget {
  final num value;
  final Duration duration;
  final TextStyle? style;

  /// Decimal places. 0 → integer, 2 → currency.
  final int decimals;
  final String prefix;
  final String suffix;

  const AnimatedCount(
    this.value, {
    super.key,
    this.duration = const Duration(milliseconds: 900),
    this.style,
    this.decimals = 0,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: reduced ? Duration.zero : duration,
      curve: Curves.easeOutExpo,
      builder: (_, v, __) => Text(
        '$prefix${v.toStringAsFixed(decimals)}$suffix',
        style: style,
      ),
    );
  }
}

/// Lightweight shimmer placeholder for loading states. A diagonal sheen
/// sweeps across a tinted block. Cheaper and calmer than a spinner.
class Shimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const Shimmer({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final baseC = dark ? const Color(0xFF1F1F23) : const Color(0xFFE9E9EC);
    final hiC = dark ? const Color(0xFF2C2C32) : const Color(0xFFF6F6F8);
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final x = (_ctrl.value * 2) - 1; // -1 → 1
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(x - 0.6, 0),
                  end: Alignment(x + 0.6, 0),
                  colors: [baseC, hiC, baseC],
                  stops: const [0.25, 0.5, 0.75],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Builds [count] stacked shimmer rows — drop-in skeleton for list loads.
class ShimmerList extends StatelessWidget {
  final int count;
  final double rowHeight;
  final EdgeInsets padding;

  const ShimmerList({
    super.key,
    this.count = 6,
    this.rowHeight = 64,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => FadeSlideIn.at(
          i,
          offsetY: 12,
          child: Padding(
            padding: padding,
            child: Shimmer(
              height: rowHeight,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
