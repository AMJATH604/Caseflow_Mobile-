import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/commission_models.dart';
import '../../theme/app_theme.dart';

/// Displays the evidence photo grid for a commission.
///
/// Shows a grid of captured evidence photos with download overlays,
/// a "Download All" button, and an "Add Photo" card.
class CommissionEvidenceTab extends StatelessWidget {
  final List<CommissionEvidence> evidence;
  final bool isDark;
  final VoidCallback onCaptureEvidence;
  final VoidCallback onDownloadAll;
  final ValueChanged<CommissionEvidence> onDownloadSingle;

  const CommissionEvidenceTab({
    super.key,
    required this.evidence,
    required this.isDark,
    required this.onCaptureEvidence,
    required this.onDownloadAll,
    required this.onDownloadSingle,
  });

  @override
  Widget build(BuildContext context) {
    if (evidence.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            SizedBox(height: 12.h),
            Text(
              'No evidence captured',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: onCaptureEvidence,
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Capture Photo'),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDownloadAll,
              icon: const Icon(Icons.download_for_offline, size: 18),
              label: Text(
                'Download All Photos for Print',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.info,
                side: BorderSide(color: AppTheme.info.withValues(alpha: 0.5)),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(16.r),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: evidence.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return _addPhotoCard();
              }
              final ev = evidence[i - 1];
              return _evidenceCard(ev);
            },
          ),
        ),
      ],
    );
  }

  Widget _addPhotoCard() => Material(
    color:
        isDark
            ? const Color(0xFF1E1E2E)
            : Colors.black.withValues(alpha: 0.04),
    borderRadius: BorderRadius.circular(14.r),
    child: InkWell(
      onTap: onCaptureEvidence,
      borderRadius: BorderRadius.circular(14.r),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_a_photo,
            size: 32,
            color: AppTheme.accent,
          ),
          SizedBox(height: 8.h),
          Text(
            'Add Photo',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: AppTheme.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _evidenceCard(CommissionEvidence ev) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14.r),
      border: Border.all(
        color: isDark ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
      ),
    ),
    child: Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(13.r),
                ),
                child: Image.network(
                  ev.fileUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder:
                      (_, __, ___) => Container(
                        color:
                            isDark
                                ? Colors.white10
                                : Colors.black.withValues(alpha: 0.05),
                        child: const Icon(Icons.broken_image, size: 32),
                      ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(13.r),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${ev.sequenceNumber}${ev.caption != null ? ' - ${ev.caption}' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    ev.locationText,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.sp,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Download button overlay
        Positioned(
          top: 6.h,
          right: 6.w,
          child: GestureDetector(
            onTap: () => onDownloadSingle(ev),
            child: Container(
              padding: EdgeInsets.all(6.r),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
