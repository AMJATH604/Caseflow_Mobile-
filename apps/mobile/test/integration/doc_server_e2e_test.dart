/// End-to-end checks of the app's document-server client against a real
/// "Caseflow Tools" backend (Word→PDF, OCR, PDF→Word, errors, and the
/// e-Filing OCR-then-rebuild path).
///
/// Skipped unless DOC_TOOLS_E2E_URL points at a running server, e.g.
///   DOC_TOOLS_E2E_URL=http://localhost:8000 \
///   DOC_TOOLS_SAMPLES=path/to/samples flutter test test/integration
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:caseflow/services/document_tools/document_files.dart';
import 'package:caseflow/services/document_tools/document_tools_service.dart';
import 'package:caseflow/services/document_tools/server_tools_client.dart';

final _url = Platform.environment['DOC_TOOLS_E2E_URL'] ?? '';
final _samples = Platform.environment['DOC_TOOLS_SAMPLES'] ?? '';

ToolFile _sample(String name) => ToolFile(name, File('$_samples/$name').readAsBytesSync());

String _text(List<int> pdf) {
  final doc = PdfDocument(inputBytes: pdf);
  final text = PdfTextExtractor(doc).extractText();
  doc.dispose();
  return text;
}

void main() {
  final skip = _url.isEmpty || _samples.isEmpty
      ? 'Set DOC_TOOLS_E2E_URL and DOC_TOOLS_SAMPLES to run against a real server'
      : false;
  final client = ServerToolsClient(
    baseUrl: _url,
    accessToken: () async => null,
    pollInterval: const Duration(milliseconds: 500),
  );
  const timeout = Timeout(Duration(minutes: 5));

  test('Word to PDF keeps Tamil and Hindi text', () async {
    final out = await client.run('word-to-pdf', [_sample('sample.docx')]);
    expect(out.file.name, endsWith('.pdf'));
    final text = _text(out.file.bytes);
    expect(text, isNotEmpty);
    expect(RegExp('[஀-௿]').hasMatch(text), isTrue, reason: 'Tamil letters');
    expect(RegExp('[ऀ-ॿ]').hasMatch(text), isTrue, reason: 'Hindi letters');
  }, skip: skip, timeout: timeout);

  test('OCR makes a scan searchable', () async {
    final scan = _sample('scanned.pdf');
    expect(_text(scan.bytes).trim(), isEmpty, reason: 'fixture must be image-only');
    final out = await client.run(
      'ocr-pdf',
      [scan],
      options: {
        'languages': ['eng', 'tam'],
        'mode': 'skip',
        'clean_up': true,
      },
    );
    expect(_text(out.file.bytes).trim().length, greaterThan(10));
  }, skip: skip, timeout: timeout);

  test('PDF to Word returns a .docx', () async {
    final out = await client.run('pdf-to-word', [_sample('text.pdf')]);
    expect(out.file.extension, 'docx');
    expect(out.file.bytes.sublist(0, 2), [0x50, 0x4B], reason: 'a zip (docx) file');
  }, skip: skip, timeout: timeout);

  test('a wrong password comes back as a readable message', () async {
    await expectLater(
      client.run('unlock-pdf', [_sample('protected.pdf')], options: {'password': 'nope'}),
      throwsA(predicate((e) => e is DocumentToolException && e.message.toLowerCase().contains('password'))),
    );
  }, skip: skip, timeout: timeout);

  test('e-Filing: OCR the scanned document, rebuild, nothing left unsearchable', () async {
    final options = FilingOptions(preset: CourtPreset.tamilNaduDistrict, maxFileMb: 20);
    final plaint = _sample('text.pdf');
    var scan = _sample('scanned.pdf');

    final before = EFilingBuilder.build(
      [FilingPart('Plaint', plaint.bytes), FilingPart('Receipt', scan.bytes)],
      options,
    );
    expect(before.documentsWithoutText, [1]);

    final ocr = await client.run(
      'ocr-pdf',
      [scan],
      options: {
        'languages': ['eng', 'tam'],
        'mode': 'skip',
        'clean_up': true,
      },
    );
    scan = ocr.file;

    final after = EFilingBuilder.build(
      [FilingPart('Plaint', plaint.bytes), FilingPart('Receipt', scan.bytes)],
      options,
    );
    expect(after.documentsWithoutText, isEmpty);
    expect(after.checks.map((c) => c.title), contains('Text is searchable'));
  }, skip: skip, timeout: timeout);
}
