/// Runs [PdfEngine] and [ImagePrep] work off the UI thread.
///
/// On mobile each call runs in a background isolate so large files do not
/// freeze the screen; on web `compute` runs inline.
library;

import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import 'compare.dart';
import 'efiling.dart';
import 'image_prep.dart';
import 'overlays.dart';
import 'page_ranges.dart';
import 'pdf_engine.dart';

export 'compare.dart';
export 'efiling.dart';
export 'image_prep.dart';
export 'overlays.dart';
export 'page_ranges.dart';
export 'pdf_engine.dart';

class DocumentToolsService {
  DocumentToolsService._();

  static Future<int> pageCount(Uint8List pdf) => compute(PdfEngine.pageCount, pdf);

  static Future<Uint8List> merge(List<Uint8List> pdfs) => compute(PdfEngine.merge, pdfs);

  static Future<Uint8List> composePages(List<Uint8List> sources, List<PageRef> pages) =>
      compute(_compose, (sources, pages));

  /// Each page's size as seen (rotation applied), in points.
  static Future<List<Size>> visualPageSizes(Uint8List pdf) =>
      compute(PdfOverlays.visualPageSizes, pdf);

  static Future<Uint8List> applyOverlays(Uint8List pdf, List<PageOverlay> overlays) =>
      compute(_overlays, (pdf, overlays));

  static Future<Uint8List> watermark(Uint8List pdf, WatermarkOptions options) =>
      compute(_watermark, (pdf, options));

  static Future<Uint8List> rgbaToJpeg(Uint8List rgba, int width, int height, {int quality = 88}) =>
      compute(ImagePrep.rgbaToJpeg, (rgba, width, height, quality));

  static Future<Uint8List> signatureFromPhoto(Uint8List photo) =>
      compute(ImagePrep.signatureFromPhoto, photo);

  static Future<Uint8List> flattenPages(Uint8List pdf, Map<int, Uint8List> images) =>
      compute(_flatten, (pdf, images));

  static Future<Comparison> compare(Uint8List oldPdf, Uint8List newPdf) =>
      compute(_compare, (oldPdf, newPdf));

  /// Builds court-ready files from [parts] and checks them (see [EFilingBuilder]).
  static Future<FilingResult> prepareFiling(List<FilingPart> parts, FilingOptions options) =>
      compute(_prepareFiling, (parts, options));

  static Future<List<Uint8List>> split(Uint8List pdf, List<PageRange> ranges) =>
      compute(_split, (pdf, ranges));

  static Future<Uint8List> rotateAll(Uint8List pdf, int degrees) =>
      compute(_rotateAll, (pdf, degrees));

  static Future<Uint8List> addPageNumbers(Uint8List pdf, PageNumberOptions options) =>
      compute(_pageNumbers, (pdf, options));

  /// Prepares each image (orientation, resolution, colour) and places one per
  /// page. Runs as one background job so the images are not copied twice.
  /// [quarterTurns], if given, turns each image clockwise.
  static Future<Uint8List> imagesToPdf(
    List<Uint8List> images, {
    List<int>? quarterTurns,
    ImagePrepOptions prep = const ImagePrepOptions(),
    ImagesToPdfOptions layout = const ImagesToPdfOptions(),
  }) => compute(
    _imagesToPdf,
    (images, quarterTurns ?? List.filled(images.length, 0), prep, layout),
  );
}

Uint8List _overlays((Uint8List, List<PageOverlay>) a) => PdfOverlays.apply(a.$1, a.$2);

Uint8List _watermark((Uint8List, WatermarkOptions) a) => PdfOverlays.watermark(a.$1, a.$2);

Uint8List _flatten((Uint8List, Map<int, Uint8List>) a) => PdfOverlays.flattenPages(a.$1, a.$2);

Comparison _compare((Uint8List, Uint8List) a) => PdfCompare.compare(a.$1, a.$2);

FilingResult _prepareFiling((List<FilingPart>, FilingOptions) a) =>
    EFilingBuilder.build(a.$1, a.$2);

Uint8List _compose((List<Uint8List>, List<PageRef>) a) => PdfEngine.composePages(a.$1, a.$2);

List<Uint8List> _split((Uint8List, List<PageRange>) a) => PdfEngine.split(a.$1, a.$2);

Uint8List _rotateAll((Uint8List, int) a) => PdfEngine.rotateAll(a.$1, a.$2);

Uint8List _pageNumbers((Uint8List, PageNumberOptions) a) => PdfEngine.addPageNumbers(a.$1, a.$2);

Uint8List _imagesToPdf(
  (List<Uint8List>, List<int>, ImagePrepOptions, ImagesToPdfOptions) a,
) => PdfEngine.imagesToPdf([
  for (var i = 0; i < a.$1.length; i++)
    ImagePrep.prepare(a.$1[i], a.$3, quarterTurns: a.$2[i]),
], a.$4);
