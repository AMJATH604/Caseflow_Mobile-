import 'package:flutter/material.dart';

/// Script fallbacks for non-Latin text.
///
/// The app sets Inter almost everywhere via `GoogleFonts.inter(...)`. Inter
/// has no Tamil glyphs, so Tamil strings rely on the platform's font-fallback
/// chain to find a Tamil face. That chain is present on essentially every
/// Android 5+ device, but it is not guaranteed on stripped-down budget ROMs —
/// where the symptom is tofu boxes (□□□) instead of text.
///
/// Naming the fallback families explicitly makes the intent survive that case
/// wherever the device has the font under a standard name.
///
/// **Production hardening:** to remove the dependency on the device entirely,
/// bundle `NotoSansTamil-Regular.ttf` under `assets/fonts/`, declare it in
/// `pubspec.yaml` as family `Noto Sans Tamil`, and it will be picked up by the
/// same fallback list with no call-site changes.
class AppFonts {
  const AppFonts._();

  /// Families tried, in order, when the primary face lacks a glyph.
  static const List<String> indicFallback = <String>[
    'Noto Sans Tamil',
    'Noto Sans',
    'sans-serif',
  ];
}

extension IndicSafeTextStyle on TextStyle {
  /// Adds Tamil-capable fallbacks to a style.
  ///
  /// Use on any style that may render a localized string:
  /// `GoogleFonts.inter(fontSize: 14).indicSafe`
  ///
  /// Harmless on Latin text — the fallback list is only consulted for glyphs
  /// the primary family cannot supply.
  TextStyle get indicSafe =>
      copyWith(fontFamilyFallback: AppFonts.indicFallback);
}
