import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// WhatsApp-style attachment picker grid.
///
/// Shows a bottom sheet with 4 colorful option icons in a row:
/// Camera, Gallery, Video, Document.
class ChatAttachmentSheet extends StatelessWidget {
  final void Function(String type) onSelect;

  const ChatAttachmentSheet({super.key, required this.onSelect});

  /// Show the attachment sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required void Function(String type) onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChatAttachmentSheet._internal(
        onSelect: (type) {
          Navigator.pop(ctx);
          onSelect(type);
        },
      ),
    );
  }

  const ChatAttachmentSheet._internal({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202C33) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFDADFE3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _attachOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFFFF6584),
                    onTap: () => onSelect('camera'),
                    isDark: isDark,
                  ),
                  _attachOption(
                    icon: Icons.photo_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF7C4DFF),
                    onTap: () => onSelect('gallery'),
                    isDark: isDark,
                  ),
                  _attachOption(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: const Color(0xFF00BFA5),
                    onTap: () => onSelect('video'),
                    isDark: isDark,
                  ),
                  _attachOption(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Document',
                    color: const Color(0xFF5C6BC0),
                    onTap: () => onSelect('file'),
                    isDark: isDark,
                  ),
                ],
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color,
                  color.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? const Color(0xFF8696A0)
                  : const Color(0xFF667781),
            ),
          ),
        ],
      ),
    );
  }
}
