import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:caseflow/services/document_tools/document_tools_service.dart';

Uint8List textPdf(List<String> pages) {
  final doc = PdfDocument();
  for (final text in pages) {
    doc.pages.add().graphics.drawString(
      text,
      PdfStandardFont(PdfFontFamily.helvetica, 14),
      bounds: const Rect.fromLTWH(40, 40, 400, 40),
    );
  }
  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return bytes;
}

String allText(Uint8List pdf, {String? password}) {
  final doc = PdfDocument(inputBytes: pdf, password: password);
  final text = PdfTextExtractor(doc).extractText();
  doc.dispose();
  return text;
}

/// The web project's shared fixtures, when this checkout sits next to it.
final _samples = Directory(
  Platform.environment['DOC_TOOLS_SAMPLES'] ?? 'C:/Users/amjat/OneDrive/Desktop/Caseflow doc tools/samples',
);
Uint8List sample(String name) => File('${_samples.path}/$name').readAsBytesSync();
final _noSamples = _samples.existsSync() ? false : 'samples folder not found';

void main() {
  group('protect and unlock', () {
    test('protect needs the password to open, and unlock removes it', () {
      final locked = PdfProtection.protect(textPdf(['Vakalat']), 'secret1');
      expect(PdfProtection.isEncrypted(locked), isTrue);
      expect(() => PdfDocument(inputBytes: locked), throwsA(anything));
      expect(allText(locked, password: 'secret1'), contains('Vakalat'));

      final open = PdfProtection.unlock(locked, 'secret1');
      expect(PdfProtection.isEncrypted(open), isFalse);
      expect(allText(open), contains('Vakalat'));
    });

    test('the owner password is not derived from the user password', () {
      final a = PdfProtection.protect(textPdf(['a']), 'secret1');
      expect(latin1.decode(a, allowInvalid: true), isNot(contains('secret1')));
    });

    test('short passwords and double protection are refused', () {
      expect(() => PdfProtection.protect(textPdf(['a']), 'abc'), throwsA(isA<DocumentToolException>()));
      final locked = PdfProtection.protect(textPdf(['a']), 'secret1');
      expect(() => PdfProtection.protect(locked, 'secret2'), throwsA(isA<DocumentToolException>()));
    });

    test('wrong or missing passwords get clear messages', () {
      final locked = PdfProtection.protect(textPdf(['a']), 'secret1');
      expect(
        () => PdfProtection.unlock(locked, 'nope'),
        throwsA(predicate((e) => e.toString() == 'That password is not correct.')),
      );
      expect(
        () => PdfProtection.unlock(locked, ''),
        throwsA(predicate((e) => e.toString().contains('needs its password'))),
      );
      expect(
        () => PdfProtection.unlock(textPdf(['a']), ''),
        throwsA(predicate((e) => e.toString().contains('no password'))),
      );
    });

    test('real AES-256 file: user and owner passwords both unlock', () {
      for (final password in ['caseflow', 'caseflow-owner']) {
        final open = PdfProtection.unlock(sample('protected.pdf'), password);
        expect(allText(open), contains('Caseflow Tools'));
      }
    }, skip: _noSamples);

    test('restrictions without an open password are removed without one', () {
      final open = PdfProtection.unlock(sample('owner-restricted.pdf'), '');
      expect(PdfProtection.isEncrypted(open), isFalse);
      expect(allText(open), contains('Caseflow Tools'));
    }, skip: _noSamples);
  });

  group('repair', () {
    test('a healthy PDF comes back readable', () {
      final out = PdfRepair.repair(textPdf(['one', 'two']));
      expect(PdfEngine.pageCount(out!), 2);
    });

    test('rebuilds a broken cross-reference table', () {
      final damaged = sample('damaged-xref.pdf');
      expect(() => PdfDocument(inputBytes: damaged), throwsA(anything), reason: 'fixture is broken');
      final fixed = PdfRepair.repair(damaged);
      expect(fixed, isNotNull);
      expect(PdfEngine.pageCount(fixed!), greaterThan(0));
      expect(allText(fixed).trim(), isNotEmpty);
    }, skip: _noSamples);

    test('rebuilds after the table and trailer were cut off', () {
      final good = textPdf(['Plaint page one', 'Plaint page two']);
      // Drop everything from "xref" on, as a cut-off download would.
      final text = latin1.decode(good);
      final cut = Uint8List.fromList(good.sublist(0, text.lastIndexOf('xref')));
      final fixed = PdfRepair.repair(cut);
      expect(fixed, isNotNull);
      expect(allText(fixed!), allOf(contains('Plaint page one'), contains('Plaint page two')));
    });

    test('not a PDF at all gives null (the app then re-renders or reports)', () {
      expect(PdfRepair.repair(Uint8List.fromList('hello'.codeUnits)), isNull);
    });
  });

  group('compression', () {
    test('finds the scanned pages and leaves typed ones', () {
      final scan = PdfEngine.imagesToPdf([
        Uint8List.fromList(img.encodeJpg(img.Image(width: 50, height: 70))),
      ], const ImagesToPdfOptions());
      final mixed = PdfEngine.merge([textPdf(['typed']), scan, textPdf(['typed again'])]);
      expect(PdfCompression.scannedPages(mixed), [1]);
    });

    test('rewrite keeps the content', () {
      final out = PdfCompression.rewrite(textPdf(['keep me']));
      expect(allText(out), contains('keep me'));
    });
  });
}
