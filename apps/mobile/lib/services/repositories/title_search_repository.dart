import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../models/title_search_models.dart';
import 'base_repository.dart';

class TitleSearchRepository {
  static final _client = BaseRepository.client;

  /// Fetches all title searches visible to the user / firm
  static Future<List<TitleSearch>> fetchTitleSearches() async {
    final user = BaseRepository.requireAuth();
    final profile = await BaseRepository.getCachedProfile();

    var query = _client.from('title_searches').select('*');

    if (profile.firmId != null && profile.firmId!.isNotEmpty) {
      query = query.or('user_id.eq.${user.id},firm_id.eq.${profile.firmId}');
    } else {
      query = query.eq('user_id', user.id);
    }

    final data = await query.order('created_at', ascending: false);
    return (data as List).map((json) => TitleSearch.fromJson(json)).toList();
  }

  /// Fetches a single title search with full details
  static Future<TitleSearch> fetchTitleSearchById(String id) async {
    BaseRepository.requireAuth();
    final data = await _client
        .from('title_searches')
        .select('*')
        .eq('id', id)
        .single();
    return TitleSearch.fromJson(data);
  }

  /// Creates a new title search
  static Future<TitleSearch> createTitleSearch(Map<String, dynamic> data) async {
    final user = BaseRepository.requireAuth();
    final profile = await BaseRepository.getCachedProfile();

    final payload = {
      ...data,
      'user_id': user.id,
      'firm_id': profile.firmId,
      'status': 'draft',
    };

    final res = await _client
        .from('title_searches')
        .insert(payload)
        .select()
        .single();
    return TitleSearch.fromJson(res);
  }

  /// Updates search details or advocate opinion
  static Future<void> updateTitleSearch(
    String id,
    Map<String, dynamic> updates,
  ) async {
    BaseRepository.requireAuth();
    await _client.from('title_searches').update(updates).eq('id', id);
  }

  /// Deletes a title search
  static Future<void> deleteTitleSearch(String id) async {
    BaseRepository.requireAuth();
    await _client.from('title_searches').delete().eq('id', id);
  }

  /// Fetches documents uploaded for this search
  static Future<List<TitleDocument>> fetchDocuments(String searchId) async {
    BaseRepository.requireAuth();
    final data = await _client
        .from('title_documents')
        .select('*')
        .eq('search_id', searchId)
        .order('chain_position', ascending: true, nullsFirst: false)
        .order('created_at', ascending: true);
    return (data as List).map((json) => TitleDocument.fromJson(json)).toList();
  }

  /// Uploads a property document to Supabase storage and records in DB
  static Future<TitleDocument> uploadDocument({
    required String searchId,
    required String documentType,
    required String documentLabel,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final user = BaseRepository.requireAuth();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = fileName.split('.').last.toLowerCase();
    final storagePath = '${user.id}/$searchId/${timestamp}_$documentType.$extension';

    final mimeType = switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };

    // 1. Upload to storage
    await _client.storage.from('title-docs').uploadBinary(
      storagePath,
      fileBytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: true),
    );

    // 2. Insert metadata record
    final record = await _client
        .from('title_documents')
        .insert({
          'search_id': searchId,
          'user_id': user.id,
          'document_type': documentType,
          'document_label': documentLabel,
          'file_path': storagePath,
          'file_name': fileName,
          'file_size': fileBytes.length,
          'mime_type': mimeType,
          'extraction_status': 'pending',
        })
        .select()
        .single();

    final doc = TitleDocument.fromJson(record);

    // 3. Fire-and-forget: Trigger Gemini AI Extraction in the background
    triggerExtraction(doc.id).catchError((e) {
      debugPrint('Background title doc extraction error: $e');
    });

    return doc;
  }

  /// Deletes a document
  static Future<void> deleteDocument(String documentId, String filePath) async {
    BaseRepository.requireAuth();
    await _client.from('title_documents').delete().eq('id', documentId);
    try {
      await _client.storage.from('title-docs').remove([filePath]);
    } catch (_) {}
  }

  /// Triggers AI extraction on a single document via Edge Function
  static Future<void> triggerExtraction(String documentId) async {
    BaseRepository.requireAuth();
    await _client.functions.invoke(
      'title-extract',
      body: {'action': 'extract_document', 'document_id': documentId},
    );
  }

  /// Triggers full cross-reference analysis across all documents
  static Future<Map<String, dynamic>> triggerAnalysis(String searchId) async {
    BaseRepository.requireAuth();
    final res = await _client.functions.invoke(
      'title-extract',
      body: {'action': 'analyze_search', 'search_id': searchId},
    );
    return res.data as Map<String, dynamic>? ?? {};
  }

  /// Fetches findings (inconsistencies, warnings, passed checks)
  static Future<List<TitleFinding>> fetchFindings(String searchId) async {
    BaseRepository.requireAuth();
    final data = await _client
        .from('title_findings')
        .select('*')
        .eq('search_id', searchId)
        .order('severity', ascending: true); // critical first
    return (data as List).map((json) => TitleFinding.fromJson(json)).toList();
  }

  /// Fetches chain of title links (30-year ownership timeline)
  static Future<List<TitleChainLink>> fetchChainLinks(String searchId) async {
    BaseRepository.requireAuth();
    final data = await _client
        .from('title_chain_links')
        .select('*')
        .eq('search_id', searchId)
        .order('link_order', ascending: true);
    return (data as List).map((json) => TitleChainLink.fromJson(json)).toList();
  }
}
