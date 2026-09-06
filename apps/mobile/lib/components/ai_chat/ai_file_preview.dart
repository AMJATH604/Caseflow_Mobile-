import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Preview strip shown above the AI chat input when a file (image or document)
/// has been queued for sending.
class AiFilePreview extends StatelessWidget {
  final File file;
  final bool isDark;
  final VoidCallback onRemove;

  const AiFilePreview({
    super.key,
    required this.file,
    required this.isDark,
    required this.onRemove,
  });

  bool get _isImage {
    final ext = p.extension(file.path).toLowerCase().replaceAll('.', '');
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(file.path);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161620) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF232330) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              if (_isImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: Image.file(
                    file,
                    width: 60.w,
                    height: 60.h,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 60.w,
                  height: 60.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getFileIcon(fileName),
                        color: const Color(0xFF6366F1),
                        size: 24,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        p.extension(fileName).toUpperCase().replaceAll('.', ''),
                        style: GoogleFonts.inter(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                top: -4,
                right: -4,
                child: InkWell(
                  onTap: onRemove,
                  child: Container(
                    width: 22.w,
                    height: 22.h,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isImage ? 'Image attached' : fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _isImage
                      ? 'Add a message or tap send'
                      : 'Document ready — add a message or tap send',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = p.extension(fileName).toLowerCase().replaceAll('.', '');
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.article_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'txt':
        return Icons.text_snippet_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
