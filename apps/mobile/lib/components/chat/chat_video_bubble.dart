import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Video message bubble with download progress and play button overlay.
class ChatVideoBubble extends StatelessWidget {
  final String attachmentUrl;
  final bool isDark;
  final Map<String, double> downloadProgress;
  final void Function(String url)? onTap;

  const ChatVideoBubble({
    super.key,
    required this.attachmentUrl,
    required this.isDark,
    this.downloadProgress = const {},
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = downloadProgress.containsKey(attachmentUrl);
    final progress = downloadProgress[attachmentUrl] ?? 0.0;

    return GestureDetector(
      onTap: isDownloading ? null : () => onTap?.call(attachmentUrl),
      child: Container(
        width: 260.w,
        height: 180.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
          ),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 1.w,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                  Icons.video_library_rounded,
                  size: 100,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            if (isDownloading)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 56.w,
                    height: 56.h,
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      color: const Color(0xFF4F46E5),
                      strokeWidth: 4,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Downloading video...',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              )
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64.w,
                    height: 64.h,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black45 : Colors.white70,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 40,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Tap to Play Video',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
