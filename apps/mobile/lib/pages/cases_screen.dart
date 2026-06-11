import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../components/error_state_widget.dart';
import '../theme/app_theme.dart';

class CasesScreen extends ConsumerStatefulWidget {
  const CasesScreen({super.key});

  @override
  ConsumerState<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends ConsumerState<CasesScreen> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _sortBy = 'recent'; // recent, hearing, filing

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(casesProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile, isDark),
          const SizedBox(height: 12),
          casesAsync.when(
            data: (cases) => _buildStatusSummary(cases, isDark),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 12),
          _buildSearchAndFilters(isMobile, isDark, casesAsync.value ?? []),
          const SizedBox(height: 8),
          _buildSortBar(isDark),
          const SizedBox(height: 8),
          Expanded(
            child: casesAsync.when(
              data: (cases) => _buildCasesList(isMobile, isDark, cases),
              loading:
                  () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
              error:
                  (err, stack) => ErrorStateWidget(
                    error: err,
                    onRetry: () => ref.invalidate(casesProvider),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Case Archive',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'CENTRALIZED LEGAL DATABASE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark ? const Color(0xFFCBD5E1) : Colors.black38,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── STATUS SUMMARY BAR ─────────────────────────────────
  Widget _buildStatusSummary(List<CaseModel> cases, bool isDark) {
    final active =
        cases.where((c) => c.status.name.toLowerCase() == 'active').length;
    final closed =
        cases.where((c) => c.status.name.toLowerCase() == 'closed').length;
    final pending =
        cases.where((c) => c.status.name.toLowerCase() == 'pending').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _summaryChip('$active Active', AppTheme.success, isDark),
          const SizedBox(width: 8),
          _summaryChip('$closed Closed', AppTheme.error, isDark),
          const SizedBox(width: 8),
          _summaryChip('$pending Pending', AppTheme.warning, isDark),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? AppTheme.surfaceLight
                      : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${cases.length} TOTAL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: isDark ? const Color(0xFFCBD5E1) : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(
    bool isMobile,
    bool isDark,
    List<CaseModel> cases,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 52,
            decoration: AppTheme.cardDecoration(
              isDark: isDark,
              color:
                  isDark
                      ? AppTheme.surfaceLight
                      : Colors.black.withValues(alpha: 0.03),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.inter(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search by title, ID or client...',
                hintStyle: GoogleFonts.inter(
                  color: isDark ? const Color(0xFFCBD5E1) : Colors.black38,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: isDark ? const Color(0xFFCBD5E1) : Colors.black38,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  ['all', 'active', 'closed', 'pending'].map((s) {
                    final isActive = _statusFilter == s;
                    final count =
                        s == 'all'
                            ? cases.length
                            : cases
                                .where(
                                  (c) =>
                                      c.status.name.toLowerCase() ==
                                      s.toLowerCase(),
                                )
                                .length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _statusFilter = s),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isActive
                                    ? AppTheme.accent
                                    : (isDark
                                        ? AppTheme.secondary
                                        : Colors.black.withValues(alpha: 0.03)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  isActive
                                      ? Colors.transparent
                                      : (Theme.of(context).dividerTheme.color ??
                                          Colors.grey),
                            ),
                          ),
                          child: Text(
                            "${s.toUpperCase()} ${s == 'all' ? '' : '($count)'}",
                            style: GoogleFonts.inter(
                              color:
                                  isActive
                                      ? Colors.white
                                      : const Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SORT BAR ─────────────────────────────────────────
  Widget _buildSortBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            'CLIENT REGISTRY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFCBD5E1) : Colors.black38,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder:
                (_) => [
                  _sortMenuItem('recent', 'Recently Updated'),
                  _sortMenuItem('hearing', 'Next Hearing'),
                  _sortMenuItem('filing', 'Filing Date'),
                  _sortMenuItem('title', 'Alphabetical'),
                ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? AppTheme.surfaceLight
                        : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sort_rounded,
                    size: 14,
                    color: isDark ? const Color(0xFFCBD5E1) : Colors.black38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _sortLabel(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFCBD5E1) : Colors.black38,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 14,
                    color: isDark ? const Color(0xFFCBD5E1) : Colors.black38,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortBy == value)
            const Icon(Icons.check_rounded, size: 16, color: AppTheme.accent),
          if (_sortBy == value) const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: _sortBy == value ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _sortLabel() {
    switch (_sortBy) {
      case 'hearing':
        return 'NEXT HEARING';
      case 'filing':
        return 'FILING DATE';
      case 'title':
        return 'A-Z';
      default:
        return 'RECENT';
    }
  }

  Widget _buildCasesList(bool isMobile, bool isDark, List<CaseModel> cases) {
    final currentUserId = ref.read(userProvider)?.id ?? '';

    final filtered =
        cases.where((c) {
          final matchesSearch =
              c.caseTitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (c.caseNumber ?? '').toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              (c.clientName ?? '').toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );
          final matchesStatus =
              _statusFilter == 'all' ||
              c.status.name.toLowerCase() == _statusFilter.toLowerCase();
          return matchesSearch && matchesStatus;
        }).toList();

    // Apply sort
    switch (_sortBy) {
      case 'hearing':
        filtered.sort((a, b) {
          final aDate = a.nextHearingDate ?? DateTime(2099);
          final bDate = b.nextHearingDate ?? DateTime(2099);
          return aDate.compareTo(bDate);
        });
        break;
      case 'filing':
        filtered.sort((a, b) {
          final aDate = a.filingDate ?? a.createdAt;
          final bDate = b.filingDate ?? b.createdAt;
          return bDate.compareTo(aDate);
        });
        break;
      case 'title':
        filtered.sort(
          (a, b) =>
              a.caseTitle.toLowerCase().compareTo(b.caseTitle.toLowerCase()),
        );
        break;
      default: // recent
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 48,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 16),
            Text(
              'ARCHIVE EMPTY',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: const Color(0xFF4B5563),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'No cases match your filters',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final c = filtered[index];
        final statColor = _caseColor(c.status.name);
        final isOwner = c.createdBy == currentUserId;
        final isSharedCase = !isOwner && c.firmId == null;

        return GestureDetector(
          onLongPress: isOwner ? () => _showCaseOptions(c) : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => context.push('/cases/${c.id}'),
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // ── Color-coded left border ──
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: statColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                    // ── Content ──
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: statColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: statColor.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.file_copy_rounded,
                                  color: statColor,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // ── Title Row with badges ──
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          c.caseTitle,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color:
                                                isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSharedCase) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue.withValues(
                                                alpha: 0.15,
                                              ),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.link_rounded,
                                                size: 10,
                                                color: Colors.blue,
                                              ),
                                              SizedBox(width: 3),
                                              Text(
                                                'SHARED',
                                                style: TextStyle(
                                                  fontSize: 7,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.blue,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (c.firmId != null &&
                                          c.firmId != currentUserId) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.withValues(
                                              alpha: 0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.indigo.withValues(
                                                alpha: 0.15,
                                              ),
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.groups_rounded,
                                                size: 10,
                                                color: Colors.indigo,
                                              ),
                                              SizedBox(width: 3),
                                              Text(
                                                'TEAM',
                                                style: TextStyle(
                                                  fontSize: 7,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.indigo,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // ── Case Number · Client ──
                                  Row(
                                    children: [
                                      Text(
                                        (c.caseNumber ?? 'NO ID').toUpperCase(),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall?.copyWith(
                                          color:
                                              isDark
                                                  ? const Color(0xFFCBD5E1)
                                                  : Colors.black38,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 3,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(
                                                context,
                                              ).dividerTheme.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          c.clientName ??
                                              (c.firmId != null
                                                  ? 'Firm Shared Case'
                                                  : 'Private Entity'),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall?.copyWith(
                                            color:
                                                isDark
                                                    ? const Color(0xFFCBD5E1)
                                                    : Colors.black38,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  // ── Next Hearing Date ──
                                  if (c.nextHearingDate != null) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _hearingDateColor(
                                          c.nextHearingDate!,
                                        ).withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.event_rounded,
                                            size: 11,
                                            color: _hearingDateColor(
                                              c.nextHearingDate!,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatHearingDate(
                                              c.nextHearingDate!,
                                            ),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: _hearingDateColor(
                                                c.nextHearingDate!,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color:
                                  isDark
                                      ? const Color(0xFF475569)
                                      : const Color(0xFFCBD5E1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── HELPERS ────────────────────────────────────────────

  Color _caseColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppTheme.success;
      case 'closed':
        return AppTheme.error;
      case 'pending':
        return AppTheme.warning;
      default:
        return AppTheme.accent;
    }
  }

  Color _hearingDateColor(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hearingDay = DateTime(date.year, date.month, date.day);
    final diff = hearingDay.difference(today).inDays;

    if (diff < 0) return Colors.grey; // Past
    if (diff == 0) return AppTheme.error; // Today!
    if (diff <= 3) return AppTheme.warning; // Urgent
    return AppTheme.success; // Comfortable
  }

  String _formatHearingDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final hearingDay = DateTime(date.year, date.month, date.day);
    final diff = hearingDay.difference(today).inDays;

    if (diff < 0) return "Past: ${DateFormat('dd MMM yyyy').format(date)}";
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'TOMORROW';
    if (diff <= 7) {
      return "In $diff days · ${DateFormat('dd MMM').format(date)}";
    }
    return "Next: ${DateFormat('dd MMM yyyy').format(date)}";
  }

  // ─── LONG-PRESS OPTIONS (replaces always-visible delete) ──
  void _showCaseOptions(CaseModel c) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCard
              : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.caseTitle,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.open_in_new_rounded,
                      color: AppTheme.accent,
                    ),
                    title: const Text(
                      'Open Case',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/cases/${c.id}');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.error,
                    ),
                    title: const Text(
                      'Delete Case',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.error,
                      ),
                    ),
                    subtitle: const Text(
                      'Permanently remove this case and all records',
                      style: TextStyle(fontSize: 11),
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
  }

  Future<bool?> _confirmDeleteCase(String title) {
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor:
                Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.secondary
                    : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Delete Case?'),
            content: Text(
              'Are you sure you want to permanently delete "$title" and all related records?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteCase(String id) async {
    try {
      await SupabaseService.deleteCase(id);
      ref.invalidate(casesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Case records removed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
