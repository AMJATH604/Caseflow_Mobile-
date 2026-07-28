import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// WhatsApp-style quoted reply block inside a chat bubble.
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
        margin: EdgeInsets.only(bottom: 4.h),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Accent bar
              Container(
                width: 4.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A884),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8.r),
                    bottomLeft: Radius.circular(8.r),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 5.h, horizontal: 2.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        replyToSender ?? 'Advocate',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00A884),
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        replyToMessage ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 12.5.sp,
                          color: isDark
                              ? const Color(0xFF8696A0)
                              : const Color(0xFF667781),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 6.w),
            ],
          ),
        ),
      ),
    );
  }
}
