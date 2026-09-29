import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caseflow/pages/tools/document_tools/doc_tool_widgets.dart';
import 'package:caseflow/pages/tools/document_tools/server_tool_screen.dart';
import 'package:caseflow/services/document_tools/document_files.dart';

import '../services/document_tools/fake_doc_server.dart';

/// Pumps a server tool as ToolsScreen hosts it, at a phone size.
Future<void> _pump(
  WidgetTester tester,
  ServerTool tool, {
  ToolFile? file,
  FakeServer? server,
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
          child: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: ServerToolScreen(
                    tool: tool,
                    client: clientFor(server ?? FakeServer()),
                    initialFile: file,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Taps [finder] in the real-async zone, so the job it starts runs on real
/// timers rather than the test's fake clock.
Future<void> _tapAndRun(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();
}

/// Pumps frames while the fake server's async work runs.
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  expect(finder, findsWidgets);
}

final _docx = ToolFile('Plaint.docx', Uint8List.fromList(List.filled(10, 1)));
final _pdf = ToolFile('Deed.pdf', Uint8List.fromList(List.filled(10, 1)));

void main() {
  group('every server tool opens on its picker without layout errors', () {
    for (final tool in ServerTool.values) {
      testWidgets(tool.title, (tester) async {
        await _pump(tester, tool, size: const Size(320, 640), textScale: 1.3);
        expect(find.byType(PickTarget), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('Word to PDF runs the job and offers the result', (tester) async {
    final server = FakeServer();
    await _pump(tester, ServerTool.wordToPdf, file: _docx, server: server);
    expect(find.text('Word · 10 B'), findsOneWidget);

    await _tapAndRun(tester, find.text('Word to PDF'));
    await _waitFor(tester, find.text('Converted to PDF'));
    expect(find.text('Plaint.pdf'), findsOneWidget);
    expect(server.log.first, 'POST /api/v1/jobs');
    expect(tester.takeException(), isNull);
  });

  testWidgets('compression reports the saving', (tester) async {
    await _pump(tester, ServerTool.compress, file: _pdf);
    await _tapAndRun(tester, find.text('Compress PDF'));
    // 10 bytes in, 4 bytes back from the fake server.
    await _waitFor(tester, find.textContaining('60% smaller'));
  });

  testWidgets('a server failure is shown and the tool stays usable', (tester) async {
    await _pump(
      tester,
      ServerTool.wordToPdf,
      file: _docx,
      server: FakeServer(statuses: const ['queued', 'failed']),
    );
    await _tapAndRun(tester, find.text('Word to PDF'));
    await _waitFor(tester, find.text('This Word file is damaged.'));
    expect(find.text('Word to PDF'), findsWidgets);
  });

  testWidgets('protect checks the passwords before uploading', (tester) async {
    final server = FakeServer();
    await _pump(tester, ServerTool.protect, file: _pdf, server: server);
    await tester.enterText(find.byType(TextField).at(0), 'secret1');
    await tester.enterText(find.byType(TextField).at(1), 'secret2');
    await tester.tap(find.text('Protect PDF'));
    await tester.pump();
    expect(find.text('The two passwords do not match'), findsOneWidget);
    expect(server.log, isEmpty);
  });

  testWidgets('OCR needs at least one language', (tester) async {
    final server = FakeServer();
    await _pump(tester, ServerTool.ocr, file: _pdf, server: server);
    // English and Tamil are on by default for Tamil Nadu; turn both off.
    await tester.tap(find.text('English'));
    await tester.tap(find.text('Tamil'));
    await tester.pump();
    await tester.tap(find.text('Make searchable'));
    await tester.pump();
    expect(find.text('Choose at least one language'), findsOneWidget);
    expect(server.log, isEmpty);
  });
}
