import 'dart:io';
import 'dart:ui';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pdfx/pdfx.dart' as native;

/// Local PDF processing service — replaces iLovePDF cloud API.
/// All operations run entirely on the device (offline-capable).
class LocalPdfService {

  // ─── MERGE PDF ──────────────────────────────────────────
  static Future<String> mergePdfs(List<File> files, {Function(double)? onProgress}) async {
    onProgress?.call(0.1);

    final PdfDocument mergedDoc = PdfDocument();
    mergedDoc.pages.removeAt(0);

    for (int i = 0; i < files.length; i++) {
      final bytes = await files[i].readAsBytes();
      final PdfDocument sourceDoc = PdfDocument(inputBytes: bytes);
      for (int j = 0; j < sourceDoc.pages.count; j++) {
        final srcPage = sourceDoc.pages[j];
        final template = srcPage.createTemplate();
        mergedDoc.pageSettings.size = srcPage.getClientSize();
        final newPage = mergedDoc.pages.add();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
      sourceDoc.dispose();
      onProgress?.call(0.1 + (0.7 * (i + 1) / files.length));
    }

    onProgress?.call(0.9);
    final outputPath = await _saveDocument(mergedDoc, 'merged');
    mergedDoc.dispose();
    onProgress?.call(1.0);
    return outputPath;
  }

  // ─── SPLIT PDF ──────────────────────────────────────────
  /// [pageRange] — optional, e.g. "1,3,5-8". If null, splits ALL pages.
  static Future<String> splitPdf(File inputFile, {String? pageRange, Function(double)? onProgress}) async {
    onProgress?.call(0.1);

    final bytes = await inputFile.readAsBytes();
    final PdfDocument sourceDoc = PdfDocument(inputBytes: bytes);
    final directory = await getApplicationDocumentsDirectory();
    final splitDir = Directory(p.join(directory.path, 'caseflow_split_${DateTime.now().millisecondsSinceEpoch}'));
    await splitDir.create(recursive: true);

    final int totalPages = sourceDoc.pages.count;

    // Parse which pages to extract
    final List<int> pagesToExtract = _parsePageRange(pageRange, totalPages);

    String firstFilePath = '';
    for (int idx = 0; idx < pagesToExtract.length; idx++) {
      final int pageNum = pagesToExtract[idx]; // 1-indexed
      if (pageNum < 1 || pageNum > totalPages) continue;

      final PdfDocument singlePageDoc = PdfDocument();
      singlePageDoc.pages.removeAt(0);

      final srcPage = sourceDoc.pages[pageNum - 1];
      final template = srcPage.createTemplate();
      singlePageDoc.pageSettings.size = srcPage.getClientSize();
      final newPage = singlePageDoc.pages.add();
      newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));

      final List<int> docBytes = await singlePageDoc.save();
      final outFile = File(p.join(splitDir.path, 'page_$pageNum.pdf'));
      await outFile.writeAsBytes(docBytes);
      if (idx == 0) firstFilePath = outFile.path;
      singlePageDoc.dispose();

      onProgress?.call(0.1 + (0.8 * (idx + 1) / pagesToExtract.length));
    }

    sourceDoc.dispose();
    onProgress?.call(1.0);
    return firstFilePath;
  }

  // ─── COMPRESS PDF ───────────────────────────────────────
  /// [level]: 'low', 'recommended', 'maximum'
  static Future<String> compressPdf(File inputFile, {String level = 'recommended', Function(double)? onProgress}) async {
    onProgress?.call(0.1);

    final bytes = await inputFile.readAsBytes();
    final PdfDocument doc = PdfDocument(inputBytes: bytes);

    onProgress?.call(0.3);
    doc.form.flattenAllFields();
    onProgress?.call(0.5);

    switch (level) {
      case 'low':
        doc.compressionLevel = PdfCompressionLevel.normal;
        break;
      case 'maximum':
        doc.compressionLevel = PdfCompressionLevel.best;
        break;
      default: // recommended
        doc.compressionLevel = PdfCompressionLevel.best;
        break;
    }

    onProgress?.call(0.8);
    final outputPath = await _saveDocument(doc, 'compressed');

    // Calculate size comparison
    final originalSize = await inputFile.length();
    final compressedSize = await File(outputPath).length();
    final savings = ((1 - compressedSize / originalSize) * 100).toStringAsFixed(1);
    // ignore: avoid_print
    print('Compression: $originalSize → $compressedSize bytes ($savings% smaller)');

    doc.dispose();
    onProgress?.call(1.0);
    return outputPath;
  }

  // ─── ROTATE PDF ─────────────────────────────────────────
  static Future<String> rotatePdf(File inputFile, int degrees, {Function(double)? onProgress}) async {
    onProgress?.call(0.1);

    final bytes = await inputFile.readAsBytes();
    final PdfDocument doc = PdfDocument(inputBytes: bytes);

    onProgress?.call(0.3);
    for (int i = 0; i < doc.pages.count; i++) {
      final page = doc.pages[i];
      final currentRotation = page.rotation.index * 90;
      final newRotation = (currentRotation + degrees) % 360;
      page.rotation = _degreesToRotation(newRotation);
      onProgress?.call(0.3 + (0.5 * (i + 1) / doc.pages.count));
    }

    onProgress?.call(0.9);
    final outputPath = await _saveDocument(doc, 'rotated');
    doc.dispose();
    onProgress?.call(1.0);
    return outputPath;
  }

  // ─── WATERMARK ──────────────────────────────────────────
  static Future<String> addWatermark(File inputFile, String text, {
    double opacity = 0.25,
    double fontSize = 60,
    Function(double)? onProgress,
  }) async {
    onProgress?.call(0.1);

    final bytes = await inputFile.readAsBytes();
    final PdfDocument doc = PdfDocument(inputBytes: bytes);

    onProgress?.call(0.3);

    final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, fontSize);
    final PdfBrush brush = PdfSolidBrush(PdfColor(128, 128, 128, (opacity * 255).toInt()));

    for (int i = 0; i < doc.pages.count; i++) {
      final page = doc.pages[i];
      final clientSize = page.getClientSize();

      page.graphics.save();
      page.graphics.setTransparency(opacity);
      page.graphics.rotateTransform(-45);
      page.graphics.drawString(
        text, font,
        brush: brush,
        bounds: Rect.fromLTWH(-clientSize.width / 2, clientSize.height / 2, clientSize.width * 2, fontSize + 40),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      page.graphics.restore();
      onProgress?.call(0.3 + (0.5 * (i + 1) / doc.pages.count));
    }

    onProgress?.call(0.9);
    final outputPath = await _saveDocument(doc, 'watermarked');
    doc.dispose();
    onProgress?.call(1.0);
    return outputPath;
  }

  // ─── IMAGES TO PDF ──────────────────────────────────────
  /// [pageSize]: 'a4', 'letter', 'original'
  static Future<String> imagesToPdf(List<File> imageFiles, {String pageSize = 'a4', Function(double)? onProgress}) async {
    onProgress?.call(0.1);

    final PdfDocument doc = PdfDocument();
    doc.pages.removeAt(0);

    for (int i = 0; i < imageFiles.length; i++) {
      final imageBytes = await imageFiles[i].readAsBytes();
      final PdfBitmap image = PdfBitmap(imageBytes);

      double pageWidth, pageHeight;

      switch (pageSize) {
        case 'letter':
          pageWidth = 612; pageHeight = 792;
          break;
        case 'original':
          pageWidth = image.width.toDouble();
          pageHeight = image.height.toDouble();
          break;
        default: // a4
          pageWidth = 595; pageHeight = 842;
      }

      // For A4 and Letter, fit the image maintaining aspect ratio
      double drawWidth = pageWidth;
      double drawHeight = pageHeight;
      double drawX = 0, drawY = 0;

      if (pageSize != 'original') {
        final imageAspect = image.width / image.height;
        final pageAspect = pageWidth / pageHeight;
        if (imageAspect > pageAspect) {
          drawHeight = pageWidth / imageAspect;
          drawY = (pageHeight - drawHeight) / 2;
        } else {
          drawWidth = pageHeight * imageAspect;
          drawX = (pageWidth - drawWidth) / 2;
        }
      }

      doc.pageSettings.size = Size(pageWidth, pageHeight);
      final PdfPage page = doc.pages.add();
      page.graphics.drawImage(image, Rect.fromLTWH(drawX, drawY, drawWidth, drawHeight));

      onProgress?.call(0.1 + (0.7 * (i + 1) / imageFiles.length));
    }

    onProgress?.call(0.9);
    final outputPath = await _saveDocument(doc, 'images_to_pdf');
    doc.dispose();
    onProgress?.call(1.0);
    return outputPath;
  }

  // ─── PDF TO IMAGES ──────────────────────────────────────
  /// [quality]: 'low', 'medium', 'high'
  static Future<String> pdfToImages(File inputFile, {String quality = 'high', Function(double)? onProgress}) async {
    onProgress?.call(0.1);

    final document = await native.PdfDocument.openFile(inputFile.path);
    final directory = await getApplicationDocumentsDirectory();
    final imgDir = Directory(p.join(directory.path, 'caseflow_images_${DateTime.now().millisecondsSinceEpoch}'));
    await imgDir.create(recursive: true);

    // Determine scale and quality based on user choice
    double scale;
    int jpgQuality;
    switch (quality) {
      case 'low':
        scale = 1.0; jpgQuality = 60;
        break;
      case 'medium':
        scale = 1.5; jpgQuality = 80;
        break;
      default: // high
        scale = 2.0; jpgQuality = 95;
    }

    final int pageCount = document.pagesCount;
    for (int i = 1; i <= pageCount; i++) {
      final page = await document.getPage(i);
      final pageImage = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: native.PdfPageImageFormat.jpeg,
        quality: jpgQuality,
      );

      if (pageImage != null) {
        final outFile = File(p.join(imgDir.path, 'page_$i.jpg'));
        await outFile.writeAsBytes(pageImage.bytes);
      }
      await page.close();
      onProgress?.call(0.1 + (0.8 * i / pageCount));
    }

    await document.close();
    onProgress?.call(1.0);
    return imgDir.path;
  }

  // ═══════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════

  /// Parse page range like "1, 3, 5-8" into list of 1-indexed page numbers.
  /// If null or empty, returns all pages [1..totalPages].
  static List<int> _parsePageRange(String? range, int totalPages) {
    if (range == null || range.trim().isEmpty) {
      return List.generate(totalPages, (i) => i + 1);
    }

    final Set<int> pages = {};
    final parts = range.split(',');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.contains('-')) {
        final rangeParts = trimmed.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0].trim());
          final end = int.tryParse(rangeParts[1].trim());
          if (start != null && end != null) {
            for (int i = start; i <= end && i <= totalPages; i++) {
              if (i >= 1) pages.add(i);
            }
          }
        }
      } else {
        final pageNum = int.tryParse(trimmed);
        if (pageNum != null && pageNum >= 1 && pageNum <= totalPages) {
          pages.add(pageNum);
        }
      }
    }

    final sorted = pages.toList()..sort();
    return sorted.isEmpty ? List.generate(totalPages, (i) => i + 1) : sorted;
  }

  static PdfPageRotateAngle _degreesToRotation(int degrees) {
    switch (degrees % 360) {
      case 90: return PdfPageRotateAngle.rotateAngle90;
      case 180: return PdfPageRotateAngle.rotateAngle180;
      case 270: return PdfPageRotateAngle.rotateAngle270;
      default: return PdfPageRotateAngle.rotateAngle0;
    }
  }

  static Future<String> _saveDocument(PdfDocument doc, String suffix) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = p.join(directory.path, '${suffix}_caseflow_${DateTime.now().millisecondsSinceEpoch}.pdf');
    final List<int> bytes = await doc.save();
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }
}
