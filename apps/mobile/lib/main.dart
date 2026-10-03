import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'services/app_constants.dart';
import 'services/providers.dart';
import 'services/fcm_service.dart';
import 'services/analytics_service.dart';
import 'services/payment_capture_service.dart';
import 'components/dialogs/payment_capture_overlay.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'services/app_localizations.dart';
import 'services/locale_service.dart';
import 'services/realtime_sync_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Top-level handler for background/terminated FCM messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM: Background message received: ${message.data}');

  // On iOS the push carries its text in `aps.alert` and iOS shows it itself
  // (see apnsAlert in the edge functions); drawing ours too would double it.
  if (defaultTargetPlatform == TargetPlatform.iOS &&
      message.notification != null) {
    return;
  }

  // Android: show our rich WhatsApp-style notification with inline Reply
  // and Mark Read action buttons. Android messages are data-only (no
  // `notification` block) so the OS never auto-displays a plain
  // notification — all rendering is done here.
  final fcm = FcmService();
  await fcm.initLocalNotifications();
  await fcm.showRichNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── Production Safety: Suppress debug logs in release builds ──
  // Prevents sensitive data (user IDs, FCM tokens, conversation IDs)
  // from appearing in device system logs on production devices.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Initialize Firebase first
  await Firebase.initializeApp();


  // ─── Crashlytics Setup ──────────────────────────────────
  // Catch all Flutter framework errors
  FlutterError.onError = (errorDetails) {
    final errorStr = errorDetails.exception.toString().toLowerCase();

    // Completely ignore network/connectivity errors to reduce noise
    final isNetworkError =
        errorStr.contains('socketexception') ||
        errorStr.contains('authretryablefetchexception') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('handshake') ||
        errorStr.contains('connection closed');

    if (!isNetworkError) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    }
  };

  // Catch async errors not caught by Flutter framework
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorStr = error.toString().toLowerCase();

    // Completely ignore network/connectivity errors to reduce noise
    final isNetworkError =
        errorStr.contains('socketexception') ||
        errorStr.contains('authretryablefetchexception') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('handshake') ||
        errorStr.contains('connection closed');

    if (!isNetworkError) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

  // Register the background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Supabase with custom HTTP timeout settings
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    realtimeClientOptions: const RealtimeClientOptions(
      timeout: Duration(seconds: 30),
    ),
  );

  // Load the saved display language before the first frame, so the app opens
  // directly in the user's language instead of rendering English and then
  // visibly switching.
  final savedLocale = await LocaleService.load();

  // Create a ProviderContainer so we can wire RealtimeSyncService callback
  final container = ProviderContainer(
    overrides: [
      localeProvider.overrideWith((ref) => LocaleNotifier(savedLocale)),
    ],
  );

  // Wire the Realtime callback for table-specific Riverpod invalidations
  RealtimeSyncService().onTableChanged = (table) {
    if (table == 'tasks') {
      container.invalidate(tasksProvider);
    } else if (table == 'strategy_tasks') {
      container.invalidate(myStrategyTasksProvider);
    } else {
      container.read(dataRefreshProvider.notifier).state++;
    }
  };

  // Initialize Realtime if user is already signed in (app restart scenario)
  if (Supabase.instance.client.auth.currentSession != null) {
    Future.delayed(const Duration(seconds: 2), () {
      FcmService().initialize();
      RealtimeSyncService().initialize();
    });
    // Set Crashlytics user identifier
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      FirebaseCrashlytics.instance.setUserIdentifier(userId);
      AnalyticsService.setUserId(userId);
    }
  }

  // Listen for future auth changes to init/cleanup FCM + Realtime
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    if (data.event == AuthChangeEvent.signedIn) {
      Future.delayed(const Duration(seconds: 2), () {
        FcmService().initialize();
        RealtimeSyncService().initialize();
      });
      // Track user in Crashlytics + Analytics on sign-in
      final userId = data.session?.user.id;
      if (userId != null) {
        FirebaseCrashlytics.instance.setUserIdentifier(userId);
        AnalyticsService.setUserId(userId);
      }
    } else if (data.event == AuthChangeEvent.signedOut) {
      FirebaseCrashlytics.instance.setUserIdentifier('');
      AnalyticsService.setUserId(null);
      RealtimeSyncService().dispose();
    }
  });

  runApp(UncontrolledProviderScope(container: container, child: const CaseFlowApp()));
}

/// Global navigator key for showing overlays from lifecycle events.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class CaseFlowApp extends ConsumerStatefulWidget {
  const CaseFlowApp({super.key});

  @override
  ConsumerState<CaseFlowApp> createState() => _CaseFlowAppState();
}

class _CaseFlowAppState extends ConsumerState<CaseFlowApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh FCM token when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      if (Supabase.instance.client.auth.currentSession != null) {
        FcmService().initialize();
        // ── Smart Sync: Check for pending payment on resume ──
        _checkPendingPayment();
      }
    }
  }

  /// Check if the user left to pay on ePay and just returned.
  Future<void> _checkPendingPayment() async {
    try {
      final pending = await PaymentCaptureService().getAndClearPendingPayment();
      if (pending == null) return;

      // Small delay to let the app fully settle before showing overlay
      await Future.delayed(const Duration(milliseconds: 800));

      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        PaymentCaptureOverlay.show(
          ctx,
          caseId: pending['caseId'] as String,
          caseTitle: pending['caseTitle'] as String,
          purpose: pending['purpose'] as String? ?? 'Court Fee',
          certifiedCopyId: pending['certifiedCopyId'] as String?,
        );
      }
    } catch (e) {
      debugPrint('Smart Sync check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    // ScreenUtilInit: design baseline = 390×844 (iPhone 14 / mid-range Android).
    // All R.sp(), R.w(), R.h() values scale proportionally on every device.
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: false,
      builder: (context, child) => MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: appRouter,
        // Driven by the user's choice in Settings, not the device locale —
        // an advocate may run their phone in English but want CaseFlow in Tamil.
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Clamp system text-scale so large-font accessibility settings
        // don't overflow fixed-height containers.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(
                minScaleFactor: 0.8,
                maxScaleFactor: 1.15,
              ),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}
