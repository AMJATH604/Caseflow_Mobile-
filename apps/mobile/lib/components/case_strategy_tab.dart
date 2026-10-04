import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/strategy_models.dart';
import '../services/providers.dart';
import '../services/repositories/strategy_repository.dart';
import '../services/firm_service.dart';
import '../theme/app_theme.dart';
import 'strategy_task_card.dart';
import 'strategy_create_dialog.dart';
import 'strategy_task_sheet.dart';

/// Kanban-style strategy board tab for case detail screen.
///
/// Displays tasks in 5 columns: To Do → In Progress → Review → Filed → Done.
/// Supports drag-and-drop between columns, task creation, and real-time updates.
class CaseStrategyTab extends ConsumerStatefulWidget {
  final String caseId;

  const CaseStrategyTab({super.key, required this.caseId});

  @override
  ConsumerState<CaseStrategyTab> createState() => _CaseStrategyTabState();
}

class _CaseStrategyTabState extends ConsumerState<CaseStrategyTab> {
  List<Map<String, dynamic>> _firmMembers = [];
  bool _membersLoaded = false;

  /// Moves that have been made on screen but not yet confirmed by the server.
  ///
  /// Without this the card visibly snapped back to its original column and
  /// only jumped after the round-trip completed, which read as "the board
  /// isn't updating". Keyed by task id → the stage the user dropped it in.
  /// Entries are cleared once the refetch returns (success) or immediately on
  /// failure, which lets the card fall back to its real stage.
  final Map<String, TaskStage> _pendingMoves = {};

  @override
  void initState() {
    super.initState();
    _loadFirmMembers();
  }

  Future<void> _loadFirmMembers() async {
    try {
      final members = await FirmService.fetchFirmMembers();
      if (mounted) {
        setState(() {
          _firmMembers = members
              .where((m) => m.memberId != null)
              .map((m) => {'id': m.memberId!, 'full_name': m.memberName ?? 'Member'})
              .toList();
          _membersLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _membersLoaded = true);
    }
  }

  void _refresh() {
    ref.invalidate(strategyTasksProvider(widget.caseId));
  }

  Future<void> _createTask() async {
    final result = await StrategyCreateDialog.show(
      context,
      caseId: widget.caseId,
      firmMembers: _firmMembers,
    );
    if (result != null) _refresh();
  }

  Future<void> _onDragAccept(StrategyTask task, TaskStage newStage) async {
    if (task.stage == newStage) return;

    // Show the move immediately, then reconcile with the server.
    setState(() => _pendingMoves[task.id] = newStage);

    try {
      await StrategyRepository.moveTask(task.id, newStage.dbValue, 0);
      if (!mounted) return;
      // Refetch, then drop the optimistic entry so the server's answer wins.
      _refresh();
      setState(() => _pendingMoves.remove(task.id));
    } catch (e) {
      if (!mounted) return;
      // Roll back — the card returns to the column it came from.
      setState(() => _pendingMoves.remove(task.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error moving task: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(strategyTasksProvider(widget.caseId));

    return tasksAsync.when(
      data: (tasks) => _buildBoard(tasks),
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      ),
      error: (err, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading tasks',
                style: GoogleFonts.inter(color: const Color(0xFF64748B))),
            SizedBox(height: 8.h),
            TextButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  /// The stage a task should be drawn in — the optimistic one if a move is
  /// still in flight, otherwise the stage the server reported.
  TaskStage _effectiveStage(StrategyTask task) =>
      _pendingMoves[task.id] ?? task.stage;

  Widget _buildBoard(List<StrategyTask> tasks) {
    // Group tasks by stage, honouring any in-flight moves so the board
    // reflects what the user just did rather than the last server response.
    final grouped = <TaskStage, List<StrategyTask>>{};
    for (final stage in TaskStage.values) {
      grouped[stage] = tasks
          .where((t) => _effectiveStage(t) == stage)
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
    }

    final doneCount = grouped[TaskStage.done]?.length ?? 0;
    final totalCount = tasks.length;
    final progress = totalCount > 0 ? doneCount / totalCount : 0.0;

    return Column(
      children: [
        // ─── Progress bar ────────────────────────
        if (totalCount > 0)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$doneCount / $totalCount tasks done',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: progress >= 1.0
                            ? AppTheme.success
                            : AppTheme.accent,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6.h,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation(
                      progress >= 1.0 ? AppTheme.success : AppTheme.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ─── Kanban columns (horizontal scroll) ──
        Expanded(
          child: tasks.isEmpty ? _buildEmptyState() : _buildColumns(grouped),
        ),

        // ─── Bottom action bar: the one way to add a task. The empty state
        // has its own "Create First Task" button, so the bar waits for that.
        if (tasks.isNotEmpty) _buildBottomBar(),
      ],
    );
  }

  Widget _buildColumns(Map<TaskStage, List<StrategyTask>> grouped) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: TaskStage.values.map((stage) {
          final stageTasks = grouped[stage] ?? [];
          return _buildColumn(stage, stageTasks);
        }).toList(),
      ),
    );
  }

  Widget _buildColumn(TaskStage stage, List<StrategyTask> tasks) {
    return DragTarget<StrategyTask>(
      onWillAcceptWithDetails: (details) => details.data.stage != stage,
      onAcceptWithDetails: (details) => _onDragAccept(details.data, stage),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 220.w,
          margin: EdgeInsets.only(right: 10.w),
          decoration: BoxDecoration(
            color: isHovering
                ? AppTheme.accent.withValues(alpha: 0.05)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isHovering
                  ? AppTheme.accent.withValues(alpha: 0.3)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              // Column header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 10.h,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      stage.emoji,
                      style: TextStyle(fontSize: 14.sp),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      stage.label.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF475569),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 7.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        '${tasks.length}',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Task cards
              Expanded(
                child: tasks.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Text(
                            isHovering ? 'Drop here' : 'No tasks',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: isHovering
                                  ? AppTheme.accent
                                  : const Color(0xFFCBD5E1),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(8.w),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return LongPressDraggable<StrategyTask>(
                            data: task,
                            feedback: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(12.r),
                              child: SizedBox(
                                width: 200.w,
                                child: Opacity(
                                  opacity: 0.85,
                                  child: StrategyTaskCard(
                                    task: task,
                                    onTap: () {},
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: StrategyTaskCard(
                                task: task,
                                onTap: () {},
                              ),
                            ),
                            child: StrategyTaskCard(
                              task: task,
                              onTap: () => StrategyTaskSheet.show(
                                context,
                                task: task,
                                onChanged: _refresh,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.view_kanban_outlined,
              size: 48.sp,
              color: const Color(0xFFCBD5E1),
            ),
            SizedBox(height: 16.h),
            Text(
              'No tasks yet',
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Create tasks to plan your case strategy.\nAssign to team members and track progress.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: const Color(0xFF94A3B8),
                height: 1.5,
              ),
            ),
            SizedBox(height: 20.h),
            ElevatedButton.icon(
              onPressed: _createTask,
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'Create First Task',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 20.w,
                  vertical: 12.h,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _createTask,
              icon: Icon(Icons.add, size: 16.sp),
              label: Text(
                'New Task',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
