import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Dark palette (kept for dark mode toggle) ──────
  static const Color _darkPrimary = Color(0xFF0A0A0F);
  static const Color _darkSecondary = Color(0xFF161620);
  static const Color _darkBorder = Color(0xFF232330);


  // ─── These statics now point to LIGHT values ───────
  // so every screen that uses them gets a white look.
  // ─── These statics are now for LIGHT MODE visibility ───────
  static const Color primary = Color(
    0xFF0F172A,
  ); // BACK TO DARK for text visibility
  static const Color secondary = Color(0xFFFFFFFF); // Pure white background
  static const Color border = Color(0xFFE2E8F0); // Light border
  static const Color surfaceLight = Color(0xFFFFFFFF); // White surface

  // ─── Exact Screenshot Theme (Aether Teal) ──────────
  static const Color primaryLight = Color(0xFFF8FAFC); // Slightly cooler gray
  static const Color secondaryLight = Color(0xFFFFFFFF); // Pure White Cards
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color surfaceLightMode = Color(0xFFFFFFFF);

  // ─── Header Card Gradient (Teal to Mint) ───────────
  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0xFF6366F1), // Deep Indigo
      Color(0xFF22D3EE), // Cyan
      Color(0xFF34D399), // Emerald/Mint
    ],
    stops: [0.0, 0.4, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Common Accents ────────────────────────────────
  static const Color accent = Color(0xFF2563EB); // Deep Royal Blue
  static const Color accentViolet = Color(0xFF6366F1);
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF0EA5E9); // Sky Blue
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ─── Backward Compat Statics (now light) ──────────
  static const Color darkCard = Color(0xFFFFFFFF); // White cards
  static const Color darkBorder = Color(0xFFE2E8F0); // Light border
  static const Color background = Color(0xFFF8FAFC); // Light gray bg

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accent, accentViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Premium Gradient Presets ──────────────────────
  static const LinearGradient headerGradient = LinearGradient(
    colors: [
      Color(0xFF0F172A),
      Color(0xFF1E3A5F),
      Color(0xFF312E81),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient navGlassGradient = LinearGradient(
    colors: [
      Color(0xFFFFFFFE),
      Color(0xFFF8FAFC),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Premium Multi-Layer Shadow System ─────────────
  /// Subtle shadow for flat elements (badges, chips)
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  /// Standard card shadow — ambient + key light
  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  /// Elevated shadow for floating elements (FABs, modals)
  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.03),
      blurRadius: 48,
      offset: const Offset(0, 24),
    ),
  ];

  /// Colored glow shadow for accented elements
  static List<BoxShadow> coloredShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.15),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.08),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  // ─── Legacy shadow (backward compat) ───────────────
  static List<BoxShadow> get cardShadow => shadowMd;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // ─── Premium Card Decoration ───────────────────────
  static BoxDecoration cardDecoration({Color? color, bool isDark = false}) =>
      BoxDecoration(
        color: color ?? (isDark ? _darkSecondary : secondaryLight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? _darkBorder : borderLight.withValues(alpha: 0.8),
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : shadowMd,
      );

  // ─── Glassmorphism Decoration ─────────────────────
  static BoxDecoration glassDecoration({
    double blur = 0,
    double opacity = 0.1,
    bool isDark = false,
    double radius = 20,
  }) =>
      BoxDecoration(
        color: isDark
            ? _darkSecondary.withValues(alpha: 0.85)
            : secondaryLight.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.6),
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: blur > 0 ? blur : 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : shadowMd,
      );

  /// Frosted glass widget wrapper — use as a parent for glassmorphism
  static Widget frostedGlass({
    required Widget child,
    double blur = 12,
    double borderRadius = 20,
    Color? backgroundColor,
    bool isDark = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ??
                (isDark
                    ? _darkSecondary.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.75)),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.5),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Premium accent-tinted card (subtle color wash)
  static BoxDecoration accentCardDecoration({
    required Color accentColor,
    bool isDark = false,
    double radius = 20,
  }) =>
      BoxDecoration(
        color: isDark
            ? _darkSecondary
            : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? accentColor.withValues(alpha: 0.15)
              : accentColor.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  // ─── Themes ─────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        primary: accent,
        secondary: accentViolet,
        surface: _darkPrimary,
        surfaceContainer: _darkSecondary,
        error: error,
      ),
      scaffoldBackgroundColor: _darkPrimary,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.8,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.4,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          color: const Color(0xFFF5F5F7),
          height: 1.55,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF9CA3AF),
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B7280),
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _darkPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
      ),
      cardTheme: CardThemeData(
        color: _darkSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _darkBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        primary: accent,
        secondary: accentViolet,
        surface: primaryLight,
        surfaceContainer: secondaryLight,
        error: error,
      ),
      scaffoldBackgroundColor: primaryLight,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.light().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
          letterSpacing: -0.8,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E293B),
          letterSpacing: -0.4,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155),
          letterSpacing: -0.2,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          color: const Color(0xFF475569),
          height: 1.55,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF64748B),
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          color: const Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A), size: 20),
      ),
      cardTheme: CardThemeData(
        color: secondaryLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: borderLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
    );
  }
}
