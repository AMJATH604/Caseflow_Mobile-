import 'package:flutter/material.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow Shimmer Loader
///
/// Premium skeleton loading that replaces CircularProgressIndicator.
/// Shows a placeholder UI with a shimmer animation while data loads.
///
/// Usage:
///   CfShimmerLoader.card()        — Single card placeholder
///   CfShimmerLoader.list()        — List of items
///   CfShimmerLoader.dashboard()   — Dashboard layout skeleton
///   CfShimmerLoader.custom(child) — Custom layout with shimmer
/// ══════════════════════════════════════════════════════════════

class CfShimmerLoader extends StatefulWidget {
  final Widget child;

  const CfShimmerLoader({super.key, required this.child});

  @override
  State<CfShimmerLoader> createState() => _CfShimmerLoaderState();

  // ─── Preset Factories ────────────────────────────────────

  /// Single card loading skeleton
  static Widget card({double height = 120}) {
    return CfShimmerLoader(
      child: Padding(
        padding: CfSpacing.pageHorizontal,
        child: _ShimmerCard(height: height),
      ),
    );
  }

  /// List of items loading skeleton
  static Widget list({int itemCount = 5, double itemHeight = 80}) {
    return CfShimmerLoader(
      child: Padding(
        padding: CfSpacing.pageHorizontal,
        child: Column(
          children: List.generate(
            itemCount,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: CfSpacing.itemGap),
              child: _ShimmerListItem(height: itemHeight),
            ),
          ),
        ),
      ),
    );
  }

  /// Dashboard layout skeleton
  static Widget dashboard() {
    return CfShimmerLoader(
      child: Padding(
        padding: CfSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting
            const _ShimmerBox(width: 200, height: 28),
            const SizedBox(height: CfSpacing.sm),
            const _ShimmerBox(width: 150, height: 16),
            const SizedBox(height: CfSpacing.xl),

            // Summary cards row
            Row(
              children: [
                Expanded(child: _ShimmerCard(height: 90)),
                const SizedBox(width: CfSpacing.itemGap),
                Expanded(child: _ShimmerCard(height: 90)),
              ],
            ),
            const SizedBox(height: CfSpacing.itemGap),
            Row(
              children: [
                Expanded(child: _ShimmerCard(height: 90)),
                const SizedBox(width: CfSpacing.itemGap),
                Expanded(child: _ShimmerCard(height: 90)),
              ],
            ),
            const SizedBox(height: CfSpacing.sectionGap),

            // Section header
            const _ShimmerBox(width: 140, height: 20),
            const SizedBox(height: CfSpacing.base),

            // Hearing cards
            _ShimmerCard(height: 100),
            const SizedBox(height: CfSpacing.itemGap),
            _ShimmerCard(height: 100),
            const SizedBox(height: CfSpacing.sectionGap),

            // Tasks section
            const _ShimmerBox(width: 120, height: 20),
            const SizedBox(height: CfSpacing.base),
            _ShimmerListItem(height: 56),
            const SizedBox(height: CfSpacing.sm),
            _ShimmerListItem(height: 56),
            const SizedBox(height: CfSpacing.sm),
            _ShimmerListItem(height: 56),
          ],
        ),
      ),
    );
  }

  /// Cases list skeleton
  static Widget casesList() {
    return CfShimmerLoader(
      child: Padding(
        padding: CfSpacing.pagePadding,
        child: Column(
          children: [
            // Search bar
            const _ShimmerBox(width: double.infinity, height: 48, radius: CfSpacing.radiusFull),
            const SizedBox(height: CfSpacing.base),

            // Filter chips
            Row(
              children: List.generate(4, (i) => Padding(
                padding: const EdgeInsets.only(right: CfSpacing.sm),
                child: _ShimmerBox(width: 70, height: 32, radius: CfSpacing.radiusFull),
              )),
            ),
            const SizedBox(height: CfSpacing.lg),

            // Case cards
            ...List.generate(4, (i) => Padding(
              padding: const EdgeInsets.only(bottom: CfSpacing.itemGap),
              child: _ShimmerCard(height: 110),
            )),
          ],
        ),
      ),
    );
  }

  /// Custom shimmer wrapper — pass any widget tree
  static Widget custom({required Widget child}) {
    return CfShimmerLoader(child: child);
  }
}

class _CfShimmerLoaderState extends State<CfShimmerLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => _ShimmerProvider(
        animation: _animation,
        child: widget.child,
      ),
    );
  }
}

/// InheritedWidget to pass shimmer animation down the tree
class _ShimmerProvider extends InheritedWidget {
  final Animation<double> animation;

  const _ShimmerProvider({
    required this.animation,
    required super.child,
  });

  static _ShimmerProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShimmerProvider>();
  }

  @override
  bool updateShouldNotify(_ShimmerProvider oldWidget) =>
      animation != oldWidget.animation;
}

/// Individual shimmer box element
class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);
    final shimmerProvider = _ShimmerProvider.of(context);

    if (shimmerProvider == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.shimmerBase,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: shimmerProvider.animation,
      builder: (context, _) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(shimmerProvider.animation.value - 1, 0),
              end: Alignment(shimmerProvider.animation.value + 1, 0),
              colors: [
                colors.shimmerBase,
                colors.shimmerHighlight,
                colors.shimmerBase,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Card shimmer placeholder
class _ShimmerCard extends StatelessWidget {
  final double height;

  const _ShimmerCard({required this.height});

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: CfSpacing.borderRadiusLg,
        border: Border.all(color: colors.border, width: 1),
      ),
      padding: CfSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _ShimmerBox(width: 40, height: 40, radius: CfSpacing.radiusMd),
              const SizedBox(width: CfSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _ShimmerBox(width: 180, height: 14),
                    SizedBox(height: CfSpacing.sm),
                    _ShimmerBox(width: 120, height: 11),
                  ],
                ),
              ),
              const _ShimmerBox(width: 60, height: 24, radius: 999),
            ],
          ),
          if (height > 100) ...[
            const SizedBox(height: CfSpacing.md),
            const _ShimmerBox(width: double.infinity, height: 12),
            const SizedBox(height: CfSpacing.xs),
            const _ShimmerBox(width: 200, height: 12),
          ],
        ],
      ),
    );
  }
}

/// List item shimmer placeholder
class _ShimmerListItem extends StatelessWidget {
  final double height;

  const _ShimmerListItem({required this.height});

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: CfSpacing.borderRadiusMd,
        border: Border.all(color: colors.border, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const _ShimmerBox(width: 36, height: 36, radius: 999),
          const SizedBox(width: CfSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _ShimmerBox(width: 160, height: 13),
                SizedBox(height: CfSpacing.sm),
                _ShimmerBox(width: 100, height: 10),
              ],
            ),
          ),
          const _ShimmerBox(width: 50, height: 12),
        ],
      ),
    );
  }
}
