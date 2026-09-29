import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:caseflow/pages/tools/document_tools/compare_pdf_tool.dart';
import 'package:caseflow/pages/tools/document_tools/doc_tool_widgets.dart';
import 'package:caseflow/pages/tools/document_tools/page_editor_tool.dart';
import 'package:caseflow/pages/tools/document_tools/pdf_to_images_tool.dart';
import 'package:caseflow/pages/tools/document_tools/signature_sheet.dart';
import 'package:caseflow/pages/tools/document_tools/single_pdf_input.dart';
import 'package:caseflow/pages/tools/document_tools/watermark_tool.dart';
import 'package:caseflow/services/document_tools/document_files.dart';
import 'package:caseflow/services/document_tools/signature_store.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
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

/// Lets real async work (isolates, image decoding) finish, pumping frames.
Future<void> _settle(WidgetTester tester, {Finder? until}) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    if (until == null ? i > 5 : until.evaluate().isNotEmpty) break;
  }
}

Uint8List _pdf(List<String> pages) {
  final doc = PdfDocument();
  for (final text in pages) {
    doc.pages.add().graphics.drawString(
      text,
      PdfStandardFont(PdfFontFamily.helvetica, 12),
      bounds: const Rect.fromLTWH(20, 20, 400, 300),
    );
  }
  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return bytes;
}

/// Stands in for the platform PDF renderer, which tests do not have.
final _whitePage = MemoryImage(Uint8List.fromList(img.encodePng(img.Image(width: 60, height: 85))));
Future<ImageProvider> _renderWhite(Uint8List pdf, int page) async => _whitePage;

PdfInput _input(List<String> pages, [String name = 'Vakalat.pdf']) =>
    PdfInput(ToolFile(name, _pdf(pages)), pages.length);

void main() {
  group('M4 tools open on their picker without layout errors', () {
    final tools = <String, Widget Function()>{
      'Sign': () => const PageEditorTool(mode: MarkupMode.sign),
      'Edit': () => const PageEditorTool(mode: MarkupMode.edit),
      'Watermark': () => const WatermarkTool(),
      'PDF to JPG': () => const PdfToImagesTool(),
      'Compare': () => const ComparePdfTool(),
    };
    for (final entry in tools.entries) {
      testWidgets(entry.key, (tester) async {
        await _pump(tester, entry.value(), size: const Size(320, 640), textScale: 1.3);
        expect(find.byType(PickTarget), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('Sign explains that it is not an e-filing signature', (tester) async {
    await _pump(tester, const PageEditorTool(mode: MarkupMode.sign));
    expect(find.textContaining('Aadhaar eSign or a DSC'), findsOneWidget);
  });

  testWidgets('Edit: add text, copy to all pages, undo, save', (tester) async {
    await _pump(
      tester,
      PageEditorTool(
        mode: MarkupMode.edit,
        initialInput: _input(['one', 'two', 'three']),
        renderPage: _renderWhite,
      ),
    );
    await _settle(tester, until: find.text('Page 1 of 3'));

    await tester.tap(find.text('Text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Received on 29.09.2026');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Received on 29.09.2026'), findsOneWidget);

    await tester.tap(find.text('All pages'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next page'));
    await tester.pump();
    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(find.text('Received on 29.09.2026'), findsOneWidget, reason: 'copied to page 2');

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(find.text('Received on 29.09.2026'), findsNothing, reason: 'copy undone');

    await tester.tap(find.byTooltip('Previous page'));
    // Let the "Added to all pages" message time out; it sits over Save.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save PDF'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await _settle(tester, until: find.text('Changes saved'));
    expect(find.text('Vakalat_edited.pdf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page that cannot be previewed says so instead of spinning', (tester) async {
    await _pump(
      tester,
      PageEditorTool(
        mode: MarkupMode.sign,
        initialInput: _input(['x']),
        renderPage: (pdf, page) async => throw Exception('no renderer'),
      ),
    );
    await _settle(tester, until: find.text('Preview unavailable'));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('whiteout offers permanent removal of the covered text', (tester) async {
    await _pump(
      tester,
      PageEditorTool(mode: MarkupMode.edit, initialInput: _input(['Aadhaar 1234']), renderPage: _renderWhite),
    );
    await _settle(tester, until: find.text('Page 1 of 1'));
    expect(find.text('Remove covered text permanently'), findsNothing);
    await tester.tap(find.text('Whiteout'));
    await tester.pump();
    expect(find.text('Remove covered text permanently'), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isTrue, reason: 'on by default');
  });

  testWidgets('Compare shows each change in context', (tester) async {
    await _pump(
      tester,
      ComparePdfTool(
        initialOld: _input(['The monthly rent is Rs. 10,000 payable in advance.'], 'Draft.pdf'),
        initialNew: _input(['The monthly rent is Rs. 12,000 payable in advance.'], 'Final.pdf'),
      ),
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Compare'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await _settle(tester, until: find.text('1 change found'));
    expect(find.text('−1 words'), findsOneWidget);
    expect(find.text('+1 words'), findsOneWidget);
    expect(find.textContaining('12,000', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drawing a signature returns a PNG and saves it on the phone', (tester) async {
    // Real file I/O never completes under the test's fake clock.
    final temp = (await tester.runAsync(() => Directory.systemTemp.createTemp('sig')))!;
    addTearDown(() => temp.delete(recursive: true));
    SignatureStore.directory = () async => Directory('${temp.path}/signatures');

    Uint8List? result;
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await SignatureSheet.show(context),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle(); // let the sheet finish sliding up

    final pad = tester.getCenter(find.text('Sign here with your finger'));
    // A stroke as a finger makes it: many small moves.
    final finger = await tester.startGesture(pad - const Offset(80, 0));
    for (var i = 0; i < 12; i++) {
      await finger.moveBy(const Offset(14, 2));
      await tester.pump();
    }
    await finger.up();
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Use this signature'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    // Rendering the PNG and saving it take real time: wait for the sheet.
    for (var i = 0; i < 100 && result == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }

    expect(result, isNotNull);
    expect(result!.sublist(1, 4), 'PNG'.codeUnits);
    expect(await tester.runAsync(SignatureStore.list), hasLength(1));
  });
}
