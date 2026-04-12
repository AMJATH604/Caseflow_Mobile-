import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A helper that wraps Supabase calls with automatic retry + session recovery.
/// Handles AuthRetryableFetchException by refreshing the session before retrying.
class RetryHelper {
  /// Execute a Supabase operation with retry logic.
  /// - [maxRetries]: Maximum number of retries (default: 3)
  /// - [initialDelay]: Initial delay between retries in ms (default: 1000)
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    int initialDelay = 1000,
  }) async {
    int attempt = 0;
    
    while (true) {
      try {
        return await operation().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Request timed out after 15 seconds'),
        );
      } catch (e) {
        attempt++;
        
        // If we've exhausted retries, throw the error
        if (attempt >= maxRetries) {
          rethrow;
        }
        
        // If it's an auth-related timeout, try to recover the session
        if (_isAuthError(e)) {
          await _tryRecoverSession();
        }
        
        // Exponential backoff: 1s, 2s, 4s...
        final delay = initialDelay * (1 << (attempt - 1));
        await Future.delayed(Duration(milliseconds: delay));
      }
    }
  }
  
  /// Check if the error is an auth-related timeout
  static bool _isAuthError(Object e) {
    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('authretryablefetchexception') ||
           errorStr.contains('refresh_token') ||
           errorStr.contains('connection timed out') ||
           errorStr.contains('socketexception');
  }
  
  /// Attempt to recover the session by refreshing it
  static Future<void> _tryRecoverSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await Supabase.instance.client.auth.refreshSession();
      }
    } catch (_) {
      // Session recovery failed — will be caught by next retry attempt
    }
  }
}
