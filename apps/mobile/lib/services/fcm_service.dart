import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // For rootNavigatorKey
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'supabase_service.dart';
import 'app_constants.dart';
import 'notification_prefs.dart';

/// Handles Firebase Cloud Messaging (FCM) for server-side push notifications.
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

  // ─── Active Chat Tracking (suppress notifications when viewing that chat) ─
  /// Set this to the current conversation ID when the user opens a DM chat.
  /// Clear it (set to null) when the user leaves the DM chat.
  String? activeConversationId;

  /// Set to true when the user is viewing the Digital Chambers chat screen.
  /// Set to false when they leave.
  bool isInChambersChat = false;

  // ─── Notification Channel IDs ──────────────────────────
  static const _chamberChannelId = 'chat_messages_v2';
  static const _chamberChannelName = 'Digital Chambers Messages';
  static const _dmChannelId = 'dm_messages_v2';
  static const _dmChannelName = 'Direct Messages';
  static const _hearingChannelId = 'hearing_reminders_v2';
  static const _hearingChannelName = 'Hearing Reminders';

  /// Initialize FCM: request permission, get token, store in Supabase.
  /// Call this after the user is authenticated.
  Future<void> initialize() async {
    debugPrint('FCM: Starting initialization...');

    // Initialize local notifications first
    await initLocalNotifications();

    // Step 1: Request permission & register token
    await _registerFcmToken();

    // Step 2: Setup message listeners (only once)
    _setupListeners();

    debugPrint('FCM: Initialization complete');
  }

  /// Initialize flutter_local_notifications with Android and iOS settings.
  Future<void> initLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
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

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _prepareIos();
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

  /// iOS needs two things before pushes work as on Android.
  ///
  /// While the app is open, iOS must not show the push itself: the app draws
  /// its own notification in [FirebaseMessaging.onMessage] (and leaves it out
  /// when that chat is already on screen), so iOS showing one too would
  /// double it. When the app is in the background or closed, iOS shows the
  /// `aps.alert` text the server sends — the app is not involved.
  ///
  /// And Firebase can only issue a token once Apple has given the phone its
  /// push token. On a first launch that can take a few seconds, and asking
  /// for the FCM token before it arrives fails, which left the phone with no
  /// token and no pushes at all.
  Future<void> _prepareIos() async {
    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
    } catch (e) {
      debugPrint('FCM: iOS presentation options failed: $e');
    }
    for (var i = 0; i < 10; i++) {
      try {
        if (await _messaging.getAPNSToken() != null) return;
      } catch (_) {
        // Not ready yet.
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    debugPrint(
      'FCM: ⚠️ No APNs token after 10s. Check the Push Notifications '
      'capability and the APNs key in Firebase.',
    );
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

    // Handle foreground messages — show rich notification or in-app banner
    FirebaseMessaging.onMessage.listen((message) {
      final data = message.data;
      final type = data['type'] ?? '';
      final title = data['title'] ?? message.notification?.title ?? 'CaseFlow';
      final body = data['body'] ?? message.notification?.body ?? '';
      debugPrint('FCM: Foreground message: type=$type, title=$title');

      // A DM push arriving means this device has received the message → stamp
      // it delivered so the sender's tick becomes a grey double-tick, even if
      // the recipient isn't on the chat screen. Fire-and-forget.
      if (type == 'dm_message') {
        SupabaseService.markAllIncomingMessagesDelivered().catchError(
          (e) => debugPrint('FCM: mark delivered failed: $e'),
        );
      }

      // ── Active chat suppression (WhatsApp-style) ──────────────
      // If the user is currently viewing the same conversation,
      // don't show a notification — the message already appears in the chat.
      if (type == 'dm_message' &&
          activeConversationId != null &&
          data['conversation_id'] == activeConversationId) {
        debugPrint('FCM: Suppressed — user is in this DM conversation');
        return;
      }
      if (type == 'chat_message' && isInChambersChat) {
        debugPrint('FCM: Suppressed — user is in Chambers chat');
        return;
      }

      // Show the rich local notification (notification tray)
      showRichNotification(message);
    });

    // Handle background/terminated tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check if app was opened from a Firebase notification (terminated state)
    _messaging.getInitialMessage().then((initialMessage) {
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }
    });

    // Check if app was launched by tapping a flutter_local_notifications
    // notification (cold start). This handles the case where the app was
    // fully killed and the user taps our rich notification to open it.
    _localNotifications.getNotificationAppLaunchDetails().then((details) {
      if (details != null &&
          details.didNotificationLaunchApp &&
          details.notificationResponse != null) {
        debugPrint('FCM: App launched from local notification tap');
        _onNotificationTap(details.notificationResponse!);
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

  // ─── Simple Local Notification Display ─────────────────────────────

  /// Show a simple local notification when app is in foreground.
  Future<void> showRichNotification(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] ?? '';
    // Data-only messages: read title/body from the data block.
    // Fallback to notification block for legacy/iOS compatibility.
    final title = data['title'] ?? message.notification?.title ?? 'CaseFlow';
    final body = data['body'] ?? message.notification?.body ?? '';

    final isDm = type == 'dm_message';
    final isChat = type == 'chat_message';

    // Settings → Notifications. Until now these switches were never read by
    // anything, so turning DMs off changed nothing. Checking here is what
    // makes them real: the pushes are data-only, so if we don't draw the
    // notification, none appears.
    final prefs = await NotificationPrefs.load();
    if (!prefs.allows(type)) {
      debugPrint('FCM: "$type" suppressed by notification settings');
      return;
    }

    // Route to appropriate channel
    String channelId;
    String channelName;
    if (isDm) {
      channelId = _dmChannelId;
      channelName = _dmChannelName;
    } else if (isChat) {
      channelId = _chamberChannelId;
      channelName = _chamberChannelName;
    } else {
      channelId = _hearingChannelId;
      channelName = _hearingChannelName;
    }

    // Android pins sound and vibration to a channel at creation time and
    // ignores playSound/enableVibration on later notifications, so the only
    // way to honour those two switches is to post to a different channel.
    // The suffix is empty when both are on, leaving the original channels —
    // and any customisation the user made to them in Android — untouched.
    channelId = '$channelId${prefs.channelSuffix}';
    channelName = '$channelName${prefs.channelLabel}';

    // Build MessagingStyleInformation for messaging notifications (WhatsApp-style)
    StyleInformation styleInformation;
    if (isDm || isChat) {
      final senderName = data['sender_name'] ?? title.replaceAll('💬 ', '');
      const mePerson = Person(name: 'You', key: 'user_me');
      final senderPerson = Person(
        name: senderName,
        key: data['sender_id'] ?? senderName,
      );

      styleInformation = MessagingStyleInformation(
        mePerson,
        conversationTitle: isChat ? 'Digital Chambers' : null,
        groupConversation: isChat,
        messages: [Message(body, DateTime.now(), senderPerson)],
      );
    } else {
      styleInformation = BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'CaseFlow',
      );
    }

    List<AndroidNotificationAction>? actions;
    if (isDm || isChat) {
      actions = [
        const AndroidNotificationAction(
          'action_reply',
          'Reply',
          inputs: [AndroidNotificationActionInput(label: 'Type a reply...')],
          showsUserInterface: false,
        ),
        const AndroidNotificationAction(
          'action_mark_read',
          'Mark as Read',
          showsUserInterface: false,
        ),
      ];
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.max,
      playSound: prefs.sound,
      enableVibration: prefs.vibration,
      styleInformation: styleInformation,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF00A884),
      category: AndroidNotificationCategory.message,
      actions: actions,
      groupKey:
          isDm
              ? 'dm_${data['conversation_id']}'
              : (isChat ? 'chat_${data['firm_id']}' : null),
    );

    final details = NotificationDetails(android: androidDetails);

    // Use a unique ID based on conversation/channel/hearing
    final notifId =
        isDm
            ? (data['conversation_id']?.hashCode ??
                    DateTime.now().millisecondsSinceEpoch) %
                2147483647
            : isChat
            ? (data['firm_id']?.hashCode ??
                    DateTime.now().millisecondsSinceEpoch) %
                2147483647
            : (data['hearing_id']?.hashCode ??
                    data['caveat_id']?.hashCode ??
                    DateTime.now().millisecondsSinceEpoch) %
                2147483647;

    await _localNotifications.show(
      notifId.abs(),
      title,
      body,
      details,
      payload: jsonEncode(data),
    );
  }

  // ─── Notification Actions ──────────────────────────────────

  /// Handle notification tap & quick actions — inline reply / mark read / deep-link.
  static void _onNotificationTap(NotificationResponse response) async {
    debugPrint(
      'FCM: Notification action/tap received: ${response.actionId}, payload: ${response.payload}',
    );

    if (response.payload == null) return;

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.payload!) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('FCM: Notification payload could not be decoded: $e');
      return;
    }
    final type = data['type'] ?? '';

    try {
      // Handle Quick Reply Action
      if (response.actionId == 'action_reply' &&
          response.input != null &&
          response.input!.trim().isNotEmpty) {
        final replyText = response.input!.trim();
        if (type == 'dm_message') {
          final conversationId = data['conversation_id'];
          if (conversationId != null) {
            await SupabaseService.sendDirectMessage(conversationId, replyText);
            debugPrint('FCM: Quick reply sent to DM $conversationId');
          }
        } else if (type == 'chat_message') {
          final firmId = data['firm_id'];
          final profile = await SupabaseService.fetchProfile();
          if (firmId != null) {
            await SupabaseService.postDiscussion({
              'firm_id': firmId,
              'message': replyText,
              'case_id':
                  data['case_id'] != null &&
                          data['case_id'].toString().isNotEmpty
                      ? data['case_id']
                      : null,
              'sender_name': profile?.fullName ?? 'Team Member',
            });
            debugPrint('FCM: Quick reply sent to Chambers $firmId');
          }
        }
        if (response.id != null) {
          _instance._localNotifications.cancel(response.id!);
        }
        return; // Quick reply handled, do not navigate
      }

      // Handle Mark as Read Action
      if (response.actionId == 'action_mark_read') {
        if (type == 'dm_message') {
          final conversationId = data['conversation_id'];
          if (conversationId != null) {
            await SupabaseService.markDirectMessagesRead(conversationId);
            debugPrint('FCM: Marked conversation $conversationId as read');
          }
        }
        if (response.id != null) {
          _instance._localNotifications.cancel(response.id!);
        }
        return; // Mark as read handled, do not navigate
      }

      // Body tap: Navigate to target chat screen
      _navigateToChat(data);
    } catch (e, stack) {
      debugPrint('FCM: Error handling notification tap: $e\n$stack');
      // Same reasoning as the background path: never drop a typed reply
      // without telling the user.
      await _notifyBackgroundActionFailed(response, data, e);
    }
  }

  /// Navigate to the appropriate chat screen.
  static void _navigateToChat(Map<String, dynamic> data) {
    debugPrint('FCM: Navigating to chat screen with data: $data');
    final type = data['type'] ?? '';

    // Wait until context is ready and router is fully initialized
    Future.delayed(const Duration(milliseconds: 500), () {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) {
        debugPrint('FCM: Navigation context is null. Retrying in 1.5s...');
        Future.delayed(const Duration(milliseconds: 1500), () {
          final retryCtx = rootNavigatorKey.currentContext;
          if (retryCtx != null) {
            _performNavigation(retryCtx, type, data);
          } else {
            debugPrint('FCM: Retry failed - context still null.');
          }
        });
      } else {
        _performNavigation(ctx, type, data);
      }
    });
  }

  static void _performNavigation(
    BuildContext ctx,
    String type,
    Map<String, dynamic> data,
  ) {
    try {
      if (type == 'dm_message') {
        // ─── 1-on-1 DM notification → open DM chat ──────────
        final conversationId = data['conversation_id'];
        if (conversationId != null && conversationId.toString().isNotEmpty) {
          debugPrint('FCM: Pushing route /dm/$conversationId');
          GoRouter.of(ctx).push('/dm/$conversationId');
        } else {
          debugPrint('FCM: conversation_id is null for dm_message');
        }
      } else if (type == 'chat_message') {
        // ─── Digital Chambers notification → open chambers ───
        debugPrint('FCM: Pushing route /chambers-chat');
        GoRouter.of(ctx).push('/chambers-chat');
      } else if (type == 'hearing_reminder' || type == 'court_diary') {
        // ─── Court Diary / Hearing Reminder → Hearings tab ──
        // A reminder is about the day's list, not one case, and the case is a
        // tap away from there. `go`, not `push`: Hearings is a bottom-nav tab,
        // and pushing it would stack a second copy over whatever was open
        // instead of switching tabs.
        debugPrint('FCM: Going to /hearings');
        GoRouter.of(ctx).go('/hearings');
      } else if (type == 'caveat_reminder') {
        // ─── Caveat Reminder → open caveats screen ──────────
        final route = data['route']?.toString() ?? '/caveats';
        debugPrint('FCM: Pushing route $route');
        GoRouter.of(ctx).push(route);
      } else if (type == 'invitation') {
        // ─── Firm/Case Invitation → open the Invitations screen ──
        final route = data['route']?.toString() ?? '/collaborator-invitations';
        debugPrint('FCM: Pushing route $route');
        GoRouter.of(ctx).push(route);
      } else {
        // ─── Fallback: detect from payload fields ────────────
        final conversationId = data['conversation_id'];
        final caseId = data['case_id'];
        final route = data['route'];
        if (conversationId != null && conversationId.toString().isNotEmpty) {
          debugPrint('FCM: Fallback → /dm/$conversationId');
          GoRouter.of(ctx).push('/dm/$conversationId');
        } else if (caseId != null && caseId.toString().isNotEmpty) {
          debugPrint('FCM: Fallback → /cases/$caseId');
          GoRouter.of(ctx).push('/cases/$caseId');
        } else if (route != null && route.toString().isNotEmpty) {
          debugPrint('FCM: Fallback → $route');
          GoRouter.of(ctx).push(route.toString());
        } else {
          debugPrint(
            'FCM: Unknown notification type "$type" with no matching payload',
          );
        }
      }
    } catch (e) {
      debugPrint('FCM: Navigation failed with error: $e');
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
      builder:
          (context) => _NotificationBanner(
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
      top: 0.h,
      left: 0.w,
      right: 0.w,
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
            margin: EdgeInsets.only(top: topPadding, left: 8.w, right: 8.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color:
                    isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                // Avatar icon
                Container(
                  width: 44.w,
                  height: 44.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12.w),
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
                                fontSize: 14.sp,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'now',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color:
                                  isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        widget.body,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color:
                              isDark
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

/// Top-level callback for handling notification action buttons (Reply / Mark Read)
/// in background or terminated state. Must be marked @pragma('vm:entry-point').
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android runs this in a fresh isolate spawned by flutter_local_notifications,
  // and plugins are NOT registered there. ensureInitialized() above sets up the
  // binding but not the plugin registry, so without this line
  // `shared_preferences` is unavailable — and that is exactly where
  // supabase_flutter persists the session. The session could then never be read,
  // requireAuth() always threw, and the reply was lost while Android kept
  // spinning on the notification waiting for us to finish.
  DartPluginRegistrant.ensureInitialized();
  debugPrint(
    'FCM: Background notification action: ${response.actionId}, input: ${response.input}',
  );

  if (response.payload == null) return;

  final Map<String, dynamic> data;
  try {
    data = jsonDecode(response.payload!) as Map<String, dynamic>;
  } catch (e) {
    debugPrint('FCM: Background payload could not be decoded: $e');
    return;
  }
  final type = data['type'] ?? '';

  try {
    // Android runs this in a fresh isolate with no memory of the running app,
    // so the Supabase client and the signed-in session both have to be
    // re-established before any write. Without a session `requireAuth()`
    // throws and the reply is lost.
    final session = await _ensureBackgroundSession();
    if (session == null) {
      throw StateError(
        'no authenticated Supabase session in background isolate',
      );
    }

    if (response.actionId == 'action_reply' &&
        response.input != null &&
        response.input!.trim().isNotEmpty) {
      final replyText = response.input!.trim();

      if (type == 'dm_message') {
        final conversationId = data['conversation_id'];
        if (conversationId == null) {
          throw StateError('reply payload is missing conversation_id');
        }
        await SupabaseService.sendDirectMessage(conversationId, replyText);
        debugPrint('FCM: Background quick reply sent to DM $conversationId');
      } else if (type == 'chat_message') {
        final firmId = data['firm_id'];
        if (firmId == null) {
          throw StateError('reply payload is missing firm_id');
        }
        final profile = await SupabaseService.fetchProfile();
        await SupabaseService.postDiscussion({
          'firm_id': firmId,
          'message': replyText,
          'case_id':
              data['case_id'] != null && data['case_id'].toString().isNotEmpty
                  ? data['case_id']
                  : null,
          'sender_name': profile?.fullName ?? 'Team Member',
        });
        debugPrint('FCM: Background quick reply sent to Chambers $firmId');
      }
    } else if (response.actionId == 'action_mark_read') {
      if (type == 'dm_message') {
        final conversationId = data['conversation_id'];
        if (conversationId != null) {
          await SupabaseService.markDirectMessagesRead(conversationId);
          debugPrint(
            'FCM: Marked DM conversation $conversationId as read in background',
          );
        }
      }
    }

    // Only dismiss the card once the action actually landed — dismissing on
    // failure is what made a dropped reply invisible.
    if (response.id != null) {
      final localNotif = FlutterLocalNotificationsPlugin();
      await localNotif.cancel(response.id!);
    }
  } catch (e, stack) {
    debugPrint(
      'FCM: Error handling background notification response: $e\n$stack',
    );
    await _notifyBackgroundActionFailed(response, data, e);
  }
}

/// Re-establish Supabase and the signed-in session inside a background isolate.
///
/// Returns null when the user genuinely cannot be authenticated, in which case
/// the caller must not pretend the action succeeded.
@pragma('vm:entry-point')
Future<Session?> _ensureBackgroundSession() async {
  SupabaseClient? client;
  try {
    // Throws if this isolate never ran Supabase.initialize — the usual case.
    client = Supabase.instance.client;
  } catch (_) {
    client = null;
  }

  if (client == null) {
    try {
      // Mirror main.dart's options: a different authFlowType here would not
      // read back the session persisted by the foreground app.
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      client = Supabase.instance.client;
    } catch (e) {
      debugPrint('FCM: Background Supabase.initialize failed: $e');
      return null;
    }
  }

  // Recovery of the persisted session is asynchronous, so a null here right
  // after initialize does not yet mean "signed out". Give it a bounded wait.
  // Android allows a background handler roughly 10s before killing the isolate,
  // and a failure still needs time to post the "Reply not sent" card, so keep
  // this short. With plugins registered the session is normally present on the
  // first check and this loop never runs.
  var session = client.auth.currentSession;
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (session == null && DateTime.now().isBefore(deadline)) {
    await Future.delayed(const Duration(milliseconds: 200));
    session = client.auth.currentSession;
  }
  if (session == null) {
    debugPrint('FCM: Background session never recovered from storage');
    return null;
  }

  // A restored session can already be expired; RLS would reject the insert.
  if (session.isExpired) {
    try {
      final refreshed = await client.auth.refreshSession();
      session = refreshed.session;
      debugPrint('FCM: Background session refreshed');
    } catch (e) {
      debugPrint('FCM: Background session refresh failed: $e');
      return null;
    }
  }

  return session;
}

/// Tell the user their quick reply did not send, instead of dropping it.
///
/// `debugPrint` is compiled out in release builds, so without this a failed
/// reply left no trace anywhere the user could see.
@pragma('vm:entry-point')
Future<void> _notifyBackgroundActionFailed(
  NotificationResponse response,
  Map<String, dynamic> data,
  Object reason,
) async {
  // Only a reply carries content that would otherwise be lost. A failed
  // "mark as read" is safe to ignore — the badge simply stays.
  if (response.actionId != 'action_reply') return;
  final attempted = response.input?.trim() ?? '';
  if (attempted.isEmpty) return;

  final type = data['type'] ?? '';
  final channelId =
      type == 'chat_message'
          ? FcmService._chamberChannelId
          : FcmService._dmChannelId;
  final channelName =
      type == 'chat_message'
          ? FcmService._chamberChannelName
          : FcmService._dmChannelName;

  try {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await plugin.show(
      // Reuse the original id so this replaces the message card rather than
      // stacking a second one under it.
      response.id ?? DateTime.now().millisecondsSinceEpoch % 2147483647,
      'Reply not sent',
      'Tap to open the chat and send it again: "$attempted"',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFFDC2626),
          styleInformation: BigTextStyleInformation(
            'Tap to open the chat and send it again:\n"$attempted"',
            contentTitle: 'Reply not sent',
            summaryText: 'CaseFlow',
          ),
        ),
      ),
      // Keep the original payload so tapping still deep-links to the chat.
      payload: response.payload,
    );
  } catch (e) {
    debugPrint(
      'FCM: Could not surface failed-reply notification: $e ($reason)',
    );
  }
}
