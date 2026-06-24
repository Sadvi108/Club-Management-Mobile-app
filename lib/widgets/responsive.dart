import 'package:flutter/material.dart';

/// Phone-first responsive helpers.
///
/// The app targets phones of every size (small ~320 → large ~430) plus the
/// OS accessibility font scale. These extensions centralise the breakpoints
/// and the notch-clearance math that were previously duplicated across
/// screens, so every screen adapts the same way.
extension ResponsiveContext on BuildContext {
  /// Logical width of the current view.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Logical height of the current view.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// True on small / compact phones (e.g. iPhone SE, older Androids).
  bool get isCompact => screenWidth < 360;

  /// Top clearance for custom headers that don't sit under a [SafeArea].
  ///
  /// On real devices this is the status-bar / notch inset. On web + the
  /// preview the OS reports no inset (0), so we fall back to a fixed value
  /// that keeps header content clear of a hardware notch.
  double get topInset {
    final inset = MediaQuery.paddingOf(this).top;
    return inset > 0 ? inset : 44.0;
  }

  /// Horizontal page padding that tightens on compact phones to reclaim
  /// width, without changing the look on normal / large phones.
  /// Matches the [Gaps] scale: 16 on compact, 20 otherwise.
  double get pagePadding => isCompact ? 16.0 : 20.0;
}
