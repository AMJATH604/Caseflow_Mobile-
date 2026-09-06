/// Generic interface for chat messages.
///
/// Both [DirectMessage] and [CaseComment] implement these fields identically,
/// so shared chat widgets can operate on this abstraction without coupling to
/// either concrete model.
abstract mixin class ChatMessageData {
  String get id;
  String get senderId;
  String get message;
  String? get attachmentUrl;
  String? get attachmentType;
  DateTime get createdAt;

  // Reply fields
  String? get replyToId;
  String? get replyToMessage;
  String? get replyToSender;

  // Computed helpers
  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isImage => attachmentType == 'image';
  bool get isVideo => attachmentType == 'video';
  bool get hasReply => replyToId != null && replyToId!.isNotEmpty;
}
