// Runs the Flutter implementations against the worked examples shared with
// the web app (packages/legal-fixtures). The web repo, caseflow_web_app,
// runs a copy of the same files in src/legal/fixtures.test.ts, so a rule
// that changes on one platform and not the other fails here or there.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:caseflow/utils/court_fee_rules.dart';
import 'package:caseflow/utils/ecourts_case_number.dart';

Map<String, dynamic> _fixture(String name) {
  // flutter test runs from apps/mobile.
  final file = File('../../packages/legal-fixtures/$name');
  if (!file.existsSync()) {
    // Loaded while the tests are being declared, where expect() is not
    // allowed — so fail loudly instead.
    throw StateError('missing ${file.absolute.path} — run from apps/mobile');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final fee = _fixture('ni_act_court_fee.json');
  final caseNo = _fixture('ecourts_case_number.json');

  group('NI Act §138 court fee — current (2017)', () {
    for (final c in (fee['current']['cases'] as List)) {
      final amount = (c['amount'] as num).toDouble();
      test('₹$amount → ₹${c['fee']}', () {
        expect(NiActComplaintFee.forAmount(amount), c['fee']);
      });
    }
  });

  group('NI Act §138 court fee — before 2017', () {
    for (final c in (fee['legacy']['cases'] as List)) {
      final amount = (c['amount'] as num).toDouble();
      test('₹$amount → ₹${c['fee']}', () {
        expect(NiActComplaintFee.legacyForAmount(amount), c['fee']);
      });
    }
  });

  group('eCourts case number', () {
    for (final c in (caseNo['cases'] as List)) {
      test('${c['expected']}', () {
        expect(
          ECourtsCaseNumber.fromJson(
            Map<String, dynamic>.from(c['input'] as Map),
          ),
          c['expected'],
        );
      });
    }
  });
}
