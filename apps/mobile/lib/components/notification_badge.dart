import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Overlays an unread-count pill on the top-right of [child].
///
/// Extracted from the inline badge in `dashboard_screen.dart`'s
/// `_buildActionButton`, which was the only badge in the app. The Notification
/// Centre needs the same pill in two more places — the More tab in the bottom
/// nav and the Notifications tile inside the More sheet — so it lives here now
/// rather than being copy-pasted a third and fourth time.
///
/// Renders [child] untouched when [count] is zero, so it is safe to wrap
/// anything unconditionally.
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;

  /// Offset of the pill from the child's top-right corner. The default suits
  /// a ~56px icon tile; the bottom nav passes a tighter value.
  final double top;
  final double right;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.count,
    this.top = -6,
    this.right = -6,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: top,
          right: right,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            constraints: BoxConstraints(minWidth: 20.w),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(10.r),
              // Ring in the page background so the pill reads as separate
              // from whatever it sits on.
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 1.5,
              ),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
