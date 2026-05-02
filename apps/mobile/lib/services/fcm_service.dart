import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // For rootNavigatorKey

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

    // Handle foreground messages — show in-app notification banner
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM: Foreground message: ${message.notification?.title}');
      final title = message.notification?.title;
      final body = message.notification?.body;
      final data = message.data;

      if (title != null) {
        _showInAppNotification(
          title: title,
          body: body ?? '',
          data: data,
        );
      }
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
    // Future: deep-link to specific chat/case based on message.data
  }

  // ─── In-App Notification Banner ─────────────────────────────
  /// Shows a WhatsApp-style notification banner at the top of the screen
  /// when a message arrives while the app is in the foreground.
  static OverlayEntry? _currentOverlay;

  void _showInAppNotification({
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

  const _NotificationBanner({
    required this.title,
    required this.body,
    required this.channelContext,
    required this.onDismiss,
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
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
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
          onTap: widget.onDismiss,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
              widget.onDismiss();
            }
          },
          child: Container(
            margin: EdgeInsets.only(top: topPadding, left: 8, right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // App icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 20),
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
                                fontSize: 13,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.channelContext.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.channelContext,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.body,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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

