import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Central responsive utility for CaseFlow.
///
/// Design baseline: 390 × 844 (iPhone 14 / mid-range Android standard).
/// All values scale automatically to every screen size at runtime.
///
/// Usage:
///   - Font size  → R.sp(14)
///   - Width      → R.w(120)
///   - Height     → R.h(48)
///   - Radius     → R.r(12)
///   - Padding    → R.padAll(16) / R.padH(24) / R.padV(12)
///   - EdgeInsets → R.insets(top: 8, bottom: 16)
///   - Screen checks → R.isSmall(context)
class R {
  R._();

  // ── Scaled font size ────────────────────────────────────────────────────────
  /// Returns a font size scaled to the current screen.
  static double sp(double size) => size.sp;

  // ── Scaled dimensions ───────────────────────────────────────────────────────
  /// Returns a width value scaled to the current screen width.
  static double w(double size) => size.w;

  /// Returns a height value scaled to the current screen height.
  static double h(double size) => size.h;

  /// Returns a radius value scaled proportionally (uses width scale).
  static double r(double size) => size.r;

  // ── Padding helpers ─────────────────────────────────────────────────────────
  /// Symmetric EdgeInsets scaled on both axes.
  static EdgeInsets padAll(double value) =>
      EdgeInsets.all(value.w);

  /// Horizontal (left + right) EdgeInsets scaled to screen width.
  static EdgeInsets padH(double horizontal) =>
      EdgeInsets.symmetric(horizontal: horizontal.w);

  /// Vertical (top + bottom) EdgeInsets scaled to screen height.
  static EdgeInsets padV(double vertical) =>
      EdgeInsets.symmetric(vertical: vertical.h);

  /// Symmetric EdgeInsets with separate H and V values.
  static EdgeInsets padHV(double horizontal, double vertical) =>
      EdgeInsets.symmetric(horizontal: horizontal.w, vertical: vertical.h);

  /// Custom EdgeInsets with all four sides.
  static EdgeInsets insets({
    double top = 0,
    double bottom = 0,
    double left = 0,
    double right = 0,
  }) => EdgeInsets.fromLTRB(left.w, top.h, right.w, bottom.h);

  // ── SizedBox helpers ────────────────────────────────────────────────────────
  /// A horizontal gap (width-based).
  static Widget gapW(double width) => SizedBox(width: width.w);

  /// A vertical gap (height-based).
  static Widget gapH(double height) => SizedBox(height: height.h);

  // ── Screen size checks ──────────────────────────────────────────────────────
  /// Returns true on very small phones (width ≤ 360 dp) like Redmi/Nokia budget models.
  static bool isSmall(BuildContext context) =>
      MediaQuery.of(context).size.width <= 360;

  /// Returns true on large phones (width ≥ 420 dp) like Pro Max models.
  static bool isLarge(BuildContext context) =>
      MediaQuery.of(context).size.width >= 420;

  /// Returns the actual screen width in logical pixels.
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Returns the actual screen height in logical pixels.
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // ── Adaptive values ─────────────────────────────────────────────────────────
  /// Returns [small] on small phones, [normal] on standard phones,
  /// and [large] on large phones. Great for font sizes and paddings.
  static double adaptive(
    BuildContext context, {
    required double small,
    required double normal,
    required double large,
  }) {
    final w = screenWidth(context);
    if (w <= 360) return small;
    if (w >= 420) return large;
    return normal;
  }
}
