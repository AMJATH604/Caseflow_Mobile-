import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/supabase_service.dart';
import '../services/providers.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../components/status_badge.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/app_localizations.dart';

class DashboardCourtDiary extends ConsumerStatefulWidget {
  DashboardCourtDiary({super.key});

  @override
  ConsumerState<DashboardCourtDiary> createState() =>
      _DashboardCourtDiaryState();
}

class _DashboardCourtDiaryState extends ConsumerState<DashboardCourtDiary> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final hearingsAsync = ref.watch(hearingsProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context).get('court_diary'),
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            hearingsAsync.when(
              skipLoadingOnRefresh: true,
              data: (hearings) {
                // Pre-compute markers for the calendar
                final hearMap = <DateTime, List<Hearing>>{};
                for (var h in hearings) {
                  final date = DateTime(
                    h.hearingDate.year,
                    h.hearingDate.month,
                    h.hearingDate.day,
                  );
                  hearMap.putIfAbsent(date, () => []).add(h);
                }

                // Get hearings for selected date
                final selectedDateMidnight = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                );
                final selectedHearings = hearMap[selectedDateMidnight] ?? [];

                return Column(
                  children: [
                    _buildTodayStrip(hearMap),
                    SizedBox(height: 14.h),
                    _buildCalendar(hearMap),
                    SizedBox(height: 16.h),
                    Divider(),
                    SizedBox(height: 8.h),
                    _buildDailyList(selectedHearings),
                  ],
                );
              },
              loading:
                  () => Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0.r),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ],
        ),
      ),
    );
  }

  /// Answers "what am I in court for today?" without a tap.
  ///
  /// The calendar below is for planning the month; this is for this morning.
  /// Both previously required selecting a date before they told you anything,
  /// which left the app's most-asked question two taps deep.
  ///
  /// Deliberately shows no clock time: a hearing carries a date and no time of
  /// day — there is no `hearing_time` column — and inventing one on a court
  /// diary is the kind of error that costs an appearance.
  Widget _buildTodayStrip(Map<DateTime, List<Hearing>> hearMap) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todays = hearMap[today] ?? const <Hearing>[];

    if (todays.isNotEmpty) {
      return _todayPanel(l10n, todays, today);
    }

    // Nothing today. The useful follow-up is when the next one actually is,
    // so find the nearest future day that has hearings.
    final upcoming =
        hearMap.keys.where((d) => d.isAfter(today)).toList()..sort();

    return _quietPanel(
      icon: Icons.event_available_rounded,
      title: l10n.get('no_hearings_today'),
      subtitle:
          upcoming.isEmpty
              ? null
              : '${l10n.get('next_hearing')}: '
                  '${DateFormat('EEE, d MMM').format(upcoming.first)}'
                  ' · ${hearMap[upcoming.first]!.length}',
      onTap:
          upcoming.isEmpty
              ? null
              : () => setState(() {
                _selectedDate = upcoming.first;
                _focusedDate = upcoming.first;
              }),
    );
  }

  Widget _todayPanel(
    AppLocalizations l10n,
    List<Hearing> todays,
    DateTime today,
  ) {
    final first = todays.first;
    final canAdjourn =
        first.status != 'adjourned' &&
        first.status != 'closed' &&
        first.status != 'disposed';

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6.w,
                height: 6.w,
                decoration: const BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 7.w),
              Expanded(
                child: Text(
                  l10n.get('todays_hearings').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: AppTheme.accent,
                  ),
                ),
              ),
              Text(
                '${todays.length}',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            first.caseTitle ?? 'Untitled matter',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.2,
            ),
          ),
          if ((first.courtName ?? '').isNotEmpty) ...[
            SizedBox(height: 3.h),
            Text(
              first.courtName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.sp, color: const Color(0xFF64748B)),
            ),
          ],
          SizedBox(height: 10.h),
          Row(
            children: [
              if (todays.length > 1)
                InkWell(
                  onTap:
                      () => setState(() {
                        _selectedDate = today;
                        _focusedDate = today;
                      }),
                  borderRadius: BorderRadius.circular(6.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 2.h,
                    ),
                    child: Text(
                      '+${todays.length - 1} more',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              if (canAdjourn)
                InkWell(
                  onTap: () => _showAdjournDialog(context, first),
                  borderRadius: BorderRadius.circular(8.r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.event_repeat_rounded,
                          size: 13,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'ADJOURN',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Used when there is nothing today — quiet on purpose, so an empty diary
  /// does not shout at a new user.
  Widget _quietPanel({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFFCBD5E1),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(Map<DateTime, List<Hearing>> hearMap) {
    return TableCalendar<Hearing>(
      firstDay: DateTime.now().subtract(const Duration(days: 365)),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedDate,
      selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDate = selectedDay;
          _focusedDate = focusedDay;
        });
      },
      eventLoader: (day) {
        final dateMidnight = DateTime(day.year, day.month, day.day);
        return hearMap[dateMidnight] ?? [];
      },
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: AppTheme.accent,
          shape: BoxShape.circle,
        ),
        markerDecoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          if (events.isNotEmpty) {
            return Positioned(
              right: 1.w,
              bottom: 1.h,
              child: _buildMarker(events.length),
            );
          }
          return null;
        },
      ),
    );
  }

  Widget _buildMarker(int count) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      width: 16.0.w,
      height: 16.0.h,
      child: Center(
        child: Text(
          '$count',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 10.0.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDailyList(List<Hearing> hearings) {
    if (hearings.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0.h),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_available, size: 48, color: Colors.grey[400]),
              SizedBox(height: 8.h),
              Text(
                "No hearings on ${DateFormat('MMM dd, yyyy').format(_selectedDate)}",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: hearings.length,
      itemBuilder: (context, index) {
        final h = hearings[index];
        final statusColor = _hearingStatusColor(h.status);

        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppTheme.darkBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
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
                        // ── Title row ──
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                h.caseTitle ?? 'Unknown Case',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.sp,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            StatusBadge(status: h.status),
                          ],
                        ),

                        // ── Case No + Court Name (prominent) ──
                        if (h.caseNumber != null || h.courtName != null) ...[
                          SizedBox(height: 8.h),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (h.caseNumber != null)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.tag_rounded,
                                        size: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                      SizedBox(width: 6.w),
                                      Expanded(
                                        child: Text(
                                          h.caseNumber!,
                                          style: TextStyle(
                                            color: Color(0xFF334155),
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
                                      const Icon(
                                        Icons.account_balance_rounded,
                                        size: 14,
                                        color: Color(0xFF64748B),
                                      ),
                                      SizedBox(width: 6.w),
                                      Expanded(
                                        child: Text(
                                          h.courtName!,
                                          style: TextStyle(
                                            color: Color(0xFF475569),
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

                        SizedBox(height: 8.h),

                        // ── Purpose / Stage row ──
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                (h.purpose ?? 'Hearing').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accent,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            if (h.stage != null) ...[
                              SizedBox(width: 6.w),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  h.stage!,
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                            if (h.isTeamCase(
                              ref.read(userProvider)?.id ?? '',
                            )) ...[
                              SizedBox(width: 6.w),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6.r),
                                  border: Border.all(
                                    color: Colors.indigo.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'TEAM',
                                  style: TextStyle(
                                    color: Colors.indigo,
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                            Spacer(),
                            if (h.status != 'adjourned' &&
                                h.status != 'closed' &&
                                h.status != 'disposed')
                              InkWell(
                                onTap: () => _showAdjournDialog(context, h),
                                borderRadius: BorderRadius.circular(8.r),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(
                                      color: Colors.blue.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.event_repeat_rounded,
                                        size: 13,
                                        color: Colors.blue,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'ADJOURN',
                                        style: TextStyle(
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _hearingStatusColor(String status) {
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

  void _showAdjournDialog(BuildContext context, Hearing hearing) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 14));
    final List<String> purposes = [
      'Next Hearing',
      'Evidence',
      'Arguments',
      'Orders',
      'Case Disposed',
      'Case Dismissed',
    ];
    String stage = 'Next Hearing';
    String notes = '';

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              final bool isFinal =
                  stage == 'Case Disposed' || stage == 'Case Dismissed';

              return AlertDialog(
                title: const Text('Adjourn Hearing'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isFinal)
                        ListTile(
                          title: const Text('Next Date'),
                          subtitle: Text(
                            DateFormat('MMM dd, yyyy').format(selectedDate),
                          ),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365 * 5),
                              ),
                            );
                            if (date != null) {
                              setDialogState(() => selectedDate = date);
                            }
                          },
                        ),
                      DropdownButtonFormField<String>(
                        initialValue: stage,
                        decoration: const InputDecoration(
                          labelText: 'Stage / Purpose',
                        ),
                        items:
                            purposes
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => stage = val);
                          }
                        },
                      ),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                        ),
                        onChanged: (val) => notes = val,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        final newHearing =
                            await SupabaseService.adjournHearing(hearing.id, {
                              'case_id': hearing.caseId,
                              'next_date': selectedDate.toIso8601String(),
                              'next_stage': stage,
                              'current_notes': notes,
                            });

                        if (newHearing != null) {}

                        ref.invalidate(hearingsProvider);
                        ref.invalidate(
                          casesProvider,
                        ); // Invalidate cases to refresh status
                        ref.invalidate(dashboardStatsProvider);

                        if (context.mounted) {
                          if (!isFinal) {
                            setState(() {
                              _selectedDate = selectedDate;
                              _focusedDate = selectedDate;
                            });
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isFinal
                                    ? 'Case $stage Successfully'
                                    : 'Hearing adjourned',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    child: Text(isFinal ? 'Update Status' : 'Adjourn'),
                  ),
                ],
              );
            },
          ),
    );
  }
}
