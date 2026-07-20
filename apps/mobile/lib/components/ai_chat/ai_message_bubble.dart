import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../services/gemini_service.dart';
import 'ai_genui_cards.dart';

/// A single AI or user message bubble with avatar, content, and action chips.
class AiMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;
  final bool isDark;

  const AiMessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAiAvatar(),
            SizedBox(width: 10.w),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.accent
                    : isDark
                        ? const Color(0xFF1E1E2E)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18.r),
                  topRight: Radius.circular(18.r),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: isDark
                            ? const Color(0xFF2D2D3F)
                            : const Color(0xFFE2E8F0),
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: message.isLoading
                  ? _buildTypingIndicator()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show attached image in user bubble
                        if (isUser && message.hasImage) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10.r),
                            child: message.imagePath != null
                                ? Image.file(
                                    File(message.imagePath!),
                                    width: 200.w,
                                    height: 150.h,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 200.w,
                                      height: 60.h,
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(Icons.broken_image),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          SizedBox(height: 8.h),
                        ],
                        _buildMessageContent(context),
                        if (!isUser) ...[
                          SizedBox(height: 8.h),
                          _buildCopyChip(context),
                        ],
                      ],
                    ),
            ),
          ),
          if (isUser) ...[
            SizedBox(width: 10.w),
            _buildUserAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAiAvatar() {
    return Container(
      width: 32.w,
      height: 32.h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF22D3EE)],
        ),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: const Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32.w,
      height: 32.h,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232330) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Icon(
        Icons.person_rounded,
        color: isDark ? Colors.white70 : const Color(0xFF475569),
        size: 18,
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (isUser) {
      return SelectableText(
        message.text,
        style: GoogleFonts.inter(
          fontSize: 14.sp,
          height: 1.6.h,
          color: Colors.white,
        ),
      );
    }

    // Parse Gen UI tags: <genui-([a-z0-9\-]+)([^>]*)\/>
    return AiGenUiContent(
      text: message.text,
      isDark: isDark,
    );
  }

  Widget _buildCopyChip(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: message.text));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Copied to clipboard'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(milliseconds: 1500),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF232330) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.copy_rounded,
                  size: 13,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
                SizedBox(width: 5.w),
                Text(
                  'Copy',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        SizedBox(width: 4.w),
        _buildDot(1),
        SizedBox(width: 4.w),
        _buildDot(2),
        SizedBox(width: 8.w),
        Text(
          'Thinking...',
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            color: const Color(0xFF94A3B8),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8.w,
          height: 8.h,
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.4 + (value * 0.6)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
