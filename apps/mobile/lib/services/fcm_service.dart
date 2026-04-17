import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Handles Firebase Cloud Messaging (FCM) for server-side push notifications.
/// Manages device token registration, refresh, and removal.
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _currentToken;
  bool _listenersRegistered = false;

  /// Initialize FCM: request permission, get token, store in Supabase.
  /// Call this after the user is authenticated.
  Future<void> initialize() async {
    debugPrint('FCM: Starting initialization...');

    // Step 1: Request permission & register token
    await _registerFcmToken();

    // Step 2: Setup message listeners (only once)
    _setupListeners();

    debugPrint('FCM: Initialization complete');
  }

  /// Register the FCM token with Supabase.
  Future<void> _registerFcmToken() async {
    try {
      // Request notification permission (required for Android 13+)
      try {
        final settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        debugPrint('FCM: Permission status: ${settings.authorizationStatus}');
      } catch (permError) {
        debugPrint('FCM: Permission request error (continuing): $permError');
      }

      // Get the FCM token with retry logic
      String? token;
      for (int i = 0; i < 3; i++) {
        try {
          debugPrint('FCM: Requesting token (attempt ${i + 1}/3)...');
          token = await _messaging.getToken().timeout(
            const Duration(seconds: 15),
          );
          if (token != null) break;
        } catch (e) {
          debugPrint('FCM: Token request attempt ${i + 1} failed: $e');
          if (i < 2) await Future.delayed(const Duration(seconds: 3));
        }
      }

      if (token != null) {
        _currentToken = token;
        await _storeToken(token);
        debugPrint('FCM: ✅ Token registered: ${token.substring(0, 20)}...');
      } else {
        debugPrint('FCM: ❌ Failed to get FCM token after 3 retries!');
      }
    } catch (e, stack) {
      debugPrint('FCM: ❌ Token registration error: $e');
      debugPrint('FCM: Stack: $stack');
    }
  }

  /// Setup FCM message listeners. Only registers once to avoid duplicates.
  void _setupListeners() {
    if (_listenersRegistered) {
      debugPrint('FCM: Listeners already registered, skipping.');
      return;
    }
    _listenersRegistered = true;

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('FCM: Token refresh event received');
      if (_currentToken != null && _currentToken != newToken) {
        await _deleteToken(_currentToken!);
      }
      _currentToken = newToken;
      await _storeToken(newToken);
      debugPrint('FCM: ✅ Token refreshed and stored');
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM: Foreground message: ${message.notification?.title}');
    });

    // Handle background/terminated tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check if app was opened from a notification
    _messaging.getInitialMessage().then((initialMessage) {
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }
    });

    debugPrint('FCM: ✅ Listeners registered');
  }

  /// Store the FCM token in Supabase `fcm_tokens` table.
  Future<void> _storeToken(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('FCM: ❌ Cannot store token — user not authenticated.');
        return;
      }

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        debugPrint('FCM: ❌ Cannot store token — no active session.');
        return;
      }

      debugPrint('FCM: Upserting token for user ${user.id}...');
      await Supabase.instance.client.from('fcm_tokens').upsert(
        {
          'user_id': user.id,
          'token': token,
          'device_info': defaultTargetPlatform.toString(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
      debugPrint('FCM: ✅ Token successfully upserted to database.');
    } catch (e) {
      debugPrint('FCM: ❌ Error storing token: $e');
      // Retry once
      try {
        await Future.delayed(const Duration(seconds: 2));
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          debugPrint('FCM: Retrying token upsert...');
          await Supabase.instance.client.from('fcm_tokens').upsert(
            {
              'user_id': user.id,
              'token': token,
              'device_info': defaultTargetPlatform.toString(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            onConflict: 'user_id,token',
          );
          debugPrint('FCM: ✅ Token retry succeeded.');
        }
      } catch (retryError) {
        debugPrint('FCM: ❌ Token retry also failed: $retryError');
      }
    }
  }

  /// Delete a specific FCM token from Supabase.
  Future<void> _deleteToken(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('fcm_tokens')
          .delete()
          .eq('user_id', user.id)
          .eq('token', token);
    } catch (e) {
      debugPrint('FCM: Error deleting token: $e');
    }
  }

  /// Remove all tokens for current user (called on sign-out).
  Future<void> removeToken() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('fcm_tokens')
          .delete()
          .eq('user_id', user.id);

      await _messaging.deleteToken();
      _currentToken = null;
      debugPrint('FCM: Token removed on sign-out');
    } catch (e) {
      debugPrint('FCM: Error removing token: $e');
    }
  }

  /// Handle when user taps on a notification.
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('FCM: Message tap: ${message.data}');
  }
}
