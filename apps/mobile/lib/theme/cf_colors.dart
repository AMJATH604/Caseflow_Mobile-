import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow Design System — Color Tokens
///
/// Single source of truth for all colors in the app.
/// Every widget should reference these tokens — never hardcode colors.
///
/// Palette: Deep Indigo primary (trust/authority) + Slate neutrals
/// Accents: Emerald (success), Amber (warning), Rose (error), Sky (info)
/// ══════════════════════════════════════════════════════════════

class CfColors {
  CfColors._();

  // ─── Brand ───────────────────────────────────────────────
  static const Color brand = Color(0xFF4F46E5);       // Indigo-600 (primary brand)
  static const Color brandLight = Color(0xFF818CF8);   // Indigo-400
  static const Color brandDark = Color(0xFF3730A3);    // Indigo-800
  static const Color brandSubtle = Color(0xFFEEF2FF);  // Indigo-50

  // ─── Gradients ───────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF7C3AED)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient subtleGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Semantic ────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);      // Emerald-500
  static const Color successLight = Color(0xFFD1FAE5);  // Emerald-100
  static const Color successDark = Color(0xFF065F46);   // Emerald-800

  static const Color warning = Color(0xFFF59E0B);      // Amber-500
  static const Color warningLight = Color(0xFFFEF3C7);  // Amber-100
  static const Color warningDark = Color(0xFF92400E);   // Amber-800

  static const Color error = Color(0xFFEF4444);        // Rose-500
  static const Color errorLight = Color(0xFFFEE2E2);    // Rose-100
  static const Color errorDark = Color(0xFF991B1B);     // Rose-800

  static const Color info = Color(0xFF0EA5E9);         // Sky-500
  static const Color infoLight = Color(0xFFE0F2FE);     // Sky-100
  static const Color infoDark = Color(0xFF075985);      // Sky-800

  // ─── Case Status Colors ──────────────────────────────────
  static const Color statusActive = Color(0xFF10B981);
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusClosed = Color(0xFF6B7280);
  static const Color statusUrgent = Color(0xFFEF4444);

  // ─── Light Mode ──────────────────────────────────────────
  static const CfColorScheme light = CfColorScheme(
    // Backgrounds
    background: Color(0xFFF8FAFC),        // Slate-50
    surface: Color(0xFFFFFFFF),           // White
    surfaceElevated: Color(0xFFFFFFFF),   // White (with shadow)
    surfaceSubtle: Color(0xFFF1F5F9),     // Slate-100
    overlay: Color(0x80000000),           // Black 50%

    // Text
    textPrimary: Color(0xFF0F172A),       // Slate-900
    textSecondary: Color(0xFF475569),     // Slate-600
    textTertiary: Color(0xFF94A3B8),      // Slate-400
    textDisabled: Color(0xFFCBD5E1),      // Slate-300
    textOnBrand: Color(0xFFFFFFFF),       // White

    // Borders
    border: Color(0xFFE2E8F0),            // Slate-200
    borderSubtle: Color(0xFFF1F5F9),      // Slate-100
    borderFocused: Color(0xFF4F46E5),     // Indigo-600

    // Interactive
    interactive: Color(0xFF4F46E5),       // Indigo-600
    interactiveHover: Color(0xFF4338CA),  // Indigo-700
    interactiveSubtle: Color(0xFFEEF2FF), // Indigo-50

    // Misc
    divider: Color(0xFFE2E8F0),           // Slate-200
    shimmerBase: Color(0xFFE2E8F0),       // Slate-200
    shimmerHighlight: Color(0xFFF8FAFC),  // Slate-50
    scrim: Color(0x33000000),             // Black 20%
  );

  // ─── Dark Mode ───────────────────────────────────────────
  static const CfColorScheme dark = CfColorScheme(
    // Backgrounds
    background: Color(0xFF0B0F19),        // Deep navy
    surface: Color(0xFF131927),           // Elevated navy
    surfaceElevated: Color(0xFF1A2235),   // Card navy
    surfaceSubtle: Color(0xFF0F1420),     // Recessed navy
    overlay: Color(0x80000000),           // Black 50%

    // Text
    textPrimary: Color(0xFFF8FAFC),       // Slate-50
    textSecondary: Color(0xFF94A3B8),     // Slate-400
    textTertiary: Color(0xFF64748B),      // Slate-500
    textDisabled: Color(0xFF475569),      // Slate-600
    textOnBrand: Color(0xFFFFFFFF),       // White

    // Borders
    border: Color(0xFF1E293B),            // Slate-800
    borderSubtle: Color(0xFF1A2235),      // Slightly lighter
    borderFocused: Color(0xFF818CF8),     // Indigo-400

    // Interactive
    interactive: Color(0xFF818CF8),       // Indigo-400
    interactiveHover: Color(0xFF6366F1),  // Indigo-500
    interactiveSubtle: Color(0xFF1E1B4B), // Indigo-950

    // Misc
    divider: Color(0xFF1E293B),           // Slate-800
    shimmerBase: Color(0xFF1E293B),       // Slate-800
    shimmerHighlight: Color(0xFF334155),  // Slate-700
    scrim: Color(0x66000000),             // Black 40%
  );

  /// Get the correct color scheme for current brightness
  static CfColorScheme of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

/// Semantic color scheme that adapts to light/dark mode
class CfColorScheme {
  // Backgrounds
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSubtle;
  final Color overlay;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color textOnBrand;

  // Borders
  final Color border;
  final Color borderSubtle;
  final Color borderFocused;

  // Interactive
  final Color interactive;
  final Color interactiveHover;
  final Color interactiveSubtle;

  // Misc
  final Color divider;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color scrim;

  const CfColorScheme({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSubtle,
    required this.overlay,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textOnBrand,
    required this.border,
    required this.borderSubtle,
    required this.borderFocused,
    required this.interactive,
    required this.interactiveHover,
    required this.interactiveSubtle,
    required this.divider,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.scrim,
  });
}
