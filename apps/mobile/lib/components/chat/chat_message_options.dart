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

  const ChatMessageOptions({
    super.key,
    required this.message,
    required this.isMe,
    required this.isDark,
    this.onReply,
    this.onSave,
    this.onDelete,
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
          SizedBox(height: 16.h),
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
