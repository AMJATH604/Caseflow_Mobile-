import 'package:flutter/material.dart';

/// A fixed-height bar that sticks to the top of a [NestedScrollView] once the
/// content above it has scrolled away — used for tab bars, so switching tabs
/// never requires scrolling back up.
class PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  final Color backgroundColor;

  const PinnedHeaderDelegate({
    required this.height,
    required this.child,
    required this.backgroundColor,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: backgroundColor,
      // A faint shadow only once content is scrolling underneath the bar.
      elevation: overlapsContent ? 2 : 0,
      child: SizedBox.expand(child: child),
    );
  }

  @override
  bool shouldRebuild(covariant PinnedHeaderDelegate oldDelegate) =>
      oldDelegate.child != child ||
      oldDelegate.height != height ||
      oldDelegate.backgroundColor != backgroundColor;
}
