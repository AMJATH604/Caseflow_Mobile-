import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:caseflow/services/case_import_service.dart';
import 'package:caseflow/utils/ecourts_case_number.dart';

// Every record below is taken from a real Tenkasi eCourts export, trimmed to
// the fields that matter.
void main() {
  group('ECourtsCaseNumber', () {
    test('a plain registered case reads as it does on the board', () {
      expect(
        ECourtsCaseNumber.fromJson({
          'type_name': 'OS',
          'case_no': '231700003842021',
          'reg_no': '384',
          'reg_year': '2021',
        }),
        'OS/384/2021',
      );
    });

    test('drops the register-series digit — OS 300194/2014 is OS 194/2014', () {
      expect(
        ECourtsCaseNumber.fromJson({
          'type_name': 'OS',
          'case_no': '231703001942014',
          'reg_no': '300194',
          'reg_year': '2014',
        }),
        'OS/194/2014',
      );
    });

    test('decodes every series seen in the export', () {
      final cases = {
        // type, case_no, reg_no, reg_year → expected
        'SC/638/2018': ['SC', '232106006382018', '600638', '2018'],
        'EP/120/2017': ['EP', '230801001202017', '100120', '2017'],
        'HMOP/84/2020': ['HMOP', '231002000842020', '200084', '2020'],
        'OS/342/2016': ['OS', '231704003422016', '400342', '2016'],
        'OS/14/2004': ['OS', '231702000142004', '200014', '2004'],
        'CRLMP/1164/2025': ['CRLMP', '232500011642025', '1164', '2025'],
        'MCOP/14/2026': ['MCOP', '231500000142026', '14', '2026'],
      };
      cases.forEach((expected, f) {
        expect(
          ECourtsCaseNumber.fromJson({
            'type_name': f[0],
            'case_no': f[1],
            'reg_no': f[2],
            'reg_year': f[3],
          }),
          expected,
          reason: 'case_no ${f[1]}',
        );
      });
    });

    test('falls back to reg_no without the series when case_no is absent', () {
      expect(
        ECourtsCaseNumber.fromJson({
          'type_name': 'OS',
          'case_no': null,
          'reg_no': 300194,
          'reg_year': 2014,
        }),
        'OS/194/2014',
      );
    });

    test('a filed-but-unregistered case shows its filing number, marked', () {
      // Previously printed as EP/0/0.
      expect(
        ECourtsCaseNumber.fromJson({
          'type_name': 'EP',
          'case_no': null,
          'reg_year': 0,
          'reg_no': 0,
          'fil_year': '2026',
          'fil_no': '1122',
        }),
        'EP/1122/2026 (filed)',
      );
    });

    test('never prints a zero number', () {
      final result = ECourtsCaseNumber.fromJson({
        'type_name': 'OS',
        'reg_no': 0,
        'reg_year': 0,
        'fil_no': 0,
        'fil_year': 0,
      });
      expect(result, isNull);
    });

    test('keeps an already-formatted number from another export shape', () {
      expect(
        ECourtsCaseNumber.fromJson({'case_number': 'O.S. 448/2022'}),
        'O.S. 448/2022',
      );
      expect(
        ECourtsCaseNumber.fromJson({'case_no': 'STC 12/2024'}),
        'STC 12/2024',
      );
    });

    test('works without a type', () {
      expect(
        ECourtsCaseNumber.fromJson({'case_no': '231700003842021'}),
        '384/2021',
      );
    });

    test('the import parser uses it — real export shape, end to end', () {
      // myCases.txt is a JSON array whose items are themselves JSON strings.
      final records = [
        {
          'cino': 'TNTS050003002014',
          'type_name': 'OS',
          'case_no': '231703002232014',
          'reg_year': '2014',
          'reg_no': '300223',
          'petparty_name': 'Sivanaintha Perumal Nadar',
          'resparty_name': 'Sankaralingam and Other',
          'establishment_name': 'Principal District Munsif Court, Tenkasi',
        },
        {
          'cino': 'TNTS030010702026',
          'type_name': 'EP',
          'case_no': null,
          'reg_year': 0,
          'reg_no': 0,
          'petparty_name': 'Muthu Kumar',
          'resparty_name': 'Mari Durai',
          'fil_year': '2026',
          'fil_no': '1122',
          'establishment_name': 'Principal Sub Court, Tenkasi',
        },
      ];
      final file = jsonEncode(records.map(jsonEncode).toList());

      final parsed = CaseImportService.parseECourtsTxt(file);

      expect(parsed, hasLength(2));
      expect(parsed[0]['case_number'], 'OS/223/2014');
      expect(
        parsed[0]['court_name'],
        'Principal District Munsif Court, Tenkasi',
      );
      expect(parsed[1]['case_number'], 'EP/1122/2026 (filed)');
    });

    test('ignores the literal string "null" that some exports carry', () {
      expect(
        ECourtsCaseNumber.fromJson({
          'type_name': 'null',
          'case_no': '231700003842021',
        }),
        '384/2021',
      );
    });
  });
}
