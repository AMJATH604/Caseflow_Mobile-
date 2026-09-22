import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// A back arrow for screens whose header is a custom container rather than an
/// AppBar, so they never got Flutter's automatic one.
///
/// Falls back to [fallbackRoute] when there is nothing to pop — a screen
/// reached by `go` rather than `push` has an empty stack, and a dead arrow is
/// worse than no arrow.
class ScreenBackButton extends StatelessWidget {
  /// Where to go when the navigation stack is empty. The dashboard by
  /// default, which is where these screens are opened from.
  final String fallbackRoute;

  /// Set on dark or gradient headers, where the default ink would vanish.
  final Color? color;

  const ScreenBackButton({
    super.key,
    this.fallbackRoute = '/',
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.w),
      icon: Icon(
        Icons.arrow_back_rounded,
        size: 20.sp,
        color: color ?? Theme.of(context).iconTheme.color,
      ),
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallbackRoute);
        }
      },
    );
  }
}
