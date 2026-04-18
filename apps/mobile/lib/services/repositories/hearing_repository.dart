import '../../models/models.dart';
import 'base_repository.dart';

/// Repository for hearing management including the adjourn workflow.
class HearingRepository {
  static final _client = BaseRepository.client;

  static Future<List<Hearing>> fetchHearings({
    String? caseId,
    int? limit,
    int? offset,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final profile = await BaseRepository.getCachedProfile();
    final visibleCaseIds =
        await BaseRepository.getVisibleCaseIds(profile, user.id);

    if (visibleCaseIds.isEmpty) return [];

    var query = _client.from('hearings').select(
        '*, cases(case_title, court_name, case_number, cnr_number, firm_id)');

    if (caseId != null) {
      query = query.eq('case_id', caseId);
    } else {
      query = query.inFilter('case_id', visibleCaseIds);
    }

    // Apply pagination and ordering in a single chain to avoid type mismatch
    final List response;
    if (limit != null && offset != null) {
      response = await query.order('hearing_date').range(offset, offset + limit - 1);
    } else if (limit != null) {
      response = await query.order('hearing_date').limit(limit);
    } else {
      response = await query.order('hearing_date');
    }
    return response.map((json) => Hearing.fromJson(json)).toList();
  }

  static Future<Hearing> createHearing(
      Map<String, dynamic> hearingData) async {
    final user = BaseRepository.requireAuth();
    final response = await _client
        .from('hearings')
        .insert({...hearingData, 'created_by': user.id})
        .select(
            '*, cases(case_title, court_name, case_number, cnr_number, firm_id)')
        .single();
    return Hearing.fromJson(response);
  }

  /// Adjourn workflow:
  /// 1. Delete the old (just completed) hearing
  /// 2. If not disposed/dismissed, create a new future hearing
  /// 3. Update the case status and next_hearing_date
  static Future<Hearing?> adjournHearing(
      String id, Map<String, dynamic> data) async {
    final user = BaseRepository.requireAuth();

    final String nextStage = data['next_stage'] ?? 'Next Hearing';
    final bool isFinal =
        nextStage == 'Case Disposed' || nextStage == 'Case Dismissed';

    // 1. Delete the old hearing
    await _client.from('hearings').delete().eq('id', id);

    Hearing? newHearing;

    if (!isFinal) {
      // 2. Create new future hearing
      final response = await _client.from('hearings').insert({
        'case_id': data['case_id'],
        'hearing_date': data['next_date'],
        'stage': nextStage,
        'created_by': user.id,
      }).select(
          '*, cases(case_title, court_name, case_number, cnr_number, firm_id)')
          .single();
      newHearing = Hearing.fromJson(response);
    }

    // 3. Update case status
    final Map<String, dynamic> caseUpdates = {'stage': nextStage};
    if (isFinal) {
      caseUpdates['status'] =
          nextStage == 'Case Disposed' ? 'disposed' : 'dismissed';
      caseUpdates['next_hearing_date'] = null;
    } else {
      caseUpdates['next_hearing_date'] = data['next_date'];
    }

    await _client
        .from('cases')
        .update(caseUpdates)
        .eq('id', data['case_id']);

    return newHearing;
  }

  static Future<void> deleteHearing(String id) async {
    await _client.from('hearings').delete().eq('id', id);
  }
}
