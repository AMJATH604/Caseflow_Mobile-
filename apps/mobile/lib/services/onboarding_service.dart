import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Tracks whether the user has completed onboarding.
/// Uses a simple file flag in the app's documents directory
/// (no extra dependency needed).
class OnboardingService {
  static const _flagFile = '.onboarding_complete';

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_flagFile');
  }

  /// Returns true if onboarding has already been completed.
  static Future<bool> isOnboardingComplete() async {
    final file = await _getFile();
    return file.existsSync();
  }

  /// Marks onboarding as complete.
  static Future<void> completeOnboarding() async {
    final file = await _getFile();
    await file.writeAsString('done');
  }
}
