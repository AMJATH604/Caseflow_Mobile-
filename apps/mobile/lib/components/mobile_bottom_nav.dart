import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/providers.dart';
import '../services/app_localizations.dart';
import '../utils/app_fonts.dart';
import '../theme/app_theme.dart';
import 'mobile_more_sheet.dart';
import 'notification_badge.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MobileBottomNav extends ConsumerWidget {
  const MobileBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
            border: const Border(
              top: BorderSide(
                color: Color(0xFFE2E8F0),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: SizedBox(
              height: 60.h,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    ref,
                    context,
                    0,
                    Icons.grid_view_rounded,
                    l10n.get('nav_home'),
                    '/',
                  ),
                  _buildNavItem(
                    ref,
                    context,
                    1,
                    Icons.folder_rounded,
                    l10n.get('nav_cases'),
                    '/cases',
                  ),
                  _buildNavItem(
                    ref,
                    context,
                    2,
                    Icons.gavel_rounded,
                    l10n.get('nav_hearings'),
                    '/hearings',
                  ),
                  _buildNavItem(
                    ref,
                    context,
                    3,
                    Icons.handyman_rounded,
                    l10n.get('nav_tools'),
                    '/tools',
                  ),
                  _buildMoreItem(ref, context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    WidgetRef ref,
    BuildContext context,
    int index,
    IconData icon,
    String label,
    String route,
  ) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final isActive = currentIndex == index;

    return InkWell(
      onTap: () {
        ref.read(navigationIndexProvider.notifier).state = index;
        context.go(route);
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 64.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated pill indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              height: 3.h,
              width: isActive ? 28 : 0,
              margin: EdgeInsets.only(bottom: 6.h),
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accentViolet],
                      )
                    : null,
                borderRadius: BorderRadius.circular(2.r),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
            // Animated icon scale
            AnimatedScale(
              scale: isActive ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Icon(
                icon,
                color: isActive ? AppTheme.accent : const Color(0xFF94A3B8),
                size: 22,
              ),
            ),
            SizedBox(height: 3.h),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppTheme.accent : const Color(0xFF94A3B8),
                letterSpacing: isActive ? 0.2 : 0,
              ).indicSafe,
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreItem(WidgetRef ref, BuildContext context) {
    // Notifications live inside the More sheet, so without a badge out here
    // the unread count is invisible until the user thinks to open the sheet.
    final unreadCount =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => MobileMoreSheet(),
        );
      },
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 64.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 9.h),
            NotificationBadge(
              count: unreadCount,
              top: -4,
              right: -8,
              child: const Icon(
                Icons.more_horiz_rounded,
                color: Color(0xFF94A3B8),
                size: 22,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              AppLocalizations.of(context).get('nav_more'),
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF94A3B8),
              ).indicSafe,
            ),
          ],
        ),
      ),
    );
  }
}
