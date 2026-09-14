import '../../models/cross_exam_models.dart';
import 'base_repository.dart';

/// Repository for Cross-Examination Preparation.
///
/// Privacy-first: All operations are local Supabase CRUD.
/// No AI APIs, no external data transfer. Every question the advocate
/// types stays in the database protected by RLS.
class CrossExamRepository {
  static final _client = BaseRepository.client;

  // ─── Sessions ─────────────────────────────────────────────

  /// Fetch all sessions for the current user (across all cases).
  static Future<List<CrossExamSession>> fetchAllSessions() async {
    BaseRepository.requireAuth();
    try {
      final response = await _client
          .from('cross_exam_sessions')
          .select('''
            *,
            cases(title),
            cross_exam_questions(count)
          ''')
          .isFilter('deleted_at', null)
          .order('updated_at', ascending: false);

      return (response as List)
          .map((json) => CrossExamSession.fromJson(json))
          .toList();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('relation') && msg.contains('does not exist') ||
          msg.contains('42p01') ||
          msg.contains('cross_exam')) {
        return [];
      }
      rethrow;
    }
  }

  /// Fetch sessions for a specific case.
  static Future<List<CrossExamSession>> fetchSessionsForCase(
      String caseId) async {
    BaseRepository.requireAuth();
    try {
      final response = await _client
          .from('cross_exam_sessions')
          .select('''
            *,
            cases(title),
            cross_exam_questions(count)
          ''')
          .eq('case_id', caseId)
          .isFilter('deleted_at', null)
          .order('updated_at', ascending: false);

      return (response as List)
          .map((json) => CrossExamSession.fromJson(json))
          .toList();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('relation') && msg.contains('does not exist') ||
          msg.contains('42p01')) {
        return [];
      }
      rethrow;
    }
  }

  /// Create a new cross-exam session.
  static Future<CrossExamSession> createSession(
      Map<String, dynamic> data) async {
    final user = BaseRepository.requireAuth();
    final profile = await BaseRepository.getCachedProfile();
    final firmId = BaseRepository.getTargetFirmId(profile, user.id);

    BaseRepository.validateRequired(data, ['case_id', 'witness_name']);
    BaseRepository.validateStringLength(
      data['witness_name'] as String?,
      'witness_name',
      maxLength: 200,
    );

    final response = await _client
        .from('cross_exam_sessions')
        .insert({
          ...data,
          'user_id': user.id,
          'firm_id': firmId,
        })
        .select('*, cases(title)')
        .single();

    return CrossExamSession.fromJson(response);
  }

  /// Update a session's metadata.
  static Future<void> updateSession(
      String id, Map<String, dynamic> updates) async {
    BaseRepository.requireAuth();
    await _client.from('cross_exam_sessions').update({
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Soft-delete a session.
  static Future<void> deleteSession(String id) async {
    await BaseRepository.softDelete('cross_exam_sessions', id);
  }

  // ─── Questions ────────────────────────────────────────────

  /// Fetch all questions for a session, ordered by position.
  static Future<List<CrossExamQuestion>> fetchQuestions(
      String sessionId) async {
    BaseRepository.requireAuth();
    final response = await _client
        .from('cross_exam_questions')
        .select()
        .eq('session_id', sessionId)
        .order('position', ascending: true);

    return (response as List)
        .map((json) => CrossExamQuestion.fromJson(json))
        .toList();
  }

  /// Add a new question (auto-positioned at the end).
  static Future<CrossExamQuestion> addQuestion(
      String sessionId, String questionText) async {
    BaseRepository.requireAuth();
    BaseRepository.validateStringLength(
      questionText,
      'question_text',
      maxLength: 2000,
    );

    // Get next position
    final existing = await _client
        .from('cross_exam_questions')
        .select('position')
        .eq('session_id', sessionId)
        .order('position', ascending: false)
        .limit(1);

    final nextPos =
        existing.isEmpty ? 0 : (existing[0]['position'] as int) + 1;

    final response = await _client
        .from('cross_exam_questions')
        .insert({
          'session_id': sessionId,
          'question_text': questionText,
          'position': nextPos,
        })
        .select()
        .single();

    // Touch parent session's updated_at
    await _client.from('cross_exam_sessions').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);

    return CrossExamQuestion.fromJson(response);
  }

  /// Update a question's content, priority, category, notes, etc.
  static Future<void> updateQuestion(
      String id, Map<String, dynamic> updates) async {
    BaseRepository.requireAuth();
    await _client.from('cross_exam_questions').update({
      ...updates,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Delete a question permanently.
  static Future<void> deleteQuestion(String id) async {
    BaseRepository.requireAuth();
    await _client.from('cross_exam_questions').delete().eq('id', id);
  }

  /// Reorder questions after a drag-and-drop.
  static Future<void> reorderQuestions(List<String> orderedIds) async {
    BaseRepository.requireAuth();
    // Batch update positions — each ID gets its list index as position
    for (int i = 0; i < orderedIds.length; i++) {
      await _client
          .from('cross_exam_questions')
          .update({'position': i})
          .eq('id', orderedIds[i]);
    }
  }

  /// Toggle the key-question flag on a question.
  static Future<void> toggleKeyQuestion(String id, bool isKey) async {
    await updateQuestion(id, {'is_key_question': isKey});
  }
}
