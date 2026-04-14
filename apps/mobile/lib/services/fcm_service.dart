import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles Firebase Cloud Messaging (FCM) for server-side push notifications.
/// Manages device token registration, refresh, and removal.
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  String? _currentToken;

  /// Initialize FCM: request permission, get token, store in Supabase.
  /// Call this after the user is authenticated.
  Future<void> initialize() async {
    try {
      // Initialize local notifications for foreground popups
      const androidInit = AndroidInitializationSettings('ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
      await _localNotificationsPlugin.initialize(settings: initSettings);

      // Create the Android Notification Channel (must match AndroidManifest)
      const channel = AndroidNotificationChannel(
        'hearing_reminders', // id
        'Hearing Reminders', // title
        description: 'Notifications for upcoming court hearings', // description
        importance: Importance.high,
      );
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Request notification permission (required for Android 13+)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Explicitly request permissions for flutter_local_notifications on Android 13+
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('FCM: User denied notification permission');
        return;
      }

      // Get the FCM device token
      final token = await _messaging.getToken();
      if (token != null) {
        _currentToken = token;
        // We always try to store the token on initialization to ensure it's fresh
        await _storeToken(token);
        debugPrint('FCM: Initial token registered: ${token.substring(0, 8)}...');
      } else {
        debugPrint('FCM: Failed to get token on initialization');
      }

      // Listen for token refresh (happens when app is reinstalled, etc.)
      _messaging.onTokenRefresh.listen((newToken) async {
        // Remove old token if exists
        if (_currentToken != null && _currentToken != newToken) {
          await _deleteToken(_currentToken!);
        }
        _currentToken = newToken;
        await _storeToken(newToken);
        debugPrint('FCM: Token refreshed');
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background/terminated tap
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }
    } catch (e) {
      debugPrint('FCM: Initialization error: $e');
    }
  }

  /// Store the FCM token in Supabase `fcm_tokens` table.
  Future<void> _storeToken(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('fcm_tokens').upsert(
        {
          'user_id': user.id,
          'token': token,
          'device_info': defaultTargetPlatform.toString(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );
    } catch (e) {
      debugPrint('FCM: Error storing token: $e');
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

      // Delete from Supabase
      await Supabase.instance.client
          .from('fcm_tokens')
          .delete()
          .eq('user_id', user.id);

      // Delete the local FCM instance token
      await _messaging.deleteToken();
      _currentToken = null;
      debugPrint('FCM: Token removed on sign-out');
    } catch (e) {
      debugPrint('FCM: Error removing token: $e');
    }
  }

  /// Handle a notification received while the app is in the foreground.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM: Foreground message: ${message.notification?.title}');
    
    // Manually trigger the local notification banner when app is open
    final notification = message.notification;

    if (notification != null) {
      _localNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'hearing_reminders',
            'Hearing Reminders',
            channelDescription: 'Notifications for upcoming court hearings',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_launcher',
          ),
        ),
      );
    }
  }

  /// Handle when user taps on a notification (from background/terminated).
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('FCM: Message tap: ${message.data}');
    // Could navigate to case details based on message.data['case_id']
    // For now, the app will just open to the default screen
  }
}
