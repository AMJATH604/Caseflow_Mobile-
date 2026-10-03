import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/material.dart' hide Rect;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:caseflow/pages/tools/document_tools/doc_tool_widgets.dart';
import 'package:caseflow/pages/tools/document_tools/pdf_maintenance_tools.dart';
import 'package:caseflow/pages/tools/document_tools/single_pdf_input.dart';
import 'package:caseflow/services/document_tools/document_files.dart';
import 'package:caseflow/services/document_tools/document_tools_service.dart';

Future<void> _pump(WidgetTester tester, Widget child, {Size size = const Size(390, 844), double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: Column(children: [Expanded(child: child)])),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Taps [label] and pumps while real background work runs, until [until].
Future<void> _run(WidgetTester tester, String label, Finder until) async {
  await tester.runAsync(() async {
    await tester.tap(find.text(label));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  for (var i = 0; i < 150 && until.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
  expect(until, findsWidgets);
}

Uint8List _textPdf(String text) {
  final doc = PdfDocument();
  doc.pages.add().graphics.drawString(
    text,
    PdfStandardFont(PdfFontFamily.helvetica, 14),
    bounds: const Rect.fromLTWH(40, 40, 400, 40),
  );
  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return bytes;
}

/// A scanned page: a big noisy JPEG, so re-saving it smaller is measurable.
Uint8List _scanPdf() {
  final photo = img.Image(width: 900, height: 1270);
  var x = 7;
  for (final p in photo) {
    x = (x * 1103515245 + 12345) & 0x7fffffff;
    p
      ..r = x & 0xff
      ..g = (x >> 8) & 0xff
      ..b = (x >> 16) & 0xff;
  }
  return PdfEngine.imagesToPdf([Uint8List.fromList(img.encodeJpg(photo, quality: 95))], const ImagesToPdfOptions());
}

/// Stands in for the platform renderer: one small grey JPEG per page.
Stream<Uint8List> _fakeJpegs(Uint8List pdf, List<int>? pages, double dpi, int quality, bool grey) async* {
  for (var i = 0; i < (pages?.length ?? 1); i++) {
    yield Uint8List.fromList(img.encodeJpg(img.Image(width: 60, height: 85), quality: 50));
  }
}

Stream<Uint8List> _noJpegs(Uint8List pdf, List<int>? pages, double dpi, int quality, bool grey) =>
    const Stream.empty();

void main() {
  group('open on their picker without layout errors', () {
    for (final entry in <String, Widget Function()>{
      'Compress': () => const CompressPdfTool(),
      'Protect': () => const PasswordPdfTool(mode: PasswordMode.protect),
      'Unlock': () => const PasswordPdfTool(mode: PasswordMode.unlock),
      'Repair': () => const RepairPdfTool(),
    }.entries) {
      testWidgets(entry.key, (tester) async {
        await _pump(tester, entry.value(), size: const Size(320, 640), textScale: 1.3);
        expect(find.byType(PickTarget), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('compress shrinks scanned pages and reports the saving', (tester) async {
    final scan = _scanPdf();
    await _pump(
      tester,
      CompressPdfTool(initialInput: PdfInput(ToolFile('Deed.pdf', scan), 1), renderJpegs: _fakeJpegs),
    );
    await _run(tester, 'Compress PDF', find.textContaining('smaller)'));
    expect(find.text('Deed_compressed.pdf'), findsOneWidget);
  });

  testWidgets('an OCR\'d scan is left alone, and shrinks with "Also shrink pages with text"', (tester) async {
    // A large scan with a text layer on top, as OCR leaves it.
    final doc = PdfDocument(inputBytes: _scanPdf());
    doc.pages[0].graphics.drawString(
      'Sale deed dated 12.03.2009',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
      bounds: const Rect.fromLTWH(40, 40, 400, 30),
    );
    final ocred = Uint8List.fromList(doc.saveSync());
    doc.dispose();

    await _pump(
      tester,
      CompressPdfTool(initialInput: PdfInput(ToolFile('Deed.pdf', ocred), 1), renderJpegs: _fakeJpegs),
    );
    await tester.tap(find.text('Also shrink pages with text'));
    await tester.pump();
    await _run(tester, 'Compress PDF', find.textContaining('smaller)'));
    expect(find.text('Deed_compressed.pdf'), findsOneWidget);
  });

  testWidgets('compress hands back a typed PDF unchanged', (tester) async {
    await _pump(
      tester,
      CompressPdfTool(initialInput: PdfInput(ToolFile('Plaint.pdf', _textPdf('typed')), 1), renderJpegs: _fakeJpegs),
    );
    await _run(tester, 'Compress PDF', find.textContaining('no scanned pages'));
  });

  testWidgets('protect checks the passwords, then locks the file', (tester) async {
    await _pump(
      tester,
      PasswordPdfTool(mode: PasswordMode.protect, initialFile: ToolFile('Deed.pdf', _textPdf('x'))),
    );
    await tester.enterText(find.byType(TextField).at(0), 'secret1');
    await tester.enterText(find.byType(TextField).at(1), 'secret2');
    await tester.tap(find.text('Protect PDF'));
    await tester.pump();
    expect(find.text('The two passwords do not match'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'secret1');
    await _run(tester, 'Protect PDF', find.text('Password added (AES-256)'));
    expect(find.textContaining('does not store it'), findsOneWidget);
  });

  testWidgets('unlock says when the password is wrong', (tester) async {
    final locked = PdfProtection.protect(_textPdf('x'), 'secret1');
    await _pump(tester, PasswordPdfTool(mode: PasswordMode.unlock, initialFile: ToolFile('Locked.pdf', locked)));
    await tester.enterText(find.byType(TextField), 'nope');
    await _run(tester, 'Unlock PDF', find.text('That password is not correct.'));

    await tester.enterText(find.byType(TextField), 'secret1');
    await _run(tester, 'Unlock PDF', find.text('Password and restrictions removed'));
  });

  testWidgets('repair rebuilds a cut-off PDF and keeps its text', (tester) async {
    final good = _textPdf('Plaint');
    final cut = Uint8List.fromList(good.sublist(0, latin1.decode(good).lastIndexOf('xref')));
    await _pump(tester, RepairPdfTool(initialFile: ToolFile('Plaint.pdf', cut), renderJpegs: _noJpegs));
    await _run(tester, 'Repair PDF', find.text('PDF repaired'));
    expect(find.textContaining('all text, pages and links are kept'), findsOneWidget);
  });

  testWidgets('repair falls back to re-drawing the pages', (tester) async {
    final junk = Uint8List.fromList(utf8.encode('%PDF-1.4 not really a pdf'));
    await _pump(tester, RepairPdfTool(initialFile: ToolFile('Broken.pdf', junk), renderJpegs: _fakeJpegs));
    await _run(tester, 'Repair PDF', find.text('Recovered 1 page'));
    expect(find.textContaining('Run OCR'), findsOneWidget);
  });

  testWidgets('repair says when nothing can be recovered', (tester) async {
    final junk = Uint8List.fromList(utf8.encode('hello'));
    await _pump(tester, RepairPdfTool(initialFile: ToolFile('Broken.pdf', junk), renderJpegs: _noJpegs));
    await _run(tester, 'Repair PDF', find.textContaining('too damaged to recover'));
  });
}
