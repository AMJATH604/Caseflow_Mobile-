import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../components/mobile_bottom_nav.dart';
import '../components/citizen_bottom_nav.dart';
import '../components/app_sidebar.dart';
import '../components/global_search_delegate.dart';
import '../components/profile_avatar.dart';
import '../components/profile_detail_sheet.dart';
import '../services/back_interceptors.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final bool isGuest;

  const AppShell({super.key, required this.child, this.isGuest = false});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Determine if user is a citizen (guest or logged-in citizen)
    final bool isCitizenMode;
    if (widget.isGuest) {
      isCitizenMode = true;
    } else {
      final profileAsync = ref.watch(userProfileProvider);
      isCitizenMode =
          profileAsync.whenOrNull(data: (profile) => profile.isCitizen) ??
          false;
    }

    final appTitle = isCitizenMode ? 'CaseFlow' : 'CaseFlow';
    final homeRoute =
        widget.isGuest
            ? '/guest-home'
            : (isCitizenMode ? '/citizen-home' : '/');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        // A screen may be showing something the router cannot see — Tools
        // renders a tool by state, not by route. Ask before treating this as
        // navigation, or back from an open tool skips to the dashboard.
        if (BackInterceptors.handleBackPress()) return;

        final location = GoRouterState.of(context).matchedLocation;

        // If on dashboard, double-tap to exit
        if (location == '/' ||
            location == '/citizen-home' ||
            location == '/guest-home') {
          final now = DateTime.now();
          if (_lastBackPress != null &&
              now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
            // Actually exit the app
            SystemNavigator.pop();
            return;
          }
          _lastBackPress = now;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    Icons.exit_to_app_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 8.w),
                  Text('Press back again to exit CaseFlow'),
                ],
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              backgroundColor: const Color(0xFF334155),
            ),
          );
          return;
        }

        // Try to pop one step back in the navigation stack first
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        } else {
          // At a top-level tab (e.g., /cases, /hearings) — go to dashboard
          context.go(homeRoute);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar:
            isMobile
                ? AppBar(
                  backgroundColor:
                      Theme.of(context).appBarTheme.backgroundColor,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  centerTitle: false,
                  title: GestureDetector(
                    onTap: () => context.go(homeRoute),
                    child: Text(
                      'CaseFlow',
                      style: Theme.of(
                        context,
                      ).appBarTheme.titleTextStyle?.copyWith(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  actions: [
                    if (!widget.isGuest) ...[
                      if (isCitizenMode)
                        IconButton(
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFE11D48),
                          ),
                          tooltip: 'Sign Out',
                          onPressed: () async {
                            await SupabaseService.signOut();
                          },
                        )
                      else ...[
                        IconButton(
                          icon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF6B7280),
                          ),
                          onPressed: () {
                            showSearch(
                              context: context,
                              delegate: GlobalSearchDelegate(),
                            );
                          },
                        ),
                        // Profile avatar in AppBar
                        Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: Builder(
                            builder: (context) {
                              final profileAsync = ref.watch(userProfileProvider);
                              final profile = profileAsync.valueOrNull;
                              return ProfileAvatar(
                                avatarUrl: profile?.avatarUrl,
                                name: profile?.fullName,
                                radius: 14,
                                borderWidth: 1.5,
                                onTap: () => ProfileDetailSheet.show(context),
                              );
                            },
                          ),
                        ),
                      ],
                      SizedBox(width: 4.w),
                    ] else ...[
                      TextButton.icon(
                        onPressed: () => context.go('/role-selection'),
                        icon: const Icon(
                          Icons.login_rounded,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        label: Text(
                          'Sign Up',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),
                    ],
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(
                      height: 1.h,
                      color: Theme.of(context).dividerTheme.color,
                    ),
                  ),
                )
                : null,
        body: Row(
          children: [
            if (!isMobile && !isCitizenMode) AppSidebar(),
            Expanded(
              child: Column(
                children: [
                  // ── Offline Banner ──────────────────────────────────
                  Consumer(
                    builder: (context, ref, _) {
                      final isOnline = ref.watch(connectivityStreamProvider).value ?? true;
                      if (isOnline) return const SizedBox.shrink();
                      return Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 16.w),
                        color: const Color(0xFFF59E0B), // Amber 500
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off_rounded, size: 14.sp, color: Colors.white),
                            SizedBox(width: 8.w),
                            Text(
                              'Offline Mode — Showing cached data',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (!isMobile)
                    Container(
                      height: 64.h,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        border: Border(
                          bottom: BorderSide(
                            color:
                                Theme.of(context).dividerTheme.color ??
                                Colors.grey,
                          ),
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Row(
                        children: [
                          Text(
                            'CaseFlow Registry',
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFCBD5E1)
                                      : Colors.black26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: AppTheme.cardDecoration(
                              isDark:
                                  Theme.of(context).brightness ==
                                  Brightness.dark,
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppTheme.surfaceLight
                                      : Colors.black.withValues(alpha: 0.03),
                            ),
                            child: InkWell(
                              onTap: () {
                                showSearch(
                                  context: context,
                                  delegate: GlobalSearchDelegate(),
                                );
                              },
                              borderRadius: BorderRadius.circular(12.r),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFCBD5E1)
                                            : Colors.black38,
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(
                                    'Search cases, clients...',
                                    style: GoogleFonts.inter(
                                      color:
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFFCBD5E1)
                                              : Colors.black38,
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 0 : 24),
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar:
            isMobile
                ? (isCitizenMode
                    ? const CitizenBottomNav()
                    : const MobileBottomNav())
                : null,
      ),
    );
  }
}
