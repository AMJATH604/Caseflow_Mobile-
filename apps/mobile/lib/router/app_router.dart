import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/app_shell.dart';
import '../pages/dashboard_screen.dart';
import '../pages/cases_screen.dart';
import '../pages/case_detail_screen.dart';
import '../pages/clients_screen.dart';
import '../pages/hearings_screen.dart';
import '../pages/payments_screen.dart';
import '../pages/efiling_screen.dart';
import '../pages/certified_copies_screen.dart';
import '../pages/portals_screen.dart';
import '../pages/tools_screen.dart';
import '../pages/notifications_screen.dart';
import '../pages/upgrade_screen.dart';
import '../pages/login_screen.dart';
import '../pages/splash_screen.dart';
import '../pages/collaborator_invitations_screen.dart';
import '../pages/firm_management_screen.dart';
import '../pages/tools/advocate_directory_screen.dart';
import '../pages/commissions_screen.dart';
import '../pages/commission_detail_screen.dart';
import '../pages/ai_chat_screen.dart';
import '../pages/notification_diagnostic_screen.dart';


class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn = state.matchedLocation == '/login';
    final isSplash = state.matchedLocation == '/splash';

    // Allow splash screen to finish its animation
    if (isSplash) return null;

    if (session == null) {
      return isLoggingIn ? null : '/login';
    }

    if (isLoggingIn || isSplash) {
      // Usually after login, go to Dashboard. But if they need to complete profile,
      // the AppShell listener handles it. Let's redirect to / initially.
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/cases',
          builder: (context, state) => const CasesScreen(),
        ),
        GoRoute(
          path: '/cases/:id',
          builder: (context, state) => CaseDetailScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/clients',
          builder: (context, state) => const ClientsScreen(),
        ),
        GoRoute(
          path: '/hearings',
          builder: (context, state) => const HearingsScreen(),
        ),
        GoRoute(
          path: '/payments',
          builder: (context, state) => const PaymentsScreen(),
        ),
        GoRoute(
          path: '/efiling',
          builder: (context, state) => const EFilingScreen(),
        ),
        GoRoute(
          path: '/certified-copies',
          builder: (context, state) => const CertifiedCopiesScreen(),
        ),
        GoRoute(
          path: '/portals',
          builder: (context, state) => const PortalsScreen(),
        ),
        GoRoute(
          path: '/tools',
          builder: (context, state) => const ToolsScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/upgrade',
          builder: (context, state) => const UpgradeScreen(),
        ),
        GoRoute(
          path: '/firm',
          builder: (context, state) => const FirmManagementScreen(),
        ),
        GoRoute(
          path: '/advocate-directory',
          builder: (context, state) => const AdvocateDirectoryScreen(),
        ),
        GoRoute(
          path: '/collaborator-invitations',
          builder: (context, state) => const CollaboratorInvitationsScreen(),
        ),
        GoRoute(
          path: '/commissions',
          builder: (context, state) => const CommissionsScreen(),
        ),
        GoRoute(
          path: '/commissions/:id',
          builder: (context, state) => CommissionDetailScreen(commissionId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/ai-chat',
          builder: (context, state) => const AiChatScreen(),
        ),
        GoRoute(
          path: '/notification-diagnostics',
          builder: (context, state) => const NotificationDiagnosticScreen(),
        ),

      ],
    ),
  ],
);
