import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/supabase_service.dart';
import '../services/providers.dart';
import '../services/paginated_providers.dart';

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
                        // The title wraps to two lines rather than being cut
                        // at one: party names like "SUMAINA vs PU MOHAMED ALI"
                        // are longer than the space left beside the badge, and
                        // a single ellipsised line hid which case it was.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                h.caseTitle ?? 'Unknown Case',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.sp,
                                  color: const Color(0xFF1E293B),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8.w),
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

                        // ── Purpose / Stage labels ──
                        // Labels on their own line, actions on the next. All
                        // five used to share one Row, and on a phone the two
                        // buttons were squeezed up against a Spacer.
                        Wrap(
                          spacing: 6.w,
                          runSpacing: 6.h,
                          crossAxisAlignment: WrapCrossAlignment.center,
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
                          ],
                        ),
                        SizedBox(height: 12.h),

                        // ── Actions: two equal halves ──
                        Row(
                          children: [
                            Expanded(
                              child:
                                  (h.status != 'adjourned' &&
                                          h.status != 'closed' &&
                                          h.status != 'disposed')
                                      ? _diaryAction(
                                        Icons.event_repeat_rounded,
                                        'ADJOURN',
                                        AppTheme.accent,
                                        () => _showAdjournDialog(context, h),
                                      )
                                      // Keeps Delete in the right half, so it
                                      // never sits where Adjourn usually is.
                                      : const SizedBox.shrink(),
                            ),
                            SizedBox(width: 10.w),
                            // Shown whatever the status, unlike Adjourn: the
                            // point is to undo a wrong adjournment, and the
                            // hearing it leaves behind may already read
                            // "adjourned".
                            Expanded(
                              child: _diaryAction(
                                Icons.delete_outline_rounded,
                                'DELETE',
                                AppTheme.error,
                                () => _confirmDelete(context, h),
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

  /// A full-width, fixed-height action, so Adjourn and Delete are the same
  /// size and a comfortable tap target side by side.
  Widget _diaryAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          height: 38.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Hearing hearing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete this hearing?'),
            content: Text(
              '${hearing.caseTitle ?? 'This case'} on '
              '${DateFormat('dd MMM yyyy').format(hearing.hearingDate)} '
              'will be removed from the Court Diary and the Hearings page. '
              'This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      // Also moves the case's next hearing date to the next one still
      // listed, or clears it when none is left.
      await SupabaseService.deleteHearing(hearing.id);
      // Only what this touched; the rest of the dashboard stays still.
      refreshAfterHearingChange(ref, hearing.caseId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Hearing deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
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

                        // Refreshes what adjourning touches — hearings, this
                        // case, the Dossier, the status counts — and nothing
                        // else. The global dataRefreshProvider bump used here
                        // reloaded the whole dashboard to move one date.
                        refreshAfterHearingChange(ref, hearing.caseId);

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
