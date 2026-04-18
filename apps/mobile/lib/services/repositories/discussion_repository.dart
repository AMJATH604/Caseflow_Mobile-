import '../../models/models.dart';
import 'base_repository.dart';

/// Repository for case discussion & firm notice board.
///
/// **Key improvement:** Replaced the old 2-second polling loop
/// (`while(true) { await Future.delayed(2s) }`) with Supabase Realtime
/// `.stream()` — true WebSocket push, zero battery drain.
class DiscussionRepository {
  static final _client = BaseRepository.client;

  static Future<List<CaseComment>> fetchDiscussions(
      {String? caseId, String? firmId}) async {
    var query = _client.from('case_discussions').select('*');
    if (caseId != null) {
      query = query.eq('case_id', caseId);
    } else if (firmId != null) {
      query = query.isFilter('case_id', null).eq('firm_id', firmId);
    }
    final response = await query.order('created_at', ascending: true);
    return (response as List)
        .map((json) => CaseComment.fromJson(json))
        .toList();
  }

  /// **Replaced polling with Supabase Realtime stream.**
  ///
  /// Before: `while(true) { fetch(); await Future.delayed(2s); }`
  /// After:  `.stream(primaryKey)` — WebSocket push, real-time, no polling.
  static Stream<List<CaseComment>> discussionsStream(
      {String? caseId, String? firmId}) {
    if (caseId != null) {
      return _client
          .from('case_discussions')
          .stream(primaryKey: ['id'])
          .eq('case_id', caseId)
          .order('created_at', ascending: true)
          .map((data) =>
              data.map((json) => CaseComment.fromJson(json)).toList());
    } else if (firmId != null) {
      // Firm notices: stream all, then filter client-side
      // (Supabase stream doesn't support isFilter)
      return _client
          .from('case_discussions')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: true)
          .map((data) => data
              .where((json) =>
                  json['case_id'] == null && json['firm_id'] == firmId)
              .map((json) => CaseComment.fromJson(json))
              .toList());
    }
    // Fallback: empty stream
    return Stream.value([]);
  }

  static Future<void> postDiscussion(Map<String, dynamic> data) async {
    final user = BaseRepository.requireAuth();
    await _client.from('case_discussions').insert({
      ...data,
      'sender_id': user.id,
    });
  }

  static Future<void> deleteDiscussion(String id) async {
    await _client.from('case_discussions').delete().eq('id', id);
  }
}
