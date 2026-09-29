import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/services/document_tools/document_files.dart';
import 'package:caseflow/services/document_tools/pdf_engine.dart' show DocumentToolException;
import 'package:caseflow/services/document_tools/server_tools_client.dart';

import 'fake_doc_server.dart';

final _word = ToolFile('Plaint.docx', Uint8List.fromList(List.filled(10, 1)));

void main() {
  test('uploads, polls, downloads, then deletes the job', () async {
    final server = FakeServer();
    final phases = <JobPhase>[];
    final out = await clientFor(server).run(
      'word-to-pdf',
      [_word],
      onProgress: (p) => phases.add(p.phase),
    );
    await pumpEventQueue(); // the delete runs in the background

    expect(out.file.name, 'Plaint.pdf');
    expect(out.file.bytes, [37, 80, 68, 70]);
    expect(out.note, isNull);
    expect(server.log, [
      'POST /api/v1/jobs',
      'GET /api/v1/jobs/job123',
      'GET /api/v1/jobs/job123',
      'GET /api/v1/jobs/job123/download',
      'DELETE /api/v1/jobs/job123',
    ]);
    expect(phases, containsAllInOrder([JobPhase.uploading, JobPhase.processing, JobPhase.downloading]));
  });

  test('sends the sign-in token only when creating the job', () async {
    final server = FakeServer();
    await clientFor(server).run('word-to-pdf', [_word]);
    await pumpEventQueue();
    expect(server.authHeaders.first, 'Bearer tok');
    expect(server.authHeaders.skip(1), everyElement(isNull));
  });

  test('works signed out (no token header at all)', () async {
    final server = FakeServer();
    await clientFor(server, token: null).run('word-to-pdf', [_word]);
    expect(server.authHeaders, everyElement(isNull));
  });

  test("a failed job reports the server's message and is still deleted", () async {
    final server = FakeServer(statuses: const ['queued', 'failed']);
    await expectLater(
      clientFor(server).run('word-to-pdf', [_word]),
      throwsA(predicate((e) => e is DocumentToolException && e.message == 'This Word file is damaged.')),
    );
    await pumpEventQueue();
    expect(server.log.last, 'DELETE /api/v1/jobs/job123');
  });

  test('a refused upload shows the reason and leaves nothing to delete', () async {
    final server = FakeServer(
      createStatus: 415,
      createError: {'code': 'unsupported_file', 'message': '“Plaint.docx” isn\'t a file type this tool can process.'},
    );
    await expectLater(
      clientFor(server).run('word-to-pdf', [_word]),
      throwsA(predicate((e) => e.toString().contains("isn't a file type"))),
    );
    expect(server.log, ['POST /api/v1/jobs']);
  });

  test('no connection gives a plain-language message', () async {
    await expectLater(
      clientFor(FakeServer(unreachable: true)).run('word-to-pdf', [_word]),
      throwsA(predicate((e) => e.toString().contains("Couldn't reach"))),
    );
  });

  test('a job that never finishes times out', () async {
    final server = FakeServer(statuses: const ['processing']);
    final client = ServerToolsClient(
      baseUrl: 'https://tools.example.in',
      dio: Dio()..httpClientAdapter = server,
      accessToken: () async => null,
      pollInterval: const Duration(milliseconds: 5),
      timeout: const Duration(milliseconds: 30),
    );
    await expectLater(
      client.run('ocr-pdf', [_word]),
      throwsA(predicate((e) => e.toString().contains('taking too long'))),
    );
  });

  test('without DOC_TOOLS_API_URL the server tools are off', () {
    expect(ServerToolsClient.isConfigured, isFalse);
    expect(ServerToolsClient.shared, isNull);
  });

  test('ToolFile knows its type', () {
    expect(ToolFile('a.docx', Uint8List(0)).kindLabel, 'Word');
    expect(ToolFile('a.XLSX', Uint8List(0)).extension, 'xlsx');
    expect(ToolFile('a.pdf', Uint8List(0)).mimeType, 'application/pdf');
  });
}
