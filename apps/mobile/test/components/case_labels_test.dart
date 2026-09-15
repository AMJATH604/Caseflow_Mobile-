import 'package:caseflow/components/case_picker_field.dart';
import 'package:caseflow/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

CaseModel _case({
  String title = 'Ramsanabeevi vs Hasinaabeevi',
  String? number = 'OS/448/2022',
  String? cnr,
  String? client,
  String? court = 'Additional Sub Court, Tenkasi',
}) {
  return CaseModel.fromJson({
    'id': 'c1',
    'case_title': title,
    'case_number': number,
    'cnr_number': cnr,
    'court_name': court,
    'client_id': 'k1',
    'created_by': 'u1',
    'created_at': '2026-01-01T00:00:00Z',
    if (client != null) 'clients': {'name': client},
  });
}

void main() {
  group('CaseLabels', () {
    test('shows the case number with the parties', () {
      expect(CaseLabels.oneLine(_case()), 'OS/448/2022 · Ramsanabeevi vs Hasinaabeevi');
    });

    test('falls back to the CNR when there is no case number', () {
      final c = _case(number: null, cnr: 'TNTK010012342022');
      expect(CaseLabels.number(c), 'TNTK010012342022');
    });

    test('never produces a blank label', () {
      final c = _case(title: '  ', number: null);
      expect(CaseLabels.number(c), isNull);
      expect(CaseLabels.title(c), 'Untitled case');
      expect(CaseLabels.oneLine(c), 'Untitled case');
    });

    test('search matches case number, parties and court, case-insensitively', () {
      final c = _case();
      expect(CaseLabels.matches(c, 'os/448'), isTrue);
      expect(CaseLabels.matches(c, 'HASINAA'), isTrue);
      expect(CaseLabels.matches(c, 'tenkasi'), isTrue);
      expect(CaseLabels.matches(c, 'madurai'), isFalse);
      expect(CaseLabels.matches(c, '   '), isTrue);
    });
  });
}
