import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:caseflow/services/document_tools/document_tools_service.dart';

/// Applies an edit script to [a] and returns the text it describes.
List<String> rebuild(List<String> a, List<String> b, List<(int, int, int)> ops) => [
  for (final (op, start, len) in ops)
    if (op == 0)
      ...a.sublist(start, start + len)
    else if (op == 1)
      ...b.sublist(start, start + len),
];

int editCount(List<(int, int, int)> ops) =>
    ops.where((o) => o.$1 != 0).fold(0, (n, o) => n + o.$3);

/// Length of the longest common subsequence, by dynamic programming.
int lcs(List<String> a, List<String> b) {
  final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      dp[i][j] = a[i - 1] == b[j - 1] ? dp[i - 1][j - 1] + 1 : max(dp[i - 1][j], dp[i][j - 1]);
    }
  }
  return dp[a.length][b.length];
}

Uint8List pdfOf(List<String> pages) {
  final doc = PdfDocument();
  for (final text in pages) {
    doc.pages.add().graphics.drawString(
      text,
      PdfStandardFont(PdfFontFamily.helvetica, 11),
      bounds: const Rect.fromLTWH(20, 20, 480, 700),
    );
  }
  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return bytes;
}

void main() {
  group('diffWords', () {
    test('finds a replaced word', () {
      final a = 'the rent is 10000 per month'.split(' ');
      final b = 'the rent is 12000 per month'.split(' ');
      final ops = PdfCompare.diffWords(a, b);
      expect(rebuild(a, b, ops), b);
      expect(editCount(ops), 2);
    });

    test('identical and empty inputs', () {
      expect(PdfCompare.diffWords(['a', 'b'], ['a', 'b']), [(0, 0, 2)]);
      expect(rebuild(['a'], [], PdfCompare.diffWords(['a'], [])), isEmpty);
      expect(rebuild([], ['x', 'y'], PdfCompare.diffWords([], ['x', 'y'])), ['x', 'y']);
    });

    test('is correct and minimal on random edits', () {
      final random = Random(7);
      const vocabulary = ['a', 'b', 'c', 'd', 'e'];
      for (var round = 0; round < 400; round++) {
        final a = [for (var i = 0; i < random.nextInt(25); i++) vocabulary[random.nextInt(5)]];
        final b = [for (var i = 0; i < random.nextInt(25); i++) vocabulary[random.nextInt(5)]];
        final ops = PdfCompare.diffWords(a, b);
        expect(rebuild(a, b, ops), b, reason: '$a -> $b');
        // Minimal: removals + additions = |a| + |b| - 2 * LCS.
        expect(editCount(ops), a.length + b.length - 2 * lcs(a, b), reason: '$a -> $b');
      }
    });

    test('long documents with a few edits stay fast', () {
      final random = Random(1);
      final a = [for (var i = 0; i < 30000; i++) 'w${random.nextInt(2000)}'];
      final b = [...a]
        ..[100] = 'changed'
        ..insert(15000, 'inserted')
        ..removeAt(25000);
      final watch = Stopwatch()..start();
      final ops = PdfCompare.diffWords(a, b);
      expect(rebuild(a, b, ops), b);
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    });
  });

  group('compare PDFs', () {
    test('reports each change with context and pages', () {
      final old = pdfOf([
        'This agreement is made at Chennai. The monthly rent is Rs. 10,000.',
        'The tenant shall pay the rent before the fifth day of each month.',
      ]);
      final revised = pdfOf([
        'This agreement is made at Chennai. The monthly rent is Rs. 12,000.',
        'The tenant shall pay the rent before the tenth day of each month. Late payment attracts interest.',
      ]);
      final result = PdfCompare.compare(old, revised);
      expect(result.changes.length, 3);

      final rent = result.changes[0];
      expect(rent.kind, ChangeKind.replaced);
      expect(rent.removed, '10,000.');
      expect(rent.added, '12,000.');
      expect(rent.before, endsWith('rent is Rs.'));
      expect(rent.oldPage, 1);

      expect(result.changes[1].removed, 'fifth');
      expect(result.changes[1].added, 'tenth');
      expect(result.changes[1].newPage, 2);

      expect(result.changes[2].kind, ChangeKind.added);
      expect(result.changes[2].added, 'Late payment attracts interest.');
      expect(result.wordsAdded, 6);
    });

    test('identical documents', () {
      final pdf = pdfOf(['Same text on the page.']);
      expect(PdfCompare.compare(pdf, pdf).identical, isTrue);
    });

    test('a scan without text asks for OCR', () {
      final blank = pdfOf(['']);
      expect(
        () => PdfCompare.compare(blank, pdfOf(['Some text here'])),
        throwsA(predicate((e) => e.toString().contains('Run OCR'))),
      );
    });
  });
}
