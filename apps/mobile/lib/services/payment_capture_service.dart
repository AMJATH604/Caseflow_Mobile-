import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PaymentCaptureService {
  static final PaymentCaptureService _instance = PaymentCaptureService._internal();
  factory PaymentCaptureService() => _instance;
  PaymentCaptureService._internal();

  static const _fileName = 'pending_payment.json';

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  /// Sets the pending payment state before the user leaves for a portal.
  Future<void> setPendingPayment({
    required String caseId,
    required String caseTitle,
    String? certifiedCopyId,
    String purpose = 'Court Fee',
  }) async {
    final file = await _getFile();
    final data = {
      'caseId': caseId,
      'caseTitle': caseTitle,
      'certifiedCopyId': certifiedCopyId,
      'purpose': purpose,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await file.writeAsString(json.encode(data));
  }

  /// Retrieves and CLEARS the pending payment state.
  Future<Map<String, dynamic>?> getAndClearPendingPayment() async {
    final file = await _getFile();
    if (await file.exists()) {
      final content = await file.readAsString();
      await file.delete(); 
      
      final data = json.decode(content);
      final timestamp = DateTime.parse(data['timestamp']);
      
      // If the intent is older than 2 hours, ignore it
      if (DateTime.now().difference(timestamp).inHours > 2) {
        return null;
      }
      
      return data;
    }
    return null;
  }
}
