import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/supabase_service.dart';
import '../services/providers.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../components/status_badge.dart';

class DashboardCourtDiary extends ConsumerStatefulWidget {
  const DashboardCourtDiary({super.key});

  @override
  ConsumerState<DashboardCourtDiary> createState() => _DashboardCourtDiaryState();
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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Court Diary",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            hearingsAsync.when(
              data: (hearings) {
                // Pre-compute markers for the calendar
                final hearMap = <DateTime, List<Hearing>>{};
                for (var h in hearings) {
                  final date = DateTime(h.hearingDate.year, h.hearingDate.month, h.hearingDate.day);
                  hearMap.putIfAbsent(date, () => []).add(h);
                }

                // Get hearings for selected date
                final selectedDateMidnight = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
                final selectedHearings = hearMap[selectedDateMidnight] ?? [];

                return Column(
                  children: [
                    _buildCalendar(hearMap),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildDailyList(selectedHearings),
                  ],
                );
              },
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator())),
              error: (err, stack) => Center(child: Text("Error: $err")),
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
        selectedDecoration: BoxDecoration(
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
              right: 1,
              bottom: 1,
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
      width: 16.0,
      height: 16.0,
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 10.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDailyList(List<Hearing> hearings) {
    if (hearings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_available, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
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
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          color: AppTheme.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              h.caseTitle ?? "Unknown Case",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: Text(h.purpose ?? 'Hearing', style: const TextStyle(color: Colors.black87, fontSize: 13))),
                    if (h.isTeamCase(ref.read(userProvider)?.id ?? ''))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
                        ),
                        child: const Text(
                          "TEAM",
                          style: TextStyle(color: Colors.indigo, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(h.stage ?? "Hearing phase", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusBadge(status: h.status),
                if (h.status != 'adjourned' && h.status != 'closed' && h.status != 'disposed')
                  IconButton(
                    icon: const Icon(Icons.event_repeat, size: 20, color: Colors.blue),
                    onPressed: () => _showAdjournDialog(context, h),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAdjournDialog(BuildContext context, Hearing hearing) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 14));
    final List<String> purposes = [
      "Next Hearing",
      "Evidence",
      "Arguments",
      "Orders",
      "Case Disposed",
      "Case Dismissed",
    ];
    String stage = "Next Hearing";
    String notes = "";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final bool isFinal = stage == 'Case Disposed' || stage == 'Case Dismissed';
          
          return AlertDialog(
            title: const Text("Adjourn Hearing"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isFinal)
                    ListTile(
                      title: const Text("Next Date"),
                      subtitle: Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (date != null) {
                          setDialogState(() => selectedDate = date);
                        }
                      },
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: stage,
                    decoration: const InputDecoration(labelText: "Stage / Purpose"),
                    items: purposes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => stage = val);
                      }
                    },
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: "Notes (Optional)"),
                    onChanged: (val) => notes = val,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    final newHearing = await SupabaseService.adjournHearing(hearing.id, {
                      'case_id': hearing.caseId,
                      'next_date': selectedDate.toIso8601String(),
                      'next_stage': stage,
                      'current_notes': notes,
                    });
                    
                    if (newHearing != null) {

                    }
                    
                    ref.invalidate(hearingsProvider);
                    ref.invalidate(casesProvider); // Invalidate cases to refresh status
                    
                    if (context.mounted) {
                      if (!isFinal) {
                        setState(() {
                          _selectedDate = selectedDate;
                          _focusedDate = selectedDate;
                        });
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isFinal ? "Case $stage Successfully" : "Hearing adjourned"))
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  }
                },
                child: Text(isFinal ? "Update Status" : "Adjourn"),
              ),
            ],
          );
        },
      ),
    );
  }
}
