import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../services/providers.dart';
import '../services/paginated_providers.dart';
import '../services/paginated_notifier.dart';
import '../services/supabase_service.dart';
import '../components/error_state_widget.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HearingsScreen extends ConsumerStatefulWidget {
  const HearingsScreen({super.key});

  @override
  ConsumerState<HearingsScreen> createState() => _HearingsScreenState();
}

class _HearingsScreenState extends ConsumerState<HearingsScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();
  String _view = 'calendar'; // calendar, list
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
      ref.read(paginatedHearingsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginatedState = ref.watch(paginatedHearingsProvider);
    final hearings = paginatedState.items;
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20.h),
              _buildHeader(isMobile, isDark),
              SizedBox(height: 24.h),
              Expanded(
                child: paginatedState.isLoading && hearings.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.accent,
                        ),
                      )
                    : paginatedState.error != null && hearings.isEmpty
                        ? ErrorStateWidget(
                            error: paginatedState.error!,
                            onRetry: () => ref.read(paginatedHearingsProvider.notifier).refresh(),
                          )
                        : _view == 'calendar'
                            ? _buildCalendarView(isMobile, isDark, hearings)
                            : RefreshIndicator(
                                color: AppTheme.accent,
                                onRefresh: () => ref.read(paginatedHearingsProvider.notifier).refresh(),
                                child: _buildListView(isMobile, isDark, hearings, paginatedState),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Court Schedule',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 32.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'TEMPORAL CASE MANAGEMENT',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? const Color(0xFFCBD5E1) : Colors.black38,
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        Container(
          padding: EdgeInsets.all(4.r),
          decoration: AppTheme.cardDecoration(isDark: isDark),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _viewToggleBtn('calendar', Icons.calendar_today_rounded, isDark),
              _viewToggleBtn(
                'list',
                Icons.format_list_bulleted_rounded,
                isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _viewToggleBtn(String value, IconData icon, bool isDark) {
    final isSelected = _view == value;
    return GestureDetector(
      onTap: () => setState(() => _view = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(
          icon,
          size: 18,
          color:
              isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFFCBD5E1) : Colors.black38),
        ),
      ),
    );
  }

  // ─── CALENDAR VIEW ───────────────────────────────────
  Widget _buildCalendarView(
    bool isMobile,
    bool isDark,
    List<dynamic> hearings,
  ) {
    return Column(
      children: [
        _buildCalendarGrid(isDark, hearings),
        SizedBox(height: 24.h),
        // Hearings for the selected date
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  size: 18,
                  color: AppTheme.accent,
                ),
              ),
              SizedBox(width: 16.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE').format(_selectedDate).toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark ? const Color(0xFFCBD5E1) : Colors.black38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    DateFormat('dd MMMM yyyy').format(_selectedDate),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Expanded(child: _buildDayHearings(isDark, hearings)),
      ],
    );
  }

  Widget _buildCalendarGrid(bool isDark, List<dynamic> hearings) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday % 7; // Sun=0

    final hearingDays = <int, int>{};
    for (var h in hearings) {
      final d = h.hearingDate;
      if (d.year == _focusedMonth.year && d.month == _focusedMonth.month) {
        hearingDays[d.day] = (hearingDays[d.day] ?? 0) + 1;
      }
    }

    final totalCells = startWeekday + lastDay.day;
    final rows = ((totalCells) / 7).ceil();

    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: AppTheme.cardDecoration(isDark: isDark),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _circularNavBtn(
                  Icons.chevron_left_rounded,
                  isDark,
                  () => setState(() {
                    _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month - 1,
                    );
                  }),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedMonth).toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 1.5,
                  ),
                ),
                _circularNavBtn(
                  Icons.chevron_right_rounded,
                  isDark,
                  () => setState(() {
                    _focusedMonth = DateTime(
                      _focusedMonth.year,
                      _focusedMonth.month + 1,
                    );
                  }),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children:
                ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? const Color(0xFFCBD5E1)
                                      : Colors.black38,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
          SizedBox(height: 8.h),
          ...List.generate(rows, (row) {
            return Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final day = cellIndex - startWeekday + 1;

                if (day < 1 || day > lastDay.day) {
                  return Expanded(child: SizedBox(height: 44.h));
                }

                final cellDate = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month,
                  day,
                );
                final isToday = DateUtils.isSameDay(cellDate, DateTime.now());
                final isSelected = DateUtils.isSameDay(cellDate, _selectedDate);
                final count = hearingDays[day] ?? 0;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDate = cellDate),
                    child: Container(
                      height: 44.h,
                      margin: EdgeInsets.all(2.r),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppTheme.accent
                                : isToday
                                ? AppTheme.accent.withValues(alpha: 0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color:
                              isSelected
                                  ? AppTheme.accent
                                  : isToday
                                  ? AppTheme.accent.withValues(alpha: 0.2)
                                  : Colors.transparent,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (count > 0 && !isSelected)
                            Positioned(
                              top: 6.h,
                              right: 6.w,
                              child: Container(
                                width: 4.w,
                                height: 4.h,
                                decoration: const BoxDecoration(
                                  color: AppTheme.accentViolet,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          Text(
                            '$day',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              fontWeight:
                                  isToday || isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : (count > 0
                                          ? (isDark
                                              ? Colors.white
                                              : Colors.black87)
                                          : (isDark
                                              ? const Color(0xFFCBD5E1)
                                              : Colors.black38)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _circularNavBtn(IconData icon, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.all(6.r),
        decoration: BoxDecoration(
          color:
              isDark
                  ? AppTheme.surfaceLight
                  : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: Theme.of(context).dividerTheme.color ?? Colors.grey,
          ),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
      ),
    );
  }

  // ─── DAY HEARINGS (Calendar View) ───────────────────
  Widget _buildDayHearings(bool isDark, List<dynamic> hearings) {
    final dayHearings =
        hearings
            .where((h) => DateUtils.isSameDay(h.hearingDate, _selectedDate))
            .toList();

    if (dayHearings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 40,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
            SizedBox(height: 16.h),
            Text(
              'NO SCHEDULED HEARINGS',
              style: GoogleFonts.inter(
                color: const Color(0xFF4B5563),
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 24.h),
      itemCount: dayHearings.length,
      itemBuilder: (context, index) {
        final h = dayHearings[index];
        return _buildHearingCard(h, isDark);
      },
    );
  }

  // ─── REUSABLE HEARING CARD ─────────────────────────
  Widget _buildHearingCard(dynamic h, bool isDark) {
    final statusColor = _statusColor(h.status);

    return GestureDetector(
      onLongPress: () => _showDeleteOption(h),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => context.push('/cases/${h.caseId}'),
          borderRadius: BorderRadius.circular(14.r),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // ── Left color strip ──
                Container(
                  width: 4.w,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14.r),
                      bottomLeft: Radius.circular(14.r),
                    ),
                  ),
                ),
                // ── Content ──
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(14.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Title + Status ──
                        Row(
                          children: [
                            Container(
                              width: 40.w,
                              height: 40.h,
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.gavel_rounded,
                                  size: 18,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h.caseTitle ?? 'Unknown Case',
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
                                  SizedBox(height: 2.h),
                                  _buildStatusChip(h.status, statusColor),
                                ],
                              ),
                            ),
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

                        // ── Case No + Court (prominent container) ──
                        if (h.caseNumber != null || h.courtName != null) ...[
                          SizedBox(height: 10.h),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color:
                                    isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (h.caseNumber != null)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.tag_rounded,
                                        size: 14,
                                        color:
                                            isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                      ),
                                      SizedBox(width: 6.w),
                                      Expanded(
                                        child: Text(
                                          h.caseNumber!,
                                          style: TextStyle(
                                            color:
                                                isDark
                                                    ? const Color(0xFFE2E8F0)
                                                    : const Color(0xFF334155),
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (h.caseNumber != null && h.courtName != null)
                                  SizedBox(height: 4.h),
                                if (h.courtName != null)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.account_balance_rounded,
                                        size: 14,
                                        color:
                                            isDark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                      ),
                                      SizedBox(width: 6.w),
                                      Expanded(
                                        child: Text(
                                          h.courtName!,
                                          style: TextStyle(
                                            color:
                                                isDark
                                                    ? const Color(0xFFCBD5E1)
                                                    : const Color(0xFF475569),
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
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
                        ],

                        // ── Purpose + Stage chips ──
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _chipWidget(
                              (h.purpose ?? h.stage ?? 'Hearing').toUpperCase(),
                              AppTheme.accent,
                              isDark,
                            ),
                            if (h.stage != null && h.purpose != null)
                              _chipWidget(h.stage!, Colors.grey, isDark),
                            if (h.isTeamCase(ref.read(userProvider)?.id ?? ''))
                              _chipWidget('TEAM', Colors.indigo, isDark),
                          ],
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
  }

  Widget _buildStatusChip(String status, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 8.sp,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _chipWidget(String label, Color color, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return AppTheme.success;
      case 'adjourned':
        return AppTheme.warning;
      case 'disposed':
      case 'closed':
      case 'dismissed':
        return AppTheme.error;
      default:
        return AppTheme.accent;
    }
  }

  // ─── LIST VIEW ──────────────────────────────────────
  Widget _buildListView(bool isMobile, bool isDark, List<dynamic> hearings, PaginatedState paginatedState) {
    if (hearings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 48,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
            SizedBox(height: 16.h),
            Text(
              'NO HEARING RECORDS',
              style: GoogleFonts.inter(
                color: const Color(0xFF4B5563),
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                fontSize: 12.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Your court schedule is empty',
              style: TextStyle(fontSize: 12.sp, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    // Group hearings by date for list view
    final grouped = <String, List<dynamic>>{};
    for (var h in hearings) {
      final key = DateFormat('yyyy-MM-dd').format(h.hearingDate);
      grouped.putIfAbsent(key, () => []).add(h);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 24.h),
      itemCount: sortedKeys.length + (paginatedState.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading more indicator at the bottom
        if (index == sortedKeys.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Center(
              child: paginatedState.isLoadingMore
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
                          'Loading more hearings...',
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

        final dateKey = sortedKeys[index];
        final date = DateTime.parse(dateKey);
        final dayHearings = grouped[dateKey]!;
        final isToday = DateUtils.isSameDay(date, DateTime.now());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Date header ──
            Padding(
              padding: EdgeInsets.only(top: 16.h, bottom: 10.h),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isToday
                              ? AppTheme.accent
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      isToday
                          ? 'TODAY'
                          : DateFormat(
                            'dd MMM yyyy, EEEE',
                          ).format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w900,
                        color:
                            isToday
                                ? Colors.white
                                : (isDark
                                    ? const Color(0xFFCBD5E1)
                                    : Colors.black38),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.04,
                      ),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      '${dayHearings.length}',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? const Color(0xFFCBD5E1) : Colors.black38,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(left: 12.w),
                      height: 1.h,
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.05,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Hearing cards ──
            ...dayHearings.map((h) => _buildHearingCard(h, isDark)),
          ],
        );
      },
    );
  }

  // ─── DELETE (long-press) ────────────────────────────
  void _showDeleteOption(dynamic h) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? AppTheme.darkCard
              : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Text(
                      h.caseTitle ?? 'Hearing',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 16.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 16.h),
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
                      context.push('/cases/${h.caseId}');
                    },
                  ),
                  Divider(height: 1.h),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.error,
                    ),
                    title: const Text(
                      'Delete Hearing',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.error,
                      ),
                    ),
                    subtitle: Text(
                      'Remove from court schedule',
                      style: TextStyle(fontSize: 11.sp),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder:
                            (c) => AlertDialog(
                              backgroundColor:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppTheme.secondary
                                      : Colors.white,
                              title: const Text('Delete Hearing?'),
                              content: const Text(
                                'This entry will be removed from your court schedule.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text(
                                    'Remove',
                                    style: TextStyle(color: AppTheme.error),
                                  ),
                                ),
                              ],
                            ),
                      );
                      if (confirmed == true) {
                        await SupabaseService.deleteHearing(h.id);
                        ref.read(paginatedHearingsProvider.notifier).refresh();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
