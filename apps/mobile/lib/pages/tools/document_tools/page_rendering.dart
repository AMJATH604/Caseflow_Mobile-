import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../services/document_tools/document_tools_service.dart';

/// Renders PDF pages with the platform's PDF engine (PDFium on Android,
/// PDFKit on iOS, pdf.js on web), which must run on the UI isolate.
class PageRendering {
  PageRendering._();

  /// One page as an image for display.
  static Future<ImageProvider> page(Uint8List pdf, int index, {double dpi = 110}) async {
    final raster = await Printing.raster(pdf, pages: [index], dpi: dpi).first;
    return PdfRasterImage(raster);
  }

  /// Pages as JPEGs (all pages when [pages] is null), one at a time so a
  /// long PDF never sits in memory uncompressed.
  static Stream<Uint8List> jpegs(
    Uint8List pdf,
    List<int>? pages, {
    double dpi = 150,
    int quality = 88,
    bool grayscale = false,
  }) async* {
    await for (final raster in Printing.raster(pdf, pages: pages, dpi: dpi)) {
      yield await DocumentToolsService.rgbaToJpeg(
        raster.pixels,
        raster.width,
        raster.height,
        quality: quality,
        grayscale: grayscale,
      );
    }
  }
}

/// Draws [text] with the phone's own fonts, which cover Tamil and Hindi
/// (the PDF's built-in fonts do not), as a transparent PNG.
///
/// [pixelRatio] is pixels per logical unit; 4 keeps text sharp when printed.
/// With [maxWidth], long text wraps onto more lines.
Future<Uint8List> renderTextPng(
  String text,
  TextStyle style, {
  double pixelRatio = 4,
  double maxWidth = double.infinity,
}) async {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  final width = painter.width.ceil().clamp(1, 4000);
  final height = painter.height.ceil().clamp(1, 4000);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  painter.paint(canvas, Offset.zero);
  final image = await recorder.endRecording().toImage(
    (width * pixelRatio).round(),
    (height * pixelRatio).round(),
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    painter.dispose();
  }
}

/// The logical size [text] takes in [style] (for placing rendered text).
Size measureText(String text, TextStyle style, {double maxWidth = double.infinity}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  final size = painter.size;
  painter.dispose();
  return size;
}
