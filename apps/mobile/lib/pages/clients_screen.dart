import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/paginated_providers.dart';
import '../services/supabase_service.dart';
import '../components/dialogs/add_client_dialog.dart';
import '../components/dialogs/client_detail_sheet.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

/// Directory filters. "Missing details" is derived from empty contact fields
/// rather than stored — see [_ClientsScreenState._isIncomplete].
enum _ClientFilter { all, active, incomplete }

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _searchQuery = '';
  _ClientFilter _filter = _ClientFilter.all;
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
      ref.read(paginatedClientsProvider.notifier).loadMore();
    }
  }

  // Generate consistent gradient color from name
  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF0EA5E9),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final paginatedState = ref.watch(paginatedClientsProvider);
    final clients = paginatedState.items;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed title; search, stats and clients scroll together below it.
            _buildCustomHeader(isMobile, isDark),
            SizedBox(height: 16.h),
            Expanded(
              child: paginatedState.isLoading && clients.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    )
                  : paginatedState.error != null && clients.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0.r),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.red,
                                  size: 48,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'Connection Error',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18.sp,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  '${paginatedState.error}',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                ElevatedButton(
                                  onPressed: () => ref.read(paginatedClientsProvider.notifier).refresh(),
                                  child: const Text('Retry Connection'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppTheme.accent,
                          onRefresh: () => ref.read(paginatedClientsProvider.notifier).refresh(),
                          child: _buildClientsList(isMobile, isDark, clients, paginatedState),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          isMobile
              ? FloatingActionButton(
                onPressed: () => _showAddClientDialog(context),
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                elevation: 6,
                child: const Icon(Icons.person_add_rounded, size: 24),
              )
              : null,
    );
  }

  Widget _buildCustomHeader(bool isMobile, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client Directory',
                        style: GoogleFonts.outfit(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Manage your professional relationships',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (!isMobile)
            ElevatedButton.icon(
              onPressed: () => _showAddClientDialog(context),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: Text(
                'Add Client',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Container(
        height: 50.h,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2030) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 14.sp,
          ),
          decoration: InputDecoration(
            hintText: 'Search clients by name, phone, or email...',
            hintStyle: GoogleFonts.inter(
              color: const Color(0xFFCBD5E1),
              fontSize: 13.sp,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14.h),
          ),
        ),
      ),
    );
  }

  Widget _buildClientsList(
    bool isMobile,
    bool isDark,
    List<ClientModel> clients,
    [dynamic paginatedState]
  ) {
    final filtered =
        clients.where((c) {
          final q = _searchQuery.toLowerCase();
          return c.name.toLowerCase().contains(q) ||
              (c.phone ?? '').contains(q) ||
              (c.email ?? '').toLowerCase().contains(q);
        }).toList();

    // The search box scrolls with the list — and stays reachable when a search
    // matches nothing, so the query can still be changed.
    final searchBlock = SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(bottom: 16.h),
        child: _buildSearch(isDark),
      ),
    );

    if (filtered.isEmpty) {
      return CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          searchBlock,
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: Color(0xFFCBD5E1),
            ),
            SizedBox(height: 16.h),
            Text(
              _searchQuery.isEmpty ? 'No clients yet' : 'No clients found',
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              _searchQuery.isEmpty
                  ? 'Add your first client to get started'
                  : 'Try a different search term',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
          ),
        ],
      );
    }

    final hasMore = paginatedState?.hasMore ?? false;
    final isLoadingMore = paginatedState?.isLoadingMore ?? false;
    final visible = _applyFilter(filtered);

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        searchBlock,
        SliverToBoxAdapter(child: _buildFilterBar(filtered, isDark)),
        if (visible.isEmpty)
          SliverToBoxAdapter(child: _buildFilterEmpty(isDark))
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 90.h),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == visible.length) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Center(
                        child: isLoadingMore
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
                                    'Loading more clients…',
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
                  return _buildClientCard(visible[index], isDark);
                },
                childCount: visible.length + (hasMore ? 1 : 0),
              ),
            ),
          ),
      ],
    );
  }

  // ─── FILTERING ──────────────────────────────────────────

  /// A client with no phone, no email and no address.
  ///
  /// Not a stored flag — derived. Importing from eCourts creates clients from
  /// the case title alone, so the directory fills with bare names that look
  /// finished but cannot be contacted. Surfacing them is how they get
  /// completed.
  static bool _isIncomplete(ClientModel c) =>
      (c.phone == null || c.phone!.trim().isEmpty) &&
      (c.email == null || c.email!.trim().isEmpty) &&
      (c.address == null || c.address!.trim().isEmpty);

  List<ClientModel> _applyFilter(List<ClientModel> all) => switch (_filter) {
        _ClientFilter.all => all,
        _ClientFilter.active => all.where((c) => c.hasActiveCases).toList(),
        _ClientFilter.incomplete => all.where(_isIncomplete).toList(),
      };

  Widget _buildFilterBar(List<ClientModel> all, bool isDark) {
    final counts = {
      _ClientFilter.all: all.length,
      _ClientFilter.active: all.where((c) => c.hasActiveCases).length,
      _ClientFilter.incomplete: all.where(_isIncomplete).length,
    };
    const labels = {
      _ClientFilter.all: 'All',
      _ClientFilter.active: 'With active cases',
      _ClientFilter.incomplete: 'Missing details',
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 14.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in _ClientFilter.values) ...[
              _buildFilterChip(labels[f]!, counts[f]!, f, isDark),
              SizedBox(width: 8.w),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    int count,
    _ClientFilter value,
    bool isDark,
  ) {
    final selected = _filter == value;
    final tint = value == _ClientFilter.incomplete && count > 0
        ? AppTheme.warning
        : AppTheme.accent;
    final border = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);

    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected
              ? tint.withValues(alpha: 0.08)
              : (isDark ? const Color(0xFF1E2030) : Colors.white),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: selected ? tint : border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? tint : muted,
              ),
            ),
            SizedBox(width: 6.w),
            Text(
              '$count',
              style: GoogleFonts.robotoMono(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: selected ? tint : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterEmpty(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 48.h),
      child: Column(
        children: [
          Icon(
            Icons.filter_alt_off_rounded,
            size: 34.sp,
            color: const Color(0xFF94A3B8),
          ),
          SizedBox(height: 12.h),
          Text(
            _filter == _ClientFilter.incomplete
                ? 'Every client has contact details'
                : 'No clients in this filter',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // ─── CARD ───────────────────────────────────────────────

  Widget _buildClientCard(ClientModel c, bool isDark) {
    final color = _avatarColor(c.name);
    final incomplete = _isIncomplete(c);
    final border = isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
    final ink = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);

    // The contact line collapses to whatever the client actually has, rather
    // than printing empty rows with placeholder dashes.
    final contact = [
      if (c.phone != null && c.phone!.trim().isNotEmpty) c.phone!.trim(),
      if (c.email != null && c.email!.trim().isNotEmpty) c.email!.trim(),
    ].join('  ·  ');

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      // Swipe to delete rather than a delete button on every row. Delete had
      // nowhere else to live — the detail sheet's comment claims an action it
      // does not have — so removing it from the card would have removed it
      // from the app.
      child: Dismissible(
        key: ValueKey('client-${c.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.w),
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: AppTheme.error,
            size: 22.sp,
          ),
        ),
        // Deletion runs from the existing confirm dialog, and the row is
        // never removed optimistically — the list refreshes from the server.
        confirmDismiss: (_) async {
          await _deleteClient(c);
          return false;
        },
        child: Material(
          color: isDark ? const Color(0xFF1E2030) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          child: InkWell(
          onTap: () => ClientDetailSheet.show(context, c),
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                // Flat initial, not a gradient tile with its own shadow —
                // fifty of those down a list is fifty things competing.
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  child: Center(
                    child: Text(
                      c.name.trim().isEmpty
                          ? '?'
                          : c.name.trim()[0].toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 17.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 13.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                          ),
                          if (incomplete) ...[
                            SizedBox(width: 7.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                'NO CONTACT',
                                style: GoogleFonts.inter(
                                  fontSize: 8.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: AppTheme.warning,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        contact.isEmpty ? 'No phone or email yet' : contact,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11.5.sp,
                          color: muted,
                          fontStyle: contact.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                // Case count as one quiet number; the list is scanned for
                // "who do I act for", not for a row of action buttons.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${c.caseCount}',
                      style: GoogleFonts.robotoMono(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: c.caseCount > 0 ? AppTheme.accent : muted,
                      ),
                    ),
                    Text(
                      c.caseCount == 1 ? 'case' : 'cases',
                      style: GoogleFonts.inter(fontSize: 9.sp, color: muted),
                    ),
                  ],
                ),
                SizedBox(width: 6.w),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18.sp,
                  color: muted,
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  void _showAddClientDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const AddClientDialog());
  }

  Future<void> _deleteClient(ClientModel client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12.w),
                const Text('Delete Client?'),
              ],
            ),
            content: Text(
              'This will permanently remove ${client.name} and unlink all associated cases.',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 14.sp,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  'Delete',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await SupabaseService.deleteClient(client.id);
      ref.read(paginatedClientsProvider.notifier).refresh();
    }
  }
}
