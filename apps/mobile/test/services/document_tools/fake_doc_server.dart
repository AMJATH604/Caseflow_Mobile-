import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:caseflow/services/document_tools/server_tools_client.dart';

/// Plays the document server's job API from a script of statuses.
class FakeServer implements HttpClientAdapter {
  final List<String> statuses;
  final Map<String, Object?>? createError;
  final int createStatus;
  final bool unreachable;
  final List<String> log = [];
  final List<String?> authHeaders = [];
  int _poll = 0;

  FakeServer({
    this.statuses = const ['queued', 'processing', 'done'],
    this.createError,
    this.createStatus = 202,
    this.unreachable = false,
  });

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  Map<String, Object?> _job(String status) => {
    'id': 'job123',
    'tool': 'word-to-pdf',
    'status': status,
    'created_at': '2026-09-28T10:00:00Z',
    'expires_at': '2026-09-28T11:00:00Z',
    'error': status == 'failed'
        ? {'code': 'conversion_failed', 'message': 'This Word file is damaged.'}
        : null,
    'result': status == 'done'
        ? {
            'filename': 'Plaint.pdf',
            'size': 4,
            'download_url': '/api/v1/jobs/job123/download',
            'input_size': 10,
          }
        : null,
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (unreachable) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
    final line = '${options.method} ${options.uri.path}';
    log.add(line);
    authHeaders.add(options.headers['Authorization'] as String?);
    if (line == 'POST /api/v1/jobs') {
      await requestStream?.drain<void>();
      if (createError != null) return _json(createError!, createStatus);
      return _json(_job(statuses[_poll]), 202);
    }
    if (line == 'GET /api/v1/jobs/job123') {
      _poll = (_poll + 1).clamp(0, statuses.length - 1);
      return _json(_job(statuses[_poll]), 200);
    }
    if (line == 'GET /api/v1/jobs/job123/download') {
      return ResponseBody.fromBytes([37, 80, 68, 70], 200);
    }
    if (line == 'DELETE /api/v1/jobs/job123') return ResponseBody.fromString('', 204);
    return _json({'code': 'not_found', 'message': 'Not found.'}, 404);
  }

  @override
  void close({bool force = false}) {}
}

ServerToolsClient clientFor(FakeServer server, {String? token = 'tok'}) {
  final dio = Dio()..httpClientAdapter = server;
  return ServerToolsClient(
    baseUrl: 'https://tools.example.in/',
    dio: dio,
    accessToken: () async => token,
    pollInterval: Duration.zero,
  );
}
