import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status.toLowerCase());

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            config.color.withValues(alpha: 0.10),
            config.color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: config.color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 10, color: config.color),
          SizedBox(width: 5.w),
          Text(
            status.isEmpty ? 'UNKNOWN' : status.toUpperCase(),
            style: GoogleFonts.inter(
              color: config.color,
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getConfig(String s) {
    switch (s) {
      case 'active':
      case 'approved':
      case 'paid':
        return const _StatusConfig(AppTheme.success, Icons.check_circle_rounded);
      case 'pending':
      case 'submitted':
      case 'drafting':
      case 'scheduled':
        return const _StatusConfig(AppTheme.warning, Icons.schedule_rounded);
      case 'closed':
      case 'rejected':
      case 'unpaid':
      case 'disposed':
        return const _StatusConfig(AppTheme.error, Icons.cancel_rounded);
      case 'filing':
        return const _StatusConfig(AppTheme.accent, Icons.upload_file_rounded);
      case 'hearing':
      case 'arguments':
        return const _StatusConfig(AppTheme.accentViolet, Icons.gavel_rounded);
      default:
        return const _StatusConfig(
          Color(0xFF6B7280),
          Icons.info_outline_rounded,
        );
    }
  }
}

class _StatusConfig {
  final Color color;
  final IconData icon;
  const _StatusConfig(this.color, this.icon);
}
