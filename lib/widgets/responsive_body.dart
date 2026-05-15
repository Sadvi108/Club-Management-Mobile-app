import 'package:flutter/material.dart';

/// Centers content at a comfortable phone-width on tablets and desktops.
///
/// Apply at the root of any screen body. Mobile widths (<600) pass through
/// unchanged; from 600px upwards we cap content at [maxWidth] (default 520)
/// and centre it horizontally. Keeps mobile-first layouts looking right on
/// every breakpoint without rewriting each screen for wide canvases.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 520,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      // On narrow viewports, pass through unmodified.
      if (c.maxWidth <= maxWidth + 24) return child;
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
    });
  }
}
