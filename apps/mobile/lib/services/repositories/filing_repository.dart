import '../../models/models.dart';
import 'base_repository.dart';

/// Repository for e-filing records and certified copies.
class FilingRepository {
  static final _client = BaseRepository.client;

  // ─── E-Filing Records ──────────────────────────────────

  static Future<List<EFilingRecord>> fetchEfilingRecords({
    String? caseId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final profile = await BaseRepository.getCachedProfile();
    final visibleCaseIds = await BaseRepository.getVisibleCaseIds(
      profile,
      user.id,
    );

    if (visibleCaseIds.isEmpty) return [];

    var query = _client
        .from('efiling_records')
        .select('*, cases(case_title, case_number, cnr_number, firm_id)');

    if (caseId != null) {
      query = query.eq('case_id', caseId);
    } else {
      query = query.inFilter('case_id', visibleCaseIds);
    }

    final response = await query.order('updated_at', ascending: false);
    return (response as List)
        .map((json) => EFilingRecord.fromJson(json))
        .toList();
  }

  static Future<void> createEfilingRecord(Map<String, dynamic> record) async {
    final user = BaseRepository.requireAuth();
    await _client.from('efiling_records').insert({
      ...record,
      'created_by': user.id,
    });
  }

  // ─── Certified Copies ──────────────────────────────────

  static Future<List<CertifiedCopy>> fetchCertifiedCopies() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final profile = await BaseRepository.getCachedProfile();
    final visibleCaseIds = await BaseRepository.getVisibleCaseIds(
      profile,
      user.id,
    );

    if (visibleCaseIds.isEmpty) return [];

    final response = await _client
        .from('certified_copies')
        .select('*, cases(case_title, case_number, cnr_number, firm_id)')
        .inFilter('case_id', visibleCaseIds)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => CertifiedCopy.fromJson(json))
        .toList();
  }

  static Future<void> createCertifiedCopy(Map<String, dynamic> data) async {
    final user = BaseRepository.requireAuth();
    await _client.from('certified_copies').insert({
      ...data,
      'created_by': user.id,
    });
  }

  static Future<void> updateCertifiedCopy(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('certified_copies').update(updates).eq('id', id);
  }

  static Future<void> deleteCertifiedCopy(String id) async {
    await _client.from('certified_copies').delete().eq('id', id);
  }
}
