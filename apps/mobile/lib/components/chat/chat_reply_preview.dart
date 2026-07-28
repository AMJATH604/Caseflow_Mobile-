import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// WhatsApp-style reply preview bar above the input field.
class ChatReplyPreview extends StatelessWidget {
  final String? senderName;
  final String previewText;
  final bool isDark;
  final VoidCallback? onClose;

  const ChatReplyPreview({
    super.key,
    this.senderName,
    required this.previewText,
    required this.isDark,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      color: isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202C33) : Colors.white,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Teal accent bar
              Container(
                width: 4.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A884),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10.r),
                    bottomLeft: Radius.circular(10.r),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              // Reply content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        senderName ?? 'Advocate',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00A884),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        previewText,
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
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
              // Close button
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 20.sp,
                  color: isDark
                      ? const Color(0xFF8696A0)
                      : const Color(0xFF667781),
                ),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
