import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caseflow/pages/tools/document_tools/doc_tool_widgets.dart';
import 'package:caseflow/pages/tools/document_tools/images_to_pdf_tool.dart';
import 'package:caseflow/pages/tools/document_tools/merge_pdf_tool.dart';
import 'package:caseflow/pages/tools/document_tools/organize_pdf_tool.dart';
import 'package:caseflow/pages/tools/document_tools/page_numbers_tool.dart';
import 'package:caseflow/pages/tools/document_tools/split_pdf_tool.dart';
import 'package:caseflow/services/document_tools/document_files.dart';

/// Pumps [child] the way ToolsScreen hosts a tool, at a real phone size
/// (see partition_tree_test.dart for why the size matters with ScreenUtil).
Future<void> _pumpTool(
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
  await tester.pumpAndSettle();
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
}
