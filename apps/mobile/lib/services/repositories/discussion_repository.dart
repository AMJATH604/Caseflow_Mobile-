import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import 'base_repository.dart';

/// Repository for case discussion & firm notice board.
///
/// **Real-time:** Uses Supabase Realtime channel subscriptions
/// for instant message delivery (not polling).
/// **File sharing:** Supports image/document attachments via Supabase Storage.
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

  /// **Real-time stream using Supabase Realtime channels.**
  ///
  /// For case discussions: uses `.stream()` with case_id filter (works well).
  /// For firm notices: uses a manual Realtime channel + initial fetch
  /// to guarantee instant delivery (the old `.stream()` approach was unreliable
  /// for firm notices because `isFilter` isn't supported by `.stream()`).
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
      // Use manual Realtime channel for firm notices — guarantees instant delivery
      return _firmNoticesStream(firmId);
    }
    return Stream.value([]);
  }

  /// Manual Realtime stream for firm notices.
  /// Combines initial fetch + INSERT/DELETE channel events.
  static Stream<List<CaseComment>> _firmNoticesStream(String firmId) {
    final controller = StreamController<List<CaseComment>>.broadcast();
    List<CaseComment> messages = [];

    // 1. Initial fetch
    fetchDiscussions(firmId: firmId).then((data) {
      messages = data;
      if (!controller.isClosed) controller.add(List.from(messages));
    }).catchError((e) {
      debugPrint('Firm notices initial fetch error: $e');
      if (!controller.isClosed) controller.addError(e);
    });

    // 2. Realtime subscription for new messages
    final channelName = 'firm_notices_$firmId';
    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'case_discussions',
          callback: (payload) {
            try {
              final newRecord = payload.newRecord;
              // Only add if it's a firm notice (case_id is null) for this firm
              if (newRecord['firm_id'] == firmId && newRecord['case_id'] == null) {
                final comment = CaseComment.fromJson(newRecord);
                // Avoid duplicates
                if (!messages.any((m) => m.id == comment.id)) {
                  messages.add(comment);
                  if (!controller.isClosed) controller.add(List.from(messages));
                }
              }
            } catch (e) {
              debugPrint('Firm notice parse error: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'case_discussions',
          callback: (payload) {
            try {
              final oldId = payload.oldRecord['id'];
              messages.removeWhere((m) => m.id == oldId);
              if (!controller.isClosed) controller.add(List.from(messages));
            } catch (e) {
              debugPrint('Firm notice delete error: $e');
            }
          },
        )
        .subscribe();

    // Cleanup on cancel
    controller.onCancel = () {
      _client.removeChannel(channel);
    };

    return controller.stream;
  }

  /// Post a discussion message (text + optional attachment).
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

  // ─── FILE UPLOAD ──────────────────────────────────────

  /// Upload a file to Supabase Storage and return the public URL.
  /// Files are stored in the `chat-attachments` bucket.
  static Future<String?> uploadAttachment({
    required File file,
    required String firmId,
  }) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final fileName = '${firmId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'chambers/$firmId/$fileName';

      await _client.storage
          .from('chat-attachments')
          .upload(storagePath, file);

      final publicUrl = _client.storage
          .from('chat-attachments')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      debugPrint('Upload attachment error: $e');
      return null;
    }
  }

  /// Determine the attachment type from file extension.
  static String getAttachmentType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)) {
      return 'image';
    } else if (['pdf', 'doc', 'docx', 'xls', 'xlsx'].contains(ext)) {
      return 'document';
    }
    return 'file';
  }
}
