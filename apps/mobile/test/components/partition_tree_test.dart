import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:caseflow/components/partition_tree.dart';

final _currency = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// The worked example: 1 son, 4 daughters, mother alive, deceased male,
/// ₹36,00,000 net, under Hanafi rules.
List<Map<String, dynamic>> _hanafiExample() => [
  {
    'heir': 'Mother',
    'fraction': '1/6',
    'amount': 600000.0,
    'relation': 'mother',
    'basis': 'fixed',
  },
  {
    'heir': 'Son',
    'fraction': '2/6 res.',
    'amount': 1000000.0,
    'relation': 'son',
    'basis': 'residuary',
  },
  for (var i = 1; i <= 4; i++)
    {
      'heir': 'Daughter $i',
      'fraction': '1/6 res.',
      'amount': 500000.0,
      'relation': 'daughter',
      'basis': 'residuary',
    },
];

/// Pumps the tree at a real device size. The default 800x600 test surface
/// would make ScreenUtil's width-based `.sp` twice as large as on a phone
/// while shrinking its height-based `.h`, which is not a layout any user sees.
Future<void> _pumpTree(
  WidgetTester tester,
  List<Map<String, dynamic>> results, {
  double netEstate = 3600000,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: PartitionTree(
                results: results,
                netEstate: netEstate,
                deceasedGender: 'Male',
                currency: _currency,
                isDark: false,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('partitionTreeColumns', () {
    test('fits as many boxes as the width allows', () {
      expect(partitionTreeColumns(330, 104), 3);
      expect(partitionTreeColumns(220, 104), 2);
      expect(partitionTreeColumns(104, 104), 1);
    });

    test('never returns zero, however narrow the screen', () {
      expect(partitionTreeColumns(40, 104), 1);
      expect(partitionTreeColumns(0, 104), 1);
      expect(partitionTreeColumns(-10, 104), 1);
    });

    test('caps at four so a box keeps room for a rupee figure', () {
      expect(partitionTreeColumns(2000, 104), 4);
    });

    test('survives a zero box width instead of dividing by zero', () {
      expect(partitionTreeColumns(330, 0), 1);
    });
  });

  group('chunkHeirs', () {
    test('splits into lines and keeps every heir, in order', () {
      final rows = chunkHeirs([1, 2, 3, 4, 5], 3);
      expect(rows, [
        [1, 2, 3],
        [4, 5],
      ]);
      expect(rows.expand((r) => r).toList(), [1, 2, 3, 4, 5]);
    });

    test('handles an exact fit without a trailing empty row', () {
      expect(chunkHeirs([1, 2, 3, 4], 2), [
        [1, 2],
        [3, 4],
      ]);
    });

    test('treats a non-positive row size as one per row', () {
      expect(chunkHeirs([1, 2], 0), [
        [1],
        [2],
      ]);
    });

    test('returns nothing for no heirs', () {
      expect(chunkHeirs([], 3), isEmpty);
    });
  });

  group('heirBandFor', () {
    test('places each relation in its generation', () {
      expect(heirBandFor('father'), HeirBand.ascendant);
      expect(heirBandFor('mother'), HeirBand.ascendant);
      expect(heirBandFor('spouse'), HeirBand.spouse);
      expect(heirBandFor('son'), HeirBand.descendant);
      expect(heirBandFor('daughter'), HeirBand.descendant);
    });

    test('returns null for an untagged share rather than guessing', () {
      expect(heirBandFor(null), isNull);
      expect(heirBandFor('grandson'), isNull);
    });
  });

  group('heirChipLabel', () {
    test('describes residuary children in parts, not fractions', () {
      // The whole point: a daughter paid from the remainder must not show
      // "1/6" next to a mother's "1/6", which are different amounts.
      expect(heirChipLabel('son', 'residuary', '2/6 res.'), '2 parts');
      expect(heirChipLabel('daughter', 'residuary', '1/6 res.'), '1 part');
    });

    test('keeps the fraction for a fixed sharer', () {
      expect(heirChipLabel('mother', 'fixed', '1/6'), '1/6');
      expect(heirChipLabel('spouse', 'equal', '1/8'), '1/8');
    });

    test('spells out a father drawing from both pots', () {
      expect(heirChipLabel('father', 'mixed', '1/6 + res.'), '1/6 + remainder');
    });

    test('falls back to empty rather than printing null', () {
      expect(heirChipLabel('son', 'fixed', null), '');
      expect(heirChipLabel('son', 'fixed', '  '), '');
    });
  });

  group('PartitionTree rendering', () {
    testWidgets('draws every heir, the deceased, and the remainder rail', (
      tester,
    ) async {
      await _pumpTree(tester, _hanafiExample());

      expect(find.text('Mother'), findsOneWidget);
      expect(find.text('Son'), findsOneWidget);
      for (var i = 1; i <= 4; i++) {
        expect(find.text('Daughter $i'), findsOneWidget);
      }

      expect(find.textContaining('DECEASED'), findsOneWidget);
      expect(find.text('REMAINDER (ASABA)'), findsOneWidget);
      expect(find.text('ELDER GENERATION'), findsOneWidget);
      expect(find.text('YOUNGER GENERATION'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the rail total equals the children it sits above', (
      tester,
    ) async {
      await _pumpTree(tester, _hanafiExample());

      // 10,00,000 + 4 x 5,00,000 = 30,00,000 — the mother's 6,00,000 is not
      // part of the remainder and must not be counted into the rail.
      expect(find.text(_currency.format(3000000)), findsOneWidget);
    });

    testWidgets('renders nothing at all for an empty result', (tester) async {
      await _pumpTree(tester, const [], netEstate: 0);
      expect(find.textContaining('DECEASED'), findsNothing);
    });

    testWidgets('omits the rail when everyone takes a fixed share', (
      tester,
    ) async {
      await _pumpTree(tester, const [
        {
          'heir': 'Widow',
          'fraction': '1/6',
          'amount': 600000.0,
          'relation': 'spouse',
          'basis': 'equal',
        },
        {
          'heir': 'Son',
          'fraction': '1/6',
          'amount': 600000.0,
          'relation': 'son',
          'basis': 'equal',
        },
      ], netEstate: 1200000);

      expect(find.text('REMAINDER (ASABA)'), findsNothing);
      expect(find.text('Widow'), findsOneWidget);
      expect(find.text('Son'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('still shows an heir whose share carries no relation', (
      tester,
    ) async {
      await _pumpTree(tester, const [
        {
          'heir': 'Grandson',
          'fraction': '1/2',
          'amount': 500000.0,
          'basis': 'fixed',
        },
      ], netEstate: 1000000);

      expect(find.text('Grandson'), findsOneWidget);
      expect(find.text('OTHER HEIRS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out without overflow on a narrow screen', (tester) async {
      await _pumpTree(tester, _hanafiExample(), size: const Size(320, 1400));

      expect(tester.takeException(), isNull);
      for (var i = 1; i <= 4; i++) {
        expect(find.text('Daughter $i'), findsOneWidget);
      }
    });

    testWidgets('lays out without overflow at the largest allowed text size', (
      tester,
    ) async {
      // Global scaling is clamped to 1.15x; a fixed-height box overflowed
      // here before the row was made to grow with its content.
      await _pumpTree(tester, _hanafiExample(), textScale: 1.15);

      expect(tester.takeException(), isNull);
      expect(find.text('Mother'), findsOneWidget);
      expect(find.text('Daughter 4'), findsOneWidget);
    });
  });

  group('every share the calculator records is placeable', () {
    // The tree can only draw an heir it can locate, so a `_results.add`
    // written without both notes would silently drop that heir. This reads
    // the calculator source and fails naming any site that is missing one —
    // which also catches a case added later by someone who has not read this.
    test('every _results.add carries a relation and a basis', () {
      final file = File('lib/pages/tools/partition_calculator.dart');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'run flutter test from apps/mobile',
      );

      final lines = file.readAsLinesSync();
      final missing = <String>[];
      var sites = 0;

      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('_results.add({')) continue;
        sites++;

        // Walk to the end of this literal, tracking brace depth so a nested
        // map or a multi-line value cannot end the block early.
        final buffer = StringBuffer();
        var depth = 0;
        var j = i;
        do {
          final line = lines[j];
          buffer.writeln(line);
          depth += '{'.allMatches(line).length;
          depth -= '}'.allMatches(line).length;
          j++;
        } while (depth > 0 && j < lines.length);

        final body = buffer.toString();
        final gaps = <String>[
          if (!body.contains("'relation':")) 'relation',
          if (!body.contains("'basis':")) 'basis',
        ];
        if (gaps.isNotEmpty) {
          missing.add('line ${i + 1} is missing ${gaps.join(" and ")}');
        }
      }

      expect(sites, greaterThan(0), reason: 'no share sites found — moved?');
      expect(missing, isEmpty, reason: missing.join('\n'));
    });
  });
}
