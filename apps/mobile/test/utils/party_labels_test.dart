import 'package:caseflow/utils/party_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PartyLabels.forCase', () {
    test('civil suits are plaintiff and defendant', () {
      for (final n in ['OS/448/2022', 'O.S. 448 of 2022', 'as/12/2021', 'SA/9/2020']) {
        final labels = PartyLabels.forCase(caseNumber: n);
        expect(labels.first, 'Plaintiff', reason: n);
        expect(labels.second, 'Defendant', reason: n);
      }
    });

    test('criminal matters are complainant and accused', () {
      for (final n in ['CC/1234/2023', 'C.C. 1234/2023', 'STC/55/2024', 'crlmp/7/2022']) {
        final labels = PartyLabels.forCase(caseNumber: n);
        expect(labels.first, 'Complainant', reason: n);
        expect(labels.second, 'Accused', reason: n);
      }
    });

    test('writs and revisions stay petitioner and respondent', () {
      for (final n in ['WP/9999/2025', 'CRP/14/2023', 'CMA/3/2021']) {
        final labels = PartyLabels.forCase(caseNumber: n);
        expect(labels.first, 'Petitioner', reason: n);
        expect(labels.second, 'Respondent', reason: n);
      }
    });

    test('an unknown or missing prefix falls back to petitioner/respondent', () {
      expect(PartyLabels.forCase(caseNumber: null), PartyLabels.petitionerRespondent);
      expect(PartyLabels.forCase(caseNumber: ''), PartyLabels.petitionerRespondent);
      expect(PartyLabels.forCase(caseNumber: '448/2022'), PartyLabels.petitionerRespondent);
      expect(PartyLabels.forCase(caseNumber: 'XYZ/1/2020'), PartyLabels.petitionerRespondent);
      expect(PartyLabels.forCase(caseNumber: '///'), PartyLabels.petitionerRespondent);
    });

    test('an explicit case type wins over the number', () {
      // The eCourts export sometimes carries a type separate from the number.
      final labels = PartyLabels.forCase(caseNumber: 'WP/1/2020', caseType: 'CC');
      expect(labels.first, 'Complainant');
    });

    test('punctuation and spacing do not change the answer', () {
      final a = PartyLabels.forCase(caseNumber: 'O.S. 448 / 2022');
      final b = PartyLabels.forCase(caseNumber: 'os448of2022');
      expect(a.first, b.first);
      expect(a.first, 'Plaintiff');
    });
  });

  group('PartyLabels equality', () {
    test('const instances compare equal', () {
      expect(
        PartyLabels.forCase(caseNumber: 'OS/1/2020'),
        PartyLabels.plaintiffDefendant,
      );
    });
  });
}
