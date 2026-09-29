/// Compare two versions of a document (e.g. a draft agreement and the other
/// side's redline) by their text: which words were added and removed, and
/// on which pages.
///
/// Pure Dart; run through `DocumentToolsService`.
library;

import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_engine.dart';

/// A word and the (1-based) page it sits on.
class Word {
  final String text;
  final int page;
  const Word(this.text, this.page);
}

enum ChangeKind { removed, added, replaced }

/// One place where the versions differ, with a little unchanged text
/// around it so the reader can find it.
class TextChange {
  final ChangeKind kind;
  final String before;
  final String removed;
  final String added;
  final String after;

  /// Pages in the old and new versions (1-based) where the change sits.
  final int oldPage;
  final int newPage;

  const TextChange({
    required this.kind,
    required this.before,
    required this.removed,
    required this.added,
    required this.after,
    required this.oldPage,
    required this.newPage,
  });
}

class Comparison {
  final List<TextChange> changes;
  final int oldWords;
  final int newWords;
  final int oldPages;
  final int newPages;
  const Comparison(this.changes, this.oldWords, this.newWords, this.oldPages, this.newPages);

  int get wordsRemoved => changes.fold(0, (n, c) => n + _count(c.removed));
  int get wordsAdded => changes.fold(0, (n, c) => n + _count(c.added));
  bool get identical => changes.isEmpty;

  static int _count(String s) => s.isEmpty ? 0 : s.split(' ').length;
}

class PdfCompare {
  PdfCompare._();

  /// Words of context shown on each side of a change.
  static const _context = 6;

  /// Gives up beyond this many word-level differences: the files are then
  /// different documents rather than versions of one.
  static const maxDifferences = 20000;

  static Comparison compare(Uint8List oldPdf, Uint8List newPdf) {
    final (oldWords, oldPages) = extractWords(oldPdf);
    final (newWords, newPages) = extractWords(newPdf);
    for (final (words, which) in [(oldWords, 'first'), (newWords, 'second')]) {
      if (words.length < 3) {
        throw DocumentToolException(
          'The $which PDF has no searchable text (it is probably a scan). '
          'Run OCR on it first, then compare.',
        );
      }
    }
    final ops = diffWords(
      [for (final w in oldWords) w.text],
      [for (final w in newWords) w.text],
    );
    return Comparison(_changes(ops, oldWords, newWords), oldWords.length, newWords.length, oldPages, newPages);
  }

  /// Every word of [pdf] with its page, and the page count.
  static (List<Word>, int) extractWords(Uint8List pdf) {
    final doc = PdfEngine.open(pdf);
    try {
      final extractor = PdfTextExtractor(doc);
      final words = <Word>[];
      for (var i = 0; i < doc.pages.count; i++) {
        String text;
        try {
          text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        } catch (_) {
          text = '';
        }
        for (final w in text.split(RegExp(r'\s+'))) {
          if (w.isNotEmpty) words.add(Word(w, i + 1));
        }
      }
      return (words, doc.pages.count);
    } finally {
      doc.dispose();
    }
  }

  /// Edit script turning [a] into [b]: runs of equal (0), removed (-1) and
  /// added (+1) words, as (op, start in a or b, length).
  ///
  /// Myers' O(ND) algorithm. Only the diagonals reached at each step are
  /// kept, so memory grows with the square of the number of differences,
  /// not with the length of the documents.
  static List<(int, int, int)> diffWords(List<String> a, List<String> b) {
    // Common start and end cost nothing; most edits are local.
    var prefix = 0;
    while (prefix < a.length && prefix < b.length && a[prefix] == b[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < a.length - prefix &&
        suffix < b.length - prefix &&
        a[a.length - 1 - suffix] == b[b.length - 1 - suffix]) {
      suffix++;
    }
    final n = a.length - prefix - suffix;
    final m = b.length - prefix - suffix;

    final middle = <(int, int, int)>[];
    if (n == 0 && m > 0) {
      middle.add((1, prefix, m));
    } else if (m == 0 && n > 0) {
      middle.add((-1, prefix, n));
    } else if (n > 0 && m > 0) {
      middle.addAll(_myers(a, b, prefix, n, m));
    }

    return _merge([
      if (prefix > 0) (0, 0, prefix),
      ...middle,
      if (suffix > 0) (0, a.length - suffix, suffix),
    ]);
  }

  static List<(int, int, int)> _myers(List<String> a, List<String> b, int offset, int n, int m) {
    final max = n + m;
    // v[k] = furthest x on diagonal k; stored per step for [-d, d] only.
    final trace = <List<int>>[];
    var v = List<int>.filled(3, 0); // covers k in [-1, 1] for d = 0
    int at(List<int> row, int d, int k) => row[k + d];

    for (var d = 0; d <= max; d++) {
      if (d > maxDifferences) {
        throw const DocumentToolException(
          'These files are too different to compare word by word.',
        );
      }
      final next = List<int>.filled(2 * d + 3, 0);
      for (var k = -d; k <= d; k += 2) {
        final prevD = d - 1;
        int x;
        if (d == 0) {
          x = 0;
        } else if (k == -d || (k != d && at(v, prevD + 1, k - 1) < at(v, prevD + 1, k + 1))) {
          x = at(v, prevD + 1, k + 1); // down: an insertion
        } else {
          x = at(v, prevD + 1, k - 1) + 1; // right: a deletion
        }
        var y = x - k;
        while (x < n && y < m && a[offset + x] == b[offset + y]) {
          x++;
          y++;
        }
        next[k + d + 1] = x;
        if (x >= n && y >= m) {
          trace.add(next);
          return _backtrack(trace, n, m, offset);
        }
      }
      trace.add(next);
      v = next;
    }
    throw StateError('unreachable');
  }

  /// Rebuilds the edit script from the stored diagonals (row d holds
  /// k in [-d-1, d+1] at index k + d + 1).
  static List<(int, int, int)> _backtrack(List<List<int>> trace, int n, int m, int offset) {
    int at(int d, int k) => trace[d][k + d + 1];
    final ops = <(int, int, int)>[];
    var x = n;
    var y = m;
    for (var d = trace.length - 1; d > 0; d--) {
      final k = x - y;
      final down = k == -d || (k != d && at(d - 1, k - 1) < at(d - 1, k + 1));
      final prevK = down ? k + 1 : k - 1;
      final prevX = at(d - 1, prevK);
      final prevY = prevX - prevK;
      // Snake (equal words) after the edit.
      final startX = down ? prevX : prevX + 1;
      if (x > startX) ops.add((0, offset + startX, x - startX));
      ops.add(down ? (1, offset + prevY, 1) : (-1, offset + prevX, 1));
      x = prevX;
      y = prevY;
    }
    if (x > 0) ops.add((0, offset, x));
    return ops.reversed.toList();
  }

  /// Joins neighbouring runs of the same kind.
  static List<(int, int, int)> _merge(List<(int, int, int)> ops) {
    final out = <(int, int, int)>[];
    for (final op in ops) {
      if (out.isNotEmpty && out.last.$1 == op.$1 && out.last.$2 + out.last.$3 == op.$2) {
        final last = out.removeLast();
        out.add((last.$1, last.$2, last.$3 + op.$3));
      } else {
        out.add(op);
      }
    }
    return out;
  }

  static List<TextChange> _changes(List<(int, int, int)> ops, List<Word> a, List<Word> b) {
    String join(List<Word> words, int start, int length) =>
        words.sublist(start, start + length).map((w) => w.text).join(' ');

    final changes = <TextChange>[];
    var ai = 0; // position in a
    var bi = 0; // position in b
    var i = 0;
    while (i < ops.length) {
      final (op, _, len) = ops[i];
      if (op == 0) {
        ai += len;
        bi += len;
        i++;
        continue;
      }
      // A change is a run of removals and/or additions between equal runs.
      var removed = 0;
      var added = 0;
      while (i < ops.length && ops[i].$1 != 0) {
        if (ops[i].$1 < 0) {
          removed += ops[i].$3;
        } else {
          added += ops[i].$3;
        }
        i++;
      }
      final beforeStart = (ai - _context).clamp(0, ai);
      final afterLen = ((a.length - (ai + removed)).clamp(0, _context)).toInt();
      changes.add(
        TextChange(
          kind: removed > 0 && added > 0
              ? ChangeKind.replaced
              : (removed > 0 ? ChangeKind.removed : ChangeKind.added),
          before: join(a, beforeStart, ai - beforeStart),
          removed: join(a, ai, removed),
          added: join(b, bi, added),
          after: join(a, ai + removed, afterLen),
          oldPage: a.isEmpty ? 1 : a[(ai < a.length ? ai : a.length - 1)].page,
          newPage: b.isEmpty ? 1 : b[(bi < b.length ? bi : b.length - 1)].page,
        ),
      );
      ai += removed;
      bi += added;
    }
    return changes;
  }
}
