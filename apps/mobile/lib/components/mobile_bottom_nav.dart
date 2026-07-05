import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import 'mobile_more_sheet.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MobileBottomNav extends ConsumerWidget {
  const MobileBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                0,
                Icons.grid_view_rounded,
                'Home',
                '/',
              ),
              _buildNavItem(
                ref,
                context,
                1,
                Icons.folder_rounded,
                'Cases',
                '/cases',
              ),
              _buildNavItem(
                ref,
                context,
                2,
                Icons.gavel_rounded,
                'Hearings',
                '/hearings',
              ),
              _buildNavItem(
                ref,
                context,
                3,
                Icons.handyman_rounded,
                'Tools',
                '/tools',
              ),
              _buildMoreItem(context),
            ],
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
      child: SizedBox(
        width: 64.w,
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
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(1.r),
              ),
            ),
            Icon(
              icon,
              color: isActive ? AppTheme.accent : const Color(0xFF4B5563),
              size: 22,
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppTheme.accent : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreItem(BuildContext context) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const MobileMoreSheet(),
        );
      },
      child: SizedBox(
        width: 64.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10.h),
            const Icon(
              Icons.more_horiz_rounded,
              color: Color(0xFF4B5563),
              size: 22,
            ),
            SizedBox(height: 4.h),
            Text(
              'More',
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
