/// Drawing on existing PDF pages: signatures, seals, text, whiteout,
/// highlights and boxes (Sign and Edit), and watermarks.
///
/// Positions are fractions (0..1) of the page *as the reader sees it*, so a
/// signature placed on a sideways-rotated page lands where it was placed on
/// screen. Pure Dart; run through `DocumentToolsService`.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_engine.dart';

enum OverlayKind { image, text, whiteout, highlight, box }

/// One thing drawn on one page.
class PageOverlay {
  final int page;

  /// Left, top, width, height as fractions of the visual page.
  final Rect box;
  final OverlayKind kind;

  /// PNG or JPEG, for [OverlayKind.image].
  final Uint8List? image;

  /// For [OverlayKind.text]: must be [isStandardFontText]. Other scripts
  /// (Tamil, Hindi) are drawn by the app as an image overlay instead.
  final String text;

  /// Points, as printed.
  final double fontSize;
  final bool bold;

  /// 0xAARRGGBB, for text, highlight and box.
  final int color;

  const PageOverlay({
    required this.page,
    required this.box,
    required this.kind,
    this.image,
    this.text = '',
    this.fontSize = 12,
    this.bold = false,
    this.color = 0xFF000000,
  });
}

/// Whether the PDF's built-in fonts can draw [text] (Latin-1 only). Those
/// keep text real and searchable; anything else must be drawn as an image.
bool isStandardFontText(String text) => text.codeUnits.every((c) => c < 256);

class WatermarkOptions {
  /// Drawn with a built-in font; must be [isStandardFontText].
  final String text;

  /// Used instead of [text] when set (a rendered Tamil/Hindi text, a seal).
  final Uint8List? image;

  /// Width of an [image] watermark as a fraction of the page width.
  final double imageWidth;
  final double fontSize;
  final int color;
  final double opacity;

  /// Corner to corner, rising left to right; otherwise horizontal.
  final bool diagonal;

  /// 0-based pages to mark; null for every page.
  final Set<int>? pages;

  const WatermarkOptions({
    this.text = '',
    this.image,
    this.imageWidth = 0.5,
    this.fontSize = 60,
    this.color = 0xFF9CA3AF,
    this.opacity = 0.3,
    this.diagonal = true,
    this.pages,
  });
}

class PdfOverlays {
  PdfOverlays._();

  /// Each page's size as the reader sees it (rotation applied), in points.
  static List<Size> visualPageSizes(Uint8List pdf) {
    final doc = _load(pdf);
    try {
      return [
        for (var i = 0; i < doc.pages.count; i++)
          _visual(doc.pages[i].size, _degrees(doc.pages[i].rotation)),
      ];
    } finally {
      doc.dispose();
    }
  }

  static Uint8List apply(Uint8List pdf, List<PageOverlay> overlays) {
    if (overlays.isEmpty) {
      throw const DocumentToolException('Add something to the page first');
    }
    final doc = _load(pdf);
    try {
      for (final o in overlays) {
        if (o.page < 0 || o.page >= doc.pages.count) {
          throw const DocumentToolException('A mark is on a page that does not exist');
        }
        final page = doc.pages[o.page];
        _onPage(page, (g, size) => _draw(g, o, size));
      }
      return _save(doc);
    } finally {
      doc.dispose();
    }
  }

  static Uint8List watermark(Uint8List pdf, WatermarkOptions options) {
    if (options.image == null && options.text.trim().isEmpty) {
      throw const DocumentToolException('Enter the watermark text');
    }
    if (options.image == null && !isStandardFontText(options.text)) {
      throw const DocumentToolException('This text needs to be drawn as an image');
    }
    final doc = _load(pdf);
    try {
      final PdfBitmap? bitmap = options.image == null ? null : PdfBitmap(options.image!);
      final font = PdfStandardFont(
        PdfFontFamily.helvetica,
        options.fontSize,
        style: PdfFontStyle.bold,
      );
      for (var i = 0; i < doc.pages.count; i++) {
        if (options.pages != null && !options.pages!.contains(i)) continue;
        _onPage(doc.pages[i], (g, size) {
          g.setTransparency(options.opacity);
          g.translateTransform(size.width / 2, size.height / 2);
          if (options.diagonal) {
            g.rotateTransform(-math.atan2(size.height, size.width) * 180 / math.pi);
          }
          if (bitmap != null) {
            final w = size.width * options.imageWidth;
            final h = w * bitmap.height / bitmap.width;
            g.drawImage(bitmap, Rect.fromLTWH(-w / 2, -h / 2, w, h));
          } else {
            final text = options.text.trim();
            final measured = font.measureString(text);
            g.drawString(
              text,
              font,
              brush: PdfSolidBrush(_color(options.color)),
              bounds: Rect.fromLTWH(
                -measured.width / 2,
                -measured.height / 2,
                measured.width + 1,
                measured.height,
              ),
            );
          }
        });
      }
      return _save(doc);
    } finally {
      doc.dispose();
    }
  }

  /// Replaces pages with images of themselves (JPEG/PNG, keyed by 0-based
  /// page), removing everything but the pixels: covered-up text can no
  /// longer be selected or copied. Used to make whiteout a real redaction.
  static Uint8List flattenPages(Uint8List pdf, Map<int, Uint8List> images) {
    final sizes = visualPageSizes(pdf);
    final sources = <Uint8List>[pdf];
    final refs = <PageRef>[];
    for (var i = 0; i < sizes.length; i++) {
      final image = images[i];
      if (image == null) {
        refs.add(PageRef(0, i));
        continue;
      }
      sources.add(_imagePage(image, sizes[i]));
      refs.add(PageRef(sources.length - 1, 0));
    }
    return PdfEngine.composePages(sources, refs);
  }

  static Uint8List _imagePage(Uint8List image, Size size) {
    final doc = PdfDocument();
    try {
      final section = doc.sections!.add();
      section.pageSettings
        ..margins.all = 0
        ..orientation = size.width > size.height
            ? PdfPageOrientation.landscape
            : PdfPageOrientation.portrait
        ..size = size;
      section.pages.add().graphics.drawImage(
        PdfBitmap(image),
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
      return Uint8List.fromList(doc.saveSync());
    } finally {
      doc.dispose();
    }
  }

  // ── Implementation ───────────────────────────────────────────────

  static void _draw(PdfGraphics g, PageOverlay o, Size page) {
    final r = Rect.fromLTWH(
      o.box.left * page.width,
      o.box.top * page.height,
      o.box.width * page.width,
      o.box.height * page.height,
    );
    switch (o.kind) {
      case OverlayKind.image:
        final bytes = o.image;
        if (bytes == null) return;
        final PdfBitmap bitmap;
        try {
          bitmap = PdfBitmap(bytes);
        } catch (_) {
          throw const DocumentToolException('An image could not be read');
        }
        g.drawImage(bitmap, r);
      case OverlayKind.text:
        if (o.text.trim().isEmpty) return;
        if (!isStandardFontText(o.text)) {
          throw const DocumentToolException('This text needs to be drawn as an image');
        }
        g.drawString(
          o.text,
          PdfStandardFont(
            PdfFontFamily.helvetica,
            o.fontSize,
            style: o.bold ? PdfFontStyle.bold : PdfFontStyle.regular,
          ),
          brush: PdfSolidBrush(_color(o.color)),
          // Height 0 = unlimited: if the PDF font wraps a little differently
          // from the preview, the last line still prints instead of clipping.
          bounds: Rect.fromLTWH(r.left, r.top, r.width, 0),
          format: PdfStringFormat(wordWrap: PdfWordWrapType.word),
        );
      case OverlayKind.whiteout:
        g.drawRectangle(brush: PdfSolidBrush(PdfColor(255, 255, 255)), bounds: r);
      case OverlayKind.highlight:
        final state = g.save();
        g.setTransparency(0.35);
        g.drawRectangle(brush: PdfSolidBrush(_color(o.color)), bounds: r);
        g.restore(state);
      case OverlayKind.box:
        g.drawRectangle(pen: PdfPen(_color(o.color), width: 1.5), bounds: r);
    }
  }

  /// Runs [draw] with coordinates matching what the reader sees on [page].
  static void _onPage(PdfPage page, void Function(PdfGraphics g, Size visual) draw) {
    final angle = _degrees(page.rotation);
    final raw = page.size;
    final g = page.graphics;
    final state = g.save();
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
    draw(g, _visual(raw, angle));
    g.restore(state);
  }

  static Size _visual(Size raw, int angle) =>
      angle % 180 == 0 ? raw : Size(raw.height, raw.width);

  static int _degrees(PdfPageRotateAngle angle) => angle.index * 90;

  static PdfColor _color(int argb) => PdfColor(
    (argb >> 16) & 0xFF,
    (argb >> 8) & 0xFF,
    argb & 0xFF,
    (argb >> 24) & 0xFF,
  );

  static PdfDocument _load(Uint8List pdf) => PdfEngine.open(pdf);

  static Uint8List _save(PdfDocument doc) {
    doc.fileStructure.incrementalUpdate = true;
    return Uint8List.fromList(doc.saveSync());
  }
}
