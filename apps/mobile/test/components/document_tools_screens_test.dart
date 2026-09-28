import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caseflow/pages/tools/document_tools/doc_tool_widgets.dart';
import 'package:caseflow/pages/tools/document_tools/images_to_pdf_tool.dart';
import 'package:caseflow/pages/tools/document_tools/merge_pdf_tool.dart';
import 'package:caseflow/pages/tools/document_tools/organize_pdf_tool.dart';
import 'package:caseflow/pages/tools/document_tools/page_numbers_tool.dart';
import 'package:caseflow/pages/tools/document_tools/prepare_efiling_screen.dart';
import 'package:caseflow/pages/tools/document_tools/split_pdf_tool.dart';
import 'package:caseflow/services/document_tools/document_files.dart';
import 'package:caseflow/services/document_tools/efiling.dart' show FilingPart;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Pumps [child] the way ToolsScreen hosts a tool, at a real phone size
/// (see partition_tree_test.dart for why the size matters with ScreenUtil).
Future<void> _pumpTool(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
            child: Scaffold(body: Column(children: [Expanded(child: child)])),
          ),
        ),
      ),
    ),
  );
  // Progress indicators spin until real background work ends, which never
  // happens under fake time, so such tests pump frames themselves.
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

void main() {
  final tools = <String, Widget Function()>{
    'Scan to PDF': () => const ImagesToPdfTool(mode: ImageSourceMode.scan),
    'Images to PDF': () => const ImagesToPdfTool(mode: ImageSourceMode.images),
    'Merge': () => const MergePdfTool(),
    'Split': () => const SplitPdfTool(),
    'Organize': () => const OrganizePdfTool(),
    'Rotate': () => const OrganizePdfTool(mode: PageEditorMode.rotate),
    'Page numbers': () => const PageNumbersTool(),
  };

  group('each tool opens on its picker without layout errors', () {
    for (final entry in tools.entries) {
      testWidgets(entry.key, (tester) async {
        await _pumpTool(tester, entry.value());
        expect(find.byType(PickTarget), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('${entry.key} on a small phone with large text', (tester) async {
        await _pumpTool(tester, entry.value(), size: const Size(320, 640), textScale: 1.3);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ToolResultView', () {
    final file = ToolFile('Petition_merged.pdf', Uint8List(2048));

    testWidgets('offers save to case, open, save and share for one file', (tester) async {
      await _pumpTool(
        tester,
        ToolResultView(files: [file], headline: 'Merged 2 PDFs', onStartOver: () {}),
      );
      expect(find.text('Petition_merged.pdf'), findsOneWidget);
      expect(find.text('2 KB'), findsOneWidget);
      for (final label in ['Save to case', 'Open', 'Save', 'Share', 'Start over']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('fits a small phone with large text', (tester) async {
      await _pumpTool(
        tester,
        ToolResultView(files: [file], headline: 'Merged 2 PDFs', onStartOver: () {}),
        size: const Size(320, 640),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('lists several files with a save-all action', (tester) async {
      await _pumpTool(
        tester,
        ToolResultView(
          files: [ToolFile('a_pages_1-3.pdf', Uint8List(10)), ToolFile('a_pages_4-6.pdf', Uint8List(10))],
          headline: 'Split into 2 files',
          onStartOver: () {},
        ),
      );
      expect(find.text('Save all 2 to a case'), findsOneWidget);
    });

    testWidgets('rename keeps a safe .pdf name', (tester) async {
      await _pumpTool(
        tester,
        ToolResultView(files: [file], headline: 'Done', onStartOver: () {}),
      );
      await tester.tap(find.byTooltip('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'O.S. 12/2026: Plaint');
      await tester.tap(find.text('Rename').last);
      await tester.pumpAndSettle();
      expect(find.text('O.S. 12_2026_ Plaint.pdf'), findsOneWidget);
    });
  });

  group('Prepare for e-Filing', () {
    testWidgets('opens with the Tamil Nadu preset and nothing to prepare yet', (tester) async {
      await _pumpTool(tester, const PrepareEfilingScreen());
      expect(find.text('Tamil Nadu District Courts'), findsOneWidget);
      expect(find.text('Add documents to begin'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton).last);
      expect(button.onPressed, isNull);
      // "Case files" only appears when opened from a case.
      expect(find.text('Case files'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a small phone with large text', (tester) async {
      await _pumpTool(
        tester,
        const PrepareEfilingScreen(),
        size: const Size(320, 640),
        textScale: 1.3,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('Bookmarks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('turning on margins also turns on A4 fitting', (tester) async {
      await _pumpTool(tester, const PrepareEfilingScreen());
      await tester.tap(find.text('Fit pages to A4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add court margins'));
      await tester.pumpAndSettle();
      final fit = tester.widget<SwitchListTile>(
        find.ancestor(of: find.text('Fit pages to A4'), matching: find.byType(SwitchListTile)),
      );
      expect(fit.value, isTrue);
    });
  
    testWidgets('prepares a filing and shows the checks and portal index', (tester) async {
      Uint8List pdf(int pages, String label) {
        final doc = PdfDocument();
        for (var i = 0; i < pages; i++) {
          doc.pages.add().graphics.drawString(
            '$label ${i + 1}',
            PdfStandardFont(PdfFontFamily.helvetica, 14),
          );
        }
        final bytes = Uint8List.fromList(doc.saveSync());
        doc.dispose();
        return bytes;
      }

      /// Pumps frames while real background work (isolates) runs.
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 200 && finder.evaluate().isEmpty; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump();
        }
        expect(finder, findsWidgets);
      }

      await _pumpTool(
        tester,
        PrepareEfilingScreen(
          initialDocuments: [
            FilingPart('Plaint', pdf(3, 'Plaint')),
            FilingPart('Vakalatnama', pdf(1, 'Vakalat')),
          ],
        ),
        size: const Size(360, 740),
        settle: false,
      );
      await waitFor(find.text('Prepare filing · 4 pages'));
      expect(find.text('Plaint'), findsOneWidget);

      await tester.tap(find.text('Prepare filing · 4 pages'));
      await waitFor(find.text('e-Filing check'));
      await tester.pumpAndSettle();

      expect(find.text('Ready to file · 5 pages'), findsOneWidget);
      expect(find.text('All pages are A4'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Save to case'), 300);
      expect(find.text('Filing_eFiling.pdf'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Portal indexing'), 300);
      expect(find.text('Portal indexing'), findsOneWidget);
      // Index 1, Plaint 2-4, Vakalatnama 5.
      expect(find.text('Vakalatnama'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Back to the documents keeps them.
      await tester.tap(find.text('Back to documents'));
      await tester.pumpAndSettle();
      expect(find.text('Prepare filing · 4 pages'), findsOneWidget);
    });
  });
}
