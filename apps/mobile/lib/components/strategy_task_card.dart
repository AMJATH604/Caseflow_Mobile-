import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/strategy_models.dart';
import '../theme/app_theme.dart';

/// A single task card displayed on the Kanban board.
///
/// Shows title, priority indicator, assignee avatar, due date,
/// and comment/attachment counts. Tapping opens the detail sheet.
class StrategyTaskCard extends StatelessWidget {
  final StrategyTask task;
  final VoidCallback onTap;

  const StrategyTaskCard({
    super.key,
    required this.task,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.isOverdue;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isOverdue
                ? AppTheme.error.withValues(alpha: 0.4)
                : AppTheme.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Priority + Title ────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPriorityDot(),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    task.title,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                      decoration: task.stage == TaskStage.done
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (task.description != null &&
                task.description!.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text(
                task.description!,
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            SizedBox(height: 8.h),

            // ─── Footer: Assignee + Due Date + Counts ─
            Row(
              children: [
                // Assignee
                if (task.assignedToName != null) ...[
                  _buildAssigneeChip(),
                  const Spacer(),
                ] else ...[
                  const Spacer(),
                ],

                // Comment count
                if (task.commentCount > 0) ...[
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 12.sp,
                    color: const Color(0xFF94A3B8),
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    '${task.commentCount}',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],

                // Attachment count
                if (task.attachmentCount > 0) ...[
                  Icon(
                    Icons.attach_file,
                    size: 12.sp,
                    color: const Color(0xFF94A3B8),
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    '${task.attachmentCount}',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],

                // Due date
                if (task.dueDate != null) _buildDueDateChip(isOverdue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityDot() {
    Color color;
    switch (task.priority) {
      case TaskPriority.urgent:
        color = AppTheme.error;
        break;
      case TaskPriority.high:
        color = AppTheme.warning;
        break;
      case TaskPriority.medium:
        color = const Color(0xFFFBBF24);
        break;
      case TaskPriority.low:
        color = AppTheme.success;
        break;
    }
    return Container(
      margin: EdgeInsets.only(top: 4.h),
      width: 8.w,
      height: 8.w,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildAssigneeChip() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 10.r,
          backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
          backgroundImage: task.assignedToAvatarUrl != null
              ? NetworkImage(task.assignedToAvatarUrl!)
              : null,
          child: task.assignedToAvatarUrl == null
              ? Text(
                  (task.assignedToName ?? '?')[0].toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                )
              : null,
        ),
        SizedBox(width: 4.w),
        Text(
          _shortenName(task.assignedToName ?? ''),
          style: GoogleFonts.inter(
            fontSize: 10.sp,
            color: const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildDueDateChip(bool isOverdue) {
    final dateStr = DateFormat('dd MMM').format(task.dueDate!);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: isOverdue
            ? AppTheme.error.withValues(alpha: 0.1)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue ? Icons.warning_amber_rounded : Icons.calendar_today,
            size: 10.sp,
            color: isOverdue ? AppTheme.error : const Color(0xFF64748B),
          ),
          SizedBox(width: 3.w),
          Text(
            dateStr,
            style: GoogleFonts.inter(
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              color: isOverdue ? AppTheme.error : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  /// Shorten names like "Muhammad Amjath" → "Amjath"
  String _shortenName(String name) {
    final parts = name.trim().split(' ');
    if (parts.length <= 1) return name;
    return parts.last;
  }
}
