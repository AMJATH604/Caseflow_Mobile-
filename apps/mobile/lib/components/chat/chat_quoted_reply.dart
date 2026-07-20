import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Quoted reply block shown inside a chat bubble when a message is a reply.
class ChatQuotedReply extends StatelessWidget {
  final String? replyToId;
  final String? replyToSender;
  final String? replyToMessage;
  final bool isDark;
  final VoidCallback? onTap;

  const ChatQuotedReply({
    super.key,
    this.replyToId,
    this.replyToSender,
    this.replyToMessage,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 6.h),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Row(
          children: [
            Container(width: 3.w, height: 36.h, color: const Color(0xFF4F46E5)),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    replyToSender ?? 'Advocate',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    replyToMessage ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
