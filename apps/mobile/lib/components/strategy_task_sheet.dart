import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/strategy_models.dart';
import '../services/repositories/strategy_repository.dart';
import '../theme/app_theme.dart';

/// Bottom sheet showing full task details, comments, and activity log.
class StrategyTaskSheet extends StatefulWidget {
  final StrategyTask task;
  final VoidCallback onChanged;

  const StrategyTaskSheet({
    super.key,
    required this.task,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required StrategyTask task,
    required VoidCallback onChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => StrategyTaskSheet(
          task: task,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  State<StrategyTaskSheet> createState() => _StrategyTaskSheetState();
}

class _StrategyTaskSheetState extends State<StrategyTaskSheet> {
  final _commentController = TextEditingController();
  List<TaskComment> _comments = [];
  List<TaskActivity> _activities = [];
  bool _isLoading = true;
  bool _isSendingComment = false;
  late TaskStage _currentStage;

  @override
  void initState() {
    super.initState();
    _currentStage = widget.task.stage;
    _loadDetails();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    try {
      final results = await Future.wait([
        StrategyRepository.fetchComments(widget.task.id),
        StrategyRepository.fetchActivityLog(widget.task.id),
      ]);
      if (mounted) {
        setState(() {
          _comments = results[0] as List<TaskComment>;
          _activities = results[1] as List<TaskActivity>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSendingComment) return;

    setState(() => _isSendingComment = true);
    try {
      await StrategyRepository.addComment(widget.task.id, text);
      _commentController.clear();
      await _loadDetails();
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _changeStage(TaskStage newStage) async {
    if (newStage == _currentStage) return;
    try {
      await StrategyRepository.moveTask(
        widget.task.id,
        newStage.dbValue,
        0,
      );
      setState(() => _currentStage = newStage);
      widget.onChanged();
      await _loadDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('This task will be removed. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await StrategyRepository.deleteTask(widget.task.id);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
            child: Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent))
                : ListView(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    children: [
                      // ─── Header ────────────────────────
                      Row(
                        children: [
                          _buildPriorityBadge(),
                          const Spacer(),
                          IconButton(
                            onPressed: _deleteTask,
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20.sp,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),

                      // ─── Title ─────────────────────────
                      Text(
                        widget.task.title,
                        style: GoogleFonts.inter(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),

                      // ─── Description ───────────────────
                      if (widget.task.description != null &&
                          widget.task.description!.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Text(
                          widget.task.description!,
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            color: const Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                      ],

                      SizedBox(height: 16.h),
                      const Divider(color: Color(0xFFE2E8F0)),
                      SizedBox(height: 12.h),

                      // ─── Properties ────────────────────
                      _buildPropertyRow(
                        Icons.person_outline,
                        'Assigned to',
                        widget.task.assignedToName ?? 'Unassigned',
                      ),
                      if (widget.task.dueDate != null) ...[
                        SizedBox(height: 8.h),
                        _buildPropertyRow(
                          widget.task.isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.calendar_today,
                          'Due date',
                          '${DateFormat('dd MMM yyyy').format(widget.task.dueDate!)}'
                              '${widget.task.isOverdue ? ' ⚠️ Overdue' : ''}',
                          valueColor: widget.task.isOverdue
                              ? AppTheme.error
                              : null,
                        ),
                      ],
                      SizedBox(height: 8.h),

                      // ─── Stage Selector ────────────────
                      _buildPropertyRow(
                        Icons.view_kanban_outlined,
                        'Stage',
                        '',
                        trailing: _buildStageDropdown(),
                      ),

                      SizedBox(height: 16.h),
                      const Divider(color: Color(0xFFE2E8F0)),
                      SizedBox(height: 12.h),

                      // ─── Comments Section ──────────────
                      Text(
                        '💬 Comments (${_comments.length})',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 10.h),

                      if (_comments.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Text(
                            'No comments yet. Start the discussion.',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: const Color(0xFF94A3B8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        ..._comments.map(_buildCommentTile),

                      SizedBox(height: 12.h),

                      // Comment input
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: GoogleFonts.inter(fontSize: 13.sp),
                              decoration: InputDecoration(
                                hintText: 'Type a comment...',
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 13.sp,
                                  color: const Color(0xFF94A3B8),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 10.h,
                                ),
                              ),
                              textCapitalization:
                                  TextCapitalization.sentences,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          GestureDetector(
                            onTap: _sendComment,
                            child: Container(
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: _isSendingComment
                                  ? SizedBox(
                                      width: 18.w,
                                      height: 18.w,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      Icons.send,
                                      size: 18.sp,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20.h),
                      const Divider(color: Color(0xFFE2E8F0)),
                      SizedBox(height: 12.h),

                      // ─── Activity Log ──────────────────
                      Text(
                        '📜 Activity Log',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 10.h),

                      if (_activities.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Text(
                            'No activity yet.',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        )
                      else
                        ..._activities.map(_buildActivityTile),

                      SizedBox(height: 24.h),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge() {
    Color bg, fg;
    switch (widget.task.priority) {
      case TaskPriority.urgent:
        bg = AppTheme.error.withValues(alpha: 0.1);
        fg = AppTheme.error;
        break;
      case TaskPriority.high:
        bg = AppTheme.warning.withValues(alpha: 0.1);
        fg = AppTheme.warning;
        break;
      case TaskPriority.medium:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case TaskPriority.low:
        bg = AppTheme.success.withValues(alpha: 0.1);
        fg = AppTheme.success;
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        '${widget.task.priority.emoji} ${widget.task.priority.label.toUpperCase()}',
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPropertyRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: const Color(0xFF94A3B8)),
        SizedBox(width: 8.w),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            color: const Color(0xFF94A3B8),
          ),
        ),
        SizedBox(width: 12.w),
        if (trailing != null)
          trailing
        else
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: valueColor ?? const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.right,
            ),
          ),
      ],
    );
  }

  Widget _buildStageDropdown() {
    return Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: DropdownButton<TaskStage>(
          value: _currentStage,
          underline: const SizedBox.shrink(),
          isDense: true,
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1E293B),
          ),
          items: TaskStage.values
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text('${s.emoji} ${s.label}'),
                  ))
              .toList(),
          onChanged: (s) {
            if (s != null) _changeStage(s);
          },
        ),
      ),
    );
  }

  Widget _buildCommentTile(TaskComment c) {
    final timeAgo = _timeAgo(c.createdAt);
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14.r,
            backgroundColor: AppTheme.accent.withValues(alpha: 0.12),
            backgroundImage: c.userAvatarUrl != null
                ? NetworkImage(c.userAvatarUrl!)
                : null,
            child: c.userAvatarUrl == null
                ? Text(
                    (c.userName ?? '?')[0].toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                    ),
                  )
                : null,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c.userName ?? 'Unknown',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      timeAgo,
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  c.content,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(TaskActivity a) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            margin: EdgeInsets.only(top: 6.h),
            decoration: const BoxDecoration(
              color: Color(0xFFCBD5E1),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              '${a.description} · ${_timeAgo(a.createdAt)}',
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt);
  }
}
