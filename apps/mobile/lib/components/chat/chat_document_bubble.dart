import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Document/file attachment bubble with icon, filename, extension badge, and download.
class ChatDocumentBubble extends StatelessWidget {
  final String attachmentUrl;
  final String messageText;
  final bool isMe;
  final bool isDark;
  final Map<String, double> downloadProgress;
  final void Function(String url, String name)? onTap;
  final VoidCallback? onSave;

  const ChatDocumentBubble({
    super.key,
    required this.attachmentUrl,
    required this.messageText,
    required this.isMe,
    required this.isDark,
    this.downloadProgress = const {},
    this.onTap,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final name = messageText.replaceFirst('📄 ', '');
    final ext = attachmentUrl.split('.').last.split('?').first.toLowerCase();
    final isDownloading = downloadProgress.containsKey(attachmentUrl);

    return Container(
      width: 250.w,
      decoration: BoxDecoration(
        color: isMe ? Colors.black12 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10.r),
      ),
      padding: EdgeInsets.all(8.r),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: _docColor(ext).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: isDownloading
                ? Padding(
                    padding: EdgeInsets.all(10.r),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _docColor(ext),
                    ),
                  )
                : Icon(_docIcon(ext), color: _docColor(ext), size: 24),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: GestureDetector(
              onTap: () => onTap?.call(attachmentUrl, name),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    ext.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isDownloading)
            GestureDetector(
              onTap: onSave,
              child: Container(
                width: 36.w,
                height: 36.h,
                decoration: BoxDecoration(
                  color: _docColor(ext).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.download_rounded,
                  color: _docColor(ext),
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Color _docColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'txt':
        return Colors.grey;
      default:
        return const Color(0xFF4F46E5);
    }
  }

  static IconData _docIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.article_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
