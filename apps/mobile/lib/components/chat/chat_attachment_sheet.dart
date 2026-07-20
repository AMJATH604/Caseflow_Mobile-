import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Bottom sheet for choosing attachment type (camera, gallery, video, document).
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Share Attachment',
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachOption(
                  Icons.camera_alt_rounded,
                  'Camera',
                  Colors.pink,
                  () => onSelect('camera'),
                ),
                _attachOption(
                  Icons.photo_library_rounded,
                  'Gallery',
                  Colors.purple,
                  () => onSelect('gallery'),
                ),
                _attachOption(
                  Icons.video_library_rounded,
                  'Video',
                  Colors.deepPurple,
                  () => onSelect('video'),
                ),
                _attachOption(
                  Icons.description_rounded,
                  'Document',
                  Colors.blue,
                  () => onSelect('file'),
                ),
              ],
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Column(
        children: [
          Container(
            width: 56.w,
            height: 56.h,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
