import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/commission_models.dart';
import '../../theme/app_theme.dart';
import '../secure_network_image.dart';

/// Displays the sketches grid for a commission.
///
/// Shows a grid of created sketches with edit/delete overlays,
/// download buttons, and a "New Sketch" card.
class CommissionSketchesTab extends StatelessWidget {
  final List<CommissionSketch> sketches;
  final bool isDark;
  final VoidCallback onCreateSketch;
  final ValueChanged<CommissionSketch> onEditSketch;
  final ValueChanged<CommissionSketch> onDeleteSketch;
  final ValueChanged<CommissionSketch> onDownloadSketch;

  const CommissionSketchesTab({
    super.key,
    required this.sketches,
    required this.isDark,
    required this.onCreateSketch,
    required this.onEditSketch,
    required this.onDeleteSketch,
    required this.onDownloadSketch,
  });

  @override
  Widget build(BuildContext context) {
    if (sketches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.draw,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            SizedBox(height: 12.h),
            Text(
              'No sketches created',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: onCreateSketch,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Sketch'),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.all(16.r),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: sketches.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return _newSketchCard();
        }
        final sk = sketches[i - 1];
        return _sketchCard(sk);
      },
    );
  }

  Widget _newSketchCard() => Material(
    color:
        isDark
            ? const Color(0xFF1E1E2E)
            : Colors.black.withValues(alpha: 0.04),
    borderRadius: BorderRadius.circular(14.r),
    child: InkWell(
      onTap: onCreateSketch,
      borderRadius: BorderRadius.circular(14.r),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add, size: 32, color: const Color(0xFF8B5CF6)),
          SizedBox(height: 8.h),
          Text(
            'New Sketch',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: const Color(0xFF8B5CF6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sketchCard(CommissionSketch sk) => GestureDetector(
    onTap: () => onEditSketch(sk),
    onLongPress: () => onDeleteSketch(sk),
    child: Container(
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
                  child:
                      sk.sketchImageUrl != null
                          ? SecureNetworkImage(
                            sk.sketchImageUrl!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            errorBuilder:
                                (_, __, ___) => _sketchPlaceholder(),
                          )
                          : _sketchPlaceholder(),
                ),
              ),
              Container(
                padding: EdgeInsets.all(10.r),
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
                      sk.title,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark
                                ? Colors.white70
                                : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      sk.sketchTypeLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Download button
          if (sk.sketchImageUrl != null)
            Positioned(
              top: 4.h,
              left: 4.w,
              child: GestureDetector(
                onTap: () => onDownloadSketch(sk),
                child: Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          // Delete button in corner
          Positioned(
            top: 4.h,
            right: 4.w,
            child: GestureDetector(
              onTap: () => onDeleteSketch(sk),
              child: Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sketchPlaceholder() => Container(
    color:
        isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
    child: Center(
      child: Icon(
        Icons.draw,
        size: 32,
        color: isDark ? Colors.white12 : Colors.black12,
      ),
    ),
  );
}
