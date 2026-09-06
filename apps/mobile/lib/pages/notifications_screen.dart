import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../components/empty_state_widget.dart';
import '../components/error_state_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationsScreen extends ConsumerWidget {
  NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(casesProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 24.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Updates',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 24.sp : 28.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Recent activity across your practice',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: casesAsync.when(
              data: (cases) => _buildActivityFeed(cases),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
              error:
                  (err, stack) => ErrorStateWidget(
                    error: err,
                    onRetry: () => ref.invalidate(casesProvider),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed(List<CaseModel> items) {
    if (items.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.notifications_none,
        title: 'No Recent Updates',
        message:
            'When your cases, clients, or payments are modified, the activity log will appear here.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 80.h),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
            ),
            boxShadow: AppTheme.shadowSm,
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 6.h,
            ),
            leading: _buildIcon(item.status),
            title: Text(
              item.caseTitle,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
                color: const Color(0xFF0F172A),
              ),
            ),
            subtitle: Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                'Updated to ${item.status.name}',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
            trailing: Text(
              DateFormat('HH:mm').format(DateTime.now()),
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                color: const Color(0xFFCBD5E1),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon(CaseStatus status) {
    IconData icon = Icons.info_outline_rounded;
    Color color = AppTheme.accent;
    final String statusStr = status.toString().split('.').last;

    if (statusStr == 'active') {
      icon = Icons.gavel_rounded;
      color = AppTheme.warning;
    } else if (statusStr == 'closed') {
      icon = Icons.check_circle_rounded;
      color = AppTheme.success;
    }

    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: color.withValues(alpha: 0.1),
        ),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
