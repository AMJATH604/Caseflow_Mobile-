import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/utils/safe_date.dart';
import 'package:caseflow/models/models.dart';

/// Regression cover for the date parsing that models use when building
/// themselves from database rows.
///
/// The bug this guards: `importCaseFlowJson` wrote `paid_date` straight from a
/// restored backup without normalising it, and `Payment.fromJson` then called
/// `DateTime.parse` on it with no guard. A single `DD-MM-YYYY` date — the form
/// eCourts and older backups produce — threw a `FormatException` inside the
/// unguarded `.map()` over the result set, so the *entire* payments query
/// failed for every case, permanently, until the row was edited by hand.
///
/// These tests exercise the real helpers and the real models. They must never
/// be rewritten to assert against a local reimplementation — a copy would pass
/// while production stayed broken.
void main() {
  group('parseDateOrNull', () {
    test('returns null for null, empty and whitespace', () {
      expect(parseDateOrNull(null), isNull);
      expect(parseDateOrNull(''), isNull);
      expect(parseDateOrNull('   '), isNull);
    });

    test('parses ISO-8601, which is what a correct row holds', () {
      expect(parseDateOrNull('2026-04-15'), DateTime.parse('2026-04-15'));
      expect(
        parseDateOrNull('2026-04-15T10:30:00.000Z'),
        DateTime.parse('2026-04-15T10:30:00.000Z'),
      );
    });

    test('passes a DateTime through untouched', () {
      final now = DateTime(2026, 4, 15);
      expect(parseDateOrNull(now), now);
    });

    test('recovers a day-first date instead of discarding it', () {
      // The exact shape that corrupted the payments table.
      expect(parseDateOrNull('15-04-2026'), DateTime(2026, 4, 15));
      expect(parseDateOrNull('15/04/2026'), DateTime(2026, 4, 15));
    });

    test('recovers a day-first date without leading zeros', () {
      expect(parseDateOrNull('5-4-2026'), DateTime(2026, 4, 5));
      expect(parseDateOrNull('5/4/2026'), DateTime(2026, 4, 5));
    });

    test('returns null for genuinely unreadable input rather than throwing', () {
      expect(parseDateOrNull('not a date'), isNull);
      expect(parseDateOrNull('15 April 2026'), isNull);
      expect(parseDateOrNull(12345), isNull);
    });
  });

  group('parseDateOr', () {
    final fallback = DateTime(2000, 1, 1);

    test('falls back on a missing value', () {
      expect(parseDateOr(null, fallback), fallback);
      expect(parseDateOr('', fallback), fallback);
    });

    test('falls back on a malformed value instead of throwing', () {
      // The old `DateTime.parse(json['x'] ?? now)` handled a *missing* value
      // but still threw on a present-but-malformed one.
      expect(parseDateOr('not a date', fallback), fallback);
    });

    test('prefers a readable value over the fallback', () {
      expect(parseDateOr('2026-04-15', fallback), DateTime.parse('2026-04-15'));
      expect(parseDateOr('15-04-2026', fallback), DateTime(2026, 4, 15));
    });
  });

  group('models survive a malformed date row', () {
    test('Payment.fromJson does not throw on a day-first paid_date', () {
      final payment = Payment.fromJson({
        'id': 'p1',
        'case_id': 'c1',
        'total_fee': 50000,
        'paid_amount': 25000,
        'balance_amount': 25000,
        'paid_date': '15-04-2026',
        'payment_mode': 'cash',
        'created_by': 'u1',
      });

      expect(payment.paidDate, DateTime(2026, 4, 15));
      expect(payment.paidAmount, 25000);
    });

    test('Payment.fromJson keeps the amounts when the date is unreadable', () {
      // Losing the date is acceptable; losing the money is not.
      final payment = Payment.fromJson({
        'id': 'p2',
        'case_id': 'c1',
        'total_fee': 50000,
        'paid_amount': 25000,
        'balance_amount': 25000,
        'paid_date': 'garbage',
        'created_by': 'u1',
      });

      expect(payment.paidDate, isNull);
      expect(payment.paidAmount, 25000);
      expect(payment.totalFee, 50000);
    });

    test('one bad row does not fail the whole result set', () {
      // This is the actual failure mode: models are built inside an unguarded
      // `.map()` over every row the query returned.
      final rows = [
        {'id': 'p1', 'case_id': 'c1', 'paid_date': '2026-04-15', 'created_by': 'u1'},
        {'id': 'p2', 'case_id': 'c1', 'paid_date': '15-04-2026', 'created_by': 'u1'},
        {'id': 'p3', 'case_id': 'c1', 'paid_date': 'garbage', 'created_by': 'u1'},
      ];

      expect(
        () => rows.map((r) => Payment.fromJson(r)).toList(),
        returnsNormally,
      );

      final payments = rows.map((r) => Payment.fromJson(r)).toList();
      expect(payments.length, 3);
      expect(payments[2].paidDate, isNull);
    });

    test('EFilingRecord.fromJson survives a day-first filing_date', () {
      final record = EFilingRecord.fromJson({
        'id': 'e1',
        'case_id': 'c1',
        'document_type': 'plaint',
        'status': 'filed',
        'filing_date': '15-04-2026',
        'created_by': 'u1',
      });

      expect(record.filingDate, DateTime(2026, 4, 15));
    });

    test('CaseModel.fromJson survives day-first dates', () {
      final model = CaseModel.fromJson({
        'id': 'c1',
        'case_title': 'Maheswari vs Prema',
        'client_id': 'cl1',
        'filing_date': '01-06-2022',
        'next_hearing_date': '30-01-2026',
        'created_by': 'u1',
      });

      expect(model.filingDate, DateTime(2022, 6, 1));
      expect(model.nextHearingDate, DateTime(2026, 1, 30));
    });

    test('Hearing.fromJson falls back rather than throwing', () {
      final hearing = Hearing.fromJson({
        'id': 'h1',
        'case_id': 'c1',
        'hearing_date': 'garbage',
        'created_by': 'u1',
      });

      // hearingDate is non-nullable, so it takes the fallback instead of
      // bringing down the Court Diary query.
      expect(hearing.id, 'h1');
    });
  });
}
