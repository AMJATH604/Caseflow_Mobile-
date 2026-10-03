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

  static Future<List<CaseComment>> fetchDiscussions({
    String? caseId,
    String? firmId,
  }) async {
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
  static Stream<List<CaseComment>> discussionsStream({
    String? caseId,
    String? firmId,
  }) {
    if (caseId != null) {
      return _client
          .from('case_discussions')
          .stream(primaryKey: ['id'])
          .eq('case_id', caseId)
          .order('created_at', ascending: true)
          .map(
            (data) => data.map((json) => CaseComment.fromJson(json)).toList(),
          );
    } else if (firmId != null) {
      // Use manual Realtime channel for firm notices — guarantees instant delivery
      return _firmNoticesStream(firmId);
    }
    return Stream.value([]);
  }

  /// Manual Realtime stream for firm notices (Chambers).
  ///
  /// Like WhatsApp, the list stays complete and in order however the
  /// connection behaves: every row is kept by id (a message can never appear
  /// twice), edits and deletions arrive live, and each time the channel
  /// (re)connects — after the phone sleeps or changes network — the thread is
  /// fetched again so messages sent meanwhile are not missed.
  static Stream<List<CaseComment>> _firmNoticesStream(String firmId) {
    final controller = StreamController<List<CaseComment>>.broadcast();
    final byId = <String, CaseComment>{};

    void emit() {
      if (controller.isClosed) return;
      final list = byId.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      controller.add(list);
    }

    Future<void> refetch() async {
      try {
        final data = await fetchDiscussions(firmId: firmId);
        final fresh = {for (final m in data) m.id};
        // Rows gone from the server were deleted while we were away.
        byId.removeWhere((id, _) => !fresh.contains(id));
        for (final m in data) {
          byId[m.id] = m;
        }
        emit();
      } catch (e) {
        debugPrint('Firm notices fetch error: $e');
        if (byId.isEmpty && !controller.isClosed) controller.addError(e);
      }
    }

    bool isFirmNotice(Map<String, dynamic> row) =>
        row['firm_id'] == firmId && row['case_id'] == null;

    // 1. Initial fetch
    refetch();

    // 2. Realtime: this firm's rows only, filtered by the server.
    final channel = _client.channel('firm_notices_$firmId');
    final firmFilter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'firm_id',
      value: firmId,
    );

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'case_discussions',
          filter: firmFilter,
          callback: (payload) {
            try {
              if (!isFirmNotice(payload.newRecord)) return;
              final comment = CaseComment.fromJson(payload.newRecord);
              byId[comment.id] = comment;
              emit();
            } catch (e) {
              debugPrint('Firm notice parse error: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'case_discussions',
          filter: firmFilter,
          callback: (payload) {
            try {
              if (!isFirmNotice(payload.newRecord)) return;
              final comment = CaseComment.fromJson(payload.newRecord);
              byId[comment.id] = comment; // An edit replaces the message.
              emit();
            } catch (e) {
              debugPrint('Firm notice update error: $e');
            }
          },
        )
        .onPostgresChanges(
          // Unfiltered: a deleted row carries only its id.
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'case_discussions',
          callback: (payload) {
            final oldId = payload.oldRecord['id'];
            if (byId.remove(oldId) != null) emit();
          },
        )
        .subscribe((status, error) {
          // On every (re)connect, catch up: the first time covers messages
          // sent between the initial fetch and the channel opening; later
          // times, whatever arrived while the phone was disconnected.
          if (status == RealtimeSubscribeStatus.subscribed) refetch();
        });

    // Cleanup on cancel
    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
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

  /// Edit a Chambers/discussion message's text (own messages only, RLS).
  static Future<void> editDiscussion(String id, String newText) async {
    await _client.from('case_discussions').update({
      'message': newText,
      'edited_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  // ─── Read tracking (Digital Chambers unread badge) ────

  /// Mark the Chambers thread read for the current user up to now.
  static Future<void> markChambersRead(String firmId) async {
    final user = BaseRepository.requireAuth();
    await _client.from('chambers_reads').upsert({
      'user_id': user.id,
      'firm_id': firmId,
      'last_read_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,firm_id');
  }

  /// Count Chambers messages the current user hasn't seen yet
  /// (created after their last_read_at and not sent by them).
  static Future<int> chambersUnreadCount(String firmId) async {
    final user = BaseRepository.requireAuth();

    final readRow = await _client
        .from('chambers_reads')
        .select('last_read_at')
        .eq('user_id', user.id)
        .eq('firm_id', firmId)
        .maybeSingle();

    final lastReadAt = readRow?['last_read_at'];

    var query = _client
        .from('case_discussions')
        .select('id')
        .isFilter('case_id', null)
        .eq('firm_id', firmId)
        .neq('sender_id', user.id);

    if (lastReadAt != null) {
      query = query.gt('created_at', lastReadAt);
    }

    final res = await query;
    return (res as List).length;
  }

  /// The set of user IDs who belong to a firm (owner + direct members +
  /// accepted invited members). Used to decide when a Chambers message has been
  /// read by everyone (group blue tick).
  static Future<Set<String>> firmMemberIds(String firmId) async {
    final ids = <String>{};

    // Firm owner = the user whose id equals the firm id.
    ids.add(firmId);

    // Direct members (profiles.firm_id points at the firm).
    final directMembers = await _client
        .from('profiles')
        .select('id')
        .eq('firm_id', firmId);
    for (final m in (directMembers as List)) {
      if (m['id'] != null) ids.add(m['id'] as String);
    }

    // Invited members that accepted.
    final invited = await _client
        .from('firm_members')
        .select('member_id')
        .eq('owner_id', firmId)
        .eq('status', 'accepted');
    for (final m in (invited as List)) {
      if (m['member_id'] != null) ids.add(m['member_id'] as String);
    }

    return ids;
  }

  /// Map of user_id → last_read_at for a firm's Chambers thread. Used with
  /// [firmMemberIds] to compute "read by all" per message.
  static Future<Map<String, DateTime>> chambersReadTimes(String firmId) async {
    final rows = await _client
        .from('chambers_reads')
        .select('user_id, last_read_at')
        .eq('firm_id', firmId);

    final map = <String, DateTime>{};
    for (final r in (rows as List)) {
      final uid = r['user_id'] as String?;
      final ts = r['last_read_at'];
      if (uid != null && ts != null) {
        final parsed = DateTime.tryParse(ts.toString());
        if (parsed != null) map[uid] = parsed;
      }
    }
    return map;
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
      final fileName =
          '${firmId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'chambers/$firmId/$fileName';

      await _client.storage.from('chat-attachments').upload(storagePath, file);

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
    } else if (['mp4', 'mov', 'avi', 'mkv', '3gp'].contains(ext)) {
      return 'video';
    } else if (['pdf', 'doc', 'docx', 'xls', 'xlsx'].contains(ext)) {
      return 'document';
    }
    return 'file';
  }

  static Future<String?> uploadChambersAttachment({
    required File file,
    required String firmId,
  }) => uploadAttachment(file: file, firmId: firmId);

  static Future<void> postChambersAttachment({
    required String firmId,
    required String message,
    required String url,
    required String type,
    required String senderName,
    String? replyToId,
    String? replyToMessage,
    String? replyToSender,
  }) async {
    await postDiscussion({
      'firm_id': firmId,
      'message': message,
      'attachment_url': url,
      'attachment_type': type,
      'sender_name': senderName,
      'reply_to_id': replyToId,
      'reply_to_message': replyToMessage,
      'reply_to_sender': replyToSender,
    });
  }
}
