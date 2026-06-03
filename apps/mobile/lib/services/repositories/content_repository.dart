import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import 'base_repository.dart';

/// Repository for legal content: bare acts, stamp values, legal templates,
/// documents, tasks, and district portals.
class ContentRepository {
  static final _client = BaseRepository.client;

  // ─── Bare Acts ─────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchBareActs() async {
    final response = await _client
        .from('bare_acts')
        .select()
        .eq('is_active', true)
        .order('title');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<dynamic>> fetchSections(String actId) async {
    final response = await _client
        .from('bare_act_sections')
        .select('*')
        .eq('act_id', actId)
        .order('sequence_order', ascending: true);
    return response as List<dynamic>;
  }

  static Future<List<dynamic>> searchBareActs(
    String query, {
    String? actId,
  }) async {
    // Normalize: Handle Art15, Art.15, Article 15, Sec 15, etc.
    String cleanQuery =
        query
            .replaceAll(
              RegExp(
                r'^(art|article|sec|section|§|art\.|sec\.)\s*',
                caseSensitive: false,
              ),
              '',
            )
            .trim();

    if (cleanQuery == query.trim()) {
      cleanQuery =
          query
              .replaceAll(
                RegExp(
                  r'^(art|article|sec|section|§|art\.|sec\.)',
                  caseSensitive: false,
                ),
                '',
              )
              .trim();
    }

    var queryBuilder = _client
        .from('bare_act_sections')
        .select('*, bare_acts(id, title, short_title)');

    bool isNumeric = RegExp(r'^\d*[a-zA-Z]?$').hasMatch(cleanQuery);

    String orFilter;
    if (isNumeric && cleanQuery.isNotEmpty) {
      orFilter =
          'section_number.ilike.$cleanQuery,section_number.ilike.$cleanQuery%,section_title.ilike.%$query%,section_text.ilike.%$query%';
    } else {
      orFilter =
          'section_title.ilike.%$query%,section_text.ilike.%$query%,section_number.ilike.%$query%';
    }

    queryBuilder = queryBuilder.or(orFilter);

    if (actId != null) {
      queryBuilder = queryBuilder.eq('act_id', actId);
    }

    final response = await queryBuilder.limit(50);
    return response as List<dynamic>;
  }

  // ─── Stamp Values ─────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchStampValues({
    String stateId = 'TN',
  }) async {
    final response = await _client
        .from('stamp_values')
        .select()
        .eq('state_id', stateId)
        .order('category', ascending: true)
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // ─── Legal Templates ──────────────────────────────────

  static Future<List<LegalTemplate>> fetchLegalTemplates() async {
    final response = await _client
        .from('legal_templates')
        .select('*')
        .order('category', ascending: true)
        .order('title', ascending: true);
    return (response as List)
        .map((json) => LegalTemplate.fromJson(json))
        .toList();
  }

  static Future<List<LegalTemplate>> searchLegalTemplates(String query) async {
    // Sanitize for safety
    final sanitized = query.replaceAll(RegExp(r'[^\w\s]'), '');
    final response = await _client
        .from('legal_templates')
        .select('*')
        .or(
          'title.ilike.%$sanitized%,description.ilike.%$sanitized%,category.ilike.%$sanitized%',
        )
        .limit(20);
    return (response as List)
        .map((json) => LegalTemplate.fromJson(json))
        .toList();
  }

  // ─── Documents (Supabase Storage) ──────────────────────

  static Future<List<Map<String, dynamic>>> fetchDocuments(
    String caseId,
  ) async {
    try {
      final files = await _client.storage
          .from('case-documents')
          .list(path: caseId);
      return files
          .map(
            (f) => {
              'name': f.name,
              'size': f.metadata?['size'] ?? 0,
              'created_at': f.createdAt ?? '',
              'url': _client.storage
                  .from('case-documents')
                  .getPublicUrl('$caseId/${f.name}'),
            },
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> uploadDocument(
    String caseId,
    Uint8List file,
    String fileName,
  ) async {
    BaseRepository.requireAuth();
    await _client.storage
        .from('case-documents')
        .uploadBinary(
          '$caseId/$fileName',
          file,
          fileOptions: const FileOptions(upsert: true),
        );
  }

  static Future<void> deleteDocument(String caseId, String fileName) async {
    await _client.storage.from('case-documents').remove(['$caseId/$fileName']);
  }

  // ─── Tasks ─────────────────────────────────────────────

  static Future<List<TaskModel>> fetchTasks() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final response = await _client
        .from('tasks')
        .select()
        .eq('created_by', user.id)
        .order('created_at');
    return (response as List).map((json) => TaskModel.fromJson(json)).toList();
  }

  static Stream<List<TaskModel>> tasksStream() {
    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((data) => data.map((json) => TaskModel.fromJson(json)).toList());
  }

  static Future<void> createTask(String title) async {
    final user = BaseRepository.requireAuth();
    await _client.from('tasks').insert({'title': title, 'created_by': user.id});
  }

  static Future<void> updateTask(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await _client.from('tasks').update(updates).eq('id', id);
  }

  static Future<void> deleteTask(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }

  // ─── District Portals ──────────────────────────────────

  static Future<String?> getDistrictPortalUrl(
    String state,
    String district,
    String type,
  ) async {
    try {
      final response =
          await _client
              .from('district_portals')
              .select('url')
              .eq('state', state)
              .eq('district', district)
              .eq('portal_type', type)
              .maybeSingle();

      if (response != null && response['url'] != null) {
        return response['url'] as String;
      }

      // Smart Fallback for Tamil Nadu
      if (state == "Tamil Nadu") {
        final cleanDistrict = district.toLowerCase().replaceAll(
          RegExp(r'\s+'),
          '',
        );
        if (type == 'certified_copy') {
          return 'https://$cleanDistrict.dcourts.gov.in/copyist-section/';
        } else if (type == 'video_conference') {
          return 'https://$cleanDistrict.dcourts.gov.in/hybrid-vc-microsoft-teams-video-conference-link-for-courts-in-$cleanDistrict-district/';
        } else if (type == 'holiday_list') {
          return 'https://$cleanDistrict.dcourts.gov.in/holiday-list/';
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Carousel Slides ──────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchCarouselSlides() async {
    try {
      final response = await _client
          .from('carousel_slides')
          .select()
          .eq('active', true)
          .order('created_at', ascending: false)
          .limit(8);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching carousel slides: $e');
      return [];
    }
  }
}
