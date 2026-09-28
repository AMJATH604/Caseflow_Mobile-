import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/services/document_tools/page_ranges.dart';

void main() {
  group('parsePageRanges', () {
    test('parses single pages and ranges into 0-based indices', () {
      expect(parsePageRanges('1-3, 5', 10), const [
        PageRange(0, 2),
        PageRange(4, 4),
      ]);
    });

    test('accepts open-ended ranges and mixed separators', () {
      expect(parsePageRanges('-2; 8-', 10), const [
        PageRange(0, 1),
        PageRange(7, 9),
      ]);
      expect(parsePageRanges(' 4  6 ', 10), const [
        PageRange(3, 3),
        PageRange(5, 5),
      ]);
    });

    test('keeps the order written', () {
      expect(parsePageRanges('5, 1-2', 5), const [
        PageRange(4, 4),
        PageRange(0, 1),
      ]);
    });

    test('rejects empty, out-of-range, backwards and junk input', () {
      expect(() => parsePageRanges('  ', 5), throwsA(isA<PageRangeException>()));
      expect(() => parsePageRanges('0', 5), throwsA(isA<PageRangeException>()));
      expect(() => parsePageRanges('6', 5), throwsA(isA<PageRangeException>()));
      expect(() => parsePageRanges('4-2', 5), throwsA(isA<PageRangeException>()));
      expect(() => parsePageRanges('a-b', 5), throwsA(isA<PageRangeException>()));
      expect(() => parsePageRanges('-', 5), throwsA(isA<PageRangeException>()));
    });

    test('error messages are readable', () {
      expect(
        () => parsePageRanges('9', 1),
        throwsA(
          predicate((e) => e.toString() == 'This PDF has only 1 page'),
        ),
      );
    });
  });

  test('flattenRanges removes duplicates and keeps order', () {
    expect(
      flattenRanges(const [PageRange(2, 4), PageRange(0, 3)]),
      [2, 3, 4, 0, 1],
    );
  });

  test('chunkPages splits evenly with a short last chunk', () {
    expect(chunkPages(7, 3), const [
      PageRange(0, 2),
      PageRange(3, 5),
      PageRange(6, 6),
    ]);
    expect(chunkPages(2, 5), const [PageRange(0, 1)]);
    expect(() => chunkPages(3, 0), throwsA(isA<PageRangeException>()));
  });

  test('PageRange label is 1-based', () {
    expect(const PageRange(0, 0).label, '1');
    expect(const PageRange(2, 5).label, '3-6');
  });
}
