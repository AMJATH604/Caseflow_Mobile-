import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'dialogs/reset_workspace_dialog.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppSidebar extends ConsumerWidget {
  AppSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 260.w,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.grey,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'REGISTRY MODULES',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFCBD5E1)
                          : Colors.black38,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              children: [
                _buildMenuItem(
                  context,
                  ref,
                  0,
                  Icons.grid_view_rounded,
                  'Dashboard',
                  '/',
                ),
                _buildMenuItem(
                  context,
                  ref,
                  1,
                  Icons.people_alt_rounded,
                  'Directory',
                  '/clients',
                ),
                _buildMenuItem(
                  context,
                  ref,
                  2,
                  Icons.folder_copy_rounded,
                  'Case Archive',
                  '/cases',
                ),
                _buildMenuItem(
                  context,
                  ref,
                  3,
                  Icons.upload_file_rounded,
                  'E-Filing',
                  '/efiling',
                ),
                _buildMenuItem(
                  context,
                  ref,
                  4,
                  Icons.calendar_month_rounded,
                  'Schedule',
                  '/hearings',
                ),
                _buildMenuItem(
                  context,
                  ref,
                  5,
                  Icons.snippet_folder_rounded,
                  'Cert. Copies',
                  '/certified-copies',
                ),
                _buildMenuItem(
                  context,
                  ref,
                  6,
                  Icons.account_balance_rounded,
                  'Portals',
                  '/portals',
                ),
                _buildMenuItem(
                  context,
                  ref,
                  7,
                  Icons.wallet_rounded,
                  'Finances',
                  '/payments',
                ),
                _buildMenuItem(
                  context,
                  ref,
                  8,
                  Icons.terminal_rounded,
                  'Admin Tools',
                  '/tools',
                ),
                _buildMenuItem(
                  context,
                  ref,
                  9,
                  Icons.assignment_ind_rounded,
                  'Commissioner',
                  '/commissions',
                ),
                _buildMenuItem(
                  context,
                  ref,
                  10,
                  Icons.gavel_rounded,
                  'Caveat Tracker',
                  '/caveats',
                ),
                _buildMenuItem(
                  context,
                  ref,
                  11,
                  Icons.hub_rounded,
                  'Advocate Hub',
                  '/firm',
                ),
                _buildMenuItem(
                  context,
                  ref,
                  12,
                  Icons.account_balance_rounded,
                  'My Bar',
                  '/bar-association',
                ),
              ],
            ),
          ),
          _buildFooter(context, ref),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.1)),
            ),
            child: const Icon(
              Icons.gavel_rounded,
              color: AppTheme.accent,
              size: 22,
            ),
          ),
          SizedBox(width: 14.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CaseFlow',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Professional v1.2',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFCBD5E1)
                          : Colors.black38,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    IconData icon,
    String label,
    String route,
  ) {
    final isActive = ref.watch(navigationIndexProvider) == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.symmetric(vertical: 2.h),
      decoration:
          isActive
              ? BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12.r),
              )
              : null,
      child: ListTile(
        onTap: () {
          ref.read(navigationIndexProvider.notifier).state = index;
          context.go(route);
        },
        dense: true,
        leading: Icon(
          icon,
          color:
              isActive
                  ? AppTheme.accent
                  : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFCBD5E1)
                      : Colors.black38),
          size: 18,
        ),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color:
                isActive
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87)
                    : (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFCBD5E1)
                        : Colors.black38),
            fontSize: 13.sp,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        minLeadingWidth: 20,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? Colors.grey,
          ),
        ),
      ),
      child: Column(
        children: [
          ref
              .watch(userProfileProvider)
              .when(
                data:
                    (profile) => Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      padding: EdgeInsets.all(12.r),
                      decoration: AppTheme.cardDecoration(
                        isDark: Theme.of(context).brightness == Brightness.dark,
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.surfaceLight
                                : Colors.black.withValues(alpha: 0.04),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: AppTheme.accent,
                            size: 18,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'BETA ACCESS',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelSmall?.copyWith(
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white
                                            : Colors.black87,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Unlimited Professional Suite',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelSmall?.copyWith(
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFFCBD5E1)
                                            : Colors.black38,
                                    fontSize: 8.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                loading: () => SizedBox(height: 40.h),
                error: (_, __) => const SizedBox(),
              ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _footerIconBtn(Icons.settings_rounded, () {
                showDialog(
                  context: context,
                  builder: (context) => const ResetWorkspaceDialog(),
                );
              }, context: context),
              _footerIconBtn(
                Icons.logout_rounded,
                () => SupabaseService.signOut(),
                context: context,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footerIconBtn(
    IconData icon,
    VoidCallback onTap, {
    Color? color,
    BuildContext? context,
  }) {
    final isDark =
        context != null
            ? Theme.of(context).brightness == Brightness.dark
            : true;
    return IconButton(
      icon: Icon(
        icon,
        color: color ?? (isDark ? const Color(0xFFCBD5E1) : Colors.black26),
        size: 20,
      ),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
