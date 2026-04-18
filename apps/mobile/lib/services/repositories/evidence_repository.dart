import '../../models/models.dart';
import 'base_repository.dart';

/// Repository for evidence lab: checklists, witness notes, photos.
class EvidenceRepository {
  static final _client = BaseRepository.client;

  // ─── Evidence Checklist ────────────────────────────────

  static Future<List<EvidenceChecklist>> fetchEvidenceChecklist(
      String caseId) async {
    final response = await _client
        .from('evidence_checklists')
        .select()
        .eq('case_id', caseId)
        .order('created_at');
    return (response as List)
        .map((json) => EvidenceChecklist.fromJson(json))
        .toList();
  }

  static Future<void> createEvidenceChecklistItem(
      Map<String, dynamic> data) async {
    final user = BaseRepository.requireAuth();
    await _client
        .from('evidence_checklists')
        .insert({...data, 'created_by': user.id});
  }

  static Future<void> updateEvidenceChecklistItem(
      String id, Map<String, dynamic> updates) async {
    await _client.from('evidence_checklists').update(updates).eq('id', id);
  }

  static Future<void> deleteEvidenceChecklistItem(String id) async {
    await _client.from('evidence_checklists').delete().eq('id', id);
  }

  // ─── Witness Examination Notes ─────────────────────────

  static Future<List<WitnessNote>> fetchWitnessNotes(String caseId) async {
    final response = await _client
        .from('witness_examination_notes')
        .select()
        .eq('case_id', caseId)
        .order('created_at');
    return (response as List)
        .map((json) => WitnessNote.fromJson(json))
        .toList();
  }

  static Future<void> createWitnessNote(Map<String, dynamic> data) async {
    final user = BaseRepository.requireAuth();
    await _client
        .from('witness_examination_notes')
        .insert({...data, 'created_by': user.id});
  }

  static Future<void> updateWitnessNote(
      String id, Map<String, dynamic> updates) async {
    await _client
        .from('witness_examination_notes')
        .update(updates)
        .eq('id', id);
  }

  static Future<void> deleteWitnessNote(String id) async {
    await _client
        .from('witness_examination_notes')
        .delete()
        .eq('id', id);
  }

  // ─── Evidence Photos ───────────────────────────────────

  static Future<List<EvidencePhoto>> fetchEvidencePhotos(
      String caseId) async {
    final response = await _client
        .from('evidence_photos')
        .select()
        .eq('case_id', caseId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => EvidencePhoto.fromJson(json))
        .toList();
  }

  static Future<void> createEvidencePhoto(Map<String, dynamic> data) async {
    final user = BaseRepository.requireAuth();
    await _client
        .from('evidence_photos')
        .insert({...data, 'created_by': user.id});
  }

  static Future<void> deleteEvidencePhoto(String id) async {
    await _client.from('evidence_photos').delete().eq('id', id);
  }
}
