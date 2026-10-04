import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../services/paginated_providers.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../components/error_state_widget.dart';
import '../components/dialogs/new_case_dialog.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Ultra-Modern Silicon Valley Grade Case Archive & Legal Intelligence Repository Screen.
class CasesScreen extends ConsumerStatefulWidget {
  /// Opens the list already filtered, e.g. from the dashboard's Disposed and
  /// Dismissed chips (`/cases?status=disposed`).
  final String? initialStatus;

  const CasesScreen({super.key, this.initialStatus});

  static const statusFilters = {'all', 'active', 'closed', 'disposed', 'dismissed'};

  @override
  ConsumerState<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends ConsumerState<CasesScreen> {
  String _searchQuery = '';
  late String _statusFilter = // all, active, closed, disposed, dismissed
      CasesScreen.statusFilters.contains(widget.initialStatus)
          ? widget.initialStatus!
          : 'all';
  String _sortBy = 'recent'; // recent, hearing, title
  bool _isGridView = false;

  /// Guards the one-off "load every page" run the Next Hearing sort needs.
  bool _loadingAllCases = false;

  /// Senior names for cases shared from another advocate's firm, by firm id.
  Map<String, String> _sharerNames = const {};
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // ─── Server search ───
  // The list loads twenty cases at a time and used to search only those, so a
  // case further down could not be found until enough pages had been
  // scrolled into memory. Two or more characters now search every case on
  // the server; the paginated list is untouched and returns when cleared.
  List<CaseModel>? _searchResults;
  bool _searching = false;
  Timer? _searchDebounce;
  int _searchSeq = 0;

  bool get _inSearch => _searchQuery.trim().length >= 2;
  bool get _showingServerResults => _inSearch && _searchResults != null;

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    final active = v.trim().length >= 2;
    setState(() {
      _searchQuery = v;
      _searching = active;
      if (!active) _searchResults = null;
    });
    if (!active) return;
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      // Only the newest query may land: an older, slower response must not
      // overwrite the results for what the user has typed since.
      final seq = ++_searchSeq;
      try {
        final results = await SupabaseService.searchCases(v);
        if (!mounted || seq != _searchSeq) return;
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      } catch (_) {
        // Falls back to filtering the loaded pages, as before, rather than
        // showing nothing.
        if (!mounted || seq != _searchSeq) return;
        setState(() {
          _searchResults = null;
          _searching = false;
        });
      }
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchSeq++;
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = null;
      _searching = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // Search results are complete already; there is no next page to fetch.
    if (_inSearch) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(paginatedCasesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginatedState = ref.watch(paginatedCasesProvider);
    final rawCases = paginatedState.items;
    // The stat cards and filter-chip counts describe the whole practice, so
    // they come from their own query. Deriving them from `rawCases` meant they
    // only ever counted the pages loaded so far, and climbed as you scrolled.
    final statusCounts =
        ref.watch(caseStatusCountsProvider).valueOrNull ??
        const <String, int>{};
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = SupabaseService.client.auth.currentUser?.id;

    // Filter & Sort
    final filteredCases = _getFilteredAndSortedCases(
      _showingServerResults ? _searchResults! : rawCases,
      // The server already matched the words; re-applying the in-memory
      // substring test would drop "murugan krishnan" for "Murugan vs Krishnan".
      applySearch: !_showingServerResults,
    );

    // Next Hearing orders across every case, and a status filter must see
    // every case, not just the pages loaded so far — otherwise a disposed case
    // on page three would not appear under Disposed. Pull in the rest first.
    if ((_sortBy == 'hearing' || _statusFilter != 'all') &&
        !_inSearch &&
        paginatedState.hasMore &&
        !paginatedState.isLoading &&
        !paginatedState.isLoadingMore &&
        paginatedState.error == null &&
        !_loadingAllCases) {
      _loadingAllCases = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(paginatedCasesProvider.notifier)
            .loadAll()
            .whenComplete(() => _loadingAllCases = false);
      });
    }

    final sharerIds =
        {
            for (final c in rawCases)
              if (currentUserId != null && c.isTeamCase(currentUserId))
                c.firmId!,
          }.toList()
          ..sort();
    _sharerNames =
        ref.watch(profileNamesProvider(sharerIds.join(','))).valueOrNull ??
        const {};

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF090D16) : const Color(0xFFF6F8FC),
      // No floating New Case button: a case is created from the dashboard's
      // Quick Actions, and the empty state below still offers it to a user
      // with no cases yet.
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed, like "Court Schedule" on the Hearings page.
            _buildTitleHeader(context, isDark),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.accent,
                onRefresh: () async {
                  if (_inSearch) _onSearchChanged(_searchQuery);
                  await ref.read(paginatedCasesProvider.notifier).refresh();
                },
                // One scroll for search, filters, sort and every case. This
                // was a NestedScrollView whose list carried its own
                // controller, which detached it from the header: the search
                // and filters stayed put and only the cards scrolled in the
                // space left beneath them.
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8.h),
                          _buildModernSearchAndFilters(
                            context,
                            isDark,
                            statusCounts,
                          ),
                          SizedBox(height: 12.h),
                          _buildModernToolbar(
                            context,
                            isDark,
                            filteredCases.length,
                          ),
                          SizedBox(height: 8.h),
                        ],
                      ),
                    ),
                    ..._buildCaseSlivers(
                      isDark,
                      filteredCases,
                      paginatedState,
                      rawCases,
                      currentUserId,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `/cases` is a bottom-nav root, so there is usually nothing to pop — fall
  /// back to the dashboard, the same shape used by know_your_rights_screen.
  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  List<Widget> _buildCaseSlivers(
    bool isDark,
    List<CaseModel> filteredCases,
    dynamic paginatedState,
    List<CaseModel> rawCases,
    String? currentUserId,
  ) {
    if ((paginatedState.isLoading && rawCases.isEmpty) ||
        (_searching && _searchResults == null)) {
      return [_buildModernShimmerLoading(isDark)];
    }
    if (paginatedState.error != null && rawCases.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorStateWidget(
            error: paginatedState.error!,
            onRetry: () => ref.read(paginatedCasesProvider.notifier).refresh(),
          ),
        ),
      ];
    }
    if (filteredCases.isEmpty) {
      return [SliverToBoxAdapter(child: _buildModernEmptyState(isDark))];
    }
    return _isGridView
        ? _buildModernCasesGrid(
          isDark,
          filteredCases,
          paginatedState,
          currentUserId,
        )
        : _buildModernCasesList(
          isDark,
          filteredCases,
          paginatedState,
          currentUserId,
        );
  }

  // ─── TITLE HEADER ───────────────────────────────────────

  /// Counts the given [CaseStatus] names out of a status→count map.
  static int _sumOf(Map<String, int> counts, List<String> names) =>
      names.fold<int>(0, (sum, n) => sum + (counts[n] ?? 0));

  /// The page title, fixed above the scrolling content.
  Widget _buildTitleHeader(BuildContext context, bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 8.h, 16.w, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => _goBack(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20.sp,
              color: titleColor,
            ),
          ),
          Expanded(
            child: Text(
              'Legal Repository',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: titleColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SEARCH & STATUS FILTERS ──────────────────────────────

  Widget _buildModernSearchAndFilters(
    BuildContext context,
    bool isDark,
    Map<String, int> counts,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Glassmorphic Search Bar
          Container(
            height: 52.h,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search cases by title, CNR, client, court...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13.sp,
                  color:
                      isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Container(
                  padding: EdgeInsets.all(12.r),
                  child: Icon(
                    Icons.search_rounded,
                    size: 20.sp,
                    color: AppTheme.accent,
                  ),
                ),
                suffixIcon:
                    _searching
                        ? Padding(
                          padding: EdgeInsets.all(14.r),
                          child: SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accent,
                            ),
                          ),
                        )
                        : _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: Icon(Icons.cancel_rounded, size: 18.sp),
                          color:
                              isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8),
                          onPressed: _clearSearch,
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14.h),
              ),
            ),
          ),
          SizedBox(height: 14.h),

          // Interactive Status Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip(
                  'all',
                  'ALL CASES',
                  counts.values.fold<int>(0, (a, b) => a + b),
                  isDark,
                ),
                SizedBox(width: 8.w),
                _buildStatusChip(
                  'active',
                  'ACTIVE',
                  _sumOf(counts, const ['active']),
                  isDark,
                  activeColor: const Color(0xFF10B981),
                ),
                SizedBox(width: 8.w),
                _buildStatusChip(
                  'closed',
                  'CLOSED',
                  _sumOf(counts, const ['closed', 'disposed', 'dismissed']),
                  isDark,
                  activeColor: const Color(0xFF6366F1),
                ),
                SizedBox(width: 8.w),
                _buildStatusChip(
                  'disposed',
                  'DISPOSED',
                  _sumOf(counts, const ['disposed']),
                  isDark,
                  activeColor: const Color(0xFF14B8A6),
                ),
                SizedBox(width: 8.w),
                _buildStatusChip(
                  'dismissed',
                  'DISMISSED',
                  _sumOf(counts, const ['dismissed']),
                  isDark,
                  activeColor: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(
    String key,
    String label,
    int count,
    bool isDark, {
    Color? activeColor,
  }) {
    final selected = _statusFilter == key;
    final themeColor = activeColor ?? AppTheme.accent;

    return GestureDetector(
      onTap: () => setState(() => _statusFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color:
              selected
                  ? themeColor
                  : (isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color:
                selected
                    ? themeColor
                    : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
            width: 1.2,
          ),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Container(
                width: 6.w,
                height: 6.w,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6.w),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color:
                    selected
                        ? Colors.white
                        : (isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
              decoration: BoxDecoration(
                color:
                    selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color:
                      selected
                          ? Colors.white
                          : (isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TOOLBAR (SORT & VIEW SWITCHER) ─────────────────────

  Widget _buildModernToolbar(BuildContext context, bool isDark, int count) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Count indicator
          Text(
            '$count ${count == 1 ? 'case dossier' : 'case dossiers'}',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),

          Row(
            children: [
              // Sort Menu Button
              PopupMenuButton<String>(
                initialValue: _sortBy,
                onSelected: (val) => setState(() => _sortBy = val),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color:
                          isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.swap_vert_rounded,
                        size: 16.sp,
                        color: AppTheme.accent,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _sortLabel(_sortBy),
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18.sp,
                        color:
                            isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
                itemBuilder:
                    (ctx) => [
                      _sortMenuItem(
                        'recent',
                        'Recently Added',
                        Icons.access_time_rounded,
                      ),
                      _sortMenuItem(
                        'hearing',
                        'Next Hearing Date',
                        Icons.event_rounded,
                      ),
                      _sortMenuItem(
                        'title',
                        'Alphabetical (A-Z)',
                        Icons.sort_by_alpha_rounded,
                      ),
                    ],
              ),
              SizedBox(width: 8.w),

              // View Mode Toggle (List / Grid)
              Container(
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color:
                        isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.view_agenda_rounded,
                        size: 17.sp,
                        color:
                            !_isGridView
                                ? AppTheme.accent
                                : (isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8)),
                      ),
                      onPressed: () => setState(() => _isGridView = false),
                      constraints: BoxConstraints(
                        minWidth: 34.w,
                        minHeight: 34.h,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.grid_view_rounded,
                        size: 17.sp,
                        color:
                            _isGridView
                                ? AppTheme.accent
                                : (isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8)),
                      ),
                      onPressed: () => setState(() => _isGridView = true),
                      constraints: BoxConstraints(
                        minWidth: 34.w,
                        minHeight: 34.h,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(String val, String label, IconData icon) {
    return PopupMenuItem<String>(
      value: val,
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: AppTheme.accent),
          SizedBox(width: 10.w),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel(String key) {
    switch (key) {
      case 'hearing':
        return 'Next Hearing';
      case 'title':
        return 'Title A-Z';
      case 'recent':
      default:
        return 'Recent First';
    }
  }

  // ─── LIST VIEW MODE ─────────────────────────────────────

  List<Widget> _buildModernCasesList(
    bool isDark,
    List<CaseModel> cases,
    dynamic paginatedState,
    String? currentUserId,
  ) {
    final hasMore = paginatedState.hasMore ?? false;
    final isLoadingMore = paginatedState.isLoadingMore ?? false;

    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index == cases.length) {
              return _buildLoadingMoreIndicator(isLoadingMore);
            }
            return _buildModernCaseCardList(
              context,
              isDark,
              cases[index],
              currentUserId,
            );
          }, childCount: cases.length + (hasMore ? 1 : 0)),
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: 90.h)),
    ];
  }

  Widget _buildModernCaseCardList(
    BuildContext context,
    bool isDark,
    CaseModel c,
    String? currentUserId,
  ) {
    final statColor = _statusColor(c.status.name);
    final isOwner = c.createdBy == currentUserId;
    // firm_id is the firm owner's id, and a solo advocate's firm is
    // themselves — so a case is shared exactly when that owner is someone else.
    final isSharedCase = currentUserId != null && c.isTeamCase(currentUserId);

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(22.r),
          onTap: () => context.push('/cases/${c.id}'),
          onLongPress: isOwner ? () => _showCaseOptionsMenu(c) : null,
          child: Padding(
            padding: EdgeInsets.all(18.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: CNR Badge + Status Pill + Options Menu
                Row(
                  children: [
                    // CNR / Case Number Chip (Interactive Copy)
                    GestureDetector(
                      onTap: () {
                        if (c.caseNumber != null) {
                          Clipboard.setData(ClipboardData(text: c.caseNumber!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Copied "${c.caseNumber}" to clipboard',
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: statColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: statColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.gavel_rounded,
                              size: 13.sp,
                              color: statColor,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              (c.caseNumber ?? 'NO CNR').toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w800,
                                color: statColor,
                                letterSpacing: 0.6,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              Icons.copy_rounded,
                              size: 10.sp,
                              color: statColor.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Status Pill
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: statColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.w,
                            height: 6.w,
                            decoration: BoxDecoration(
                              color: statColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            c.status.name.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              color: statColor,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Options menu
                    IconButton(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20.sp,
                        color:
                            isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                      ),
                      onPressed: () => _showCaseOptionsMenu(c),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: 32.w,
                        minHeight: 32.h,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Case Title
                Text(
                  c.caseTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12.h),

                if (isSharedCase) ...[
                  _buildSharedByBadge(c, isDark),
                  SizedBox(height: 12.h),
                ],

                // Client Name & Court Forum
                Row(
                  children: [
                    // Client Avatar Circle
                    Container(
                      width: 24.w,
                      height: 24.w,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          (c.clientName ?? 'P').substring(0, 1).toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        c.clientName ?? 'No client linked',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Court Forum Tag
                    if (c.courtName != null && c.courtName!.isNotEmpty) ...[
                      Icon(
                        Icons.account_balance_rounded,
                        size: 14.sp,
                        color:
                            isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        c.courtName!,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),

                // Next Hearing Urgency Banner
                if (c.nextHearingDate != null) ...[
                  SizedBox(height: 14.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: _hearingColor(
                        c.nextHearingDate!,
                      ).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: _hearingColor(
                          c.nextHearingDate!,
                        ).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_rounded,
                          size: 16.sp,
                          color: _hearingColor(c.nextHearingDate!),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'NEXT HEARING: ',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                            color: _hearingColor(c.nextHearingDate!),
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          _formatHearingDate(c.nextHearingDate!),
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: _hearingColor(c.nextHearingDate!),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.all(4.r),
                          decoration: BoxDecoration(
                            color: _hearingColor(
                              c.nextHearingDate!,
                            ).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 12.sp,
                            color: _hearingColor(c.nextHearingDate!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── GRID VIEW MODE ─────────────────────────────────────

  List<Widget> _buildModernCasesGrid(
    bool isDark,
    List<CaseModel> cases,
    dynamic paginatedState,
    String? currentUserId,
  ) {
    final hasMore = paginatedState.hasMore ?? false;
    final isLoadingMore = paginatedState.isLoadingMore ?? false;

    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14.h,
            crossAxisSpacing: 14.w,
            childAspectRatio: 0.82,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final c = cases[index];
            return _buildModernCaseCardGrid(context, isDark, c, currentUserId);
          }, childCount: cases.length),
        ),
      ),
      if (hasMore)
        SliverToBoxAdapter(child: _buildLoadingMoreIndicator(isLoadingMore)),
      SliverToBoxAdapter(child: SizedBox(height: 90.h)),
    ];
  }

  Widget _buildSharedByBadge(CaseModel c, bool isDark, {bool compact = false}) {
    final name = _sharerNames[c.firmId];
    final fg = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8.w : 10.w,
        vertical: compact ? 4.h : 6.h,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_rounded, size: compact ? 13.sp : 16.sp, color: fg),
          SizedBox(width: 6.w),
          Flexible(
            child: Text(
              name != null ? 'Shared by $name' : 'Shared with you',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: compact ? 10.sp : 12.sp,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCaseCardGrid(
    BuildContext context,
    bool isDark,
    CaseModel c,
    String? currentUserId,
  ) {
    final statColor = _statusColor(c.status.name);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(22.r),
          onTap: () => context.push('/cases/${c.id}'),
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: statColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        c.status.name.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          color: statColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 18.sp,
                        color:
                            isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                      ),
                      onPressed: () => _showCaseOptionsMenu(c),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: 24.w,
                        minHeight: 24.h,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),

                // Case CNR Number
                Text(
                  (c.caseNumber ?? 'NO CNR').toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: statColor,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 4.h),

                // Case Title
                Text(
                  c.caseTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (currentUserId != null && c.isTeamCase(currentUserId)) ...[
                  SizedBox(height: 6.h),
                  _buildSharedByBadge(c, isDark, compact: true),
                ],
                const Spacer(),

                // Client Name
                Text(
                  c.clientName ?? 'No client linked',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Hearing Date Banner
                if (c.nextHearingDate != null) ...[
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 12.sp,
                        color: _hearingColor(c.nextHearingDate!),
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          _formatHearingDate(c.nextHearingDate!),
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: _hearingColor(c.nextHearingDate!),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── EMPTY STATE & LOADING SKELETON ─────────────────────

  Widget _buildModernEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 64.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100.w,
              height: 100.w,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 48.sp,
                color: AppTheme.accent,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Case Files Found',
              style: GoogleFonts.outfit(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _searchQuery.isNotEmpty || _statusFilter != 'all'
                  ? 'No cases match your active filters or search terms. Try clearing search.'
                  : 'Your legal repository is empty. Create your first case dossier to get started.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            SizedBox(height: 28.h),
            ElevatedButton.icon(
              onPressed: () => _showNewCaseDialog(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                'Create First Case File',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.sp,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernShimmerLoading(bool isDark) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          childCount: 4,
          (context, index) => Container(
            height: 140.h,
            margin: EdgeInsets.only(bottom: 14.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(bool isLoadingMore) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child:
            isLoadingMore
                ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accent,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      'Loading more case dossiers...',
                      style: GoogleFonts.inter(
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

  // ─── OPTIONS & DIALOGS ──────────────────────────────────

  void _showCaseOptionsMenu(CaseModel c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.caseTitle,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 18.sp,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.folder_open_rounded,
                      color: AppTheme.accent,
                    ),
                    title: Text(
                      'Open Case Dossier & Strategy',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/cases/${c.id}');
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.copy_rounded,
                      color: Color(0xFF2563EB),
                    ),
                    title: Text(
                      'Copy CNR / Case Details',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      final details =
                          'Title: ${c.caseTitle}\nCNR: ${c.caseNumber ?? 'N/A'}\nClient: ${c.clientName ?? 'N/A'}';
                      Clipboard.setData(ClipboardData(text: details));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Case details copied!')),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.error,
                    ),
                    title: Text(
                      'Delete Case Record',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.error,
                      ),
                    ),
                    subtitle: Text(
                      'Permanently remove this case from archive',
                      style: GoogleFonts.inter(fontSize: 11.sp),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirmed = await _confirmDeleteCase(c.caseTitle);
                      if (confirmed == true) {
                        await _deleteCase(c.id);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNewCaseDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const NewCaseDialog());
  }

  Future<bool?> _confirmDeleteCase(String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Text(
            'Delete Case File?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$title"? This action will remove all related documents and records.',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCase(String id) async {
    try {
      await SupabaseService.deleteCase(id);
      ref.read(paginatedCasesProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case record removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error removing case: $e')));
      }
    }
  }

  // ─── FILTER & SORT UTILS ────────────────────────────────

  List<CaseModel> _getFilteredAndSortedCases(
    List<CaseModel> cases, {
    bool applySearch = true,
  }) {
    var list =
        cases.where((c) {
          // Search Query
          if (applySearch && _searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            final matchTitle = c.caseTitle.toLowerCase().contains(q);
            final matchNum = (c.caseNumber ?? '').toLowerCase().contains(q);
            final matchClient = (c.clientName ?? '').toLowerCase().contains(q);
            final matchCourt = (c.courtName ?? '').toLowerCase().contains(q);
            if (!matchTitle && !matchNum && !matchClient && !matchCourt)
              return false;
          }

          // Status Filter
          if (_statusFilter != 'all') {
            final statusName = c.status.name.toLowerCase();
            if (_statusFilter == 'closed') {
              if (!['closed', 'disposed', 'dismissed'].contains(statusName))
                return false;
            } else if (statusName != _statusFilter) {
              return false;
            }
          }

          return true;
        }).toList();

    // Sorting
    switch (_sortBy) {
      case 'hearing':
        // Upcoming hearings first, soonest at the top; then hearings whose
        // date has passed, most recent first; then cases with no date. A
        // plain ascending sort put years-old dates above next week's.
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        int group(DateTime? d) => d == null ? 2 : (d.isBefore(today) ? 1 : 0);
        list.sort((a, b) {
          final ga = group(a.nextHearingDate);
          final gb = group(b.nextHearingDate);
          if (ga != gb) return ga.compareTo(gb);
          if (ga == 2) return 0;
          return ga == 0
              ? a.nextHearingDate!.compareTo(b.nextHearingDate!)
              : b.nextHearingDate!.compareTo(a.nextHearingDate!);
        });
        break;
      case 'title':
        list.sort(
          (a, b) =>
              a.caseTitle.toLowerCase().compareTo(b.caseTitle.toLowerCase()),
        );
        break;
      case 'recent':
      default:
        // Already ordered by recent from repository
        break;
    }

    return list;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF10B981);
      case 'closed':
      case 'disposed':
        return const Color(0xFF6366F1);
      case 'dismissed':
        return const Color(0xFFEF4444);
      case 'appeal':
        return const Color(0xFFF59E0B);
      default:
        return AppTheme.accent;
    }
  }

  Color _hearingColor(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hearingDay = DateTime(date.year, date.month, date.day);
    final diff = hearingDay.difference(today).inDays;

    if (diff < 0) return const Color(0xFF94A3B8); // Past
    if (diff == 0) return const Color(0xFFEF4444); // Today!
    if (diff <= 3) return const Color(0xFFF59E0B); // Urgent
    return const Color(0xFF10B981); // Upcoming
  }

  String _formatHearingDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hearingDay = DateTime(date.year, date.month, date.day);
    final diff = hearingDay.difference(today).inDays;

    if (diff < 0) return DateFormat('dd MMM yyyy').format(date);
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'TOMORROW';
    if (diff <= 7)
      return 'In $diff days (${DateFormat('dd MMM').format(date)})';
    return DateFormat('dd MMM yyyy').format(date);
  }
}
