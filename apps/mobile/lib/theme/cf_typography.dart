import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow Design System — Typography
///
/// All text styles for the app. Uses:
/// - Outfit: For display, headings, and titles (elegant, modern)
/// - Inter: For body, labels, and UI text (highly readable)
///
/// Usage: Text('Hello', style: CfTypography.headingLg)
/// Or with color override: CfTypography.headingLg.copyWith(color: ...)
/// ══════════════════════════════════════════════════════════════

class CfTypography {
  CfTypography._();

  // ─── Display (Hero sections, splash) ─────────────────────
  static TextStyle displayLg = GoogleFonts.outfit(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    height: 1.15,
  );

  static TextStyle displayMd = GoogleFonts.outfit(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle displaySm = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
  );

  // ─── Headings (Section titles, card headers) ─────────────
  static TextStyle headingLg = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static TextStyle headingMd = GoogleFonts.outfit(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static TextStyle headingSm = GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // ─── Body (Content text, descriptions) ───────────────────
  static TextStyle bodyLg = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
  );

  static TextStyle bodyMd = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  static TextStyle bodySm = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ─── Labels (Buttons, chips, badges) ─────────────────────
  static TextStyle labelLg = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static TextStyle labelMd = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.35,
  );

  static TextStyle labelSm = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    height: 1.3,
  );

  // ─── Caption (Timestamps, hints, metadata) ───────────────
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle captionSm = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.3,
  );

  // ─── Legal (For legal text, acts, sections) ──────────────
  static TextStyle legalTitle = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );

  static TextStyle legalBody = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.7,  // Extra line height for readability of legal text
  );

  static TextStyle legalSection = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.6,
  );

  // ─── Stat / KPI Numbers ──────────────────────────────────
  static TextStyle statLg = GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.1,
  );

  static TextStyle statMd = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.15,
  );

  static TextStyle statSm = GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  // ─── Monospace (for CNR numbers, case IDs) ───────────────
  static TextStyle mono = GoogleFonts.jetBrainsMono(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );
}
