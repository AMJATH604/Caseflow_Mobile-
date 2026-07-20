import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'chat_message_data.dart';
import 'chat_quoted_reply.dart';
import 'chat_image_bubble.dart';
import 'chat_video_bubble.dart';
import 'chat_voice_bubble.dart';
import 'chat_document_bubble.dart';

/// The main chat message bubble widget.
///
/// Renders a WhatsApp-style bubble that adapts its content based on message type
/// (text, image, video, voice, document) and includes reply quotes, timestamps,
/// and read receipts.
class ChatBubble<T extends ChatMessageData> extends StatelessWidget {
  final T message;
  final bool isMe;
  final bool isDark;

  /// Whether to show read receipts (blue/grey double-ticks). Only applicable for DMs.
  final bool showReadReceipt;

  /// Whether the message has been read (only used when [showReadReceipt] is true).
  final bool isRead;

  /// Optional sender name to display above the message (for group chats).
  final String? senderName;

  /// Color for the sender name label (for group chat identity).
  final Color? senderNameColor;

  // Callbacks
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyTap;
  final void Function(String url)? onImageTap;
  final void Function(String url)? onVideoTap;
  final void Function(String url)? onPlayVoice;
  final void Function(String url, String name)? onDocumentTap;
  final void Function(T message)? onSaveAttachment;

  // Audio state (passed through to voice bubble)
  final String? playingUrl;
  final bool isPlaying;
  final double audioProgress;
  final String? audioDurationText;

  // Download state
  final Map<String, double> downloadProgress;
  final Map<String, bool> localFilesExist;
  final Map<String, String> localPaths;

  // Image background download trigger
  final void Function(String url, String displayName)? onDownloadInBackground;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isDark,
    this.showReadReceipt = false,
    this.isRead = false,
    this.senderName,
    this.senderNameColor,
    this.onLongPress,
    this.onReplyTap,
    this.onImageTap,
    this.onVideoTap,
    this.onPlayVoice,
    this.onDocumentTap,
    this.onSaveAttachment,
    this.playingUrl,
    this.isPlaying = false,
    this.audioProgress = 0.0,
    this.audioDurationText,
    this.downloadProgress = const {},
    this.localFilesExist = const {},
    this.localPaths = const {},
    this.onDownloadInBackground,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6))
        : (isDark ? const Color(0xFF202C33) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2C34);
    final metaColor = isMe
        ? (isDark ? Colors.white54 : const Color(0xFF667781))
        : (isDark ? Colors.white38 : const Color(0xFF667781));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: EdgeInsets.only(bottom: 6.h),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: isMe
                  ? Colors.transparent
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (senderName != null && !isMe) ...[
                  Text(
                    senderName!,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: senderNameColor ?? const Color(0xFF4F46E5),
                    ),
                  ),
                  SizedBox(height: 4.h),
                ],
                if (message.hasReply)
                  ChatQuotedReply(
                    replyToId: message.replyToId,
                    replyToSender: message.replyToSender,
                    replyToMessage: message.replyToMessage,
                    isDark: isDark,
                    onTap: onReplyTap,
                  ),
                if (message.hasAttachment) ...[
                  if (message.isImage)
                    ChatImageBubble(
                      attachmentUrl: message.attachmentUrl!,
                      isDark: isDark,
                      localFilesExist: localFilesExist,
                      localPaths: localPaths,
                      downloadProgress: downloadProgress,
                      onTap: onImageTap,
                      onDownloadInBackground: onDownloadInBackground,
                    )
                  else if (message.isVideo)
                    ChatVideoBubble(
                      attachmentUrl: message.attachmentUrl!,
                      isDark: isDark,
                      downloadProgress: downloadProgress,
                      onTap: onVideoTap,
                    )
                  else if (message.attachmentType == 'audio' ||
                      message.attachmentType == 'voice')
                    ChatVoiceBubble(
                      attachmentUrl: message.attachmentUrl!,
                      messageText: message.message,
                      isMe: isMe,
                      isDark: isDark,
                      playingUrl: playingUrl,
                      isPlaying: isPlaying,
                      audioProgress: audioProgress,
                      audioDurationText: audioDurationText,
                      onPlayVoice: onPlayVoice,
                    )
                  else
                    ChatDocumentBubble(
                      attachmentUrl: message.attachmentUrl!,
                      messageText: message.message,
                      isMe: isMe,
                      isDark: isDark,
                      downloadProgress: downloadProgress,
                      onTap: onDocumentTap,
                      onSave: onSaveAttachment != null
                          ? () => onSaveAttachment!(message)
                          : null,
                    ),
                  SizedBox(height: 6.h),
                ],
                if (!message.hasAttachment)
                  Text(
                    message.message,
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 14.sp,
                      height: 1.4.h,
                    ),
                  ),
                SizedBox(height: 4.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(message.createdAt.toLocal()),
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        color: metaColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (showReadReceipt && isMe) ...[
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.done_all_rounded,
                        size: 14,
                        color: isRead ? const Color(0xFF10B981) : metaColor,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
