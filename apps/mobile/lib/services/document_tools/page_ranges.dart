/// Parsing of page-range text such as `1-3, 5, 8-` typed by the user.
///
/// Page numbers in the text are 1-based (what the user sees); the parsed
/// result is 0-based page indices (what the PDF engine uses).
library;

class PageRangeException implements Exception {
  final String message;
  const PageRangeException(this.message);

  @override
  String toString() => message;
}

/// One inclusive range of 0-based page indices.
class PageRange {
  final int first;
  final int last;
  const PageRange(this.first, this.last);

  List<int> get indices => [for (var i = first; i <= last; i++) i];

  /// The range as the user would write it (1-based).
  String get label => first == last ? '${first + 1}' : '${first + 1}-${last + 1}';

  @override
  bool operator ==(Object other) =>
      other is PageRange && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => 'PageRange($label)';
}

/// Parses [text] against a document of [pageCount] pages.
///
/// Accepts comma/space separated parts: `4`, `2-6`, `8-` (to the end) and
/// `-3` (from the start). Ranges are kept in the order written so callers can
/// treat each one as a separate output file. Throws [PageRangeException] with
/// a message fit to show the user.
List<PageRange> parsePageRanges(String text, int pageCount) {
  final parts = text
      .split(RegExp(r'[,;\s]+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    throw const PageRangeException('Enter the pages, for example 1-3, 5');
  }

  final ranges = <PageRange>[];
  for (final part in parts) {
    final match = RegExp(r'^(\d*)\s*[-–]\s*(\d*)$').firstMatch(part);
    int first;
    int last;
    if (match != null) {
      final a = match.group(1)!;
      final b = match.group(2)!;
      if (a.isEmpty && b.isEmpty) {
        throw PageRangeException('"$part" is not a page range');
      }
      first = a.isEmpty ? 1 : int.parse(a);
      last = b.isEmpty ? pageCount : int.parse(b);
    } else if (RegExp(r'^\d+$').hasMatch(part)) {
      first = last = int.parse(part);
    } else {
      throw PageRangeException('"$part" is not a page number');
    }

    if (first < 1 || last < 1) {
      throw const PageRangeException('Page numbers start at 1');
    }
    if (first > pageCount || last > pageCount) {
      throw PageRangeException(
        'This PDF has only $pageCount page${pageCount == 1 ? '' : 's'}',
      );
    }
    if (first > last) {
      throw PageRangeException('"$part" runs backwards; write $last-$first');
    }
    ranges.add(PageRange(first - 1, last - 1));
  }
  return ranges;
}

/// All pages covered by [ranges], in order, without duplicates.
List<int> flattenRanges(List<PageRange> ranges) {
  final seen = <int>{};
  return [
    for (final r in ranges)
      for (final i in r.indices)
        if (seen.add(i)) i,
  ];
}

/// Splits [pageCount] pages into consecutive chunks of [size] pages.
List<PageRange> chunkPages(int pageCount, int size) {
  if (size < 1) throw const PageRangeException('Pages per file must be 1 or more');
  return [
    for (var start = 0; start < pageCount; start += size)
      PageRange(start, (start + size - 1).clamp(0, pageCount - 1)),
  ];
}
