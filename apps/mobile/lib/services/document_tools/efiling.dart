/// "Prepare for e-Filing": turns a set of documents (petition, vakalat,
/// annexures...) into court-ready PDFs following a court's rules, and
/// reports anything the court is likely to reject.
///
/// Pure Dart like [PdfEngine]; run it through `DocumentToolsService`.
library;

import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_engine.dart';

/// A court's formatting rules.
class CourtPreset {
  final String id;
  final String name;
  final String description;
  final PageFit margins;
  final NumberPosition numberPosition;

  /// Largest file the portal is expected to accept, in megabytes.
  final int maxFileMb;

  /// Filings longer than this should carry bookmarks.
  final int bookmarkAfterPages;

  const CourtPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.margins,
    required this.numberPosition,
    required this.maxFileMb,
    required this.bookmarkAfterPages,
  });

  static final tamilNaduDistrict = CourtPreset(
    id: 'tn_district',
    name: 'Tamil Nadu District Courts',
    description:
        'eCourts eFiling 3.0 · A4 · margins 3.5 cm left, 2.5 cm others · '
        'page numbers bottom centre',
    margins: PageFit(
      left: PageFit.cm(3.5),
      top: PageFit.cm(2.5),
      right: PageFit.cm(2.5),
      bottom: PageFit.cm(2.5),
    ),
    numberPosition: NumberPosition.bottomCenter,
    maxFileMb: 20,
    bookmarkAfterPages: 20,
  );

  static final all = [tamilNaduDistrict];
}

/// One document in the filing, in filing order.
class FilingPart {
  final String title;
  final Uint8List pdf;
  const FilingPart(this.title, this.pdf);
}

class FilingOptions {
  final CourtPreset preset;

  /// Put every page on A4 (keeping its orientation).
  final bool fitToA4;

  /// Also shrink pages so the court margins are blank. Needed when the
  /// content runs to the edge; unneeded for pleadings typed with margins.
  final bool addMargins;
  final bool pageNumbers;
  final bool indexPage;
  final bool bookmarks;
  final int maxFileMb;

  /// Shown at the top of the index page, e.g. the cause title.
  final String? heading;
  final String? subheading;

  const FilingOptions({
    required this.preset,
    this.fitToA4 = true,
    this.addMargins = false,
    this.pageNumbers = true,
    this.indexPage = true,
    this.bookmarks = true,
    required this.maxFileMb,
    this.heading,
    this.subheading,
  });
}

/// A row of the portal's "Indexing" form for one uploaded file.
class IndexEntry {
  final String title;

  /// 1-based pages within that file.
  final int from;
  final int to;
  const IndexEntry(this.title, this.from, this.to);

  String get pages => from == to ? '$from' : '$from-$to';
}

class FilingFile {
  final Uint8List pdf;
  final int pageCount;
  final List<IndexEntry> index;
  const FilingFile(this.pdf, this.pageCount, this.index);
}

enum CheckLevel { ok, warning, problem, info }

class FilingCheck {
  final CheckLevel level;
  final String title;
  final String detail;
  const FilingCheck(this.level, this.title, this.detail);
}

class FilingResult {
  final List<FilingFile> files;
  final List<FilingCheck> checks;

  /// Indexes of the documents (in filing order) that have scanned pages
  /// without searchable text: the ones to OCR before rebuilding. OCR must
  /// run on the documents, not the finished filing, whose page numbers
  /// would make every page look like it already has text.
  final List<int> documentsWithoutText;
  const FilingResult(this.files, this.checks, [this.documentsWithoutText = const []]);

  int get totalPages => files.fold(0, (sum, f) => sum + f.pageCount);
}

class EFilingBuilder {
  EFilingBuilder._();

  static FilingResult build(List<FilingPart> parts, FilingOptions options) {
    if (parts.isEmpty) {
      throw const DocumentToolException('Add at least one document');
    }
    final counts = [for (final p in parts) PdfEngine.pageCount(p.pdf)];
    final signed = [
      for (var i = 0; i < parts.length; i++)
        if (hasDigitalSignature(parts[i].pdf)) parts[i].title,
    ];

    // 1. Index page(s): rendering them decides how many pages they take,
    //    which shifts every later page number, so render until stable.
    Uint8List? index;
    var indexPages = 0;
    if (options.indexPage) {
      for (var attempt = 0; attempt < 3; attempt++) {
        index = _renderIndex(parts, counts, indexPages, options);
        final rendered = PdfEngine.pageCount(index);
        if (rendered == indexPages) break;
        indexPages = rendered;
      }
    }

    // 2. One document: index, then every part, fitted to A4 if asked.
    final sources = [if (index != null) index, for (final p in parts) p.pdf];
    final offset = index == null ? 0 : 1;
    final refs = <PageRef>[
      for (var i = 0; i < indexPages; i++) PageRef(0, i),
      for (var s = 0; s < parts.length; s++)
        for (var p = 0; p < counts[s]; p++)
          PageRef(s + offset, p, fit: options.fitToA4),
    ];
    final fit = options.addMargins ? options.preset.margins : PageFit.none;
    // A lone document with nothing to add is edited in place, keeping links.
    var combined = PdfEngine.composePages(sources, refs, fit: fit);

    // Checked before numbering, which would add text to every page.
    final report = _inspect(combined);
    final textless = [
      for (final i in report.textlessPages)
        if (i >= indexPages) i + 1,
    ];
    final documentsWithoutText = <int>[];
    var first = indexPages + 1;
    for (var i = 0; i < parts.length; i++) {
      final last = first + counts[i] - 1;
      if (textless.any((p) => p >= first && p <= last)) documentsWithoutText.add(i);
      first = last + 1;
    }

    // 3. Page numbers on every page, index included, so printed numbers
    //    match the page numbers the portal's indexing form asks for.
    if (options.pageNumbers) {
      combined = PdfEngine.addPageNumbers(
        combined,
        PageNumberOptions(position: options.preset.numberPosition),
      );
    }

    // 4. Where each document starts and ends.
    final starts = <IndexEntry>[
      if (indexPages > 0) IndexEntry('Index', 1, indexPages),
    ];
    var next = indexPages + 1;
    for (var i = 0; i < parts.length; i++) {
      starts.add(IndexEntry(parts[i].title, next, next + counts[i] - 1));
      next += counts[i];
    }
    final totalPages = next - 1;

    // 5. Keep each file under the size limit; add bookmarks per file.
    final limit = options.maxFileMb * 1024 * 1024;
    final ranges = combined.length <= limit
        ? [(0, totalPages - 1)]
        : _rangesUnder(combined, totalPages, limit);
    final files = <FilingFile>[];
    for (final (first, last) in ranges) {
      final pdf = ranges.length == 1
          ? combined
          : PdfEngine.composePages([combined], [
              for (var p = first; p <= last; p++) PageRef(0, p),
            ]);
      final index = _indexForRange(starts, first + 1, last + 1);
      final withMarks = options.bookmarks ? _setBookmarks(pdf, index) : pdf;
      files.add(FilingFile(withMarks, last - first + 1, index));
    }

    return FilingResult(
      files,
      _checks(options, files, report, textless, signed, totalPages),
      documentsWithoutText,
    );
  }

  // ── Index page ───────────────────────────────────────────────────

  static Uint8List _renderIndex(
    List<FilingPart> parts,
    List<int> counts,
    int indexPages,
    FilingOptions options,
  ) {
    final doc = PdfDocument();
    try {
      final section = doc.sections!.add();
      final m = options.preset.margins;
      section.pageSettings
        ..orientation = PdfPageOrientation.portrait
        ..size = a4Size
        ..margins.left = m.left
        ..margins.top = m.top
        ..margins.right = m.right
        ..margins.bottom = m.bottom;
      final page = section.pages.add();
      final width = page.getClientSize().width;
      final bold = PdfStandardFont(PdfFontFamily.timesRoman, 16, style: PdfFontStyle.bold);
      final body = PdfStandardFont(PdfFontFamily.timesRoman, 14);
      final centred = PdfStringFormat(alignment: PdfTextAlignment.center);

      var y = 0.0;
      void line(String text, PdfFont font) {
        page.graphics.drawString(
          text,
          font,
          bounds: Rect.fromLTWH(0, y, width, 0),
          format: centred,
        );
        y += font.measureString(text, layoutArea: Size(width, 0)).height + 6;
      }

      if (options.heading case final h? when h.trim().isNotEmpty) line(h.trim(), body);
      if (options.subheading case final s? when s.trim().isNotEmpty) line(s.trim(), body);
      if (y > 0) y += 8;
      line('INDEX', bold);
      y += 6;

      final grid = PdfGrid();
      grid.columns.add(count: 3);
      grid.columns[0].width = 56;
      grid.columns[2].width = 90;
      grid.style = PdfGridStyle(
        font: body,
        cellPadding: PdfPaddings(left: 6, right: 6, top: 5, bottom: 5),
      );
      final header = grid.headers.add(1).first;
      header.cells[0].value = 'Sl. No.';
      header.cells[1].value = 'Particulars';
      header.cells[2].value = 'Page No.';
      header.style = PdfGridRowStyle(
        font: PdfStandardFont(PdfFontFamily.timesRoman, 14, style: PdfFontStyle.bold),
      );
      var next = indexPages + 1;
      for (var i = 0; i < parts.length; i++) {
        final row = grid.rows.add();
        final last = next + counts[i] - 1;
        row.cells[0].value = '${i + 1}';
        row.cells[1].value = parts[i].title;
        row.cells[2].value = next == last ? '$next' : '$next - $last';
        next = last + 1;
      }
      for (final row in [header, for (var i = 0; i < grid.rows.count; i++) grid.rows[i]]) {
        row.cells[0].stringFormat = centred;
        row.cells[2].stringFormat = centred;
      }
      grid.draw(page: page, bounds: Rect.fromLTWH(0, y, width, 0));
      return Uint8List.fromList(doc.saveSync());
    } finally {
      doc.dispose();
    }
  }

  // ── Splitting and bookmarks ──────────────────────────────────────

  /// Page ranges (0-based, inclusive) whose files each stay under [limit]
  /// bytes. Scanned pages weigh far more than typed ones, so each file is
  /// packed greedily: a binary search finds the most pages that still fit.
  static List<(int, int)> _rangesUnder(Uint8List pdf, int pages, int limit) {
    bool fits(int first, int last) =>
        PdfEngine.composePages([pdf], [
          for (var p = first; p <= last; p++) PageRef(0, p),
        ]).length <=
        limit;

    final ranges = <(int, int)>[];
    var start = 0;
    while (start < pages) {
      if (start > 0 && fits(start, pages - 1)) {
        ranges.add((start, pages - 1));
        break;
      }
      // A single page over the limit still gets its own file; the checks
      // report it.
      var lo = start;
      var hi = pages - 1;
      if (!fits(start, start)) {
        hi = start;
      }
      while (hi - lo > 1) {
        final mid = (lo + hi) ~/ 2;
        if (fits(start, mid)) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      if (hi != lo && fits(start, hi)) lo = hi;
      ranges.add((start, lo));
      start = lo + 1;
    }
    return ranges;
  }

  /// The documents that appear in pages [first]..[last] (1-based, of the
  /// whole filing), numbered within that file.
  static List<IndexEntry> _indexForRange(List<IndexEntry> all, int first, int last) => [
    for (final e in all)
      if (e.to >= first && e.from <= last)
        IndexEntry(
          e.from < first ? '${e.title} (contd.)' : e.title,
          (e.from < first ? first : e.from) - first + 1,
          (e.to > last ? last : e.to) - first + 1,
        ),
  ];

  static Uint8List _setBookmarks(Uint8List pdf, List<IndexEntry> index) {
    final doc = PdfDocument(inputBytes: pdf);
    try {
      doc.bookmarks.clear();
      for (final e in index) {
        // Set through the setter: add(destination:) silently ignores it.
        doc.bookmarks.add(e.title).destination = PdfDestination(doc.pages[e.from - 1]);
      }
      doc.fileStructure.incrementalUpdate = false;
      return Uint8List.fromList(doc.saveSync());
    } finally {
      doc.dispose();
    }
  }

  // ── Checks ───────────────────────────────────────────────────────

  static _Report _inspect(Uint8List pdf) {
    final doc = PdfDocument(inputBytes: pdf);
    try {
      final extractor = PdfTextExtractor(doc);
      final textless = <int>[];
      final notA4 = <int>[];
      for (var i = 0; i < doc.pages.count; i++) {
        String text;
        try {
          text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        } catch (_) {
          text = '';
        }
        if (text.trim().length < 3) textless.add(i);
        final s = doc.pages[i].size;
        final shortSide = s.width < s.height ? s.width : s.height;
        final longSide = s.width < s.height ? s.height : s.width;
        if ((shortSide - a4Size.width).abs() > 3 || (longSide - a4Size.height).abs() > 3) {
          notA4.add(i);
        }
      }
      return _Report(textless, notA4);
    } finally {
      doc.dispose();
    }
  }

  /// Whether [pdf] looks digitally signed: signature dictionaries carry a
  /// /ByteRange entry.
  static bool hasDigitalSignature(Uint8List pdf) {
    const needle = '/ByteRange';
    final codes = needle.codeUnits;
    outer:
    for (var i = 0; i <= pdf.length - codes.length; i++) {
      for (var j = 0; j < codes.length; j++) {
        if (pdf[i + j] != codes[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  static List<FilingCheck> _checks(
    FilingOptions options,
    List<FilingFile> files,
    _Report report,
    List<int> textless,
    List<String> signed,
    int totalPages,
  ) {
    final limitMb = options.maxFileMb;
    final biggest = files.map((f) => f.pdf.length).reduce((a, b) => a > b ? a : b);
    String mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

    return [
      if (report.notA4.isEmpty)
        const FilingCheck(CheckLevel.ok, 'All pages are A4', 'Every page is A4 size.')
      else
        FilingCheck(
          CheckLevel.problem,
          '${report.notA4.length} page${report.notA4.length == 1 ? ' is' : 's are'} not A4',
          'Pages ${_list(report.notA4.map((i) => i + 1))}. Turn on "Fit pages to A4".',
        ),
      if (biggest <= limitMb * 1024 * 1024)
        FilingCheck(
          CheckLevel.ok,
          files.length == 1
              ? 'Size ${mb(biggest)} MB (limit $limitMb MB)'
              : 'Split into ${files.length} files under $limitMb MB',
          files.length == 1
              ? 'Within the upload limit.'
              : 'Upload them in order; each has its own index below.',
        )
      else
        FilingCheck(
          CheckLevel.problem,
          'A page is too large for $limitMb MB',
          'Even a single page is over the limit. Rescan at 200 DPI in black & white.',
        ),
      if (textless.isEmpty)
        const FilingCheck(
          CheckLevel.ok,
          'Text is searchable',
          'Every document page has selectable text.',
        )
      else
        FilingCheck(
          CheckLevel.warning,
          '${textless.length} scanned page${textless.length == 1 ? '' : 's'} without searchable text',
          'Pages ${_list(textless)}. Courts prefer searchable (OCR) scans.',
        ),
      if (options.pageNumbers)
        const FilingCheck(CheckLevel.ok, 'Pages numbered', 'Bottom centre, matching the index.')
      else
        const FilingCheck(
          CheckLevel.warning,
          'No page numbers',
          'Courts expect every page numbered; turn on "Page numbers".',
        ),
      if (options.bookmarks)
        const FilingCheck(CheckLevel.ok, 'Bookmarked', 'Each document is a bookmark for quick navigation.')
      else if (totalPages > options.preset.bookmarkAfterPages)
        FilingCheck(
          CheckLevel.warning,
          'No bookmarks',
          'Filings over ${options.preset.bookmarkAfterPages} pages should be bookmarked.',
        ),
      if (signed.isNotEmpty)
        FilingCheck(
          CheckLevel.warning,
          'Digital signature removed',
          '${signed.join(', ')} ${signed.length == 1 ? 'was' : 'were'} digitally signed. '
              'Combining documents breaks a signature; sign the prepared file instead.',
        ),
      if (!options.addMargins)
        const FilingCheck(
          CheckLevel.info,
          'Margins not added',
          'Pleadings typed with a 3.5 cm left margin need nothing more. If text runs '
              'to the edge (scans, photos), turn on "Add court margins".',
        ),
      const FilingCheck(
        CheckLevel.info,
        'Sign on the portal',
        'eSign (Aadhaar OTP) or DSC after uploading. Signed files cannot be merged, so prepare first.',
      ),
    ];
  }

  static String _list(Iterable<int> pages) {
    final list = pages.toList();
    final shown = list.take(12).join(', ');
    return list.length > 12 ? '$shown and ${list.length - 12} more' : shown;
  }
}

class _Report {
  final List<int> textlessPages;
  final List<int> notA4;
  const _Report(this.textlessPages, this.notA4);
}
