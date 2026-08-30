import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow Design System — Spacing & Layout
///
/// Consistent spacing scale based on 4px grid.
/// Use these values everywhere instead of arbitrary numbers.
/// ══════════════════════════════════════════════════════════════

class CfSpacing {
  CfSpacing._();

  // ─── Base Scale (4px grid) ───────────────────────────────
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double huge = 48.0;
  static const double massive = 64.0;

  // ─── Page Padding ────────────────────────────────────────
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: 20.0,
    vertical: 16.0,
  );

  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(
    horizontal: 20.0,
  );

  static const EdgeInsets pageVertical = EdgeInsets.symmetric(
    vertical: 16.0,
  );

  // ─── Card Padding ────────────────────────────────────────
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(12.0);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(20.0);

  // ─── List Item Padding ───────────────────────────────────
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: 20.0,
    vertical: 12.0,
  );

  // ─── Section Spacing ─────────────────────────────────────
  static const double sectionGap = 24.0;
  static const double itemGap = 12.0;
  static const double tightGap = 8.0;

  // ─── Border Radius ───────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 24.0;
  static const double radiusFull = 999.0;

  static final BorderRadius borderRadiusSm = BorderRadius.circular(radiusSm);
  static final BorderRadius borderRadiusMd = BorderRadius.circular(radiusMd);
  static final BorderRadius borderRadiusLg = BorderRadius.circular(radiusLg);
  static final BorderRadius borderRadiusXl = BorderRadius.circular(radiusXl);
  static final BorderRadius borderRadiusXxl = BorderRadius.circular(radiusXxl);
  static final BorderRadius borderRadiusFull = BorderRadius.circular(radiusFull);

  // ─── Responsive Helpers ──────────────────────────────────
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768 &&
      MediaQuery.of(context).size.width < 1024;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  /// Get responsive page padding that adapts to screen size
  static EdgeInsets responsivePadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 48.0, vertical: 24.0);
    }
    if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0);
    }
    return pagePadding;
  }

  /// Get responsive content max width
  static double maxContentWidth(BuildContext context) {
    if (isDesktop(context)) return 1200;
    if (isTablet(context)) return 800;
    return double.infinity;
  }
}
