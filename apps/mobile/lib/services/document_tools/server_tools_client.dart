/// Client for the CaseFlow document server (the "Caseflow Tools" FastAPI
/// backend) that runs the tools a phone cannot: Word/Excel/PowerPoint to
/// PDF, OCR, compression, PDF to Word/Excel, password protect/unlock, repair.
///
/// One call runs a whole job: upload → poll until done → download → delete.
/// The server keeps files for an hour at most; deleting right after the
/// download means a client's document is on it only while being processed.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../utils/env_config.dart';
import '../supabase_service.dart';
import 'document_files.dart';
import 'pdf_engine.dart' show DocumentToolException;

enum JobPhase { uploading, processing, downloading }

class JobProgress {
  final JobPhase phase;

  /// 0..1 while uploading or downloading; null while the server works.
  final double? fraction;
  const JobProgress(this.phase, [this.fraction]);

  String get label => switch (phase) {
    JobPhase.uploading => 'Uploading…',
    JobPhase.processing => 'Processing on the server…',
    JobPhase.downloading => 'Downloading the result…',
  };
}

/// A finished job's file, with the server's remark about it if any
/// (e.g. which pages had no tables).
class ServerOutput {
  final ToolFile file;
  final String? note;
  const ServerOutput(this.file, this.note);
}

class ServerToolsClient {
  final Dio _dio;
  final Future<String?> Function() _accessToken;
  final Duration pollInterval;
  final Duration timeout;

  ServerToolsClient({
    required String baseUrl,
    Dio? dio,
    Future<String?> Function()? accessToken,
    this.pollInterval = const Duration(milliseconds: 1500),
    this.timeout = const Duration(minutes: 16),
  }) : _dio = dio ?? Dio(),
       _accessToken = accessToken ?? SupabaseService.freshAccessToken {
    _dio.options
      ..baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(minutes: 3)
      ..sendTimeout = const Duration(minutes: 5);
  }

  /// Whether this build knows where the document server is.
  static bool get isConfigured => EnvConfig.docToolsApiUrl.trim().isNotEmpty;

  static ServerToolsClient? _shared;

  /// The app-wide client, or null when no server is configured.
  static ServerToolsClient? get shared {
    if (!isConfigured) return null;
    return _shared ??= ServerToolsClient(baseUrl: EnvConfig.docToolsApiUrl.trim());
  }

  static const _api = '/api/v1';

  /// Runs [tool] (a server slug such as `word-to-pdf`) on [files] and returns
  /// the output. Throws [DocumentToolException] with a message fit to show.
  Future<ServerOutput> run(
    String tool,
    List<ToolFile> files, {
    Map<String, Object?> options = const {},
    void Function(JobProgress progress)? onProgress,
    CancelToken? cancel,
  }) async {
    String? jobId;
    try {
      onProgress?.call(const JobProgress(JobPhase.uploading, 0));
      final job = await _create(tool, files, options, onProgress, cancel);
      jobId = job['id'] as String;

      final done = await _waitUntilDone(jobId, job, onProgress, cancel);
      final result = done['result'] as Map<String, dynamic>;

      onProgress?.call(const JobProgress(JobPhase.downloading, 0));
      final bytes = await _download(result['download_url'] as String, onProgress, cancel);
      return ServerOutput(ToolFile(result['filename'] as String, bytes), result['note'] as String?);
    } on DioException catch (e) {
      throw _friendly(e);
    } finally {
      if (jobId != null) unawaited(_delete(jobId));
    }
  }

  Future<Map<String, dynamic>> _create(
    String tool,
    List<ToolFile> files,
    Map<String, Object?> options,
    void Function(JobProgress)? onProgress,
    CancelToken? cancel,
  ) async {
    final token = await _accessToken();
    final response = await _dio.post<dynamic>(
      '$_api/jobs',
      data: FormData.fromMap({
        'tool': tool,
        'options': jsonEncode(options),
        'files': [
          for (final f in files) MultipartFile.fromBytes(f.bytes, filename: f.name),
        ],
      }),
      // Only job creation carries the sign-in token: downloads may be
      // redirected to storage that refuses a second credential.
      options: Options(headers: {if (token != null) 'Authorization': 'Bearer $token'}),
      cancelToken: cancel,
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(JobProgress(JobPhase.uploading, sent / total));
      },
    );
    return _json(response.data);
  }

  Future<Map<String, dynamic>> _waitUntilDone(
    String id,
    Map<String, dynamic> job,
    void Function(JobProgress)? onProgress,
    CancelToken? cancel,
  ) async {
    final deadline = DateTime.now().add(timeout);
    var current = job;
    while (true) {
      switch (current['status']) {
        case 'done':
          return current;
        case 'failed':
          final error = current['error'] as Map<String, dynamic>?;
          throw DocumentToolException(
            (error?['message'] as String?) ?? 'The server could not process this file.',
          );
        case 'expired':
          throw const DocumentToolException('The job expired on the server. Please try again.');
      }
      if (DateTime.now().isAfter(deadline)) {
        throw const DocumentToolException(
          'The server is taking too long. Please try again with a smaller file.',
        );
      }
      onProgress?.call(const JobProgress(JobPhase.processing));
      await Future<void>.delayed(pollInterval);
      if (cancel?.isCancelled ?? false) {
        throw const DocumentToolException('Cancelled.');
      }
      current = _json((await _dio.get<dynamic>('$_api/jobs/$id', cancelToken: cancel)).data);
    }
  }

  Future<Uint8List> _download(
    String path,
    void Function(JobProgress)? onProgress,
    CancelToken? cancel,
  ) async {
    final response = await _dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
      cancelToken: cancel,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(JobProgress(JobPhase.downloading, received / total));
      },
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  Future<void> _delete(String id) async {
    try {
      await _dio.delete<dynamic>('$_api/jobs/$id');
    } catch (e) {
      // The server deletes it after an hour anyway.
      debugPrint('Document server: could not delete job: $e');
    }
  }

  static Map<String, dynamic> _json(Object? data) => switch (data) {
    final Map<String, dynamic> map => map,
    final String text => jsonDecode(text) as Map<String, dynamic>,
    _ => throw const DocumentToolException('The document server sent an unexpected reply.'),
  };

  static DocumentToolException _friendly(DioException e) {
    if (e.type == DioExceptionType.cancel) {
      return const DocumentToolException('Cancelled.');
    }
    final data = e.response?.data;
    try {
      final message = _json(data)['message'];
      if (message is String && message.isNotEmpty) return DocumentToolException(message);
    } catch (_) {
      // Not the server's error shape; fall through.
    }
    return switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout => const DocumentToolException(
        "Couldn't reach the CaseFlow document server. Check your internet connection.",
      ),
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const DocumentToolException(
        'The connection is too slow for this file. Please try again on a better network.',
      ),
      _ => DocumentToolException(
        'The document server had a problem (${e.response?.statusCode ?? 'no reply'}). Please try again.',
      ),
    };
  }
}
