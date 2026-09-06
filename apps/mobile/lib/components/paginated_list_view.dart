import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';
import '../services/paginated_notifier.dart';

/// A reusable paginated list view that handles infinite scroll,
/// loading indicators, pull-to-refresh, and empty/error states.
///
/// Usage:
/// ```dart
/// PaginatedListView<CaseModel>(
///   state: ref.watch(paginatedCasesProvider),
///   onLoadMore: () => ref.read(paginatedCasesProvider.notifier).loadMore(),
///   onRefresh: () => ref.read(paginatedCasesProvider.notifier).refresh(),
///   itemBuilder: (context, item, index) => CaseCard(item),
///   emptyIcon: Icons.inventory_2_outlined,
///   emptyTitle: 'ARCHIVE EMPTY',
///   emptySubtitle: 'No items found',
/// )
/// ```
class PaginatedListView<T> extends StatefulWidget {
  final PaginatedState<T> state;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final EdgeInsetsGeometry? padding;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final VoidCallback? onRetry;

  const PaginatedListView({
    super.key,
    required this.state,
    required this.onLoadMore,
    required this.onRefresh,
    required this.itemBuilder,
    this.padding,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'NO ITEMS',
    this.emptySubtitle = 'Nothing to display',
    this.onRetry,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Initial loading
    if (widget.state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    // Error with no data loaded
    if (widget.state.error != null && widget.state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
            SizedBox(height: 16.h),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '${widget.state.error}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                color: const Color(0xFF94A3B8),
              ),
            ),
            if (widget.onRetry != null) ...[
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: widget.onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
    }

    // Empty state
    if (widget.state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.emptyIcon,
              size: 48,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
            SizedBox(height: 16.h),
            Text(
              widget.emptyTitle,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.sp,
                color: const Color(0xFF4B5563),
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              widget.emptySubtitle,
              style: TextStyle(
                fontSize: 12.sp,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    // Data loaded — show list with infinite scroll
    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding ??
            EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        itemCount: widget.state.items.length + (widget.state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Loading more indicator at the bottom
          if (index == widget.state.items.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: widget.state.isLoadingMore
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accent,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Loading more...',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }

          return widget.itemBuilder(
            context,
            widget.state.items[index],
            index,
          );
        },
      ),
    );
  }
}
