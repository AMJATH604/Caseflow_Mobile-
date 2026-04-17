import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// PDF processing service using iLovePDF via Edge Function proxy.
///
/// **Security:** All authentication is handled by the `pdf-proxy` Edge Function.
/// The iLovePDF public/secret keys are stored as Supabase secrets and never
/// reach the client binary. The proxy also validates the user's JWT.
///
/// **Flow:**
/// 1. Client calls `pdf-proxy` with action='start' → gets token + server + taskId
/// 2. Client uploads file directly to iLovePDF server (using the proxy-provided token)
/// 3. Client calls `pdf-proxy` with action='forward' to process
/// 4. Client downloads result directly from iLovePDF server
class ILovePdfService {
  static final Dio _dio = Dio();

  /// Step 1: Start a task via the secure Edge Function proxy.
  /// The proxy authenticates with iLovePDF and returns a session token.
  /// Returns a map with 'token', 'server', and 'task' (ID).
  static Future<Map<String, dynamic>> startTask(String tool) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'pdf-proxy',
        body: {
          'action': 'start',
          'tool': tool,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'Unknown error';
        throw Exception('Failed to start iLovePDF task: $errorMsg');
      }

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception('Failed to start iLovePDF task: ${e.toString()}');
    }
  }

  /// Step 2: Upload a file directly to iLovePDF server.
  /// Uses the token obtained from the proxy in step 1.
  static Future<void> uploadFile(
      String server, String taskId, String token, File file) async {
    try {
      final String uploadUrl = 'https://$server/v1/upload';
      final formData = FormData.fromMap({
        'task': taskId,
        'file': await MultipartFile.fromFile(file.path,
            filename: p.basename(file.path)),
      });

      await _dio.post(
        uploadUrl,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
    } catch (e) {
      throw Exception('Failed to upload file to iLovePDF: ${e.toString()}');
    }
  }

  /// Step 3: Process the task via the Edge Function proxy.
  static Future<void> processTask(String server, String taskId, String tool,
      String token, {Map<String, dynamic>? params}) async {
    try {
      final String processUrl = 'https://$server/v1/process';
      final Map<String, dynamic> payload = {
        'task': taskId,
        'tool': tool,
        ...?params,
      };

      await Supabase.instance.client.functions.invoke(
        'pdf-proxy',
        body: {
          'action': 'forward',
          'token': token,
          'url': processUrl,
          'method': 'POST',
          'payload': payload,
        },
      );
    } catch (e) {
      throw Exception('Failed to process iLovePDF task: ${e.toString()}');
    }
  }

  /// Step 4: Download the result directly from iLovePDF server.
  /// Returns the local path to the downloaded file.
  static Future<String> downloadFile(String server, String taskId, String token,
      String originalFileName, String targetExtension) async {
    try {
      final String downloadUrl = 'https://$server/v1/download/$taskId';
      final directory = await getApplicationDocumentsDirectory();

      final nameWithoutExt = p.basenameWithoutExtension(originalFileName);
      final String filePath = p.join(
          directory.path, '${nameWithoutExt}_caseflow.$targetExtension');

      await _dio.download(
        downloadUrl,
        filePath,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      return filePath;
    } catch (e) {
      throw Exception('Failed to download file from iLovePDF: $e');
    }
  }

  /// Complete workflow helper — runs all 4 steps in sequence.
  static Future<String> runTool({
    required String tool,
    required File inputFile,
    required String targetExtension,
    Map<String, dynamic>? params,
    Function(double)? onProgress,
  }) async {
    // 1. Start (via proxy — gets token securely)
    if (onProgress != null) onProgress(0.1);
    final taskData = await startTask(tool);
    final String server = taskData['server'];
    final String taskId = taskData['task'];
    final String token = taskData['token'];

    // 2. Upload (direct to iLovePDF with proxy-provided token)
    if (onProgress != null) onProgress(0.3);
    await uploadFile(server, taskId, token, inputFile);

    // 3. Process (via proxy)
    if (onProgress != null) onProgress(0.6);
    await processTask(server, taskId, tool, token, params: params);

    // 4. Download (direct from iLovePDF with token)
    if (onProgress != null) onProgress(0.8);
    final outputPath = await downloadFile(
        server, taskId, token, inputFile.path, targetExtension);

    if (onProgress != null) onProgress(1.0);
    return outputPath;
  }
}
