import 'package:caseflow/utils/court_fee_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NiActComplaintFee.forAmount', () {
    test('charges nothing before an amount is entered', () {
      expect(NiActComplaintFee.forAmount(0), 0);
      expect(NiActComplaintFee.forAmount(-1), 0);
    });

    test('counts a part slab as a whole slab', () {
      // "for every ₹50,000 or part thereof" — one rupee still costs a slab.
      expect(NiActComplaintFee.forAmount(1), 25);
      expect(NiActComplaintFee.forAmount(49999), 25);
      expect(NiActComplaintFee.forAmount(60000), 50);
      expect(NiActComplaintFee.forAmount(110000), 75);
    });

    test('keeps an exact slab boundary in the lower slab', () {
      // The boundary case: ₹50,000 is one slab, not two. Getting this wrong
      // doubles the fee on every round-number cheque.
      expect(NiActComplaintFee.forAmount(50000), 25);
      expect(NiActComplaintFee.forAmount(50001), 50);
      expect(NiActComplaintFee.forAmount(100000), 50);
      expect(NiActComplaintFee.forAmount(100001), 75);
    });

    test('matches the worked example for a ₹5,00,000 cheque', () {
      // 10 slabs × ₹25. The calculator previously charged 3% — ₹15,000.
      expect(NiActComplaintFee.forAmount(500000), 250);
    });

    test('stays linear until the cap', () {
      expect(NiActComplaintFee.forAmount(1000000), 500);
      expect(NiActComplaintFee.forAmount(1950000), 975);
    });

    test('caps at ₹1,000 — reached at exactly 40 slabs', () {
      // ₹20,00,000 is 40 × ₹25 = ₹1,000 on the nose; anything above pays the
      // same. A ₹1 crore cheque costs no more than a ₹20 lakh one.
      expect(NiActComplaintFee.forAmount(1999999), 1000);
      expect(NiActComplaintFee.forAmount(2000000), 1000);
      expect(NiActComplaintFee.forAmount(2000001), 1000);
      expect(NiActComplaintFee.forAmount(10000000), 1000);
    });

    test('rounds paise up to the next whole rupee before slabbing', () {
      expect(NiActComplaintFee.forAmount(50000.01), 50);
    });

    test('applies a minimum fee when one is prescribed', () {
      expect(NiActComplaintFee.forAmount(1000, minimumFee: 100), 100);
      expect(NiActComplaintFee.forAmount(500000, minimumFee: 100), 250);
    });

    test('applies a maximum fee when one is prescribed', () {
      expect(NiActComplaintFee.forAmount(500000, maximumFee: 200), 200);
      expect(NiActComplaintFee.forAmount(50000, maximumFee: 200), 25);
    });

    test('honours a different slab size and rate', () {
      expect(
        NiActComplaintFee.forAmount(100000, slabSize: 10000, perSlab: 5),
        50,
      );
    });

    test('has no floor but does have a ₹1,000 ceiling', () {
      expect(NiActComplaintFee.defaultMinimumFee, isNull);
      expect(NiActComplaintFee.defaultMaximumFee, 1000);
    });
  });

  group('NiActComplaintFee.basis', () {
    test('states the rule and the cap, grouped Indian-style', () {
      expect(
        NiActComplaintFee.basis(),
        'NI Act §138 complaint — Schedule II slab: ₹25 per ₹50,000 '
        '(or part) of cheque amount, max ₹1,000',
      );
    });

    test('drops the cap clause when there is no ceiling', () {
      expect(
        NiActComplaintFee.basis(maximumFee: null),
        'NI Act §138 complaint — Schedule II slab: ₹25 per ₹50,000 '
        '(or part) of cheque amount',
      );
    });

    test('reflects overridden figures', () {
      expect(
        NiActComplaintFee.basis(slabSize: 100000, perSlab: 50, maximumFee: null),
        'NI Act §138 complaint — Schedule II slab: ₹50 per ₹1,00,000 '
        '(or part) of cheque amount',
      );
    });
  });
}
