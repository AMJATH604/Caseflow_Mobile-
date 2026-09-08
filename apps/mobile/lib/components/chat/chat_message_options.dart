import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'chat_message_data.dart';

/// Long-press message options bottom sheet (reply, copy, save, delete).
class ChatMessageOptions<T extends ChatMessageData> extends StatelessWidget {
  final T message;
  final bool isMe;
  final bool isDark;
  final VoidCallback? onReply;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onForward;
  final VoidCallback? onEdit;

  /// Called with the tapped emoji from the quick-reaction row.
  final void Function(String emoji)? onReact;

  /// The current user's existing reaction on this message (to highlight it).
  final String? myReaction;

  /// Quick reactions shown in the row (WhatsApp-style).
  static const List<String> quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  const ChatMessageOptions({
    super.key,
    required this.message,
    required this.isMe,
    required this.isDark,
    this.onReply,
    this.onSave,
    this.onDelete,
    this.onForward,
    this.onEdit,
    this.onReact,
    this.myReaction,
  });

  /// Show message options as a modal bottom sheet.
  static Future<void> show<T extends ChatMessageData>(
    BuildContext context, {
    required T message,
    required bool isMe,
    required bool isDark,
    VoidCallback? onReply,
    VoidCallback? onSave,
    VoidCallback? onDelete,
    VoidCallback? onForward,
    VoidCallback? onEdit,
    void Function(String emoji)? onReact,
    String? myReaction,
  }) {
    return showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      builder: (ctx) => ChatMessageOptions<T>(
        message: message,
        isMe: isMe,
        isDark: isDark,
        myReaction: myReaction,
        onReact: onReact != null
            ? (emoji) {
                Navigator.pop(ctx);
                onReact(emoji);
              }
            : null,
        onReply: onReply != null
            ? () {
                Navigator.pop(ctx);
                onReply();
              }
            : null,
        onSave: onSave != null
            ? () {
                Navigator.pop(ctx);
                onSave();
              }
            : null,
        onForward: onForward != null
            ? () {
                Navigator.pop(ctx);
                onForward();
              }
            : null,
        onEdit: onEdit != null
            ? () {
                Navigator.pop(ctx);
                onEdit();
              }
            : null,
        onDelete: onDelete != null
            ? () {
                Navigator.pop(ctx);
                onDelete();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12.h),
          Container(
            width: 38.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 12.h),
          // ─── Quick reaction row (WhatsApp-style) ──────────
          if (onReact != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: quickReactions.map((emoji) {
                final selected = myReaction == emoji;
                return GestureDetector(
                  onTap: () => onReact!(emoji),
                  child: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? (isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : const Color(0xFF4F46E5).withValues(alpha: 0.12))
                          : Colors.transparent,
                    ),
                    child: Text(emoji, style: TextStyle(fontSize: 24.sp)),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 8.h),
            Divider(
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              height: 1,
            ),
            SizedBox(height: 4.h),
          ],
          if (onReply != null)
            _buildOption(
              icon: Icons.reply_rounded,
              label: 'Reply',
              color: isDark ? Colors.white70 : const Color(0xFF4F46E5),
              onTap: onReply!,
            ),
          if (!message.hasAttachment)
            _buildOption(
              icon: Icons.copy_rounded,
              label: 'Copy Text',
              color: isDark ? Colors.white70 : const Color(0xFF4F46E5),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.message));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          if (onForward != null)
            _buildOption(
              icon: Icons.forward_rounded,
              label: 'Forward',
              color: isDark ? Colors.white70 : const Color(0xFF4F46E5),
              onTap: onForward!,
            ),
          if (isMe && !message.hasAttachment && onEdit != null)
            _buildOption(
              icon: Icons.edit_rounded,
              label: 'Edit',
              color: isDark ? Colors.white70 : const Color(0xFF4F46E5),
              onTap: onEdit!,
            ),
          if (message.hasAttachment && onSave != null)
            _buildOption(
              icon: Icons.download_rounded,
              label: 'Save to Device',
              color: isDark ? Colors.white70 : const Color(0xFF4F46E5),
              onTap: onSave!,
            ),
          if (isMe && onDelete != null)
            _buildOption(
              icon: Icons.delete_rounded,
              label: 'Delete for Everyone',
              color: const Color(0xFFEF4444),
              onTap: onDelete!,
            ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: color == const Color(0xFFEF4444)
              ? color
              : (isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
      ),
      onTap: onTap,
    );
  }
}
