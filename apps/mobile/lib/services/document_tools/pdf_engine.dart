/// Pure PDF operations used by the document tools.
///
/// Everything here is synchronous and free of Flutter plugins so it can run
/// in a background isolate (see `DocumentToolsService`) and in unit tests.
/// Inputs and outputs are raw bytes; page numbers are 0-based indices.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'page_ranges.dart';

/// A failure the user can act on (wrong password, damaged file, bad input).
class DocumentToolException implements Exception {
  final String message;
  const DocumentToolException(this.message);

  @override
  String toString() => message;
}

/// One page of an output document: which input file and page it comes from,
/// and how many degrees (clockwise, multiple of 90) to turn it.
class PageRef {
  final int source;
  final int page;
  final int rotation;

  /// Scale the page onto A4 inside the [PageFit] margins (see
  /// [PdfEngine.composePages]).
  final bool fit;
  const PageRef(this.source, this.page, {this.rotation = 0, this.fit = false});
}

/// Blank space kept around page content, in points, as the reader sees the
/// page (so "left" stays the binding edge however the page is rotated).
class PageFit {
  final double left;
  final double top;
  final double right;
  final double bottom;
  const PageFit({this.left = 0, this.top = 0, this.right = 0, this.bottom = 0});

  static const none = PageFit();

  /// Centimetres to points.
  static double cm(double value) => value * 72 / 2.54;
}

enum NumberPosition { bottomCenter, bottomRight, topRight }

enum PageNumberStyle { plain, pageN, pageNofTotal, dashed }

class PageNumberOptions {
  final NumberPosition position;
  final PageNumberStyle style;

  /// The number printed on the first numbered page.
  final int startAt;

  /// Leading pages left unnumbered (e.g. a cover or index page).
  final int skipFirst;
  final double fontSize;

  const PageNumberOptions({
    this.position = NumberPosition.bottomCenter,
    this.style = PageNumberStyle.plain,
    this.startAt = 1,
    this.skipFirst = 0,
    this.fontSize = 12,
  });

  String label(int number, int total) => switch (style) {
    PageNumberStyle.plain => '$number',
    PageNumberStyle.pageN => 'Page $number',
    PageNumberStyle.pageNofTotal => 'Page $number of $total',
    PageNumberStyle.dashed => '- $number -',
  };
}

enum PageSizeOption { a4, fitImage }

class ImagesToPdfOptions {
  final PageSizeOption pageSize;

  /// White space around each image, in points (72 per inch).
  final double margin;

  const ImagesToPdfOptions({this.pageSize = PageSizeOption.a4, this.margin = 0});
}

/// A4 in points.
const Size a4Size = Size(595.28, 841.89);

class PdfEngine {
  PdfEngine._();

  static int pageCount(Uint8List pdf) {
    final doc = open(pdf);
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }

  /// Builds one document from pages of [sources], in the order of [pages].
  ///
  /// When the pages come from a single file and keep their order (only
  /// deletions and rotations), the file is edited in place so links, form
  /// fields, bookmarks and annotations survive. Otherwise each page is copied
  /// as a template, which keeps text and images (still searchable) but drops
  /// interactive elements.
  ///
  /// Pages marked [PageRef.fit] are scaled (up or down, keeping proportions)
  /// onto an A4 sheet of the same orientation, inside [fit]'s margins.
  static Uint8List composePages(
    List<Uint8List> sources,
    List<PageRef> pages, {
    PageFit fit = PageFit.none,
  }) {
    if (pages.isEmpty) {
      throw const DocumentToolException('Keep at least one page');
    }
    final inPlace = pages.every((p) => p.source == pages.first.source && !p.fit) &&
        _isIncreasing(pages.map((p) => p.page).toList());
    return inPlace
        ? _editInPlace(sources[pages.first.source], pages)
        : _copyPages(sources, pages, fit);
  }

  /// All pages of every file in [pdfs], one after another.
  static Uint8List merge(List<Uint8List> pdfs) {
    if (pdfs.length < 2) {
      throw const DocumentToolException('Choose at least two PDFs to merge');
    }
    final refs = <PageRef>[];
    for (var s = 0; s < pdfs.length; s++) {
      final count = pageCount(pdfs[s]);
      for (var p = 0; p < count; p++) {
        refs.add(PageRef(s, p));
      }
    }
    return _copyPages(pdfs, refs, PageFit.none);
  }

  /// One output file per range.
  static List<Uint8List> split(Uint8List pdf, List<PageRange> ranges) => [
    for (final r in ranges)
      composePages([pdf], [for (final i in r.indices) PageRef(0, i)]),
  ];

  /// Turns every page by [degrees] (clockwise, multiple of 90).
  static Uint8List rotateAll(Uint8List pdf, int degrees) {
    final count = pageCount(pdf);
    return _editInPlace(pdf, [
      for (var i = 0; i < count; i++) PageRef(0, i, rotation: degrees),
    ]);
  }

  /// Stamps page numbers, drawn upright however each page is rotated.
  static Uint8List addPageNumbers(Uint8List pdf, PageNumberOptions options) {
    final doc = open(pdf);
    try {
      final count = doc.pages.count;
      final numbered = count - options.skipFirst;
      if (numbered <= 0) {
        throw const DocumentToolException(
          'Every page would be skipped; lower "Skip first pages"',
        );
      }
      final total = options.startAt + numbered - 1;
      final font = PdfStandardFont(PdfFontFamily.timesRoman, options.fontSize);
      const edge = 36.0; // half an inch from the page edge

      for (var i = options.skipFirst; i < count; i++) {
        final page = doc.pages[i];
        final text = options.label(options.startAt + i - options.skipFirst, total);
        final textSize = font.measureString(text);
        final angle = _degrees(page.rotation);
        final raw = page.size;
        final visual = angle % 180 == 0 ? raw : Size(raw.height, raw.width);

        final x = switch (options.position) {
          NumberPosition.bottomCenter => (visual.width - textSize.width) / 2,
          NumberPosition.bottomRight ||
          NumberPosition.topRight => visual.width - edge - textSize.width,
        };
        final y = options.position == NumberPosition.topRight
            ? edge - textSize.height
            : visual.height - edge;

        final g = page.graphics;
        final state = g.save();
        _alignWithDisplay(g, angle, raw);
        g.drawString(
          text,
          font,
          brush: PdfSolidBrush(PdfColor(0, 0, 0)),
          bounds: Rect.fromLTWH(x, y, textSize.width + 1, textSize.height),
        );
        g.restore(state);
      }
      return _save(doc, incremental: true);
    } finally {
      doc.dispose();
    }
  }

  /// One page per image. [images] must be JPEG or PNG (see `ImagePrep`).
  static Uint8List imagesToPdf(List<Uint8List> images, ImagesToPdfOptions options) {
    if (images.isEmpty) {
      throw const DocumentToolException('Add at least one image');
    }
    final doc = PdfDocument();
    try {
      PdfSection? section;
      Size? sectionSize;
      for (final bytes in images) {
        final PdfBitmap bitmap;
        try {
          bitmap = PdfBitmap(bytes);
        } catch (_) {
          throw const DocumentToolException('One of the images could not be read');
        }
        final landscape = bitmap.width > bitmap.height;
        final Size pageSize;
        if (options.pageSize == PageSizeOption.a4) {
          pageSize = landscape ? Size(a4Size.height, a4Size.width) : a4Size;
        } else {
          // Treat the image as 150 DPI so a phone photo lands near A4 size.
          const scale = 72 / 150;
          pageSize = Size(
            bitmap.width * scale + options.margin * 2,
            bitmap.height * scale + options.margin * 2,
          );
        }
        if (section == null || sectionSize != pageSize) {
          section = _newSection(doc, pageSize);
          sectionSize = pageSize;
        }
        final page = section.pages.add();
        final box = Rect.fromLTWH(
          options.margin,
          options.margin,
          pageSize.width - options.margin * 2,
          pageSize.height - options.margin * 2,
        );
        page.graphics.drawImage(
          bitmap,
          _fit(Size(bitmap.width.toDouble(), bitmap.height.toDouble()), box),
        );
      }
      return _save(doc);
    } finally {
      doc.dispose();
    }
  }

  // ── Implementation ───────────────────────────────────────────────

  /// Loads [bytes], turning Syncfusion's errors into messages for the user.
  /// The caller must dispose the document.
  static PdfDocument open(Uint8List bytes) {
    try {
      return PdfDocument(inputBytes: bytes);
    } on ArgumentError catch (e) {
      final message = '${e.message}'.toLowerCase();
      if (e.name == 'password' || message.contains('password')) {
        throw const DocumentToolException(
          'This PDF is password-protected. Unlock it first, then try again.',
        );
      }
      throw const DocumentToolException(
        'This PDF could not be read. It may be damaged or not a real PDF.',
      );
    } catch (_) {
      throw const DocumentToolException(
        'This PDF could not be read. It may be damaged or not a real PDF.',
      );
    }
  }

  static Uint8List _editInPlace(Uint8List pdf, List<PageRef> pages) {
    final doc = open(pdf);
    try {
      final keep = {for (final p in pages) p.page: p.rotation};
      for (final p in pages) {
        if (p.page >= doc.pages.count) {
          throw const DocumentToolException('A selected page does not exist');
        }
      }
      for (var i = doc.pages.count - 1; i >= 0; i--) {
        if (!keep.containsKey(i)) doc.pages.removeAt(i);
      }
      var i = 0;
      for (final p in pages) {
        final page = doc.pages[i++];
        if (p.rotation % 360 != 0) {
          page.rotation = _angle(_degrees(page.rotation) + p.rotation);
        }
      }
      // A full rewrite, so pages that were removed do not stay in the file.
      return _save(doc, incremental: false);
    } finally {
      doc.dispose();
    }
  }

  static Uint8List _copyPages(List<Uint8List> sources, List<PageRef> pages, PageFit fit) {
    final opened = <int, PdfDocument>{};
    final out = PdfDocument();
    final rotations = <int>[];
    try {
      PdfSection? section;
      Size? sectionSize;
      for (final ref in pages) {
        final src = opened[ref.source] ??= open(sources[ref.source]);
        if (ref.page >= src.pages.count) {
          throw const DocumentToolException('A selected page does not exist');
        }
        final page = src.pages[ref.page];
        final template = page.createTemplate();
        final angle = _degrees(page.rotation);
        final size = ref.fit
            ? (template.size.width > template.size.height
                ? Size(a4Size.height, a4Size.width)
                : a4Size)
            : template.size;
        if (section == null || sectionSize != size) {
          section = _newSection(out, size);
          sectionSize = size;
        }
        final box = ref.fit
            ? _unrotatedBox(size, fit, angle)
            : Rect.fromLTWH(0, 0, size.width, size.height);
        final placed = ref.fit ? _fit(template.size, box) : box;
        section.pages.add().graphics.drawPdfTemplate(template, placed.topLeft, placed.size);
        rotations.add(angle + ref.rotation);
      }
      final copied = _save(out);
      if (rotations.every((r) => r % 360 == 0)) return copied;

      // New pages cannot carry /Rotate while being drawn, so set it on a
      // reloaded copy; the page content stays untouched.
      final reloaded = PdfDocument(inputBytes: copied);
      try {
        for (var i = 0; i < rotations.length; i++) {
          reloaded.pages[i].rotation = _angle(rotations[i]);
        }
        return _save(reloaded, incremental: false);
      } finally {
        reloaded.dispose();
      }
    } finally {
      for (final doc in opened.values) {
        doc.dispose();
      }
      out.dispose();
    }
  }

  static PdfSection _newSection(PdfDocument doc, Size size) {
    final section = doc.sections!.add();
    final settings = section.pageSettings;
    settings.margins.all = 0;
    // Orientation first: the size setter otherwise forces portrait.
    settings.orientation = size.width > size.height
        ? PdfPageOrientation.landscape
        : PdfPageOrientation.portrait;
    settings.size = size;
    return section;
  }

  /// Makes drawing coordinates match what the reader sees on a page shown
  /// turned by [angle] degrees. Mirrors what Syncfusion does for new pages.
  static void _alignWithDisplay(PdfGraphics g, int angle, Size raw) {
    switch (angle) {
      case 90:
        g.translateTransform(0, raw.height);
        g.rotateTransform(-90);
      case 180:
        g.translateTransform(raw.width, raw.height);
        g.rotateTransform(-180);
      case 270:
        g.translateTransform(raw.width, 0);
        g.rotateTransform(-270);
    }
  }

  /// The margin box of an unrotated [page] whose reader sees it turned by
  /// [angle]: the visual left margin sits on a different raw edge per angle.
  static Rect _unrotatedBox(Size page, PageFit m, int angle) {
    final (l, t, r, b) = switch (angle) {
      90 => (m.top, m.right, m.bottom, m.left),
      180 => (m.right, m.bottom, m.left, m.top),
      270 => (m.bottom, m.left, m.top, m.right),
      _ => (m.left, m.top, m.right, m.bottom),
    };
    return Rect.fromLTRB(l, t, page.width - r, page.height - b);
  }

  static Rect _fit(Size content, Rect box) {
    final scale = math.min(box.width / content.width, box.height / content.height);
    final w = content.width * scale;
    final h = content.height * scale;
    return Rect.fromLTWH(
      box.left + (box.width - w) / 2,
      box.top + (box.height - h) / 2,
      w,
      h,
    );
  }

  static bool _isIncreasing(List<int> values) {
    for (var i = 1; i < values.length; i++) {
      if (values[i] <= values[i - 1]) return false;
    }
    return true;
  }

  static int _degrees(PdfPageRotateAngle angle) => switch (angle) {
    PdfPageRotateAngle.rotateAngle0 => 0,
    PdfPageRotateAngle.rotateAngle90 => 90,
    PdfPageRotateAngle.rotateAngle180 => 180,
    PdfPageRotateAngle.rotateAngle270 => 270,
  };

  static PdfPageRotateAngle _angle(int degrees) => switch (degrees % 360) {
    90 => PdfPageRotateAngle.rotateAngle90,
    180 => PdfPageRotateAngle.rotateAngle180,
    270 => PdfPageRotateAngle.rotateAngle270,
    _ => PdfPageRotateAngle.rotateAngle0,
  };

  static Uint8List _save(PdfDocument doc, {bool incremental = true}) {
    doc.fileStructure.incrementalUpdate = incremental;
    return Uint8List.fromList(doc.saveSync());
  }
}
