import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:caseflow/services/document_tools/document_tools_service.dart';

/// A PDF whose pages say "<label> 1", "<label> 2", ... with optional
/// per-page sizes and /Rotate values.
Uint8List makePdf(
  int pages, {
  String label = 'Page',
  Map<int, int> rotations = const {},
  Map<int, Size> sizes = const {},
}) {
  final doc = PdfDocument();
  final font = PdfStandardFont(PdfFontFamily.helvetica, 20);
  for (var i = 0; i < pages; i++) {
    final section = doc.sections!.add();
    final size = sizes[i] ?? a4Size;
    section.pageSettings.margins.all = 0;
    section.pageSettings.orientation = size.width > size.height
        ? PdfPageOrientation.landscape
        : PdfPageOrientation.portrait;
    section.pageSettings.size = size;
    section.pages.add().graphics.drawString(
      '$label ${i + 1}',
      font,
      bounds: const Rect.fromLTWH(50, 50, 300, 40),
    );
  }
  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  if (rotations.isEmpty) return bytes;

  final loaded = PdfDocument(inputBytes: bytes);
  rotations.forEach((i, deg) {
    loaded.pages[i].rotation = PdfPageRotateAngle.values[deg ~/ 90];
  });
  final rotated = Uint8List.fromList(loaded.saveSync());
  loaded.dispose();
  return rotated;
}

/// The text of each page, trimmed.
List<String> pageTexts(Uint8List pdf) {
  final doc = PdfDocument(inputBytes: pdf);
  final extractor = PdfTextExtractor(doc);
  final texts = [
    for (var i = 0; i < doc.pages.count; i++)
      extractor.extractText(startPageIndex: i, endPageIndex: i).trim(),
  ];
  doc.dispose();
  return texts;
}

List<int> pageRotations(Uint8List pdf) {
  final doc = PdfDocument(inputBytes: pdf);
  final r = [for (var i = 0; i < doc.pages.count; i++) doc.pages[i].rotation.index * 90];
  doc.dispose();
  return r;
}

List<Size> pageSizes(Uint8List pdf) {
  final doc = PdfDocument(inputBytes: pdf);
  final s = [for (var i = 0; i < doc.pages.count; i++) doc.pages[i].size];
  doc.dispose();
  return s;
}

Matcher closeToSize(Size expected) => predicate<Size>(
  (s) => (s.width - expected.width).abs() < 1 && (s.height - expected.height).abs() < 1,
  'size close to $expected',
);

void main() {
  group('pageCount', () {
    test('counts pages', () {
      expect(PdfEngine.pageCount(makePdf(3)), 3);
    });

    test('rejects bytes that are not a PDF', () {
      expect(
        () => PdfEngine.pageCount(Uint8List.fromList('hello'.codeUnits)),
        throwsA(isA<DocumentToolException>()),
      );
    });

    test('explains password-protected files', () {
      final doc = PdfDocument();
      doc.pages.add();
      doc.security.userPassword = 'secret';
      final locked = Uint8List.fromList(doc.saveSync());
      doc.dispose();
      expect(
        () => PdfEngine.pageCount(locked),
        throwsA(predicate((e) => e.toString().contains('password-protected'))),
      );
    });
  });

  group('merge', () {
    test('joins every page of every file in order', () {
      final out = PdfEngine.merge([makePdf(2, label: 'A'), makePdf(3, label: 'B')]);
      expect(pageTexts(out), ['A 1', 'A 2', 'B 1', 'B 2', 'B 3']);
    });

    test('keeps page sizes and rotations', () {
      final landscape = makePdf(
        2,
        label: 'L',
        sizes: {0: const Size(841.89, 595.28)},
        rotations: {1: 90},
      );
      final out = PdfEngine.merge([makePdf(1), landscape]);
      final sizes = pageSizes(out);
      expect(sizes[0], closeToSize(a4Size));
      expect(sizes[1], closeToSize(const Size(841.89, 595.28)));
      expect(sizes[2], closeToSize(a4Size));
      expect(pageRotations(out), [0, 0, 90]);
    });

    test('needs two files', () {
      expect(() => PdfEngine.merge([makePdf(1)]), throwsA(isA<DocumentToolException>()));
    });
  });

  group('composePages', () {
    test('reorders pages', () {
      final src = makePdf(4);
      final out = PdfEngine.composePages([src], const [
        PageRef(0, 3),
        PageRef(0, 0),
        PageRef(0, 2),
      ]);
      expect(pageTexts(out), ['Page 4', 'Page 1', 'Page 3']);
    });

    test('deletes pages in place and adds rotation to existing rotation', () {
      final src = makePdf(4, rotations: {2: 90});
      final out = PdfEngine.composePages([src], const [
        PageRef(0, 0, rotation: 180),
        PageRef(0, 2, rotation: 270),
      ]);
      expect(pageTexts(out), ['Page 1', 'Page 3']);
      expect(pageRotations(out), [180, 0]);
    });

    test('rotation survives reordering', () {
      final src = makePdf(2, rotations: {0: 270});
      final out = PdfEngine.composePages([src], const [
        PageRef(0, 1, rotation: 90),
        PageRef(0, 0),
      ]);
      expect(pageTexts(out), ['Page 2', 'Page 1']);
      expect(pageRotations(out), [90, 270]);
    });

    test('refuses an empty result', () {
      expect(
        () => PdfEngine.composePages([makePdf(1)], const []),
        throwsA(isA<DocumentToolException>()),
      );
    });
  });

  group('split', () {
    test('writes one file per range', () {
      final parts = PdfEngine.split(makePdf(5), const [PageRange(0, 1), PageRange(4, 4)]);
      expect(parts.map(pageTexts).toList(), [
        ['Page 1', 'Page 2'],
        ['Page 5'],
      ]);
    });

    test('a one-page part is smaller than the whole file', () {
      // Big incompressible images so that leftover pages would show in size.
      final images = [
        for (var i = 0; i < 3; i++)
          Uint8List.fromList(img.encodeJpg(noise(600, 800, seed: i), quality: 95)),
      ];
      final whole = PdfEngine.imagesToPdf(images, const ImagesToPdfOptions());
      final part = PdfEngine.split(whole, const [PageRange(1, 1)]).single;
      expect(part.length, lessThan(whole.length * 0.5));
    });
  });

  test('rotateAll turns every page', () {
    final out = PdfEngine.rotateAll(makePdf(2, rotations: {1: 90}), 90);
    expect(pageRotations(out), [90, 180]);
  });

  group('addPageNumbers', () {
    test('numbers pages after the skipped ones', () {
      final out = PdfEngine.addPageNumbers(
        makePdf(3),
        const PageNumberOptions(skipFirst: 1, style: PageNumberStyle.pageNofTotal),
      );
      final texts = pageTexts(out);
      expect(texts[0], 'Page 1');
      expect(texts[1], contains('Page 1 of 2'));
      expect(texts[2], contains('Page 2 of 2'));
    });

    test('honours the starting number', () {
      final out = PdfEngine.addPageNumbers(
        makePdf(2),
        const PageNumberOptions(startAt: 7, style: PageNumberStyle.dashed),
      );
      expect(pageTexts(out).last, contains('- 8 -'));
    });

    test('works on rotated pages', () {
      final out = PdfEngine.addPageNumbers(
        makePdf(2, rotations: {0: 90, 1: 270}),
        const PageNumberOptions(style: PageNumberStyle.pageN),
      );
      final texts = pageTexts(out);
      expect(texts[0], contains('Page 1'));
      expect(texts[1], contains('Page 2'));
      expect(pageRotations(out), [90, 270]);
    });

    test('refuses to skip every page', () {
      expect(
        () => PdfEngine.addPageNumbers(makePdf(2), const PageNumberOptions(skipFirst: 2)),
        throwsA(isA<DocumentToolException>()),
      );
    });
  });

  group('imagesToPdf', () {
    final portrait = Uint8List.fromList(img.encodePng(img.Image(width: 300, height: 400)));
    final landscape = Uint8List.fromList(img.encodeJpg(img.Image(width: 400, height: 300)));

    test('A4 pages follow each image orientation', () {
      final out = PdfEngine.imagesToPdf([portrait, landscape], const ImagesToPdfOptions());
      final sizes = pageSizes(out);
      expect(sizes[0], closeToSize(a4Size));
      expect(sizes[1], closeToSize(Size(a4Size.height, a4Size.width)));
    });

    test('fit-to-image pages match the image shape plus margins', () {
      final out = PdfEngine.imagesToPdf(
        [landscape],
        const ImagesToPdfOptions(pageSize: PageSizeOption.fitImage, margin: 10),
      );
      expect(pageSizes(out).single, closeToSize(const Size(400 * 72 / 150 + 20, 300 * 72 / 150 + 20)));
    });

    test('rejects unreadable images', () {
      expect(
        () => PdfEngine.imagesToPdf([Uint8List.fromList([1, 2, 3])], const ImagesToPdfOptions()),
        throwsA(isA<DocumentToolException>()),
      );
    });
  });

  group('ImagePrep', () {
    test('caps the long side and outputs JPEG', () {
      final big = Uint8List.fromList(img.encodePng(img.Image(width: 3000, height: 1000)));
      final out = ImagePrep.prepare(big, const ImagePrepOptions());
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, ScanQuality.standard.maxSide);
      expect(decoded.height, closeTo(ScanQuality.standard.maxSide / 3, 1));
    });

    test('applies EXIF orientation', () {
      final photo = img.Image(width: 40, height: 20);
      photo.exif.imageIfd.orientation = 6; // rotate 90° clockwise to view
      final out = ImagePrep.prepare(
        Uint8List.fromList(img.encodeJpg(photo)),
        const ImagePrepOptions(),
      );
      final decoded = img.decodeJpg(out)!;
      expect([decoded.width, decoded.height], [20, 40]);
    });

    test('quarterTurns rotates clockwise', () {
      final photo = img.Image(width: 40, height: 20);
      img.fill(photo, color: img.ColorRgb8(255, 255, 255));
      img.fillRect(photo, x1: 0, y1: 0, x2: 9, y2: 9, color: img.ColorRgb8(0, 0, 0));
      final out = img.decodeJpg(
        ImagePrep.prepare(
          Uint8List.fromList(img.encodePng(photo)),
          const ImagePrepOptions(),
          quarterTurns: 1,
        ),
      )!;
      expect([out.width, out.height], [20, 40]);
      // The dark top-left corner ends up top-right after a clockwise turn.
      expect(out.getPixel(15, 4).r, lessThan(60));
      expect(out.getPixel(4, 4).r, greaterThan(200));
    });

    test('puts transparent areas on white', () {
      final clear = img.Image(width: 4, height: 4, numChannels: 4);
      final out = ImagePrep.prepare(Uint8List.fromList(img.encodePng(clear)), const ImagePrepOptions());
      final pixel = img.decodeJpg(out)!.getPixel(1, 1);
      expect(pixel.r, greaterThan(240));
    });

    test('grayscale option removes colour', () {
      final red = img.Image(width: 4, height: 4);
      img.fill(red, color: img.ColorRgb8(255, 0, 0));
      final out = ImagePrep.prepare(
        Uint8List.fromList(img.encodePng(red)),
        const ImagePrepOptions(grayscale: true),
      );
      final pixel = img.decodeJpg(out)!.getPixel(1, 1);
      expect((pixel.r - pixel.g).abs(), lessThan(8));
    });

    test('rejects non-images', () {
      expect(
        () => ImagePrep.prepare(Uint8List.fromList([0, 1, 2]), const ImagePrepOptions()),
        throwsA(isA<DocumentToolException>()),
      );
    });
  });
}

img.Image noise(int w, int h, {required int seed}) {
  final image = img.Image(width: w, height: h);
  var x = seed * 7919 + 1;
  for (final p in image) {
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    p
      ..r = x & 0xff
      ..g = (x >> 8) & 0xff
      ..b = (x >> 16) & 0xff;
  }
  return image;
}
