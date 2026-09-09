import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../models/notification_models.dart';
import '../theme/app_theme.dart';
import '../components/empty_state_widget.dart';
import '../components/error_state_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The Notification Centre — everything that happened across the practice in
/// the last 24 hours, in one place.
///
/// This replaced a placeholder that listed the user's *cases* and stamped
/// every row with `DateTime.now()`. Rows now come from `public.notifications`,
/// written by the notification edge functions and database triggers, and are
/// purged server-side after 24 hours.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 24.sp : 28.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        unreadCount > 0
                            ? '$unreadCount unread · cleared after 24 hours'
                            : 'Cleared automatically after 24 hours',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unreadCount > 0)
                  TextButton(
                    onPressed: () async {
                      await SupabaseService.markAllNotificationsRead();
                      ref.invalidate(notificationsProvider);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Mark all read',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: notificationsAsync.when(
              data: (items) => _buildFeed(context, ref, items),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
              error:
                  (err, stack) => ErrorStateWidget(
                    error: err,
                    onRetry: () => ref.invalidate(notificationsProvider),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> items,
  ) {
    if (items.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: () async => ref.invalidate(notificationsProvider),
        // A scrollable is required for pull-to-refresh to work on an empty list.
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 40.h),
            EmptyStateWidget(
              icon: Icons.notifications_none,
              title: 'All caught up',
              message:
                  'Hearing reminders, caveat alerts, invitations and case '
                  'activity land here. Notifications clear automatically '
                  'after 24 hours.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: () async => ref.invalidate(notificationsProvider),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 80.h),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildTile(context, ref, items[index]),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    WidgetRef ref,
    AppNotification item,
  ) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.only(right: 20.w),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppTheme.error,
          size: 22,
        ),
      ),
      onDismissed: (_) async {
        await SupabaseService.dismissNotification(item.id);
        ref.invalidate(notificationsProvider);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          // Unread rows are tinted and outlined in the type's accent colour so
          // the feed is scannable without reading it.
          color: item.isUnread
              ? item.color.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: item.isUnread
                ? item.color.withValues(alpha: 0.25)
                : const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          ),
          boxShadow: AppTheme.shadowSm,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () async {
            if (item.isUnread) {
              await SupabaseService.markNotificationRead(item.id);
              ref.invalidate(notificationsProvider);
            }
            final route = item.route;
            if (route != null && route.isNotEmpty && context.mounted) {
              context.push(route);
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIcon(item),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontWeight:
                              item.isUnread ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 14.sp,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      if (item.body.isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          item.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            height: 1.45,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.relativeTime,
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        color: const Color(0xFFCBD5E1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.isUnread) ...[
                      SizedBox(height: 6.h),
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(AppNotification item) {
    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            item.color.withValues(alpha: 0.12),
            item.color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: item.color.withValues(alpha: 0.1)),
      ),
      child: Icon(item.icon, color: item.color, size: 20),
    );
  }
}
