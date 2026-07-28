import '../../models/strategy_models.dart';
import 'base_repository.dart';
import '../audit_logger.dart';

/// Repository for case strategy board operations.
///
/// Provides CRUD for strategy tasks, comments, attachments, and
/// activity logging. Follows the same patterns as [CaseRepository]
/// and other domain repositories.
class StrategyRepository {
  static final _client = BaseRepository.client;

  // ─── Fetch Tasks ──────────────────────────────────────

  /// Fetch all tasks for a case, with assignee profile joins and counts.
  static Future<List<StrategyTask>> fetchTasks(String caseId) async {
    final response = await _client
        .from('strategy_tasks')
        .select('''
          *,
          assigned_profile:profiles!strategy_tasks_assigned_to_fkey(full_name, avatar_url),
          creator_profile:profiles!strategy_tasks_created_by_fkey(full_name)
        ''')
        .eq('case_id', caseId)
        .isFilter('deleted_at', null)
        .order('position', ascending: true);

    final tasks = (response as List)
        .map((json) => StrategyTask.fromJson(json))
        .toList();
    return tasks;
  }

  /// Fetch tasks assigned to the current user across all cases.
  static Future<List<StrategyTask>> fetchMyTasks() async {
    final user = BaseRepository.requireAuth();
    final response = await _client
        .from('strategy_tasks')
        .select('''
          *,
          assigned_profile:profiles!strategy_tasks_assigned_to_fkey(full_name, avatar_url),
          creator_profile:profiles!strategy_tasks_created_by_fkey(full_name)
        ''')
        .eq('assigned_to', user.id)
        .isFilter('deleted_at', null)
        .neq('stage', 'done')
        .order('due_date', ascending: true);

    return (response as List)
        .map((json) => StrategyTask.fromJson(json))
        .toList();
  }

  // ─── Create Task ──────────────────────────────────────

  static Future<StrategyTask> createTask(Map<String, dynamic> data) async {
    final user = BaseRepository.requireAuth();
    final profile = await BaseRepository.getCachedProfile();
    final firmId = BaseRepository.getTargetFirmId(profile, user.id);

    BaseRepository.validateRequired(data, ['case_id', 'title']);
    BaseRepository.validateStringLength(
      data['title'] as String?,
      'title',
      maxLength: 300,
    );

    // Get the max position in the target stage for ordering
    final stage = data['stage'] ?? 'todo';
    final maxPosResult = await _client
        .from('strategy_tasks')
        .select('position')
        .eq('case_id', data['case_id'])
        .eq('stage', stage)
        .isFilter('deleted_at', null)
        .order('position', ascending: false)
        .limit(1);

    final nextPosition =
        maxPosResult.isEmpty ? 0 : (maxPosResult[0]['position'] as int) + 1;

    final response = await _client
        .from('strategy_tasks')
        .insert({
          ...data,
          'created_by': user.id,
          'firm_id': firmId,
          'position': nextPosition,
        })
        .select()
        .single();

    final task = StrategyTask.fromJson(response);

    // Log activity
    await _logActivity(task.id, user.id, 'created');

    AuditLogger.log(
      action: AuditAction.create,
      entity: 'strategy_tasks',
      entityId: task.id,
      details: {'title': task.title, 'case_id': task.caseId},
    );

    return task;
  }

  // ─── Update Task ──────────────────────────────────────

  static Future<void> updateTask(
    String taskId,
    Map<String, dynamic> updates,
  ) async {
    final user = BaseRepository.requireAuth();

    await _client.from('strategy_tasks').update(updates).eq('id', taskId);

    // Log what changed
    for (final key in updates.keys) {
      await _logActivity(
        taskId,
        user.id,
        'updated',
        newValue: key,
      );
    }

    AuditLogger.log(
      action: AuditAction.update,
      entity: 'strategy_tasks',
      entityId: taskId,
      details: {'updated_fields': updates.keys.toList()},
    );
  }

  // ─── Move Task (Stage Change) ─────────────────────────

  static Future<void> moveTask(
    String taskId,
    String newStage,
    int newPosition,
  ) async {
    final user = BaseRepository.requireAuth();

    // Fetch old stage for activity log
    final old = await _client
        .from('strategy_tasks')
        .select('stage')
        .eq('id', taskId)
        .single();

    await _client.from('strategy_tasks').update({
      'stage': newStage,
      'position': newPosition,
    }).eq('id', taskId);

    await _logActivity(
      taskId,
      user.id,
      newStage == 'done' ? 'completed' : 'moved',
      oldValue: old['stage'] as String?,
      newValue: newStage,
    );
  }

  // ─── Assign Task ──────────────────────────────────────

  static Future<void> assignTask(String taskId, String? assigneeId) async {
    final user = BaseRepository.requireAuth();

    await _client
        .from('strategy_tasks')
        .update({'assigned_to': assigneeId})
        .eq('id', taskId);

    String? assigneeName;
    if (assigneeId != null) {
      final profile = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', assigneeId)
          .maybeSingle();
      assigneeName = profile?['full_name'] as String?;
    }

    await _logActivity(
      taskId,
      user.id,
      'assigned',
      newValue: assigneeName ?? 'Unassigned',
    );
  }

  // ─── Delete Task (Soft) ───────────────────────────────

  static Future<void> deleteTask(String taskId) async {
    AuditLogger.log(
      action: AuditAction.delete,
      entity: 'strategy_tasks',
      entityId: taskId,
    );
    await BaseRepository.softDelete('strategy_tasks', taskId);
  }

  // ─── Comments ─────────────────────────────────────────

  static Future<List<TaskComment>> fetchComments(String taskId) async {
    final response = await _client
        .from('task_comments')
        .select('*, profiles(full_name, avatar_url)')
        .eq('task_id', taskId)
        .order('created_at', ascending: true);
    return (response as List)
        .map((json) => TaskComment.fromJson(json))
        .toList();
  }

  static Future<void> addComment(String taskId, String content) async {
    final user = BaseRepository.requireAuth();
    await _client.from('task_comments').insert({
      'task_id': taskId,
      'user_id': user.id,
      'content': content,
    });
    await _logActivity(taskId, user.id, 'commented');
  }

  // ─── Attachments ──────────────────────────────────────

  static Future<List<TaskAttachment>> fetchAttachments(String taskId) async {
    final response = await _client
        .from('task_attachments')
        .select()
        .eq('task_id', taskId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => TaskAttachment.fromJson(json))
        .toList();
  }

  static Future<void> addAttachment(Map<String, dynamic> data) async {
    final user = BaseRepository.requireAuth();
    await _client.from('task_attachments').insert({
      ...data,
      'uploaded_by': user.id,
    });
  }

  static Future<void> deleteAttachment(String attachmentId) async {
    await _client.from('task_attachments').delete().eq('id', attachmentId);
  }

  // ─── Activity Log ─────────────────────────────────────

  static Future<List<TaskActivity>> fetchActivityLog(String taskId) async {
    final response = await _client
        .from('task_activity_log')
        .select('*, profiles(full_name)')
        .eq('task_id', taskId)
        .order('created_at', ascending: false)
        .limit(50);
    return (response as List)
        .map((json) => TaskActivity.fromJson(json))
        .toList();
  }

  // ─── Board Summary ────────────────────────────────────

  /// Returns task count per stage for a case.
  static Future<Map<String, int>> fetchBoardSummary(String caseId) async {
    final tasks = await fetchTasks(caseId);
    return {
      'total': tasks.length,
      'todo': tasks.where((t) => t.stage == TaskStage.todo).length,
      'in_progress':
          tasks.where((t) => t.stage == TaskStage.inProgress).length,
      'review': tasks.where((t) => t.stage == TaskStage.review).length,
      'filed': tasks.where((t) => t.stage == TaskStage.filed).length,
      'done': tasks.where((t) => t.stage == TaskStage.done).length,
      'overdue': tasks.where((t) => t.isOverdue).length,
    };
  }

  // ─── Private Helpers ──────────────────────────────────

  static Future<void> _logActivity(
    String taskId,
    String userId,
    String action, {
    String? oldValue,
    String? newValue,
  }) async {
    try {
      await _client.from('task_activity_log').insert({
        'task_id': taskId,
        'user_id': userId,
        'action': action,
        'old_value': oldValue,
        'new_value': newValue,
      });
    } catch (_) {
      // Don't fail the main operation if activity logging fails
    }
  }
}
