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
import '../components/cf_shimmer_loader.dart';
import '../components/cf_search_bar.dart';
import '../components/cf_empty_state.dart';
import '../components/dialogs/new_case_dialog.dart';
import '../theme/app_theme.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';
import '../theme/cf_decorations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Ultra-Modern Silicon Valley Grade Case Archive & Legal Intelligence Repository Screen.
class CasesScreen extends ConsumerStatefulWidget {
  const CasesScreen({super.key});

  @override
  ConsumerState<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends ConsumerState<CasesScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, active, pending, closed
  String _sortBy = 'recent'; // recent, hearing, title
  bool _isGridView = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

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
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(paginatedCasesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginatedState = ref.watch(paginatedCasesProvider);
    final rawCases = paginatedState.items;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = SupabaseService.client.auth.currentUser?.id;

    // Filter & Sort
    final filteredCases = _getFilteredAndSortedCases(rawCases);

    final colors = CfColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: CfDecorations.glowShadow(CfColors.brand),
        ),
        child: FloatingActionButton.extended(
          onPressed: () => _showNewCaseDialog(context),
          backgroundColor: CfColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30.r),
          ),
          icon: Icon(Icons.add_rounded, size: 22.sp),
          label: Text(
            'New Case File',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14.sp,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Modern Glassmorphic Hero Header ──────
                  _buildModernHeroHeader(context, isDark, rawCases),
                  SizedBox(height: 16.h),

                  // ─── Search & Status Filters ──────────────
                  _buildModernSearchAndFilters(context, isDark, rawCases),
                  SizedBox(height: 12.h),

                  // ─── Toolbar (Sort & Grid/List View) ─────
                  _buildModernToolbar(context, isDark, filteredCases.length),
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          ],
          body: paginatedState.isLoading && rawCases.isEmpty
              ? CfShimmerLoader.casesList()
              : paginatedState.error != null && rawCases.isEmpty
                  ? ErrorStateWidget(
                      error: paginatedState.error!,
                      onRetry: () =>
                          ref.read(paginatedCasesProvider.notifier).refresh(),
                    )
                  : RefreshIndicator(
                      color: CfColors.brand,
                      onRefresh: () =>
                          ref.read(paginatedCasesProvider.notifier).refresh(),
                      child: filteredCases.isEmpty
                          ? CfEmptyState.noCases(
                              onAdd: () => _showNewCaseDialog(context),
                            )
                          : _isGridView
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
                                ),
                    ),
        ),
      ),
    );
  }

  // ─── MODERN HERO HEADER ─────────────────────────────────

  Widget _buildModernHeroHeader(
    BuildContext context,
    bool isDark,
    List<CaseModel> cases,
  ) {
    final activeCount =
        cases.where((c) => c.status.name.toLowerCase() == 'active').length;
    final pendingCount =
        cases.where((c) => c.status.name.toLowerCase() == 'pending').length;
    final closedCount = cases.where((c) =>
        ['closed', 'disposed', 'dismissed'].contains(c.status.name.toLowerCase())).length;

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0F172A),
                  const Color(0xFF1E1B4B),
                  const Color(0xFF312E81),
                  const Color(0xFF4338CA),
                ]
              : [
                  const Color(0xFF1E1B4B),
                  const Color(0xFF312E81),
                  const Color(0xFF4338CA),
                  const Color(0xFF6366F1),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: isDark ? 0.5 : 0.3),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background ambient glow circles
          Positioned(
            right: -20.w,
            top: -20.h,
            child: Container(
              width: 140.w,
              height: 140.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: -40.w,
            bottom: -40.h,
            child: Container(
              width: 160.w,
              height: 160.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withValues(alpha: 0.2),
              ),
            ),
          ),

          // Main Header Content
          Padding(
            padding: EdgeInsets.all(22.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(
                            Icons.folder_special_rounded,
                            color: Colors.white,
                            size: 22.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CASE ARCHIVE',
                              style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.75),
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Legal Repository',
                              style: GoogleFonts.outfit(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Total Count Pill Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${cases.length}',
                            style: GoogleFonts.outfit(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'TOTAL',
                            style: GoogleFonts.inter(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.7),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),

                // Stat KPI Cards Row
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassStatTile(
                        label: 'Active',
                        count: activeCount,
                        color: const Color(0xFF10B981),
                        icon: Icons.play_circle_fill_rounded,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildGlassStatTile(
                        label: 'Pending',
                        count: pendingCount,
                        color: const Color(0xFFF59E0B),
                        icon: Icons.hourglass_full_rounded,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildGlassStatTile(
                        label: 'Closed',
                        count: closedCount,
                        color: const Color(0xFF818CF8),
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassStatTile({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12.sp, color: color),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
    List<CaseModel> cases,
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
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
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
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search cases by title, CNR, client, court...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13.sp,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
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
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.cancel_rounded, size: 18.sp),
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
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
                _buildStatusChip('all', 'ALL CASES', cases.length, isDark),
                SizedBox(width: 8.w),
                _buildStatusChip(
                  'active',
                  'ACTIVE',
                  cases.where((c) => c.status.name.toLowerCase() == 'active').length,
                  isDark,
                  activeColor: const Color(0xFF10B981),
                ),
                SizedBox(width: 8.w),
                _buildStatusChip(
                  'pending',
                  'PENDING',
                  cases.where((c) => c.status.name.toLowerCase() == 'pending').length,
                  isDark,
                  activeColor: const Color(0xFFF59E0B),
                ),
                SizedBox(width: 8.w),
                _buildStatusChip(
                  'closed',
                  'CLOSED',
                  cases.where((c) => ['closed', 'disposed', 'dismissed'].contains(c.status.name.toLowerCase())).length,
                  isDark,
                  activeColor: const Color(0xFF6366F1),
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
          color: selected
              ? themeColor
              : (isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: selected
                ? themeColor
                : (isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0)),
            width: 1.2,
          ),
          boxShadow: selected
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
                color: selected
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
                color: selected
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
                  color: selected
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
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDark
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
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18.sp,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => [
                  _sortMenuItem('recent', 'Recently Added', Icons.access_time_rounded),
                  _sortMenuItem('hearing', 'Next Hearing Date', Icons.event_rounded),
                  _sortMenuItem('title', 'Alphabetical (A-Z)', Icons.sort_by_alpha_rounded),
                ],
              ),
              SizedBox(width: 8.w),

              // View Mode Toggle (List / Grid)
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isDark
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
                        color: !_isGridView
                            ? AppTheme.accent
                            : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ),
                      onPressed: () => setState(() => _isGridView = false),
                      constraints: BoxConstraints(minWidth: 34.w, minHeight: 34.h),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.grid_view_rounded,
                        size: 17.sp,
                        color: _isGridView
                            ? AppTheme.accent
                            : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ),
                      onPressed: () => setState(() => _isGridView = true),
                      constraints: BoxConstraints(minWidth: 34.w, minHeight: 34.h),
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

  PopupMenuItem<String> _sortMenuItem(
    String val,
    String label,
    IconData icon,
  ) {
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

  Widget _buildModernCasesList(
    bool isDark,
    List<CaseModel> cases,
    dynamic paginatedState,
    String? currentUserId,
  ) {
    final hasMore = paginatedState.hasMore ?? false;
    final isLoadingMore = paginatedState.isLoadingMore ?? false;

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: cases.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == cases.length) {
          return _buildLoadingMoreIndicator(isLoadingMore);
        }
        final c = cases[index];
        return _buildModernCaseCardList(context, isDark, c, currentUserId);
      },
    );
  }

  Widget _buildModernCaseCardList(
    BuildContext context,
    bool isDark,
    CaseModel c,
    String? currentUserId,
  ) {
    final statColor = _statusColor(c.status.name);
    final isOwner = c.createdBy == currentUserId;
    final isSharedCase = !isOwner && c.firmId == null;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark
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
                              content: Text('Copied "${c.caseNumber}" to clipboard'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
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

                    // Shared Tag
                    if (isSharedCase) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          'SHARED',
                          style: GoogleFonts.inter(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                    ],

                    // Status Pill
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
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
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      onPressed: () => _showCaseOptionsMenu(c),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
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
                SizedBox(height: 14.h),

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
                        c.clientName ?? (c.firmId != null ? 'Firm Shared Case' : 'Private Client'),
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
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
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        c.courtName!,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: _hearingColor(c.nextHearingDate!).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: _hearingColor(c.nextHearingDate!).withValues(alpha: 0.2),
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
                            color: _hearingColor(c.nextHearingDate!).withValues(alpha: 0.15),
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

  Widget _buildModernCasesGrid(
    bool isDark,
    List<CaseModel> cases,
    dynamic paginatedState,
    String? currentUserId,
  ) {
    final hasMore = paginatedState.hasMore ?? false;
    final isLoadingMore = paginatedState.isLoadingMore ?? false;

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14.h,
              crossAxisSpacing: 14.w,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final c = cases[index];
                return _buildModernCaseCardGrid(context, isDark, c, currentUserId);
              },
              childCount: cases.length,
            ),
          ),
        ),
        if (hasMore)
          SliverToBoxAdapter(
            child: _buildLoadingMoreIndicator(isLoadingMore),
          ),
      ],
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
          color: isDark
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
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
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
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      onPressed: () => _showCaseOptionsMenu(c),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: 24.w, minHeight: 24.h),
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
                const Spacer(),

                // Client Name
                Text(
                  c.clientName ?? 'Private Client',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
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
                    : 'Your legal repository is empty. Tap "+ New Case File" below to create your first case dossier.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
      ),
    );
  }

  Widget _buildModernShimmerLoading(bool isDark) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        height: 140.h,
        margin: EdgeInsets.only(bottom: 14.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(bool isLoadingMore) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: isLoadingMore
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
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
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
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                    leading: const Icon(Icons.folder_open_rounded, color: AppTheme.accent),
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
                    leading: const Icon(Icons.copy_rounded, color: Color(0xFF2563EB)),
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
                    leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
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
    showDialog(
      context: context,
      builder: (context) => const NewCaseDialog(),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing case: $e')),
        );
      }
    }
  }

  // ─── FILTER & SORT UTILS ────────────────────────────────

  List<CaseModel> _getFilteredAndSortedCases(List<CaseModel> cases) {
    var list = cases.where((c) {
      // Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = c.caseTitle.toLowerCase().contains(q);
        final matchNum = (c.caseNumber ?? '').toLowerCase().contains(q);
        final matchClient = (c.clientName ?? '').toLowerCase().contains(q);
        final matchCourt = (c.courtName ?? '').toLowerCase().contains(q);
        if (!matchTitle && !matchNum && !matchClient && !matchCourt) return false;
      }

      // Status Filter
      if (_statusFilter != 'all') {
        final statusName = c.status.name.toLowerCase();
        if (_statusFilter == 'closed') {
          if (!['closed', 'disposed', 'dismissed'].contains(statusName)) return false;
        } else if (statusName != _statusFilter) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sorting
    switch (_sortBy) {
      case 'hearing':
        list.sort((a, b) {
          if (a.nextHearingDate == null) return 1;
          if (b.nextHearingDate == null) return -1;
          return a.nextHearingDate!.compareTo(b.nextHearingDate!);
        });
        break;
      case 'title':
        list.sort((a, b) => a.caseTitle.toLowerCase().compareTo(b.caseTitle.toLowerCase()));
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
      case 'pending':
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
    if (diff <= 7) return 'In $diff days (${DateFormat('dd MMM').format(date)})';
    return DateFormat('dd MMM yyyy').format(date);
  }
}
