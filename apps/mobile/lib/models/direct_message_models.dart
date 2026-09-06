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
      lastMessageAt: DateTime.parse(
        json['last_message_at'] ?? DateTime.now().toIso8601String(),
      ),
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
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
  final DateTime createdAt;
  final String? replyToId;
  final String? replyToMessage;
  final String? replyToSender;

  DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.message,
    this.attachmentUrl,
    this.attachmentType,
    this.isRead = false,
    required this.createdAt,
    this.replyToId,
    this.replyToMessage,
    this.replyToSender,
  });

  // hasAttachment, isImage, isVideo, hasReply are inherited from ChatMessageData

  factory DirectMessage.fromJson(Map<String, dynamic> json) => DirectMessage(
        id: json['id'] ?? '',
        conversationId: json['conversation_id'] ?? '',
        senderId: json['sender_id'] ?? '',
        message: json['message'] ?? '',
        attachmentUrl: json['attachment_url'],
        attachmentType: json['attachment_type'],
        isRead: json['is_read'] ?? false,
        createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String(),
        ),
        replyToId: json['reply_to_id'],
        replyToMessage: json['reply_to_message'],
        replyToSender: json['reply_to_sender'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'message': message,
        'attachment_url': attachmentUrl,
        'attachment_type': attachmentType,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
        'reply_to_id': replyToId,
        'reply_to_message': replyToMessage,
        'reply_to_sender': replyToSender,
      };
}

