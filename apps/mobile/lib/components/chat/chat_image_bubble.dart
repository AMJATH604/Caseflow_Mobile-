import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Image message bubble with local cache support and network fallback.
class ChatImageBubble extends StatelessWidget {
  final String attachmentUrl;
  final bool isDark;
  final Map<String, bool> localFilesExist;
  final Map<String, String> localPaths;
  final Map<String, double> downloadProgress;
  final void Function(String url)? onTap;
  final void Function(String url, String displayName)? onDownloadInBackground;

  const ChatImageBubble({
    super.key,
    required this.attachmentUrl,
    required this.isDark,
    this.localFilesExist = const {},
    this.localPaths = const {},
    this.downloadProgress = const {},
    this.onTap,
    this.onDownloadInBackground,
  });

  @override
  Widget build(BuildContext context) {
    final localExists = localFilesExist[attachmentUrl] == true;
    final localPath = localPaths[attachmentUrl];

    if (!localExists && !downloadProgress.containsKey(attachmentUrl)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onDownloadInBackground?.call(attachmentUrl, 'Image.png');
      });
    }

    return GestureDetector(
      onTap: () {
        if (localExists && localPath != null) {
          onTap?.call(localPath);
        } else {
          onTap?.call(attachmentUrl);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: localExists && localPath != null
            ? Image.file(
                File(localPath),
                width: 260.w,
                height: 200.h,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildNetworkImage(),
              )
            : _buildNetworkImage(),
      ),
    );
  }

  Widget _buildNetworkImage() {
    return Image.network(
      attachmentUrl,
      width: 260.w,
      height: 200.h,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          width: 260.w,
          height: 200.h,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey[200],
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!
                  : null,
              color: const Color(0xFF4F46E5),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        width: 260.w,
        height: 80.h,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: const Center(
          child: Icon(
            Icons.broken_image_rounded,
            color: Colors.grey,
            size: 32,
          ),
        ),
      ),
    );
  }
}
