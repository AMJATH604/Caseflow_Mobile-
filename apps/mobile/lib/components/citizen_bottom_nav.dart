import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CitizenBottomNav extends ConsumerWidget {
  const CitizenBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final isGuest = location.startsWith('/guest');

    final homeRoute = isGuest ? '/guest-home' : '/citizen-home';
    final libraryRoute = isGuest ? '/guest-tools' : '/citizen-tools';
    final trackRoute = isGuest ? '/guest-track-case' : '/track-case';
    const aiRoute = '/ai-chat';

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
                Icons.home_rounded,
                'Home',
                homeRoute,
                location == homeRoute || (location == '/' && !isGuest),
              ),
              _buildNavItem(
                ref,
                context,
                Icons.menu_book_rounded,
                'Library',
                libraryRoute,
                location == libraryRoute,
              ),
              _buildNavItem(
                ref,
                context,
                Icons.search_rounded,
                'Track Case',
                trackRoute,
                location == trackRoute,
              ),
              _buildNavItem(
                ref,
                context,
                Icons.auto_awesome_rounded,
                'AI Help',
                aiRoute,
                location == aiRoute,
              ),
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
    IconData icon,
    String label,
    String route,
    bool isActive,
  ) {
    final location = GoRouterState.of(context).matchedLocation;
    final isGuest = location.startsWith('/guest');

    return InkWell(
      onTap: () {
        if (isGuest && route == '/ai-chat') {
          _showAuthRequiredDialog(context, 'AI Legal Help');
        } else {
          context.go(route);
        }
      },
      child: SizedBox(
        width: 72.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              height: 3.h,
              width: isActive ? 28 : 0,
              margin: EdgeInsets.only(bottom: 6.h),
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF34D399)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(2.r),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
            AnimatedScale(
              scale: isActive ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Icon(
                icon,
                color: isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                size: 22,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color:
                    isActive
                        ? const Color(0xFF10B981)
                        : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuthRequiredDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            backgroundColor:
                Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
            title: Text(
              'Sign In Required',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF0F172A),
              ),
            ),
            content: Text(
              'You need to sign in or create an account to use $featureName.\n\nIt takes less than a minute and unlocks personalized legal tools, saved cases, and AI legal help.',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                height: 1.5.h,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF4B5563),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/login?role=citizen');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Sign In / Sign Up',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
