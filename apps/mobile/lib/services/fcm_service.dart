import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // For rootNavigatorKey
import 'package:go_router/go_router.dart';

/// Handles Firebase Cloud Messaging (FCM) for server-side push notifications.
/// Includes WhatsApp-style rich notifications with Reply, Mark as Read actions.
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  String? _currentToken;
  bool _listenersRegistered = false;
  bool _localNotificationsInitialized = false;

  // ─── Notification Channel IDs ──────────────────────────
  static const _chamberChannelId = 'chat_messages';
  static const _chamberChannelName = 'Chat Messages';
  static const _dmChannelId = 'dm_messages';
  static const _dmChannelName = 'Direct Messages';

  // ─── Action IDs ────────────────────────────────────────
  static const _actionReply = 'REPLY';
  static const _actionMarkRead = 'MARK_READ';

  /// Initialize FCM: request permission, get token, store in Supabase.
  /// Call this after the user is authenticated.
  Future<void> initialize() async {
    debugPrint('FCM: Starting initialization...');

    // Initialize local notifications first
    await _initLocalNotifications();

    // Step 1: Request permission & register token
    await _registerFcmToken();

    // Step 2: Setup message listeners (only once)
    _setupListeners();

    debugPrint('FCM: Initialization complete');
  }

  /// Initialize flutter_local_notifications with Android settings and actions.
  Future<void> _initLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationAction,
    );

    _localNotificationsInitialized = true;
    debugPrint('FCM: Local notifications initialized');
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

    // Handle foreground messages — show rich notification
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM: Foreground message: ${message.notification?.title}');
      _showRichNotification(message);
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
      await Supabase.instance.client.from('fcm_tokens').upsert({
        'user_id': user.id,
        'token': token,
        'device_info': defaultTargetPlatform.toString(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,token');
      debugPrint('FCM: ✅ Token successfully upserted to database.');
    } catch (e) {
      debugPrint('FCM: ❌ Error storing token: $e');
      // Retry once
      try {
        await Future.delayed(const Duration(seconds: 2));
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          debugPrint('FCM: Retrying token upsert...');
          await Supabase.instance.client.from('fcm_tokens').upsert({
            'user_id': user.id,
            'token': token,
            'device_info': defaultTargetPlatform.toString(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id,token');
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

  // ─── Rich Notification Display ─────────────────────────────

  /// Show a WhatsApp-style rich notification with Reply and Mark as Read actions.
  Future<void> _showRichNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? 'CaseFlow';
    final body = message.notification?.body ?? '';
    final data = message.data;
    final type = data['type'] ?? '';
    final senderName = data['sender_name'] ?? title;

    // Determine channel based on message type
    final isDm = type == 'dm_message';
    final channelId = isDm ? _dmChannelId : _chamberChannelId;
    final channelName = isDm ? _dmChannelName : _chamberChannelName;

    // Create notification with actions
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: senderName,
        summaryText: isDm ? 'Direct Message' : (data['channel'] ?? 'Chambers'),
      ),
      actions: [
        const AndroidNotificationAction(
          _actionReply,
          'Reply',
          showsUserInterface: false,
          inputs: [
            AndroidNotificationActionInput(
              label: 'Type a message...',
            ),
          ],
        ),
        const AndroidNotificationAction(
          _actionMarkRead,
          'Mark as Read',
          showsUserInterface: false,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    // Use a unique ID based on conversation/channel
    final notifId = isDm
        ? (data['conversation_id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch) % 2147483647
        : (data['firm_id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch) % 2147483647;

    await _localNotifications.show(
      notifId.abs(),
      senderName,
      body,
      details,
      payload: jsonEncode(data),
    );
  }

  // ─── Notification Actions ──────────────────────────────────

  /// Handle notification tap — deep-link to chat screen.
  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('FCM: Notification tapped. Payload: ${response.payload}');

    if (response.payload == null) return;

    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _navigateToChat(data);
    } catch (e) {
      debugPrint('FCM: Error parsing notification payload: $e');
    }
  }

  /// Handle background notification actions (Reply, Mark as Read).
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationAction(NotificationResponse response) {
    debugPrint('FCM: Background action: ${response.actionId}');

    if (response.payload == null) return;

    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      final type = data['type'] ?? '';
      final isDm = type == 'dm_message';

      if (response.actionId == _actionReply) {
        final replyText = response.input;
        if (replyText != null && replyText.isNotEmpty) {
          _handleReplyAction(data, replyText, isDm);
        }
      } else if (response.actionId == _actionMarkRead) {
        _handleMarkReadAction(data, isDm);
      }
    } catch (e) {
      debugPrint('FCM: Error handling action: $e');
    }
  }

  /// Send a reply directly from the notification.
  static Future<void> _handleReplyAction(
    Map<String, dynamic> data,
    String replyText,
    bool isDm,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      if (isDm) {
        // Send DM reply
        final conversationId = data['conversation_id'];
        if (conversationId == null) return;

        // Get sender's name
        final profile = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .single();

        await supabase.from('direct_messages').insert({
          'conversation_id': conversationId,
          'sender_id': user.id,
          'message': replyText,
        });

        // Update conversation's last_message_at
        await supabase.from('direct_conversations').update({
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', conversationId);

        debugPrint('FCM: ✅ DM reply sent from notification');
      } else {
        // Send chambers reply
        final firmId = data['firm_id'];
        final caseId = data['case_id'];
        if (firmId == null) return;

        final profile = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .single();

        await supabase.from('case_discussions').insert({
          'firm_id': firmId,
          'case_id': (caseId != null && caseId.isNotEmpty) ? caseId : null,
          'sender_id': user.id,
          'sender_name': profile['full_name'] ?? 'You',
          'message': replyText,
        });

        debugPrint('FCM: ✅ Chambers reply sent from notification');
      }
    } catch (e) {
      debugPrint('FCM: ❌ Reply action failed: $e');
    }
  }

  /// Mark messages as read from the notification.
  static Future<void> _handleMarkReadAction(
    Map<String, dynamic> data,
    bool isDm,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      if (isDm) {
        final conversationId = data['conversation_id'];
        if (conversationId == null) return;

        await supabase
            .from('direct_messages')
            .update({'is_read': true})
            .eq('conversation_id', conversationId)
            .neq('sender_id', user.id)
            .eq('is_read', false);

        debugPrint('FCM: ✅ DM messages marked as read');
      }
      // For chambers, no explicit read tracking needed

      // Dismiss the notification
      final notifId = isDm
          ? (data['conversation_id']?.hashCode ?? 0) % 2147483647
          : (data['firm_id']?.hashCode ?? 0) % 2147483647;

      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(notifId.abs());

      debugPrint('FCM: ✅ Notification dismissed after mark-as-read');
    } catch (e) {
      debugPrint('FCM: ❌ Mark as read failed: $e');
    }
  }

  /// Navigate to the appropriate chat screen.
  static void _navigateToChat(Map<String, dynamic> data) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    final type = data['type'] ?? '';

    if (type == 'dm_message') {
      final conversationId = data['conversation_id'];
      if (conversationId != null) {
        GoRouter.of(ctx).push('/dm/$conversationId');
      }
    } else if (type == 'chat_message') {
      GoRouter.of(ctx).push('/chambers');
    }
  }

  /// Handle when user taps on a Firebase notification (background/terminated).
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('FCM: Message tap: ${message.data}');
    _navigateToChat(message.data);
  }

  // ─── In-App Notification Banner (Foreground) ──────────────

  /// Also shows a slide-down banner for extra visibility in foreground.
  static OverlayEntry? _currentOverlay;

  void showInAppBanner({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    final overlay = Overlay.of(ctx);

    // Remove existing notification if any
    _currentOverlay?.remove();
    _currentOverlay = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _NotificationBanner(
        title: title,
        body: body,
        channelContext: data?['channel'] ?? '',
        onDismiss: () {
          entry.remove();
          if (_currentOverlay == entry) _currentOverlay = null;
        },
        onTap: () {
          entry.remove();
          if (_currentOverlay == entry) _currentOverlay = null;
          if (data != null) _navigateToChat(data);
        },
      ),
    );

    _currentOverlay = entry;
    overlay.insert(entry);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (_currentOverlay == entry) {
        entry.remove();
        _currentOverlay = null;
      }
    });
  }
}

/// A WhatsApp-style notification banner widget with slide-in animation.
class _NotificationBanner extends StatefulWidget {
  final String title;
  final String body;
  final String channelContext;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _NotificationBanner({
    required this.title,
    required this.body,
    required this.channelContext,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! < 0) {
              widget.onDismiss();
            }
          },
          child: Container(
            margin: EdgeInsets.only(top: topPadding, left: 8, right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                // Avatar icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'now',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
