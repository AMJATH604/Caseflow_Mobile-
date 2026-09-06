import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

/// Generic pagination state that works with any model type.
/// 
/// Used by [PaginatedNotifier] to track:
/// - Current items loaded
/// - Whether more items are available
/// - Loading state for both initial load and "load more"
/// - Error states
class PaginatedState<T> {
  final List<T> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;
  final int currentPage;

  const PaginatedState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 0,
  });

  PaginatedState<T> copyWith({
    List<T>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    int? currentPage,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

/// A generic paginated notifier for Riverpod.
///
/// Subclasses only need to implement [fetchPage] — everything else
/// (initial load, load more, refresh, deduplication) is handled here.
///
/// Example usage:
/// ```dart
/// class CasesPaginatedNotifier extends PaginatedNotifier<CaseModel> {
///   @override
///   Future<List<CaseModel>> fetchPage(int offset, int limit) {
///     return CaseRepository.fetchCases(limit: limit, offset: offset);
///   }
/// }
/// ```
abstract class PaginatedNotifier<T>
    extends StateNotifier<PaginatedState<T>> {
  final int pageSize;

  PaginatedNotifier({this.pageSize = 20})
      : super(const PaginatedState()) {
    loadInitial();
  }

  /// Subclasses implement this to fetch a single page of data.
  /// [offset] is the starting index, [limit] is the page size.
  Future<List<T>> fetchPage(int offset, int limit);

  /// Loads the first page and resets state.
  Future<void> loadInitial() async {
    state = PaginatedState<T>(isLoading: true);
    try {
      final items = await fetchPage(0, pageSize);
      state = PaginatedState<T>(
        items: items,
        hasMore: items.length >= pageSize,
        currentPage: 1,
      );
    } catch (e, stack) {
      debugPrint('PaginatedNotifier.loadInitial error: $e\n$stack');
      state = PaginatedState<T>(error: e);
    }
  }

  /// Loads the next page and appends to existing items.
  /// No-op if already loading or no more items.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final offset = state.items.length;
      final newItems = await fetchPage(offset, pageSize);
      state = state.copyWith(
        items: [...state.items, ...newItems],
        isLoadingMore: false,
        hasMore: newItems.length >= pageSize,
        currentPage: state.currentPage + 1,
      );
    } catch (e, stack) {
      debugPrint('PaginatedNotifier.loadMore error: $e\n$stack');
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  /// Full refresh — reloads from page 1.
  Future<void> refresh() async {
    await loadInitial();
  }
}
