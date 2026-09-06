import 'package:flutter/foundation.dart';

/// Production-safe logging utility for CaseFlow.
///
/// All log output is suppressed in release builds automatically.
/// This replaces scattered `debugPrint()` calls throughout the codebase,
/// ensuring no sensitive data (user IDs, tokens, conversation IDs) leaks
/// to device logs in production.
///
/// Usage:
/// ```dart
/// import '../utils/logger.dart';
///
/// Log.d('FCM: Token registered');        // Debug (verbose)
/// Log.i('Payment processed');            // Info
/// Log.w('Cache miss, fetching fresh');    // Warning
/// Log.e('Network request failed', e);    // Error
/// ```
class Log {
  Log._();

  /// Debug-level log. Only prints in debug mode.
  static void d(String message) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
    }
  }

  /// Info-level log. Only prints in debug mode.
  static void i(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  /// Warning-level log. Only prints in debug mode.
  static void w(String message) {
    if (kDebugMode) {
      debugPrint('[WARN] $message');
    }
  }

  /// Error-level log. Only prints in debug mode.
  /// Errors are also recorded to Crashlytics in production via the
  /// global error handlers in main.dart — no need to log them here.
  static void e(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) debugPrint('  → $error');
      if (stackTrace != null) debugPrint('  → $stackTrace');
    }
  }
}
