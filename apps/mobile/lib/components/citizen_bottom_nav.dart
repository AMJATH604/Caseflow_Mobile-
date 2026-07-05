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

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.grey,
          ),
        ),
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
            // Active indicator line
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2.h,
              width: isActive ? 24 : 0,
              margin: EdgeInsets.only(bottom: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(1.r),
              ),
            ),
            Icon(
              icon,
              color:
                  isActive ? const Color(0xFF10B981) : const Color(0xFF4B5563),
              size: 22,
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
