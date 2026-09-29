import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:caseflow/services/document_tools/document_tools_service.dart';

Uint8List textPdf(List<String> pages, {Map<int, int> rotations = const {}}) {
  final doc = PdfDocument();
  for (final text in pages) {
    doc.pages.add().graphics.drawString(
      text,
      PdfStandardFont(PdfFontFamily.helvetica, 14),
      bounds: const Rect.fromLTWH(40, 40, 400, 40),
    );
  }
  var bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  if (rotations.isNotEmpty) {
    final loaded = PdfDocument(inputBytes: bytes);
    rotations.forEach((i, deg) => loaded.pages[i].rotation = PdfPageRotateAngle.values[deg ~/ 90]);
    bytes = Uint8List.fromList(loaded.saveSync());
    loaded.dispose();
  }
  return bytes;
}

String pageText(Uint8List pdf, int page) {
  final doc = PdfDocument(inputBytes: pdf);
  final text = PdfTextExtractor(doc).extractText(startPageIndex: page, endPageIndex: page);
  doc.dispose();
  return text;
}

final _png = Uint8List.fromList(img.encodePng(img.Image(width: 20, height: 10)));

void main() {
  test('visual page sizes swap for rotated pages', () {
    final sizes = PdfOverlays.visualPageSizes(textPdf(['a', 'b'], rotations: {1: 90}));
    expect(sizes[0].width, lessThan(sizes[0].height));
    expect(sizes[1].width, greaterThan(sizes[1].height));
  });

  test('text overlays stay real, searchable text', () {
    final out = PdfOverlays.apply(textPdf(['Plaint']), const [
      PageOverlay(
        page: 0,
        box: Rect.fromLTWH(0.1, 0.5, 0.6, 0.1),
        kind: OverlayKind.text,
        text: 'Filed on 29.09.2026',
      ),
    ]);
    expect(pageText(out, 0), contains('Filed on 29.09.2026'));
  });

  test('every overlay kind draws, on rotated pages too', () {
    final out = PdfOverlays.apply(textPdf(['one', 'two'], rotations: {1: 270}), [
      for (final page in [0, 1]) ...[
        PageOverlay(page: page, box: const Rect.fromLTWH(0.6, 0.8, 0.3, 0.1), kind: OverlayKind.image, image: _png),
        PageOverlay(page: page, box: const Rect.fromLTWH(0.1, 0.1, 0.3, 0.05), kind: OverlayKind.whiteout),
        PageOverlay(page: page, box: const Rect.fromLTWH(0.1, 0.2, 0.3, 0.05), kind: OverlayKind.highlight, color: 0xFFFDE047),
        PageOverlay(page: page, box: const Rect.fromLTWH(0.1, 0.3, 0.3, 0.05), kind: OverlayKind.box, color: 0xFFDC2626),
      ],
    ]);
    expect(PdfEngine.pageCount(out), 2);
  });

  test('Tamil or Hindi text must come as an image', () {
    expect(isStandardFontText('Rs. 10,000 – “paid”'), isFalse); // curly quotes, en dash
    expect(isStandardFontText('Rs. 10,000 paid'), isTrue);
    expect(isStandardFontText('வாடகை'), isFalse);
    expect(
      () => PdfOverlays.apply(textPdf(['x']), const [
        PageOverlay(page: 0, box: Rect.fromLTWH(0, 0, 0.5, 0.1), kind: OverlayKind.text, text: 'வாடகை'),
      ]),
      throwsA(isA<DocumentToolException>()),
    );
  });

  test('refuses marks on missing pages and empty edits', () {
    expect(
      () => PdfOverlays.apply(textPdf(['x']), const [
        PageOverlay(page: 3, box: Rect.fromLTWH(0, 0, 0.1, 0.1), kind: OverlayKind.box),
      ]),
      throwsA(isA<DocumentToolException>()),
    );
    expect(() => PdfOverlays.apply(textPdf(['x']), const []), throwsA(isA<DocumentToolException>()));
  });

  group('watermark', () {
    test('adds text to chosen pages only', () {
      final out = PdfOverlays.watermark(
        textPdf(['one', 'two', 'three']),
        const WatermarkOptions(text: 'DRAFT', pages: {0, 2}),
      );
      expect(pageText(out, 0), contains('DRAFT'));
      expect(pageText(out, 1), isNot(contains('DRAFT')));
      expect(pageText(out, 2), contains('DRAFT'));
    });

    test('an image watermark and a rotated page work', () {
      final out = PdfOverlays.watermark(
        textPdf(['one'], rotations: {0: 90}),
        WatermarkOptions(image: _png, diagonal: false),
      );
      expect(PdfEngine.pageCount(out), 1);
    });

    test('needs text or an image', () {
      expect(
        () => PdfOverlays.watermark(textPdf(['x']), const WatermarkOptions(text: '  ')),
        throwsA(isA<DocumentToolException>()),
      );
    });
  });

  test('flattening a page removes its text for good and keeps the rest', () {
    final pdf = textPdf(['Aadhaar 1234 5678 9012', 'Second page stays searchable'], rotations: {1: 90});
    final jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 60, height: 85)));
    final out = PdfOverlays.flattenPages(pdf, {0: jpeg});

    expect(pageText(out, 0), isNot(contains('1234')));
    expect(pageText(out, 1), contains('Second page stays searchable'));
    final before = PdfOverlays.visualPageSizes(pdf);
    final after = PdfOverlays.visualPageSizes(out);
    for (var i = 0; i < 2; i++) {
      expect(after[i].width, closeTo(before[i].width, 1));
      expect(after[i].height, closeTo(before[i].height, 1));
    }
  });
}
