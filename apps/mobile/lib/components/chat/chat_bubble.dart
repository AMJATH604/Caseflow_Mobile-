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

/// Premium WhatsApp-style chat bubble.
///
/// Where one of my messages is on its way, as WhatsApp shows it: a clock
/// while sending, ticks once saved, a red mark if it could not be sent.
enum MessageSendState { sent, sending, failed }

/// Renders a message bubble with proper tail shape, adaptive colors,
/// and supports text, image, video, voice, and document content types.
class ChatBubble<T extends ChatMessageData> extends StatelessWidget {
  final T message;
  final bool isMe;
  final bool isDark;

  /// Whether to show read receipts (blue/grey double-ticks). Only applicable for DMs.
  final bool showReadReceipt;

  /// Whether the message has been read (only used when [showReadReceipt] is true).
  final bool isRead;

  /// Whether the message has been delivered to the recipient's device.
  /// Drives the single-tick (sent) vs double-tick (delivered/read) distinction.
  final bool isDelivered;

  /// Sending / sent / failed, for my own messages.
  final MessageSendState sendState;

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

  /// Emoji → count for reactions on this message.
  final Map<String, int> reactionCounts;

  /// The current user's own reaction emoji on this message, if any (highlighted).
  final String? myReactionEmoji;

  /// Tapped a reaction chip (WhatsApp: tap your own reaction to remove it).
  final void Function(String emoji)? onReactionTap;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isDark,
    this.showReadReceipt = false,
    this.isRead = false,
    this.isDelivered = false,
    this.sendState = MessageSendState.sent,
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
    this.reactionCounts = const {},
    this.myReactionEmoji,
    this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    // ─── Modern High-Contrast Bubble Colors ────────────
    final bubbleColor = isMe
        ? (isDark ? const Color(0xFF1E293B) : Colors.white)
        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9));
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final metaColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              margin: EdgeInsets.only(
                bottom: reactionCounts.isEmpty ? 4.h : 2.h,
                left: isMe ? 64.w : 0,
                right: isMe ? 0 : 64.w,
              ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
              bottomLeft: Radius.circular(isMe ? 16.r : 4.r),
              bottomRight: Radius.circular(isMe ? 4.r : 16.r),
            ),
            border: Border.all(
              color: isMe
                  ? (isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0))
                  : (isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0)),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 8.w,
              right: 8.w,
              top: 6.h,
              bottom: 5.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── Sender name (group chats) ───────
                if (senderName != null && !isMe) ...[
                  Text(
                    senderName!,
                    style: GoogleFonts.inter(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                      color: senderNameColor ?? const Color(0xFF00A884),
                    ),
                  ),
                  SizedBox(height: 2.h),
                ],

                // ─── Quoted reply ────────────────────
                if (message.hasReply)
                  ChatQuotedReply(
                    replyToId: message.replyToId,
                    replyToSender: message.replyToSender,
                    replyToMessage: message.replyToMessage,
                    isDark: isDark,
                    onTap: onReplyTap,
                  ),

                // ─── Attachment content ──────────────
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
                  SizedBox(height: 4.h),
                ],

                // ─── Text content ────────────────────
                if (!message.hasAttachment)
                  Text(
                    message.message,
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 14.5.sp,
                      height: 1.35,
                    ),
                  ),

                // ─── Timestamp + read receipt ────────
                SizedBox(height: 2.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (message.isEdited) ...[
                      Text(
                        'edited',
                        style: GoogleFonts.inter(
                          fontSize: 10.5.sp,
                          color: metaColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(width: 5.w),
                    ],
                    Text(
                      DateFormat('h:mm a').format(message.createdAt.toLocal()),
                      style: GoogleFonts.inter(
                        fontSize: 10.5.sp,
                        color: metaColor,
                      ),
                    ),
                    if (isMe && sendState != MessageSendState.sent) ...[
                      SizedBox(width: 4.w),
                      Icon(
                        sendState == MessageSendState.sending
                            ? Icons.schedule_rounded
                            : Icons.error_rounded,
                        size: 15.sp,
                        color: sendState == MessageSendState.sending
                            ? metaColor
                            : const Color(0xFFEF4444),
                      ),
                    ] else if (showReadReceipt && isMe) ...[
                      SizedBox(width: 4.w),
                      // 3-state ticks:
                      //   sent      → single grey  ✓
                      //   delivered → double grey  ✓✓
                      //   read      → double blue  ✓✓
                      Icon(
                        (isRead || isDelivered)
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 16.sp,
                        color: isRead
                            ? const Color(0xFF53BDEB)
                            : metaColor,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
          if (reactionCounts.isNotEmpty) _buildReactionChips(metaColor),
        ],
      ),
    );
  }

  Widget _buildReactionChips(Color metaColor) {
    return Container(
      margin: EdgeInsets.only(
        bottom: 6.h,
        left: isMe ? 0 : 8.w,
        right: isMe ? 8.w : 0,
      ),
      child: Wrap(
        spacing: 4.w,
        children: reactionCounts.entries.map((e) {
          final mine = myReactionEmoji == e.key;
          return GestureDetector(
            onTap: onReactionTap != null ? () => onReactionTap!(e.key) : null,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: mine
                    ? (isDark
                        ? const Color(0xFF4F46E5).withValues(alpha: 0.35)
                        : const Color(0xFF4F46E5).withValues(alpha: 0.12))
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: mine
                      ? const Color(0xFF4F46E5)
                      : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.key, style: TextStyle(fontSize: 12.sp)),
                  if (e.value > 1) ...[
                    SizedBox(width: 3.w),
                    Text(
                      '${e.value}',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        color: metaColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
