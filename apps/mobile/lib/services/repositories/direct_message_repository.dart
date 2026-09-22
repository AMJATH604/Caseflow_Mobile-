import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import 'base_repository.dart';

class DirectMessageRepository {
  static final _client = BaseRepository.client;

  /// Fetch all active 1-on-1 conversations for the current user.
  static Future<List<DirectConversation>> fetchConversations() async {
    final user = BaseRepository.requireAuth();

    // Fetch conversations where user is participant
    final res = await _client
        .from('direct_conversations')
        .select()
        .or('participant_1.eq.${user.id},participant_2.eq.${user.id}')
        .order('last_message_at', ascending: false);

    final conversations = List<Map<String, dynamic>>.from(res);
    if (conversations.isEmpty) return [];

    // Extract partner IDs
    final partnerIds = conversations.map((c) {
      return c['participant_1'] == user.id
          ? c['participant_2'] as String
          : c['participant_1'] as String;
    }).toSet();

    // Fetch partner profiles
    Map<String, Map<String, dynamic>> profileMap = {};
    if (partnerIds.isNotEmpty) {
      // Contact fields are returned only for advocates in the public
      // directory or in your own firm.
      final profiles = await _client.rpc(
        'get_profiles',
        params: {'p_ids': partnerIds.toList()},
      );

      for (final p in profiles) {
        profileMap[p['id']] = p;
      }
    }

    // Fetch last message & unread count for each conversation
    for (final conv in conversations) {
      final partnerId =
          conv['participant_1'] == user.id
              ? conv['participant_2']
              : conv['participant_1'];

      conv['partner'] =
          profileMap[partnerId] ??
          {
            'id': partnerId,
            'full_name': 'Unknown Advocate',
            'user_role': 'advocate',
            'subscription_tier': 'free',
          };

      // Last message
      final lastMsgRes = await _client
          .from('direct_messages')
          .select()
          .eq('conversation_id', conv['id'])
          .order('created_at', ascending: false)
          .limit(1);

      if (lastMsgRes.isNotEmpty) {
        conv['last_message'] = lastMsgRes[0];
      }

      // Unread count (messages sent by partner that are not read)
      final unreadRes = await _client
          .from('direct_messages')
          .select('id')
          .eq('conversation_id', conv['id'])
          .neq('sender_id', user.id)
          .eq('is_read', false);

      conv['unread_count'] = unreadRes.length;
    }

    return conversations
        .map((json) => DirectConversation.fromJson(json))
        .toList();
  }

  /// Fetch messages for a specific conversation.
  static Future<List<DirectMessage>> fetchDirectMessages(
    String conversationId,
  ) async {
    final res = await _client
        .from('direct_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return (res as List).map((json) => DirectMessage.fromJson(json)).toList();
  }

  /// Real-time stream for direct messages in a conversation.
  static Stream<List<DirectMessage>> directMessagesStream(
    String conversationId,
  ) {
    return _client
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map(
          (data) => data.map((json) => DirectMessage.fromJson(json)).toList(),
        );
  }

  /// Send a 1-on-1 direct message.
  static Future<void> sendDirectMessage(
    String conversationId,
    String message, {
    String? attachmentUrl,
    String? attachmentType,
    String? replyToId,
    String? replyToMessage,
    String? replyToSender,
  }) async {
    final user = BaseRepository.requireAuth();

    // Insert the message
    await _client.from('direct_messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'message': message,
      'attachment_url': attachmentUrl,
      'attachment_type': attachmentType,
      'is_read': false,
      'reply_to_id': replyToId,
      'reply_to_message': replyToMessage,
      'reply_to_sender': replyToSender,
    });

    // Update last_message_at in conversation
    await _client
        .from('direct_conversations')
        .update({'last_message_at': DateTime.now().toIso8601String()})
        .eq('id', conversationId);
  }

  /// Mark all messages in a conversation as read (except ones sent by self).
  static Future<void> markMessagesRead(String conversationId) async {
    final user = BaseRepository.requireAuth();
    await _client
        .from('direct_messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', user.id)
        .eq('is_read', false);
  }

  /// Stamp `delivered_at` on every message addressed to the current user that
  /// hasn't been marked delivered yet — across all their conversations. This is
  /// what turns the sender's single tick into a grey double tick. Called when
  /// the recipient's device receives a message (foreground push, chat-list
  /// load), which is the moment "delivered" becomes true.
  static Future<void> markAllIncomingDelivered() async {
    final user = BaseRepository.requireAuth();

    final convs = await _client
        .from('direct_conversations')
        .select('id')
        .or('participant_1.eq.${user.id},participant_2.eq.${user.id}');

    final ids = (convs as List).map((c) => c['id'] as String).toList();
    if (ids.isEmpty) return;

    await _client
        .from('direct_messages')
        .update({'delivered_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('conversation_id', ids)
        .neq('sender_id', user.id)
        .isFilter('delivered_at', null);
  }

  /// Get or create a direct conversation with a partner advocate.
  static Future<String> createOrGetConversation(String partnerId) async {
    final user = BaseRepository.requireAuth();
    final myId = user.id;

    // Check if conversation already exists
    final existing = await _client
        .from('direct_conversations')
        .select('id')
        .or(
          'and(participant_1.eq.$myId,participant_2.eq.$partnerId),and(participant_1.eq.$partnerId,participant_2.eq.$myId)',
        )
        .limit(1);

    if (existing.isNotEmpty) {
      return existing[0]['id'] as String;
    }

    // Otherwise create a new one
    final newConv = await _client
        .from('direct_conversations')
        .insert({
          'participant_1': myId,
          'participant_2': partnerId,
        })
        .select('id')
        .single();

    return newConv['id'] as String;
  }

  /// Delete a direct message.
  static Future<void> deleteDirectMessage(String id) async {
    await _client.from('direct_messages').delete().eq('id', id);
  }

  /// Edit a direct message's text (own messages only, enforced by RLS).
  static Future<void> editDirectMessage(String id, String newText) async {
    await _client.from('direct_messages').update({
      'message': newText,
      'edited_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Upload an attachment for DMs to the chat-attachments bucket.
  static Future<String?> uploadAttachment({
    required File file,
    required String conversationId,
  }) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final fileName =
          '${conversationId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = 'dms/$conversationId/$fileName';

      await _client.storage.from('chat-attachments').upload(storagePath, file);

      final publicUrl = _client.storage
          .from('chat-attachments')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      debugPrint('Upload DM attachment error: $e');
      return null;
    }
  }

  /// Helper to determine the attachment type based on extension.
  static String getAttachmentType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)) {
      return 'image';
    } else if (['mp4', 'mov', 'avi', 'mkv', '3gp'].contains(ext)) {
      return 'video';
    } else if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'ppt', 'pptx'].contains(ext)) {
      return 'document';
    } else if (['m4a', 'mp3', 'wav', 'aac', 'ogg'].contains(ext)) {
      return 'audio';
    }
    return 'file';
  }
}
