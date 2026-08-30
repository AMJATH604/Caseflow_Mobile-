import 'package:flutter/material.dart';
import 'cf_colors.dart';
import 'cf_spacing.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow Design System — Decorations & Elevation
///
/// Reusable BoxDecoration presets for cards, containers, and surfaces.
/// Ensures visual consistency across the entire app.
/// ══════════════════════════════════════════════════════════════

class CfDecorations {
  CfDecorations._();

  // ─── Elevation Shadows ───────────────────────────────────
  static List<BoxShadow> shadowNone = [];

  static List<BoxShadow> shadowSm(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> shadowMd(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.02),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> shadowLg(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> shadowXl(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
      blurRadius: 40,
      offset: const Offset(0, 12),
    ),
  ];

  /// Colored glow shadow (for brand-colored buttons, FABs)
  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.30),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // ─── Card Decorations ────────────────────────────────────

  /// Standard card — clean white/dark surface with subtle border
  static BoxDecoration card(BuildContext context) {
    final colors = CfColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: colors.surface,
      borderRadius: CfSpacing.borderRadiusLg,
      border: Border.all(color: colors.border, width: 1),
      boxShadow: shadowSm(isDark),
    );
  }

  /// Elevated card — for modal sheets, popovers, important cards
  static BoxDecoration cardElevated(BuildContext context) {
    final colors = CfColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: colors.surfaceElevated,
      borderRadius: CfSpacing.borderRadiusXl,
      border: Border.all(color: colors.border, width: 1),
      boxShadow: shadowLg(isDark),
    );
  }

  /// Subtle card — for grouped content within a page
  static BoxDecoration cardSubtle(BuildContext context) {
    final colors = CfColors.of(context);
    return BoxDecoration(
      color: colors.surfaceSubtle,
      borderRadius: CfSpacing.borderRadiusMd,
      border: Border.all(color: colors.borderSubtle, width: 1),
    );
  }

  /// Glass card — frosted glass effect (e.g., overlaying gradients)
  static BoxDecoration cardGlass(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.80),
      borderRadius: CfSpacing.borderRadiusXl,
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.60),
        width: 1,
      ),
      boxShadow: shadowMd(isDark),
    );
  }

  /// Brand gradient card — for hero sections, KPI highlights
  static BoxDecoration cardBrand() {
    return BoxDecoration(
      gradient: CfColors.brandGradient,
      borderRadius: CfSpacing.borderRadiusXl,
      boxShadow: glowShadow(CfColors.brand),
    );
  }

  // ─── Input Decorations ───────────────────────────────────

  /// Standard input field decoration
  static BoxDecoration inputField(BuildContext context) {
    final colors = CfColors.of(context);
    return BoxDecoration(
      color: colors.surface,
      borderRadius: CfSpacing.borderRadiusMd,
      border: Border.all(color: colors.border, width: 1),
    );
  }

  /// Focused input field decoration
  static BoxDecoration inputFieldFocused(BuildContext context) {
    final colors = CfColors.of(context);
    return BoxDecoration(
      color: colors.surface,
      borderRadius: CfSpacing.borderRadiusMd,
      border: Border.all(color: colors.borderFocused, width: 1.5),
    );
  }

  // ─── Pill / Chip Decorations ─────────────────────────────

  /// Active filter pill
  static BoxDecoration pillActive() {
    return BoxDecoration(
      gradient: CfColors.brandGradient,
      borderRadius: CfSpacing.borderRadiusFull,
    );
  }

  /// Inactive filter pill
  static BoxDecoration pillInactive(BuildContext context) {
    final colors = CfColors.of(context);
    return BoxDecoration(
      color: colors.surfaceSubtle,
      borderRadius: CfSpacing.borderRadiusFull,
      border: Border.all(color: colors.border, width: 1),
    );
  }

  // ─── Status Decorations ──────────────────────────────────

  /// Status indicator dot with color
  static BoxDecoration statusDot(Color color) {
    return BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.40),
          blurRadius: 6,
          offset: Offset.zero,
        ),
      ],
    );
  }

  /// Colored left border for case/hearing cards
  static BoxDecoration cardWithStatusBorder(
    BuildContext context,
    Color statusColor,
  ) {
    final colors = CfColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: colors.surface,
      borderRadius: CfSpacing.borderRadiusLg,
      border: Border.all(color: colors.border, width: 1),
      boxShadow: shadowSm(isDark),
    );
    // Note: Use a Row with a colored Container on the left for the status border
    // BoxDecoration doesn't support partial borders natively
  }

  // ─── Bottom Sheet ────────────────────────────────────────
  static BoxDecoration bottomSheet(BuildContext context) {
    final colors = CfColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(24),
      ),
      boxShadow: shadowXl(isDark),
    );
  }

  // ─── Navigation Bar ──────────────────────────────────────
  static BoxDecoration bottomNav(BuildContext context) {
    final colors = CfColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: colors.surface,
      border: Border(
        top: BorderSide(color: colors.border, width: 0.5),
      ),
      boxShadow: isDark ? shadowNone : shadowMd(false),
    );
  }

  // ─── Animation Curves & Durations ────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationPage = Duration(milliseconds: 350);

  static const Curve curveDefault = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveDecelerate = Curves.decelerate;
}
