import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
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

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _searchQuery = '';
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
      Color(0xFFEC4899),
      Color(0xFF14B8A6),
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

    // Stats bar
    final activeCount = filtered.where((c) => c.hasActiveCases).length;
    final hasMore = paginatedState?.hasMore ?? false;
    final isLoadingMore = paginatedState?.isLoadingMore ?? false;

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        searchBlock,
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 16.h),
            child: Row(
              children: [
                _buildQuickStat(
                  'Total',
                  filtered.length,
                  const Color(0xFF6366F1),
                ),
                SizedBox(width: 8.w),
                _buildQuickStat('Active', activeCount, const Color(0xFF10B981)),
                SizedBox(width: 8.w),
                _buildQuickStat(
                  'Inactive',
                  filtered.length - activeCount,
                  const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
        // Client Cards List
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 90.h),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                // Loading more indicator at the bottom
                if (index == filtered.length) {
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
                                  'Loading more clients...',
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

                final c = filtered[index];
                return _buildClientCard(c, isDark);
              },
              childCount: filtered.length + (hasMore ? 1 : 0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStat(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 8.sp,
                fontWeight: FontWeight.w800,
                color: color.withValues(alpha: 0.7),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientCard(ClientModel c, bool isDark) {
    final color = _avatarColor(c.name);

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: InkWell(
        onTap: () => ClientDetailSheet.show(context, c),
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2030) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Gradient Avatar
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    c.name[0].toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              // Client Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                              fontSize: 15.sp,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Status dot
                        Container(
                          width: 7.w,
                          height: 7.h,
                          margin: EdgeInsets.only(left: 6.w),
                          decoration: BoxDecoration(
                            color:
                                c.hasActiveCases
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFCBD5E1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        if (c.phone != null && c.phone!.isNotEmpty)
                          Expanded(
                            child: Text(
                              c.phone!,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        else if (c.email != null && c.email!.isNotEmpty)
                          Expanded(
                            child: Text(
                              c.email!,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        else
                          Expanded(
                            child: Text(
                              'No contact info',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFCBD5E1),
                                fontSize: 12.sp,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        // Case count badge
                        if (c.caseCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              "${c.caseCount} ${c.caseCount == 1 ? 'Case' : 'Cases'}",
                              style: GoogleFonts.inter(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "Since ${DateFormat('MMM yyyy').format(c.createdAt)}",
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        color: const Color(0xFFCBD5E1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              // Actions
              Column(
                children: [
                  _buildActionIcon(
                    Icons.open_in_new_rounded,
                    const Color(0xFF64748B),
                    () {
                      ClientDetailSheet.show(context, c);
                    },
                  ),
                  SizedBox(height: 6.h),
                  _buildActionIcon(
                    Icons.delete_outline_rounded,
                    Colors.redAccent.withValues(alpha: 0.5),
                    () => _deleteClient(c),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  void _showAddClientDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const AddClientDialog());
  }

  void _deleteClient(ClientModel client) async {
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
