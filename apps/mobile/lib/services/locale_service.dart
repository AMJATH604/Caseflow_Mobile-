import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A language CaseFlow can be displayed in.
///
/// [label] is deliberately written in the language's own script — a user who
/// cannot read English must still be able to find their language in the list,
/// so "Tamil" would defeat the purpose.
class AppLanguage {
  final Locale locale;
  final String label;
  final String englishName;

  const AppLanguage({
    required this.locale,
    required this.label,
    required this.englishName,
  });

  String get code => locale.languageCode;
}

/// Loads and persists the user's chosen display language.
///
/// Stored in SharedPreferences rather than the SQLite offline cache on
/// purpose: [OfflineCacheService.clearAll] runs on sign-out, and a language
/// preference must survive signing out — otherwise a Tamil-only user is
/// dropped back into an English login screen.
class LocaleService {
  static const String _prefsKey = 'app_locale_code';

  /// Languages offered in Settings.
  ///
  /// Adding another language is two steps: add an entry here, and add its
  /// map to [AppLocalizations]. Nothing else needs to change.
  static const List<AppLanguage> supported = [
    AppLanguage(
      locale: Locale('en'),
      label: 'English',
      englishName: 'English',
    ),
    AppLanguage(
      locale: Locale('ta'),
      label: 'தமிழ்',
      englishName: 'Tamil',
    ),
  ];

  static const Locale fallback = Locale('en');

  /// The [AppLanguage] for a locale, falling back to English.
  static AppLanguage languageFor(Locale locale) {
    for (final lang in supported) {
      if (lang.code == locale.languageCode) return lang;
    }
    return supported.first;
  }

  /// Reads the saved language. Returns English if nothing is stored, if the
  /// stored code is no longer offered, or if storage is unavailable.
  static Future<Locale> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code == null) return fallback;
      for (final lang in supported) {
        if (lang.code == code) return lang.locale;
      }
      return fallback;
    } catch (_) {
      // Storage unavailable — never block app start over a preference.
      return fallback;
    }
  }

  /// Persists the chosen language. Failures are swallowed: the in-memory
  /// switch has already taken effect, and losing the preference on restart is
  /// preferable to crashing the settings screen.
  static Future<void> save(Locale locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, locale.languageCode);
    } catch (_) {}
  }
}
