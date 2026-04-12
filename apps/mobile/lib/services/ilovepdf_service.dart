import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'app_constants.dart';

class ILovePdfService {
  static final Dio _dio = Dio();
  static const String _baseUrl = 'https://api.ilovepdf.com/v1';

  /// Generates a JWT for iLovePDF authentication.
  /// Note: Ideally this should be done on a secure backend to keep the Secret Key hidden.
  static String _generateToken() {
    final jwt = JWT(
      {
        'jti': DateTime.now().millisecondsSinceEpoch.toString(),
        'iss': AppConstants.iLovePdfPublicKey,
      },
      issuer: AppConstants.iLovePdfPublicKey,
    );
    return jwt.sign(SecretKey(AppConstants.iLovePdfSecretKey));
  }

  /// Step 1: Start a task
  /// Returns a map with 'server' and 'task' (ID).
  static Future<Map<String, dynamic>> startTask(String tool) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/start/$tool',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_generateToken()}',
          },
        ),
      );
      return response.data;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        throw Exception('iLovePDF Authentication Failed. Please check your keys in AppConstants.');
      }
      throw Exception('Failed to start iLovePDF task: ${e.toString()}');
    }
  }

  /// Step 2: Upload a file
  static Future<void> uploadFile(String server, String taskId, File file) async {
    try {
      final String uploadUrl = 'https://$server/v1/upload';
      final formData = FormData.fromMap({
        'task': taskId,
        'file': await MultipartFile.fromFile(file.path, filename: p.basename(file.path)),
      });

      await _dio.post(
        uploadUrl,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_generateToken()}',
          },
        ),
      );
    } catch (e) {
      throw Exception('Failed to upload file to iLovePDF: ${e.toString()}');
    }
  }

  /// Step 3: Process the task
  static Future<void> processTask(String server, String taskId, String tool, {Map<String, dynamic>? params}) async {
    try {
      final String processUrl = 'https://$server/v1/process';
      final Map<String, dynamic> data = {
        'task': taskId,
        'tool': tool,
        ...?params,
      };

      await _dio.post(
        processUrl,
        data: data,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_generateToken()}',
          },
        ),
      );
    } catch (e) {
      throw Exception('Failed to process iLovePDF task: ${e.toString()}');
    }
  }

  /// Step 4: Download the result
  /// Returns the local path to the downloaded file.
  static Future<String> downloadFile(String server, String taskId, String originalFileName, String targetExtension) async {
    try {
      final String downloadUrl = 'https://$server/v1/download/$taskId';
      final directory = await getApplicationDocumentsDirectory();
      
      // Clean up filename (remove old extension)
      final nameWithoutExt = p.basenameWithoutExtension(originalFileName);
      final String filePath = p.join(directory.path, '${nameWithoutExt}_caseflow.$targetExtension');

      await _dio.download(
        downloadUrl,
        filePath,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_generateToken()}',
          },
        ),
      );
      
      return filePath;
    } catch (e) {
      throw Exception('Failed to download file from iLovePDF: $e');
    }
  }

  /// Complete workflow helper
  static Future<String> runTool({
    required String tool,
    required File inputFile,
    required String targetExtension,
    Map<String, dynamic>? params,
    Function(double)? onProgress,
  }) async {
    // onProgress is a bit tricky with distinct steps, we'll manually emit some values
    
    // 1. Start
    if (onProgress != null) onProgress(0.1);
    final taskData = await startTask(tool);
    final String server = taskData['server'];
    final String taskId = taskData['task'];

    // 2. Upload
    if (onProgress != null) onProgress(0.3);
    await uploadFile(server, taskId, inputFile);

    // 3. Process
    if (onProgress != null) onProgress(0.6);
    await processTask(server, taskId, tool, params: params);

    // 4. Download
    if (onProgress != null) onProgress(0.8);
    final outputPath = await downloadFile(server, taskId, inputFile.path, targetExtension);
    
    if (onProgress != null) onProgress(1.0);
    return outputPath;
  }
}
