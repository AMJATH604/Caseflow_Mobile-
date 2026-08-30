import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cf_colors.dart';
import 'cf_spacing.dart';
import 'cf_typography.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow App Theme
///
/// Central theme configuration using the CfColors/CfSpacing/CfTypography
/// design system. Both light and dark ThemeData are built from tokens.
///
/// MIGRATION NOTE:
/// - Old statics (accent, darkCard, border, etc.) are kept for backward
///   compatibility. New screens should use CfColors.of(context) instead.
/// - Old statics will be removed once all screens migrate to the new system.
/// ══════════════════════════════════════════════════════════════

class AppTheme {
  // ─── Legacy Statics (backward compat — DO NOT USE in new code) ──
  // These map to the new CfColors values so existing screens still work.
  static const Color primary = Color(0xFF0F172A);
  static const Color secondary = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color primaryLight = Color(0xFFF8FAFC);
  static const Color secondaryLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color surfaceLightMode = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF4F46E5);       // Now using CfColors.brand
  static const Color accentViolet = Color(0xFF7C3AED);
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF0EA5E9);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color darkCard = Color(0xFFFFFFFF);
  static const Color darkBorder = Color(0xFFE2E8F0);
  static const Color background = Color(0xFFF8FAFC);

  static const LinearGradient glassGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF06B6D4)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Legacy Helpers (kept for compat) ──────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static BoxDecoration cardDecoration({Color? color, bool isDark = false}) =>
      BoxDecoration(
        color: color ?? (isDark ? const Color(0xFF131927) : secondaryLight),
        borderRadius: BorderRadius.circular(CfSpacing.radiusLg),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration glassDecoration({
    double blur = 0,
    double opacity = 0.1,
    bool isDark = false,
  }) =>
      BoxDecoration(
        color: isDark
            ? const Color(0xFF131927).withValues(alpha: 0.85)
            : secondaryLight.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(CfSpacing.radiusXl),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: blur > 0 ? blur : 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // ─── Dark Theme ─────────────────────────────────────────
  static ThemeData get darkTheme {
    final darkColors = CfColors.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CfColors.brand,
        brightness: Brightness.dark,
        primary: CfColors.brand,
        secondary: CfColors.brandLight,
        surface: darkColors.background,
        surfaceContainer: darkColors.surface,
        error: CfColors.error,
      ),
      scaffoldBackgroundColor: darkColors.background,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        displayLarge: CfTypography.displayLg.copyWith(color: darkColors.textPrimary),
        displayMedium: CfTypography.displayMd.copyWith(color: darkColors.textPrimary),
        titleLarge: CfTypography.headingLg.copyWith(color: darkColors.textPrimary),
        bodyLarge: CfTypography.bodyLg.copyWith(color: darkColors.textPrimary),
        bodyMedium: CfTypography.bodyMd.copyWith(color: darkColors.textSecondary),
        labelLarge: CfTypography.labelMd.copyWith(color: darkColors.textTertiary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: CfTypography.headingMd.copyWith(color: darkColors.textPrimary),
        iconTheme: IconThemeData(color: darkColors.textPrimary, size: 20),
      ),
      cardTheme: CardThemeData(
        color: darkColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusLg),
          side: BorderSide(color: darkColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CfColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CfSpacing.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: CfTypography.labelLg,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusMd),
          borderSide: BorderSide(color: darkColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusMd),
          borderSide: BorderSide(color: darkColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusMd),
          borderSide: BorderSide(color: darkColors.borderFocused, width: 1.5),
        ),
        hintStyle: CfTypography.bodyMd.copyWith(color: darkColors.textTertiary),
      ),
      dividerTheme: DividerThemeData(color: darkColors.divider, thickness: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: darkColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusXl),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkColors.surfaceSubtle,
        selectedColor: CfColors.brand.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusFull),
        ),
      ),
    );
  }

  // ─── Light Theme ────────────────────────────────────────
  static ThemeData get lightTheme {
    final lightColors = CfColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CfColors.brand,
        brightness: Brightness.light,
        primary: CfColors.brand,
        secondary: CfColors.brandLight,
        surface: lightColors.background,
        surfaceContainer: lightColors.surface,
        error: CfColors.error,
      ),
      scaffoldBackgroundColor: lightColors.background,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).copyWith(
        displayLarge: CfTypography.displayLg.copyWith(color: lightColors.textPrimary),
        displayMedium: CfTypography.displayMd.copyWith(color: lightColors.textPrimary),
        titleLarge: CfTypography.headingLg.copyWith(color: lightColors.textPrimary),
        bodyLarge: CfTypography.bodyLg.copyWith(color: lightColors.textPrimary),
        bodyMedium: CfTypography.bodyMd.copyWith(color: lightColors.textSecondary),
        labelLarge: CfTypography.labelMd.copyWith(color: lightColors.textTertiary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: CfTypography.headingMd.copyWith(color: lightColors.textPrimary),
        iconTheme: IconThemeData(color: lightColors.textPrimary, size: 20),
      ),
      cardTheme: CardThemeData(
        color: lightColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusLg),
          side: BorderSide(color: lightColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CfColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CfSpacing.radiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: CfTypography.labelLg,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusMd),
          borderSide: BorderSide(color: lightColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusMd),
          borderSide: BorderSide(color: lightColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusMd),
          borderSide: BorderSide(color: lightColors.borderFocused, width: 1.5),
        ),
        hintStyle: CfTypography.bodyMd.copyWith(color: lightColors.textTertiary),
      ),
      dividerTheme: DividerThemeData(color: lightColors.divider, thickness: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: lightColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF334155),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusXl),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightColors.surfaceSubtle,
        selectedColor: CfColors.brandSubtle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusFull),
        ),
      ),
    );
  }
}
