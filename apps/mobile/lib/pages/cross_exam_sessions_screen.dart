import 'package:flutter/material.dart';
import '../components/case_picker_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../models/cross_exam_models.dart';
import '../services/providers.dart';
import '../services/repositories/cross_exam_repository.dart';
import '../theme/app_theme.dart';
import 'cross_exam_detail_screen.dart';

/// Screen listing all Cross-Examination Preparation sessions.
///
/// Fully private: all data is stored locally in Supabase under firm RLS.
/// No AI, no third-party APIs.
class CrossExamSessionsScreen extends ConsumerStatefulWidget {
  /// Optional initial case ID if opened from within a specific case.
  final String? caseId;

  const CrossExamSessionsScreen({super.key, this.caseId});

  @override
  ConsumerState<CrossExamSessionsScreen> createState() =>
      _CrossExamSessionsScreenState();
}

class _CrossExamSessionsScreenState
    extends ConsumerState<CrossExamSessionsScreen> {
  String _searchQuery = '';
  SessionStatus? _statusFilter;

  static const _tagColors = <String, List<Color>>{
    'PW': [Color(0xFF2563EB), Color(0xFF3B82F6)],
    'DW': [Color(0xFFDC2626), Color(0xFFEF4444)],
    'CW': [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
  };

  static const _avatarGradients = [
    [Color(0xFF6366F1), Color(0xFF818CF8)],
    [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
    [Color(0xFF10B981), Color(0xFF34D399)],
    [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    [Color(0xFFEC4899), Color(0xFFF472B6)],
    [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sessionsAsync = widget.caseId != null
        ? ref.watch(crossExamCaseSessionsProvider(widget.caseId!))
        : ref.watch(crossExamSessionsProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context, isDark),
      body: sessionsAsync.when(
        data: (sessions) => _buildBody(context, sessions, isDark),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
        error: (e, _) => _buildErrorState(context, e.toString(), isDark),
      ),
      floatingActionButton: _buildFab(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18.sp,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Cross-Exam Prep',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 18.sp,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '100% Private Courtroom Workspace',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh_rounded,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            size: 20.sp,
          ),
          onPressed: () {
            if (widget.caseId != null) {
              ref.invalidate(crossExamCaseSessionsProvider(widget.caseId!));
            } else {
              ref.invalidate(crossExamSessionsProvider);
            }
          },
        ),
        SizedBox(width: 4.w),
      ],
    );
  }

  Widget _buildBody(
      BuildContext context, List<CrossExamSession> sessions, bool isDark) {
    final filtered = sessions.where((s) {
      final matchesSearch = _searchQuery.isEmpty ||
          s.witnessName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.witnessTag.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s.caseTitle != null &&
              s.caseTitle!.toLowerCase().contains(_searchQuery.toLowerCase()));

      final matchesStatus =
          _statusFilter == null || s.status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    return Column(
      children: [
        _buildSearchAndFilters(sessions, isDark),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(context, sessions.isEmpty, isDark)
              : RefreshIndicator(
                  color: AppTheme.accent,
                  onRefresh: () async {
                    if (widget.caseId != null) {
                      ref.invalidate(
                          crossExamCaseSessionsProvider(widget.caseId!));
                    } else {
                      ref.invalidate(crossExamSessionsProvider);
                    }
                  },
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 90.h),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildSessionCard(
                          context, filtered[index], index, isDark);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters(
      List<CrossExamSession> allSessions, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          // Search Input
          Container(
            height: 42.h,
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
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: TextStyle(
                fontSize: 13.sp,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Search witness or case name...',
                hintStyle: TextStyle(
                  fontSize: 12.sp,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18.sp,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 16.sp),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10.h),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          // Status Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All (${allSessions.length})',
                  isSelected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null),
                  isDark: isDark,
                ),
                ...SessionStatus.values.map((status) {
                  final count =
                      allSessions.where((s) => s.status == status).length;
                  return _buildFilterChip(
                    label: '${status.emoji} ${status.label} ($count)',
                    isSelected: _statusFilter == status,
                    onTap: () => setState(() => _statusFilter = status),
                    isDark: isDark,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accent
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(
      BuildContext context, CrossExamSession session, int index, bool isDark) {
    final tag = session.witnessTag.toUpperCase();
    final tagPrefix = session.witnessTagPrefix.toUpperCase();
    final colors = _tagColors[tagPrefix] ?? _tagColors['CW']!;
    final avatarColors = _avatarGradients[index % _avatarGradients.length];
    final initial = session.witnessName.isNotEmpty
        ? session.witnessName[0].toUpperCase()
        : '?';

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F30) : Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: isDark ? const Color(0xFF26334D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18.r),
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CrossExamDetailScreen(session: session),
              ),
            );
            if (widget.caseId != null) {
              ref.invalidate(crossExamCaseSessionsProvider(widget.caseId!));
            } else {
              ref.invalidate(crossExamSessionsProvider);
            }
          },
          borderRadius: BorderRadius.circular(18.r),
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Avatar + Witness Details + Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Gradient Avatar
                    Container(
                      width: 44.w,
                      height: 44.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: avatarColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13.r),
                        boxShadow: [
                          BoxShadow(
                            color: avatarColors[0].withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18.sp,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // Name & Tag
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  session.witnessName,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              // Tag Badge
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 7.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: colors),
                                  borderRadius: BorderRadius.circular(5.r),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 3.h),
                          // Case Name
                          Row(
                            children: [
                              Icon(
                                Icons.folder_outlined,
                                size: 12.sp,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(
                                  session.caseTitle ?? 'General Case',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    _buildStatusPill(session.status),
                  ],
                ),
                SizedBox(height: 14.h),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark
                      ? const Color(0xFF26334D)
                      : const Color(0xFFF1F5F9),
                ),
                SizedBox(height: 12.h),
                // Bottom row: Question Count Pill + Hearing Date + Arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Question count
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.format_list_numbered_rounded,
                                size: 13.sp,
                                color: AppTheme.accent,
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                '${session.questionCount} Questions',
                                style: TextStyle(
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (session.hearingDate != null) ...[
                          SizedBox(width: 8.w),
                          _buildHearingDateBadge(session.hearingDate!),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        // Quick actions menu
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 18.sp,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          onSelected: (action) =>
                              _handleSessionAction(action, session),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'change_status',
                              child: Row(
                                children: [
                                  Icon(Icons.swap_horiz_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Update Status'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded,
                                      size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete Session',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13.sp,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(SessionStatus status) {
    Color bg;
    Color fg;

    switch (status) {
      case SessionStatus.draft:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        break;
      case SessionStatus.preparing:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        break;
      case SessionStatus.ready:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF059669);
        break;
      case SessionStatus.completed:
        bg = const Color(0xFFFAF5FF);
        fg = const Color(0xFF7C3AED);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        '${status.emoji} ${status.label}',
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildHearingDateBadge(DateTime hearingDate) {
    final days = hearingDate.difference(DateTime.now()).inDays;
    String label;
    Color bg = const Color(0xFFFEF3C7);
    Color fg = const Color(0xFFD97706);

    if (days < 0) {
      label = 'Past';
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
    } else if (days == 0) {
      label = 'Hearing Today!';
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
    } else if (days == 1) {
      label = 'Hearing Tomorrow';
    } else if (days <= 7) {
      label = 'In $days days';
    } else {
      label = DateFormat('dd MMM').format(hearingDate);
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF475569);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(Icons.event_rounded, size: 12.sp, color: fg),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, bool isTotalEmpty, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.r,
              height: 80.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.15),
                    AppTheme.accentViolet.withValues(alpha: 0.15),
                  ],
                ),
              ),
              child: Icon(
                Icons.gavel_rounded,
                size: 38.sp,
                color: AppTheme.accent,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              isTotalEmpty
                  ? 'Prepare Witness Cross-Examination'
                  : 'No Matching Sessions',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              isTotalEmpty
                  ? 'Organize killer cross-examination questions by witness, contradiction, trap, and priority. 100% private to your firm.'
                  : 'Try adjusting your search query or filter chips above.',
              style: TextStyle(
                fontSize: 13.sp,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            // No button here. The "New Session" action is always on screen as
            // the button above the list, so an empty state that added its own
            // gave two controls doing one job.
            if (isTotalEmpty) ...[
              SizedBox(height: 16.h),
              Text(
                'Tap New Session to start.',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error, bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48.sp, color: Colors.redAccent),
            SizedBox(height: 16.h),
            Text(
              'Unable to Load Sessions',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: () => ref.invalidate(crossExamSessionsProvider),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () => _showNewSessionSheet(context),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 20.sp),
                SizedBox(width: 6.w),
                Text(
                  'New Session',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.sp,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSessionAction(String action, CrossExamSession session) {
    if (action == 'delete') {
      _confirmDeleteSession(session);
    } else if (action == 'change_status') {
      _showChangeStatusDialog(session);
    }
  }

  void _confirmDeleteSession(CrossExamSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text(
          'Are you sure you want to delete the cross-examination session for "${session.witnessName}"? All ${session.questionCount} questions will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await CrossExamRepository.deleteSession(session.id);
                if (widget.caseId != null) {
                  ref.invalidate(crossExamCaseSessionsProvider(widget.caseId!));
                } else {
                  ref.invalidate(crossExamSessionsProvider);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Session deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangeStatusDialog(CrossExamSession session) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Update Session Status'),
        children: SessionStatus.values.map((st) {
          final isCurrent = session.status == st;
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (isCurrent) return;
              try {
                await CrossExamRepository.updateSession(
                    session.id, {'status': st.name});
                if (widget.caseId != null) {
                  ref.invalidate(crossExamCaseSessionsProvider(widget.caseId!));
                } else {
                  ref.invalidate(crossExamSessionsProvider);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update status: $e')),
                  );
                }
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                children: [
                  Text(st.emoji, style: TextStyle(fontSize: 18.sp)),
                  SizedBox(width: 12.w),
                  Text(
                    st.label,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight:
                          isCurrent ? FontWeight.w800 : FontWeight.w500,
                      color: isCurrent ? AppTheme.accent : null,
                    ),
                  ),
                  if (isCurrent) ...[
                    const Spacer(),
                    const Icon(Icons.check, color: AppTheme.accent, size: 18),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showNewSessionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewSessionSheet(
        initialCaseId: widget.caseId,
        onSessionCreated: (newSession) {
          if (widget.caseId != null) {
            ref.invalidate(crossExamCaseSessionsProvider(widget.caseId!));
          } else {
            ref.invalidate(crossExamSessionsProvider);
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CrossExamDetailScreen(session: newSession),
            ),
          );
        },
      ),
    );
  }
}

/// Bottom sheet dialog for creating a new cross-examination session.
class _NewSessionSheet extends ConsumerStatefulWidget {
  final String? initialCaseId;
  final ValueChanged<CrossExamSession> onSessionCreated;

  const _NewSessionSheet({
    this.initialCaseId,
    required this.onSessionCreated,
  });

  @override
  ConsumerState<_NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends ConsumerState<_NewSessionSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCaseId;
  final _witnessNameController = TextEditingController();
  String _selectedTag = 'PW1';
  DateTime? _hearingDate;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  final List<String> _tagPresets = [
    'PW1',
    'PW2',
    'PW3',
    'DW1',
    'DW2',
    'DW3',
    'CW1',
    'CW2',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCaseId = widget.initialCaseId;
  }

  @override
  void dispose() {
    _witnessNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final casesAsync = ref.watch(casesProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(
        20.w,
        16.h,
        20.w,
        MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              // Title
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.person_search_rounded,
                      color: AppTheme.accent,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Cross-Exam Session',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Select case and witness details',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              // Case Selector
              Text(
                'CASE',
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 6.h),
              casesAsync.when(
                data: (cases) {
                  if (cases.isEmpty) {
                    return Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: const Text('No cases found. Please create a case first.'),
                    );
                  }

                  if (_selectedCaseId == null && cases.isNotEmpty) {
                    _selectedCaseId = cases.first.id;
                  }

                  return CasePickerField(
                    cases: cases,
                    value: _selectedCaseId,
                    sheetTitle: 'Select case for session',
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 12.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      prefixIcon: const Icon(Icons.folder_open_rounded),
                    ),
                    onSelected: (c) => setState(() => _selectedCaseId = c.id),
                    validator: (v) => v == null ? 'Select a case' : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error loading cases: $e'),
              ),
              SizedBox(height: 16.h),
              // Witness Name
              Text(
                'WITNESS NAME',
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 6.h),
              TextFormField(
                controller: _witnessNameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. Inspector Ramesh Kumar or Dr. Ananya Sen',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter witness name' : null,
              ),
              SizedBox(height: 16.h),
              // Witness Tag Selector
              Text(
                'WITNESS DESIGNATION / TAG',
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: _tagPresets.map((tag) {
                  final isSelected = _selectedTag == tag;
                  return ChoiceChip(
                    label: Text(tag),
                    selected: isSelected,
                    selectedColor: AppTheme.accent,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 11.5.sp,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTag = tag);
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 16.h),
              // Hearing Date Picker
              Text(
                'HEARING DATE (OPTIONAL)',
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 6.h),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _hearingDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) {
                    setState(() => _hearingDate = picked);
                  }
                },
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 14.w, vertical: 13.h),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18.sp),
                      SizedBox(width: 10.w),
                      Text(
                        _hearingDate != null
                            ? DateFormat('EEE, dd MMM yyyy').format(_hearingDate!)
                            : 'Select expected examination date',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: _hearingDate != null
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : (isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8)),
                        ),
                      ),
                      if (_hearingDate != null) ...[
                        const Spacer(),
                        InkWell(
                          onTap: () => setState(() => _hearingDate = null),
                          child: Icon(Icons.close_rounded, size: 16.sp),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    elevation: 3,
                  ),
                  onPressed: _isLoading ? null : _submitNewSession,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Start Examination Prep',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitNewSession() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCaseId == null) return;

    setState(() => _isLoading = true);

    try {
      final session = await CrossExamRepository.createSession({
        'case_id': _selectedCaseId,
        'witness_name': _witnessNameController.text.trim(),
        'witness_tag': _selectedTag,
        'status': SessionStatus.draft.name,
        'hearing_date': _hearingDate?.toIso8601String().split('T').first,
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      });

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSessionCreated(session);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create session: $e')),
        );
      }
    }
  }
}
