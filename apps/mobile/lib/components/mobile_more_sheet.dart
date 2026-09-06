import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'dialogs/reset_workspace_dialog.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MobileMoreSheet extends ConsumerWidget {
  MobileMoreSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(28.r),
        topRight: Radius.circular(28.r),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.r),
          topRight: Radius.circular(28.r),
        ),
        boxShadow: AppTheme.shadowLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 14.h),
          // Premium drag handle with gradient
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFCBD5E1),
                  const Color(0xFF94A3B8),
                  const Color(0xFFCBD5E1),
                ],
              ),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'More Hub',
                  style: GoogleFonts.outfit(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildMenuItem(
                context,
                Icons.people,
                'Clients',
                Colors.blue,
                '/clients',
              ),
              _buildMenuItem(
                context,
                Icons.description,
                'E-Filing',
                Colors.green,
                '/efiling',
              ),
              _buildMenuItem(
                context,
                Icons.copy,
                'CC Copies',
                Colors.amber,
                '/certified-copies',
              ),
              _buildMenuItem(
                context,
                Icons.account_balance,
                'Portals',
                Colors.indigo,
                '/portals',
              ),
              _buildMenuItem(
                context,
                Icons.credit_card,
                'Payments',
                Colors.purple,
                '/payments',
              ),

              _buildMenuItem(
                context,
                Icons.assignment_ind_rounded,
                'Commissioner',
                const Color(0xFF7C3AED),
                '/commissions',
              ),
              _buildMenuItem(
                context,
                Icons.gavel_rounded,
                'Caveats',
                const Color(0xFFEA580C),
                '/caveats',
              ),
              _buildMenuItem(
                context,
                Icons.newspaper_rounded,
                'Legal Pulse',
                const Color(0xFFDC2626),
                '/legal-pulse',
              ),
              _buildMenuItem(
                context,
                Icons.account_balance_rounded,
                'My Bar',
                const Color(0xFF0891B2),
                '/bar-association',
              ),
              _buildMenuItem(
                context,
                Icons.notifications,
                'Updates',
                Colors.pink,
                '/notifications',
              ),
              _buildMenuItem(
                context,
                Icons.settings_rounded,
                'Settings',
                const Color(0xFF64748B),
                '/settings',
              ),
            ],
          ),
          SizedBox(height: 24.h),
          const Divider(),
          // Sign Out
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.error),
            title: const Text(
              'Sign Out',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              // Pop the sheet first to avoid blank screen/navigation conflicts
              Navigator.pop(context);
              await SupabaseService.signOut();
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh_rounded, color: AppTheme.error),
            title: const Text(
              'Reset Workspace',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'Delete all cases and data',
              style: TextStyle(fontSize: 10.sp),
            ),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => const ResetWorkspaceDialog(),
              );
            },
          ),
          SizedBox(height: 40.h),
        ],
      ),
    ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    String route,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56.w,
            height: 56.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.12),
                  color.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: color.withValues(alpha: 0.15),
              ),
              boxShadow: AppTheme.shadowSm,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
