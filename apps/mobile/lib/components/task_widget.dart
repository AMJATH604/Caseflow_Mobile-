import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TaskWidget extends ConsumerStatefulWidget {
  const TaskWidget({super.key});

  @override
  ConsumerState<TaskWidget> createState() => _TaskWidgetState();
}

class _TaskWidgetState extends ConsumerState<TaskWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(tasksProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header with gradient ─────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20.w, 18.h, 12.w, 0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [Colors.white, const Color(0xFFF8FAFC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Progress ring
                    tasksAsync.when(
                      data: (tasks) => _buildProgressRing(tasks, isDark),
                      loading: () => SizedBox(
                        width: 44.w,
                        height: 44.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppTheme.accent.withValues(alpha: 0.3),
                        ),
                      ),
                      error: (_, __) => SizedBox(width: 44.w, height: 44.w),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Tasks',
                            style: GoogleFonts.inter(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          tasksAsync.when(
                            data: (tasks) {
                              final done =
                                  tasks.where((t) => t.isCompleted).length;
                              return Text(
                                '$done of ${tasks.length} completed',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    // Add button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showAddTaskSheet(context),
                        borderRadius: BorderRadius.circular(12.r),
                        child: Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: AppTheme.accent,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                // ─── Tab Bar ─────────────────────────────
                Container(
                  height: 36.h,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: isDark
                          ? AppTheme.accent.withValues(alpha: 0.2)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                      ],
                    ),
                    dividerColor: Colors.transparent,
                    labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
                    unselectedLabelColor: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    labelPadding: EdgeInsets.zero,
                    tabs: const [
                      Tab(text: 'All'),
                      Tab(text: 'Pending'),
                      Tab(text: 'Done'),
                    ],
                  ),
                ),
                SizedBox(height: 4.h),
              ],
            ),
          ),

          // ─── Task List ─────────────────────────────────
          tasksAsync.when(
            data: (tasks) {
              final filtered = _filterTasks(tasks);
              if (filtered.isEmpty) {
                return _buildEmptyState(isDark);
              }
              return Padding(
                padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 12.h),
                child: Column(
                  children: filtered
                      .map((task) => _buildTaskItem(task, isDark))
                      .toList(),
                ),
              );
            },
            loading: () => Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.accent,
                  strokeWidth: 2.5,
                ),
              ),
            ),
            error: (err, _) => _buildErrorState(isDark),
          ),
        ],
      ),
    );
  }

  List<TaskModel> _filterTasks(List<TaskModel> tasks) {
    switch (_tabController.index) {
      case 1:
        return tasks.where((t) => !t.isCompleted).toList();
      case 2:
        return tasks.where((t) => t.isCompleted).toList();
      default:
        return tasks;
    }
  }

  Widget _buildProgressRing(List<TaskModel> tasks, bool isDark) {
    final total = tasks.length;
    final done = tasks.where((t) => t.isCompleted).length;
    final progress = total > 0 ? done / total : 0.0;

    return SizedBox(
      width: 44.w,
      height: 44.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44.w,
            height: 44.w,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0
                    ? const Color(0xFF10B981)
                    : AppTheme.accent,
              ),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            total > 0 ? '${(progress * 100).round()}%' : '—',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(TaskModel task, bool isDark) {
    final isCompleted = task.isCompleted;
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        margin: EdgeInsets.symmetric(vertical: 3.h),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
      ),
      confirmDismiss: (_) async {
        await SupabaseService.deleteTask(task.id);
        ref.invalidate(tasksProvider);
        return false;
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 3.h),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
          child: InkWell(
            borderRadius: BorderRadius.circular(12.r),
            onTap: () async {
              if (!isCompleted) {
                // Marking as completed → ask for confirmation
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    final dlgDark = Theme.of(ctx).brightness == Brightness.dark;
                    return AlertDialog(
                      backgroundColor: dlgDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      icon: Container(
                        width: 48.w,
                        height: 48.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Color(0xFF10B981),
                          size: 28,
                        ),
                      ),
                      title: Text(
                        'Mark as Completed?',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 17.sp,
                          color: dlgDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Are you sure you want to mark "${task.title}" as completed? This action can be undone.',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              color: dlgDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 20.h),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 12.h),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    side: BorderSide(
                                      color: dlgDark
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.sp,
                                      color: dlgDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 12.h),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                  child: Text(
                                    'Complete',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
                if (confirm != true) return;
              }
              await SupabaseService.updateTask(
                  task.id, {'is_completed': !isCompleted});
              ref.invalidate(tasksProvider);
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 14.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : (isCompleted
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFAFAFA)),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : (isCompleted
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFF1F5F9)),
                ),
              ),
              child: Row(
                children: [
                  // Animated checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24.w,
                    height: 24.w,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7.r),
                      border: Border.all(
                        color: isCompleted
                            ? const Color(0xFF10B981)
                            : (isDark
                                ? const Color(0xFF475569)
                                : const Color(0xFFCBD5E1)),
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Text(
                      task.title,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight:
                            isCompleted ? FontWeight.w400 : FontWeight.w500,
                        color: isCompleted
                            ? (isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8))
                            : (isDark
                                ? Colors.white
                                : const Color(0xFF1E293B)),
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Priority dot
                  Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final labels = ['No tasks yet', 'All done! 🎉', 'Nothing completed yet'];
    final icons = [
      Icons.task_alt_rounded,
      Icons.celebration_rounded,
      Icons.pending_actions_rounded,
    ];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 24.w),
      child: Column(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.accent.withValues(alpha: 0.08)
                  : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icons[_tabController.index],
              color: isDark
                  ? const Color(0xFF64748B)
                  : const Color(0xFF94A3B8),
              size: 28,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            labels[_tabController.index],
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? const Color(0xFF64748B)
                  : const Color(0xFF94A3B8),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            _tabController.index == 0
                ? 'Tap + to add your first task'
                : (_tabController.index == 1
                    ? 'All tasks are completed'
                    : 'Complete a task to see it here'),
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: isDark
                  ? const Color(0xFF475569)
                  : const Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            size: 32,
          ),
          SizedBox(height: 8.h),
          Text(
            'Unable to load tasks',
            style: GoogleFonts.inter(
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          TextButton.icon(
            onPressed: () => ref.invalidate(tasksProvider),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              'Retry',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
          ),
        ],
      ),
    );
  }

  void _showAddTaskSheet(BuildContext context) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          24.w,
          20.h,
          24.w,
          MediaQuery.of(ctx).viewInsets.bottom + 24.h,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'New Task',
              style: GoogleFonts.inter(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'What needs to be done?',
                hintStyle: GoogleFonts.inter(
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                  fontSize: 15.sp,
                ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(
                    color: AppTheme.accent,
                    width: 1.5,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w, vertical: 14.h),
              ),
              onSubmitted: (val) async {
                if (val.trim().isNotEmpty) {
                  await SupabaseService.createTask(val.trim());
                  ref.invalidate(tasksProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isNotEmpty) {
                    await SupabaseService.createTask(
                        controller.text.trim());
                    ref.invalidate(tasksProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: Text(
                  'Add Task',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 15.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
