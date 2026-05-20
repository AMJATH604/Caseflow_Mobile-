import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // Import rootNavigatorKey
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

import '../pages/login_screen.dart';
import '../pages/splash_screen.dart';
import '../pages/onboarding_screen.dart';
import '../pages/role_selection_screen.dart';
import '../pages/citizen_home_screen.dart';
import '../pages/citizen_tools_screen.dart';
import '../pages/track_case_screen.dart';
import '../pages/collaborator_invitations_screen.dart';
import '../pages/firm_management_screen.dart';
import '../pages/tools/advocate_directory_screen.dart';
import '../pages/commissions_screen.dart';
import '../pages/commission_detail_screen.dart';
import '../pages/ai_chat_screen.dart';
import '../pages/caveats_screen.dart';
import '../pages/legal_pulse_screen.dart';
import '../pages/chambers_chat_screen.dart';


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

/// Tracks whether the app is in guest mode (browsing without login).
/// This is set by RoleSelectionScreen and checked by the router redirect.
class GuestModeService {
  static bool isGuestMode = false;
}


final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn = state.matchedLocation == '/login';
    final isSplash = state.matchedLocation == '/splash';
    final isOnboarding = state.matchedLocation == '/onboarding';
    final isRoleSelection = state.matchedLocation == '/role-selection';
    final isGuestRoute = state.matchedLocation.startsWith('/guest');

    // Allow splash, onboarding, and role selection screens without redirect
    if (isSplash || isOnboarding || isRoleSelection) return null;

    // Allow guest mode routes without authentication
    if (GuestModeService.isGuestMode && isGuestRoute) return null;

    if (session == null) {
      // If in guest mode, allow guest routes
      if (GuestModeService.isGuestMode && isGuestRoute) return null;
      return isLoggingIn ? null : '/role-selection';
    }

    if (isLoggingIn) {
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
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/role-selection',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'advocate';
        return LoginScreen(initialRole: role);
      },
    ),

    // ─── Guest Mode Routes (no auth required) ────────────────
    ShellRoute(
      builder: (context, state, child) => AppShell(isGuest: true, child: child),
      routes: [
        GoRoute(
          path: '/guest-home',
          builder: (context, state) => const CitizenHomeScreen(),
        ),
        GoRoute(
          path: '/guest-tools',
          builder: (context, state) {
            final toolId = state.uri.queryParameters['tool'];
            return CitizenToolsScreen(initialToolId: toolId);
          },
        ),
        GoRoute(
          path: '/guest-track-case',
          builder: (context, state) => const TrackCaseScreen(),
        ),
      ],
    ),

    // ─── Authenticated Routes ────────────────────────────────
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
          path: '/caveats',
          builder: (context, state) => const CaveatsScreen(),
        ),
        GoRoute(
          path: '/legal-pulse',
          builder: (context, state) => const LegalPulseScreen(),
        ),
        GoRoute(
          path: '/chambers-chat',
          builder: (context, state) => const ChambersChatScreen(),
        ),
        // ─── Citizen-specific authenticated routes ─────────
        GoRoute(
          path: '/citizen-home',
          builder: (context, state) => const CitizenHomeScreen(),
        ),
        GoRoute(
          path: '/citizen-tools',
          builder: (context, state) {
            final toolId = state.uri.queryParameters['tool'];
            return CitizenToolsScreen(initialToolId: toolId);
          },
        ),
        GoRoute(
          path: '/track-case',
          builder: (context, state) => const TrackCaseScreen(),
        ),
      ],
    ),
  ],
);
