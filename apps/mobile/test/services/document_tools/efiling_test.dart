import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:caseflow/services/document_tools/document_tools_service.dart';

/// A text PDF whose pages say "<label> 1", "<label> 2"... at [size].
Uint8List textPdf(int pages, String label, {Size size = a4Size}) {
  final doc = PdfDocument();
  final section = doc.sections!.add();
  section.pageSettings
    ..margins.all = 0
    ..orientation = size.width > size.height
        ? PdfPageOrientation.landscape
        : PdfPageOrientation.portrait
    ..size = size;
  for (var i = 0; i < pages; i++) {
    section.pages.add().graphics.drawString(
      '$label ${i + 1}',
      PdfStandardFont(PdfFontFamily.helvetica, 20),
      bounds: const Rect.fromLTWH(10, 10, 300, 40),
    );
  }
  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return bytes;
}

/// An image-only (scanned) PDF of [pages] noisy pages; large on purpose.
Uint8List scannedPdf(int pages, {int width = 500, int height = 700}) => PdfEngine.imagesToPdf([
  for (var i = 0; i < pages; i++)
    Uint8List.fromList(img.encodeJpg(_noise(width, height, i), quality: 95)),
], const ImagesToPdfOptions());

img.Image _noise(int w, int h, int seed) {
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

String pageText(Uint8List pdf, int index) {
  final doc = PdfDocument(inputBytes: pdf);
  final text = PdfTextExtractor(doc).extractText(startPageIndex: index, endPageIndex: index);
  doc.dispose();
  return text;
}

/// Bookmarks as "title -> page number" (1-based), read back from the file.
List<String> bookmarks(Uint8List pdf) {
  final doc = PdfDocument(inputBytes: pdf);
  final marks = [
    for (var i = 0; i < doc.bookmarks.count; i++)
      '${doc.bookmarks[i].title} -> '
          '${doc.bookmarks[i].destination == null ? 'nowhere' : doc.pages.indexOf(doc.bookmarks[i].destination!.page) + 1}',
  ];
  doc.dispose();
  return marks;
}

FilingOptions options({
  bool index = true,
  bool fit = true,
  bool margins = false,
  bool numbers = true,
  bool marks = true,
  int maxMb = 20,
}) => FilingOptions(
  preset: CourtPreset.tamilNaduDistrict,
  indexPage: index,
  fitToA4: fit,
  addMargins: margins,
  pageNumbers: numbers,
  bookmarks: marks,
  maxFileMb: maxMb,
  heading: 'IN THE COURT OF THE DISTRICT MUNSIF, CHENNAI',
  subheading: 'O.S. No. 12 of 2026',
);

void main() {
  final plaint = textPdf(3, 'Plaint');
  final vakalat = textPdf(1, 'Vakalat');
  final parts = [FilingPart('Plaint', plaint), FilingPart('Vakalatnama', vakalat)];

  test('index page, page ranges, numbers and bookmarks line up', () {
    final result = EFilingBuilder.build(parts, options());
    final file = result.files.single;

    expect(file.pageCount, 5);
    expect([for (final e in file.index) '${e.title} ${e.pages}'], [
      'Index 1',
      'Plaint 2-4',
      'Vakalatnama 5',
    ]);

    final index = pageText(file.pdf, 0);
    expect(index, contains('INDEX'));
    expect(index, contains('O.S. No. 12 of 2026'));
    expect(index, contains('2 - 4'));
    expect(index, contains('Vakalatnama'));

    // Page 2 is the first page of the plaint and is numbered "2".
    expect(pageText(file.pdf, 1), allOf(contains('Plaint 1'), contains('2')));
    expect(bookmarks(file.pdf), ['Index -> 1', 'Plaint -> 2', 'Vakalatnama -> 5']);
  });

  test('without an index the documents start at page 1', () {
    final result = EFilingBuilder.build(parts, options(index: false));
    expect([for (final e in result.files.single.index) e.pages], ['1-3', '4']);
  });

  test('fits Letter and landscape pages onto A4', () {
    final letter = textPdf(1, 'Letter', size: const Size(612, 792));
    final wide = textPdf(1, 'Wide', size: const Size(800, 500));
    final result = EFilingBuilder.build(
      [FilingPart('Letter', letter), FilingPart('Wide', wide)],
      options(index: false, margins: true),
    );
    final doc = PdfDocument(inputBytes: result.files.single.pdf);
    final sizes = [for (var i = 0; i < doc.pages.count; i++) doc.pages[i].size];
    doc.dispose();
    expect(sizes[0].width, closeTo(a4Size.width, 1));
    expect(sizes[0].height, closeTo(a4Size.height, 1));
    expect(sizes[1].width, closeTo(a4Size.height, 1));
    expect(result.checks.first.level, CheckLevel.ok);
  });

  test('reports pages that are not A4 when fitting is off', () {
    final letter = textPdf(2, 'Letter', size: const Size(612, 792));
    final result = EFilingBuilder.build(
      [FilingPart('Letter', letter)],
      options(index: false, fit: false),
    );
    final check = result.checks.firstWhere((c) => c.title.contains('not A4'));
    expect(check.level, CheckLevel.problem);
    expect(check.detail, contains('1, 2'));
  });

  test('flags scanned pages without text, by filing page number', () {
    final result = EFilingBuilder.build(
      [FilingPart('Plaint', plaint), FilingPart('Sale deed', scannedPdf(2))],
      options(),
    );
    final check = result.checks.firstWhere((c) => c.title.contains('without searchable text'));
    expect(check.level, CheckLevel.warning);
    expect(check.detail, startsWith('Pages 5, 6.'));
  });

  test('splits into files under the size limit with per-file indexes', () {
    // Six scans of roughly 215 KB: about 1.3 MB, so two files at 1 MB.
    final scans = scannedPdf(6, width: 250, height: 350);
    expect(scans.length, greaterThan(1024 * 1024), reason: 'fixture must exceed 1 MB');
    final result = EFilingBuilder.build(
      [FilingPart('Plaint', plaint), FilingPart('Documents', scans)],
      options(maxMb: 1),
    );
    expect(result.files.length, greaterThan(1));
    for (final f in result.files) {
      expect(f.pdf.length, lessThanOrEqualTo(1024 * 1024));
      expect(f.index.first.from, 1);
      expect(f.index.last.to, f.pageCount);
      expect(bookmarks(f.pdf).length, f.index.length);
    }
    expect(result.totalPages, 1 + 3 + 6);
    // The scans run across files, so a later file continues them.
    expect(
      result.files.skip(1).map((f) => f.index.first.title),
      contains('Documents (contd.)'),
    );
    // Greedy packing uses as few files as the pages allow.
    expect(result.files.length, 2);
  });

  test('checks mention missing page numbers and bookmarks', () {
    final result = EFilingBuilder.build(
      [FilingPart('Long', textPdf(25, 'Page'))],
      options(numbers: false, marks: false, index: false),
    );
    final titles = result.checks.map((c) => c.title).toList();
    expect(titles, containsAll(['No page numbers', 'No bookmarks']));
  });

  test('warns when a signed document is combined', () {
    final signed = Uint8List.fromList([...plaint, ...'%/ByteRange [0 1 2 3]\n'.codeUnits]);
    expect(EFilingBuilder.hasDigitalSignature(signed), isTrue);
    expect(EFilingBuilder.hasDigitalSignature(plaint), isFalse);
  });

  test('needs at least one document', () {
    expect(
      () => EFilingBuilder.build(const [], options()),
      throwsA(isA<DocumentToolException>()),
    );
  });

  group('composePages fit', () {
    test('rotated pages keep the binding margin on the visual left', () {
      // A portrait page shown turned 90°: it looks landscape.
      final doc = PdfDocument(inputBytes: textPdf(1, 'Turned'));
      doc.pages[0].rotation = PdfPageRotateAngle.rotateAngle90;
      final turned = Uint8List.fromList(doc.saveSync());
      doc.dispose();

      final out = PdfEngine.composePages(
        [turned],
        const [PageRef(0, 0, fit: true)],
        fit: const PageFit(left: 100),
      );
      final check = PdfDocument(inputBytes: out);
      expect(check.pages[0].rotation, PdfPageRotateAngle.rotateAngle90);
      expect(check.pages[0].size.width, closeTo(a4Size.width, 1));
      check.dispose();
    });
  });
}
