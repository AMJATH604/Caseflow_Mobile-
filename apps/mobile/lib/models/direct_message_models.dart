import '../utils/safe_date.dart';
import 'models.dart';
import '../components/chat/chat_message_data.dart';

class DirectConversation {
  final String id;
  final String participant1;
  final String participant2;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final UserProfile? partner;
  final DirectMessage? lastMessage;
  final int unreadCount;

  DirectConversation({
    required this.id,
    required this.participant1,
    required this.participant2,
    required this.lastMessageAt,
    required this.createdAt,
    this.partner,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory DirectConversation.fromJson(Map<String, dynamic> json) {
    return DirectConversation(
      id: json['id'] ?? '',
      participant1: json['participant_1'] ?? '',
      participant2: json['participant_2'] ?? '',
      lastMessageAt: parseDateOr(json['last_message_at'], DateTime.now()),
      createdAt: parseDateOr(json['created_at'], DateTime.now()),
      partner: json['partner'] != null ? UserProfile.fromJson(json['partner']) : null,
      lastMessage: json['last_message'] != null ? DirectMessage.fromJson(json['last_message']) : null,
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}

class DirectMessage with ChatMessageData {
  final String id;
  final String conversationId;
  final String senderId;
  final String message;
  final String? attachmentUrl;
  final String? attachmentType;
  final bool isRead;
  final DateTime? deliveredAt;
  final DateTime createdAt;
  final String? replyToId;
  final String? replyToMessage;
  final String? replyToSender;
  @override
  final DateTime? editedAt;

  DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.message,
    this.attachmentUrl,
    this.attachmentType,
    this.isRead = false,
    this.deliveredAt,
    required this.createdAt,
    this.replyToId,
    this.replyToMessage,
    this.replyToSender,
    this.editedAt,
  });

  // hasAttachment, isImage, isVideo, hasReply are inherited from ChatMessageData

  /// Whether the recipient's device has received this message (double ticks).
  bool get isDelivered => deliveredAt != null || isRead;

  factory DirectMessage.fromJson(Map<String, dynamic> json) => DirectMessage(
        id: json['id'] ?? '',
        conversationId: json['conversation_id'] ?? '',
        senderId: json['sender_id'] ?? '',
        message: json['message'] ?? '',
        attachmentUrl: json['attachment_url'],
        attachmentType: json['attachment_type'],
        isRead: json['is_read'] ?? false,
        deliveredAt: json['delivered_at'] != null
            ? parseDateOr(json['delivered_at'], DateTime.now())
            : null,
        createdAt: parseDateOr(json['created_at'], DateTime.now()),
        replyToId: json['reply_to_id'],
        replyToMessage: json['reply_to_message'],
        replyToSender: json['reply_to_sender'],
        editedAt: json['edited_at'] != null
            ? parseDateOr(json['edited_at'], DateTime.now())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'message': message,
        'attachment_url': attachmentUrl,
        'attachment_type': attachmentType,
        'is_read': isRead,
        'delivered_at': deliveredAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'reply_to_id': replyToId,
        'reply_to_message': replyToMessage,
        'reply_to_sender': replyToSender,
        'edited_at': editedAt?.toIso8601String(),
      };
}

/// A single emoji reaction on a message (DM or Chambers).
class MessageReaction {
  final String id;
  final String scope; // 'dm' | 'chambers'
  final String messageId;
  final String userId;
  final String emoji;

  MessageReaction({
    required this.id,
    required this.scope,
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) => MessageReaction(
        id: json['id'] ?? '',
        scope: json['scope'] ?? '',
        messageId: json['message_id'] ?? '',
        userId: json['user_id'] ?? '',
        emoji: json['emoji'] ?? '',
      );
}

