import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../models/case_dossier_models.dart';
import 'base_repository.dart';

/// Repository for all case-related operations.
///
/// Extracted from the monolithic SupabaseService to follow
/// Single Responsibility Principle. Each method uses [BaseRepository]
/// for profile caching and visibility filtering.
class CaseRepository {
  static final _client = BaseRepository.client;

  // ─── Cases CRUD ────────────────────────────────────────

  static Future<List<CaseModel>> fetchCases({int? limit, int? offset}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final profile = await BaseRepository.getCachedProfile();
    final orFilter = BaseRepository.buildVisibilityFilter(profile, user.id);

    // Fetch collaborator case IDs
    final collabRes = await _client
        .from('case_collaborations')
        .select('case_id')
        .or('collaborator_email.eq.${user.email},collaborator_id.eq.${user.id}')
        .eq('status', 'accepted');

    final List<String> collaborationCaseIds =
        (collabRes as List).map((c) => c['case_id'] as String).toList();

    var query = _client.from('cases').select('*, clients(name)');

    if (collaborationCaseIds.isEmpty) {
      query = query.or(orFilter);
    } else {
      final List<String> inClause =
          collaborationCaseIds.map((id) => 'id.eq.$id').toList();
      final String fullFilter = '$orFilter,${inClause.join(',')}';
      query = query.or(fullFilter);
    }

    if (limit != null && offset != null) {
      query = query.range(offset, offset + limit - 1);
    } else if (limit != null) {
      query = query.limit(limit);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List).map((json) => CaseModel.fromJson(json)).toList();
  }

  static Future<CaseModel> fetchCaseById(String id) async {
    final response = await _client
        .from('cases')
        .select('*, clients(name, phone, email)')
        .eq('id', id)
        .single();
    return CaseModel.fromJson(response);
  }

  static Future<CaseModel> createCase(Map<String, dynamic> caseData) async {
    final user = BaseRepository.requireAuth();
    final profile = await BaseRepository.getCachedProfile();
    final targetFirmId = BaseRepository.getTargetFirmId(profile, user.id);

    final response = await _client.from('cases').insert({
      ...caseData,
      'created_by': user.id,
      'firm_id': targetFirmId,
    }).select().single();
    return CaseModel.fromJson(response);
  }

  static Future<void> updateCase(
      String id, Map<String, dynamic> updates) async {
    await _client.from('cases').update(updates).eq('id', id);
  }

  /// Cascading delete: removes all related records before the case itself.
  /// Ordered to avoid foreign key violations.
  static Future<void> deleteCase(String id) async {
    await _client.from('ecourt_sync_records').delete().eq('case_id', id);
    await _client.from('ecourt_hearing_history').delete().eq('case_id', id);
    await _client.from('hearings').delete().eq('case_id', id);
    await _client.from('payments').delete().eq('case_id', id);
    await _client.from('efiling_records').delete().eq('case_id', id);
    await _client.from('certified_copies').delete().eq('case_id', id);
    await _client.from('evidence_checklists').delete().eq('case_id', id);
    await _client
        .from('witness_examination_notes')
        .delete()
        .eq('case_id', id);
    await _client.from('evidence_photos').delete().eq('case_id', id);
    await _client.from('cases').delete().eq('id', id);
  }

  static Future<void> updateCaseCnr(String id, String cnr) async {
    await _client.from('cases').update({'cnr_number': cnr}).eq('id', id);
  }

  // ─── eCourt Dossier: Acts ──────────────────────────────

  static Future<List<CaseAct>> fetchCaseActs(String caseId) async {
    final response = await _client
        .from('case_acts')
        .select()
        .eq('case_id', caseId)
        .order('created_at', ascending: true);
    return (response as List).map((json) => CaseAct.fromJson(json)).toList();
  }

  static Future<void> createCaseAct(Map<String, dynamic> data) async {
    final user = BaseRepository.requireAuth();
    await _client.from('case_acts').insert({...data, 'created_by': user.id});
  }

  static Future<void> upsertCaseActs(List<Map<String, dynamic>> acts) async {
    if (acts.isEmpty) return;
    final user = BaseRepository.requireAuth();
    final batch = acts.map((a) => {...a, 'created_by': user.id}).toList();
    await _client.from('case_acts').upsert(
      batch,
      onConflict: 'case_id,act_name,section_number',
    );
  }

  static Future<void> upsertCaseAct(Map<String, dynamic> data) async {
    await upsertCaseActs([data]);
  }

  static Future<void> deleteCaseAct(String id) async {
    await _client.from('case_acts').delete().eq('id', id);
  }

  // ─── eCourt Dossier: IA Applications ───────────────────

  static Future<List<CaseIAApplication>> fetchCaseIAs(String caseId) async {
    final response = await _client
        .from('case_ia_applications')
        .select()
        .eq('case_id', caseId)
        .order('filing_date', ascending: true);
    return (response as List)
        .map((json) => CaseIAApplication.fromJson(json))
        .toList();
  }

  static Future<void> createCaseIA(Map<String, dynamic> data) async {
    final user = BaseRepository.requireAuth();
    await _client
        .from('case_ia_applications')
        .insert({...data, 'created_by': user.id});
  }

  static Future<void> upsertCaseIAs(List<Map<String, dynamic>> ias) async {
    if (ias.isEmpty) return;
    final user = BaseRepository.requireAuth();
    final batch = ias.map((ia) {
      final copy = Map<String, dynamic>.from(ia);
      if (copy['filing_date'] != null) {
        copy['filing_date'] =
            BaseRepository.normalizeDateStr(copy['filing_date'].toString());
      }
      if (copy['next_date'] != null) {
        copy['next_date'] =
            BaseRepository.normalizeDateStr(copy['next_date'].toString());
      }
      return {...copy, 'created_by': user.id};
    }).toList();

    await _client.from('case_ia_applications').upsert(
      batch,
      onConflict: 'case_id,ia_number',
    );
  }

  static Future<void> upsertCaseIA(Map<String, dynamic> data) async {
    await upsertCaseIAs([data]);
  }

  static Future<void> updateCaseIA(
      String id, Map<String, dynamic> updates) async {
    await _client.from('case_ia_applications').update(updates).eq('id', id);
  }

  static Future<void> deleteCaseIA(String id) async {
    await _client.from('case_ia_applications').delete().eq('id', id);
  }

  // ─── eCourt Dossier: Interim Orders ────────────────────

  static Future<List<CaseInterimOrder>> fetchInterimOrders(
      String caseId) async {
    final response = await _client
        .from('case_interim_orders')
        .select()
        .eq('case_id', caseId)
        .order('order_date', ascending: true);
    return (response as List)
        .map((json) => CaseInterimOrder.fromJson(json))
        .toList();
  }

  static Future<void> createInterimOrder(Map<String, dynamic> data) async {
    final user = BaseRepository.requireAuth();
    await _client
        .from('case_interim_orders')
        .insert({...data, 'created_by': user.id});
  }

  static Future<void> upsertInterimOrders(
      List<Map<String, dynamic>> orders) async {
    if (orders.isEmpty) return;
    final user = BaseRepository.requireAuth();
    final batch = orders.map((o) {
      final copy = Map<String, dynamic>.from(o);
      if (copy['order_date'] != null) {
        copy['order_date'] =
            BaseRepository.normalizeDateStr(copy['order_date'].toString());
      }
      return {...copy, 'created_by': user.id};
    }).toList();

    await _client.from('case_interim_orders').upsert(
      batch,
      onConflict: 'case_id,order_date,order_summary',
    );
  }

  static Future<void> upsertInterimOrder(Map<String, dynamic> data) async {
    await upsertInterimOrders([data]);
  }

  static Future<void> deleteInterimOrder(String id) async {
    await _client.from('case_interim_orders').delete().eq('id', id);
  }

  // ─── Global Search ─────────────────────────────────────

  static Future<Map<String, List<dynamic>>> searchAll(String query) async {
    final cases = await _client
        .from('cases')
        .select('id, case_title, case_number')
        .or('case_title.ilike.%$query%,case_number.ilike.%$query%')
        .limit(5);
    final clients = await _client
        .from('clients')
        .select('id, name')
        .ilike('name', '%$query%')
        .limit(5);

    return {
      'cases': cases as List,
      'clients': clients as List,
    };
  }

  // ─── Workspace Reset ───────────────────────────────────

  static Future<void> resetUserWorkspace() async {
    final user = BaseRepository.requireAuth();
    final userId = user.id;

    // Ordered deletion to minimize FK conflicts
    await _client.from('hearings').delete().eq('created_by', userId);
    await _client.from('payments').delete().eq('created_by', userId);
    await _client.from('efiling_records').delete().eq('created_by', userId);
    await _client.from('certified_copies').delete().eq('created_by', userId);
    await _client
        .from('evidence_checklists')
        .delete()
        .eq('created_by', userId);
    await _client
        .from('witness_examination_notes')
        .delete()
        .eq('created_by', userId);
    await _client.from('evidence_photos').delete().eq('created_by', userId);
    await _client
        .from('case_discussions')
        .delete()
        .eq('sender_id', userId);
    await _client.from('tasks').delete().eq('created_by', userId);
    await _client.from('cases').delete().eq('created_by', userId);
    await _client.from('clients').delete().eq('created_by', userId);
  }
}
