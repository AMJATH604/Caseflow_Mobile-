import 'package:caseflow/utils/court_fee_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Schedule II, Article 20 as substituted by the 2017 Amendment Act:
  // "Half per cent ad valorem, subject to a maximum of rupees ten thousand."
  group('NiActComplaintFee.forAmount — current law', () {
    test('charges nothing before an amount is entered', () {
      expect(NiActComplaintFee.forAmount(0), 0);
      expect(NiActComplaintFee.forAmount(-1), 0);
    });

    test('charges half a per cent', () {
      expect(NiActComplaintFee.forAmount(50000), 250);
      expect(NiActComplaintFee.forAmount(100000), 500);
      expect(NiActComplaintFee.forAmount(500000), 2500);
      expect(NiActComplaintFee.forAmount(1000000), 5000);
    });

    test('caps at ₹10,000 — reached at exactly ₹20,00,000', () {
      expect(NiActComplaintFee.forAmount(1999999), 10000);
      expect(NiActComplaintFee.forAmount(2000000), 10000);
      expect(NiActComplaintFee.forAmount(2000001), 10000);
      expect(NiActComplaintFee.forAmount(10000000), 10000);
    });

    test('rounds up to the whole rupee', () {
      // A fee short by a rupee gets the complaint returned at the counter.
      expect(NiActComplaintFee.forAmount(33333), 167); // 166.665
      expect(NiActComplaintFee.forAmount(201), 2); // 1.005
      expect(NiActComplaintFee.forAmount(1), 1); // 0.005
    });

    test('has no minimum — a tiny cheque costs a rupee, not a floor', () {
      expect(NiActComplaintFee.forAmount(100), 1);
    });

    test('honours an overridden rate and cap', () {
      expect(NiActComplaintFee.forAmount(100000, rate: 0.01), 1000);
      expect(NiActComplaintFee.forAmount(100000, maximumFee: 200), 200);
      expect(NiActComplaintFee.forAmount(10000000, maximumFee: null), 50000);
    });

    test('declares the 2017 figures', () {
      expect(NiActComplaintFee.defaultRate, 0.005);
      expect(NiActComplaintFee.defaultMaximumFee, 10000);
    });
  });

  // Article 20 as it stood 2003–2017, kept for filings made before the
  // amendment.
  group('NiActComplaintFee.legacyForAmount — pre-2017', () {
    test('charges nothing before an amount is entered', () {
      expect(NiActComplaintFee.legacyForAmount(0), 0);
      expect(NiActComplaintFee.legacyForAmount(-1), 0);
    });

    test('counts a part slab as a whole slab', () {
      expect(NiActComplaintFee.legacyForAmount(1), 25);
      expect(NiActComplaintFee.legacyForAmount(49999), 25);
      expect(NiActComplaintFee.legacyForAmount(60000), 50);
      expect(NiActComplaintFee.legacyForAmount(110000), 75);
    });

    test('keeps an exact slab boundary in the lower slab', () {
      // Getting this wrong doubles the fee on every round-number cheque.
      expect(NiActComplaintFee.legacyForAmount(50000), 25);
      expect(NiActComplaintFee.legacyForAmount(50001), 50);
      expect(NiActComplaintFee.legacyForAmount(100000), 50);
      expect(NiActComplaintFee.legacyForAmount(100001), 75);
    });

    test('matches the worked example for a ₹5,00,000 cheque', () {
      expect(NiActComplaintFee.legacyForAmount(500000), 250);
    });

    test('caps at ₹1,000 — also at ₹20,00,000', () {
      expect(NiActComplaintFee.legacyForAmount(1950000), 975);
      expect(NiActComplaintFee.legacyForAmount(2000000), 1000);
      expect(NiActComplaintFee.legacyForAmount(10000000), 1000);
    });

    test('rounds paise up to the next whole rupee before slabbing', () {
      expect(NiActComplaintFee.legacyForAmount(50000.01), 50);
    });
  });

  group('the amendment made the fee ten times larger', () {
    test('at every amount below the cap', () {
      for (final amount in [50000.0, 100000.0, 500000.0, 1000000.0]) {
        expect(
          NiActComplaintFee.forAmount(amount),
          NiActComplaintFee.legacyForAmount(amount) * 10,
          reason: 'at ₹$amount',
        );
      }
    });

    test('and both caps bite at ₹20,00,000', () {
      expect(NiActComplaintFee.forAmount(2000000), 10000);
      expect(NiActComplaintFee.legacyForAmount(2000000), 1000);
    });
  });

  group('basis strings', () {
    test('current basis cites Article 20 as amended, with the cap', () {
      expect(
        NiActComplaintFee.basis(),
        'NI Act §138 complaint — TN Court-Fees Act, Schedule II, Art. 20 '
        '(as amended 2017): 0.5% of the cheque amount, max ₹10,000',
      );
    });

    test('legacy basis states the old slab', () {
      expect(
        NiActComplaintFee.legacyBasis(),
        'Schedule II, Art. 20 before the 2017 amendment: ₹25 per ₹50,000 '
        '(or part) of cheque amount, max ₹1,000',
      );
    });

    test('a whole-number rate does not render as "1.0%"', () {
      expect(NiActComplaintFee.basis(rate: 0.01), contains('1% of'));
    });
  });
}
