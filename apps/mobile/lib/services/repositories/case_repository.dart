import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../models/models.dart';
import '../../models/case_conflict.dart';
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

  /// Builds the PostgREST `or()` filter scoping a `cases` query to everything
  /// the current user may see: their own and their firm's records, plus any
  /// case shared with them through an accepted collaboration.
  ///
  /// Extracted so the paginated list and the status counts below cannot drift
  /// apart — a count computed over a different visibility rule than the list
  /// would quietly disagree with it.
  /// Delegates to [BaseRepository.buildCaseVisibilityFilter] so the case list
  /// and everything scoped to case ids — hearings, payments, e-filing — share
  /// one rule. They were two copies, and only this one counted collaborations.
  static Future<String> _visibilityFilter(String userId, String? email) async {
    final profile = await BaseRepository.getCachedProfile();
    return BaseRepository.buildCaseVisibilityFilter(profile, userId, email);
  }

  /// Per-status counts across **all** visible cases.
  ///
  /// The Legal Repository list is paginated, and its stat cards used to count
  /// the rows loaded so far — so the numbers climbed as the user scrolled.
  /// This selects a single column for every visible case instead: no joins,
  /// no pagination, cheap enough to run alongside the list.
  ///
  /// Statuses are normalised through [CaseStatus.fromString], the same
  /// coercion the list rows use, so the totals always agree with what is on
  /// screen even when the database holds a value outside the enum.
  static Future<Map<String, int>> fetchCaseStatusCounts() async {
    final user = _client.auth.currentUser;
    if (user == null) return <String, int>{};

    final filter = await _visibilityFilter(user.id, user.email);
    final rows = await _client.from('cases').select('status').or(filter);

    final counts = <String, int>{};
    for (final row in rows as List) {
      final name = CaseStatus.fromString(row['status'] ?? 'active').name;
      counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts;
  }

  static Future<List<CaseModel>> fetchCases({int? limit, int? offset}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final query = _client
        .from('cases')
        .select('*, clients(name)')
        .or(await _visibilityFilter(user.id, user.email));

    // Apply pagination and ordering in a single chain to avoid type mismatch
    final List response;
    if (limit != null && offset != null) {
      response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    } else if (limit != null) {
      response = await query.order('created_at', ascending: false).limit(limit);
    } else {
      response = await query.order('created_at', ascending: false);
    }
    return response.map((json) => CaseModel.fromJson(json)).toList();
  }

  /// Searches **every** visible case on the server, not the pages loaded so far.
  ///
  /// The Legal Repository filtered its loaded rows in memory, and the list
  /// loads twenty at a time — so a case further down could not be found
  /// until the user had scrolled far enough to load it.
  ///
  /// The query is split into words and matched as `%w1%w2%`, so "OS 194" finds
  /// `OS/194/2014` and "murugan krishnan" finds "Murugan vs Krishnan": what an
  /// advocate types rarely matches the stored punctuation exactly.
  static Future<List<CaseModel>> searchCases(
    String query, {
    int limit = 100,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final words =
        BaseRepository.sanitizeFilterValue(query)
            .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
            .where((w) => w.isNotEmpty)
            .toList();
    if (words.isEmpty) return [];
    final pattern = '%${words.join('%')}%';

    // The client's name lives in another table, so resolve matching client
    // ids first and fold them into the case filter. RLS limits these to the
    // user's own clients.
    final clientRows = await _client
        .from('clients')
        .select('id')
        .ilike('name', pattern)
        .limit(200);
    final clientIds = [for (final r in clientRows as List) r['id'] as String];

    final text = [
      'case_title.ilike.$pattern',
      'case_number.ilike.$pattern',
      'cnr_number.ilike.$pattern',
      'court_name.ilike.$pattern',
      'opposing_party.ilike.$pattern',
      if (clientIds.isNotEmpty) 'client_id.in.(${clientIds.join(',')})',
    ].join(',');
    final visible = await _visibilityFilter(user.id, user.email);

    // One `or` holding both groups ANDed, rather than two `.or()` calls, so
    // the visibility rule can never be replaced by the text match.
    final rows = await _client
        .from('cases')
        .select('*, clients(name)')
        .or('and(or($visible),or($text))')
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final j in rows as List) CaseModel.fromJson(j)];
  }

  static Future<CaseModel> fetchCaseById(String id) async {
    final response =
        await _client
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

    // Input validation
    BaseRepository.validateRequired(caseData, ['case_title', 'client_id']);
    BaseRepository.validateStringLength(
      caseData['case_title'] as String?,
      'case_title',
      maxLength: 300,
    );

    final response =
        await _client
            .from('cases')
            .insert({
              ...caseData,
              'created_by': user.id,
              'firm_id': targetFirmId,
            })
            .select()
            .single();

    final newCase = CaseModel.fromJson(response);

    // Auditing is handled by the database trigger trg_audit_cases, which
    // cannot be skipped by a client and also covers the web console. It
    // deliberately records only the entity id and changed column names — the
    // call removed from here wrote case_title and client_id into audit_logs,
    // which is privileged material sitting in the table the admin console
    // reads. See 20260917_audit_foundations.sql.

    return newCase;
  }

  /// Existing cases that clash with the one about to be saved.
  ///
  /// A pre-check for the user's benefit only — the authority is the partial
  /// unique index `cases_unique_number_per_court`, which is what actually
  /// stops two devices saving the same case at the same moment. Callers must
  /// still handle [isDuplicateCaseError] on the insert.
  ///
  /// Returns blocking conflicts first, so a caller that shows one row shows
  /// the serious one.
  static Future<List<CaseConflict>> findConflictingCases({
    String? caseNumber,
    String? courtName,
    String? caseTitle,
    String? excludeId,
  }) async {
    BaseRepository.requireAuth();
    final rows = await _client.rpc(
      'find_conflicting_cases',
      params: {
        'p_case_number': caseNumber,
        'p_court_name': courtName,
        'p_case_title': caseTitle,
        'p_exclude_id': excludeId,
      },
    );
    return ((rows as List?) ?? const [])
        .map((r) => CaseConflict.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Whether an error thrown by [createCase] is the duplicate-case rejection
  /// rather than a genuine failure. Postgres reports it as 23505 naming the
  /// index, which is the only way to tell it from any other unique violation
  /// on the table.
  static bool isDuplicateCaseError(Object error) {
    if (error is PostgrestException) {
      return error.code == '23505' &&
          (error.message.contains('cases_unique_number_per_court') ||
              (error.details?.toString() ?? '').contains(
                'cases_unique_number_per_court',
              ));
    }
    return error.toString().contains('cases_unique_number_per_court');
  }

  static Future<void> updateCase(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('cases').update(updates).eq('id', id);
    // Audited by trg_audit_cases.
  }

  /// Cascading delete: removes all related records before the case itself.
  /// Ordered to avoid foreign key violations.
  static Future<void> deleteCase(String id) async {
    // Audited by trg_audit_cases, which fires on the DELETE below. The child
    // rows removed first are audited by their own triggers, so the cascade is
    // recorded in full rather than as a single summary line.

    // Cascading delete: removes all related records before the case itself.
    await _client.from('strategy_tasks').delete().eq('case_id', id);
    await _client.from('ecourt_sync_records').delete().eq('case_id', id);
    await _client.from('ecourt_hearing_history').delete().eq('case_id', id);
    await _client.from('hearings').delete().eq('case_id', id);
    await _client.from('payments').delete().eq('case_id', id);
    await _client.from('efiling_records').delete().eq('case_id', id);
    await _client.from('certified_copies').delete().eq('case_id', id);
    await _client.from('evidence_checklists').delete().eq('case_id', id);
    await _client.from('witness_examination_notes').delete().eq('case_id', id);
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
    await _client
        .from('case_acts')
        .upsert(batch, onConflict: 'case_id,act_name,section_number');
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
    await _client.from('case_ia_applications').insert({
      ...data,
      'created_by': user.id,
    });
  }

  static Future<void> upsertCaseIAs(List<Map<String, dynamic>> ias) async {
    if (ias.isEmpty) return;
    final user = BaseRepository.requireAuth();
    final batch =
        ias.map((ia) {
          final copy = Map<String, dynamic>.from(ia);
          if (copy['filing_date'] != null) {
            copy['filing_date'] = BaseRepository.normalizeDateStr(
              copy['filing_date'].toString(),
            );
          }
          if (copy['next_date'] != null) {
            copy['next_date'] = BaseRepository.normalizeDateStr(
              copy['next_date'].toString(),
            );
          }
          return {...copy, 'created_by': user.id};
        }).toList();

    await _client
        .from('case_ia_applications')
        .upsert(batch, onConflict: 'case_id,ia_number');
  }

  static Future<void> upsertCaseIA(Map<String, dynamic> data) async {
    await upsertCaseIAs([data]);
  }

  static Future<void> updateCaseIA(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('case_ia_applications').update(updates).eq('id', id);
  }

  static Future<void> deleteCaseIA(String id) async {
    await _client.from('case_ia_applications').delete().eq('id', id);
  }

  // ─── eCourt Dossier: Interim Orders ────────────────────

  static Future<List<CaseInterimOrder>> fetchInterimOrders(
    String caseId,
  ) async {
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
    await _client.from('case_interim_orders').insert({
      ...data,
      'created_by': user.id,
    });
  }

  static Future<void> upsertInterimOrders(
    List<Map<String, dynamic>> orders,
  ) async {
    if (orders.isEmpty) return;
    final user = BaseRepository.requireAuth();
    final batch =
        orders.map((o) {
          final copy = Map<String, dynamic>.from(o);
          if (copy['order_date'] != null) {
            copy['order_date'] = BaseRepository.normalizeDateStr(
              copy['order_date'].toString(),
            );
          }
          return {...copy, 'created_by': user.id};
        }).toList();

    await _client
        .from('case_interim_orders')
        .upsert(batch, onConflict: 'case_id,order_date,order_summary');
  }

  static Future<void> upsertInterimOrder(Map<String, dynamic> data) async {
    await upsertInterimOrders([data]);
  }

  static Future<void> deleteInterimOrder(String id) async {
    await _client.from('case_interim_orders').delete().eq('id', id);
  }

  // ─── Global Search ─────────────────────────────────────

  static Future<Map<String, List<dynamic>>> searchAll(String query) async {
    // Raw input cannot go straight into an .or() filter — a comma or paren
    // would inject an extra filter term and widen visibility.
    final safe = BaseRepository.sanitizeFilterValue(query);
    if (safe.isEmpty) return {'cases': [], 'clients': []};

    final cases = await _client
        .from('cases')
        .select('id, case_title, case_number')
        .or('case_title.ilike.%$safe%,case_number.ilike.%$safe%')
        .limit(5);
    final clients = await _client
        .from('clients')
        .select('id, name')
        .ilike('name', '%$safe%')
        .limit(5);

    return {'cases': cases as List, 'clients': clients as List};
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
    await _client.from('evidence_checklists').delete().eq('created_by', userId);
    await _client
        .from('witness_examination_notes')
        .delete()
        .eq('created_by', userId);
    await _client.from('evidence_photos').delete().eq('created_by', userId);
    await _client.from('case_discussions').delete().eq('sender_id', userId);
    await _client.from('tasks').delete().eq('created_by', userId);
    await _client.from('cases').delete().eq('created_by', userId);
    await _client.from('clients').delete().eq('created_by', userId);
  }
}
