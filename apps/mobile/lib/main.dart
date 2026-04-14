import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/app_constants.dart';
import 'services/providers.dart';
import 'services/fcm_service.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';

/// Top-level handler for background/terminated FCM messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM: Background message: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first
  await Firebase.initializeApp();

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

  // Initialize FCM if user is already signed in (app restart scenario)
  if (Supabase.instance.client.auth.currentSession != null) {
    await FcmService().initialize();
  }

  // Listen for future auth changes to init/cleanup FCM
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    if (data.event == AuthChangeEvent.signedIn) {
      await FcmService().initialize();
    }
  });

  runApp(
    const ProviderScope(
      child: CaseFlowApp(),
    ),
  );
}

class CaseFlowApp extends ConsumerStatefulWidget {
  const CaseFlowApp({super.key});

  @override
  ConsumerState<CaseFlowApp> createState() => _CaseFlowAppState();
}

class _CaseFlowAppState extends ConsumerState<CaseFlowApp> with WidgetsBindingObserver {
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
