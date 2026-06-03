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
  static const Color primaryLight = Color(0xFFF5F7FA); // Soft Gray Background
  static const Color secondaryLight = Color(0xFFFFFFFF); // Pure White Cards
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color surfaceLightMode = Color(0xFFFFFFFF);

  // ─── Header Card Gradient (Teal to Mint) ───────────
  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(
        0xFF6366F1,
      ), // Deep Indigo (Start of original image actually looks blueish indigo on the left edge)
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
  static const Color background = Color(0xFFF5F7FA); // Light gray bg

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accent, accentViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Decorations ────────────────────────────────────
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
        color: color ?? secondaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration glassDecoration({
    double blur = 0,
    double opacity = 0.1,
  }) => cardDecoration();

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
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          color: const Color(0xFFF5F5F7),
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF9CA3AF),
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B7280),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _darkPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
      ),
      cardTheme: CardThemeData(
        color: _darkSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _darkBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
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
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E293B),
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155),
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          color: const Color(0xFF475569),
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF64748B),
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.outfit(
          color: const Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A), size: 20),
      ),
      cardTheme: CardThemeData(
        color: secondaryLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderLight, thickness: 1),
    );
  }
}
