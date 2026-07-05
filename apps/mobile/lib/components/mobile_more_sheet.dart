import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'dialogs/reset_workspace_dialog.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MobileMoreSheet extends ConsumerWidget {
  const MobileMoreSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
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
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(fontSize: 22.sp),
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
                Icons.handyman_rounded,
                'Tools',
                Colors.teal,
                '/tools',
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
            subtitle: const Text(
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
              color: color,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF1E293B), size: 24),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}
