import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/services/app_localizations.dart';
import 'package:caseflow/services/locale_service.dart';

/// Guards the Tamil translation.
///
/// [AppLocalizations.translate] falls back to English silently, so a missing
/// or mistyped key is invisible in the UI — it just renders in English. These
/// tests make that visible at build time instead.
void main() {
  group('Tamil coverage', () {
    test('every English key has a Tamil translation', () {
      final missing = AppLocalizations.missingKeys('ta');
      expect(
        missing,
        isEmpty,
        reason:
            'Tamil is offered in Settings, so it must cover every key. '
            'Missing: ${missing.join(', ')}',
      );
    });

    test('no Tamil value is left as its English source', () {
      final ta = AppLocalizations(const Locale('ta'));
      final en = AppLocalizations(const Locale('en'));

      // Keys whose value is intentionally identical in both languages:
      // product names and legal terms of art are not translated.
      const sharedByDesign = {'ai_title'};

      final untranslated = <String>[];
      for (final key in AppLocalizations.englishKeys) {
        if (sharedByDesign.contains(key)) continue;
        if (ta.get(key) == en.get(key)) untranslated.add(key);
      }

      expect(
        untranslated,
        isEmpty,
        reason: 'These keys still render English text under Tamil: '
            '${untranslated.join(', ')}',
      );
    });

    test('falls back to English for an unknown key rather than throwing', () {
      final ta = AppLocalizations(const Locale('ta'));
      expect(ta.get('save'), isNot('save'));
      // Unknown keys return the key itself — the documented last resort.
      expect(ta.get('definitely_not_a_key'), 'definitely_not_a_key');
    });
  });

  group('LocaleService', () {
    test('offers English and Tamil', () {
      final codes = LocaleService.supported.map((l) => l.code).toList();
      expect(codes, containsAll(<String>['en', 'ta']));
    });

    test('every offered language has a translation map', () {
      for (final lang in LocaleService.supported) {
        expect(
          AppLocalizations.supportedLocales
              .any((l) => l.languageCode == lang.code),
          isTrue,
          reason: '${lang.englishName} is offered in Settings but '
              'AppLocalizations has no map for "${lang.code}"',
        );
      }
    });

    test('every offered language is labelled in its own script', () {
      // A user who cannot read English must recognise their language in the
      // picker, so the label must not simply repeat the English name.
      for (final lang in LocaleService.supported) {
        if (lang.code == 'en') continue;
        expect(
          lang.label,
          isNot(lang.englishName),
          reason: '${lang.englishName} is labelled in English in the picker',
        );
      }
    });

    test('languageFor falls back to English for an unsupported locale', () {
      expect(LocaleService.languageFor(const Locale('fr')).code, 'en');
      expect(LocaleService.languageFor(const Locale('ta')).code, 'ta');
    });
  });
}
