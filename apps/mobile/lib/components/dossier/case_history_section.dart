import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../services/providers.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../hearing_notes_dialog.dart';
import '../status_badge.dart';
import 'dossier_shared.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CaseHistorySection extends ConsumerStatefulWidget {
  final String caseId;
  final String caseTitle;

  const CaseHistorySection({
    super.key,
    required this.caseId,
    required this.caseTitle,
  });

  @override
  ConsumerState<CaseHistorySection> createState() => _CaseHistorySectionState();
}

class _CaseHistorySectionState extends ConsumerState<CaseHistorySection> {
  void _showAddHearingDialog() {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    String purpose = '';

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
                title: const Text('Schedule Hearing'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Hearing Date'),
                        subtitle: Text(
                          DateFormat('dd MMM yyyy').format(selectedDate),
                        ),
                        trailing: const Icon(
                          Icons.calendar_today,
                          color: AppTheme.accent,
                        ),
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
                      SizedBox(height: 8.h),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Purpose / Stage',
                        ),
                        onChanged: (v) => purpose = v,
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
                      // The page's messenger: the dialog's context is gone
                      // once it closes, so the warning below never showed.
                      final messenger = ScaffoldMessenger.of(this.context);
                      Navigator.pop(context);
                      try {
                        await SupabaseService.createHearing({
                          'case_id': widget.caseId,
                          'hearing_date': selectedDate.toIso8601String(),
                          'purpose': purpose.isNotEmpty ? purpose : null,
                          'status': 'scheduled',
                        });
                        ref.invalidate(caseHearingsProvider(widget.caseId));
                        ref.invalidate(hearingsProvider);
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                SupabaseService.isDuplicateHearing(e)
                                    ? 'This case is already listed on that date.'
                                    : 'Error: $e',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Schedule'),
                  ),
                ],
              );
            },
          ),
    );
  }

  Widget _buildCaseHistoryTable(List<Hearing> hearings) {
    final df = DateFormat('dd-MM-yyyy');
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7.r)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'HEARING DATE',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'PURPOSE OF HEARING',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'STATUS',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(width: 30.w),
              ],
            ),
          ),
          ...hearings.map((h) {
            final isFuture = h.hearingDate.isAfter(DateTime.now());
            final isCompleted = h.status.toLowerCase() == 'completed';
            final rowColor =
                isFuture
                    ? const Color(0xFFFFF7ED)
                    : isCompleted
                    ? const Color(0xFFF0FDF4)
                    : Colors.transparent;

            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder:
                      (_) => HearingNotesDialog(
                        hearingId: h.id,
                        caseTitle: widget.caseTitle,
                        hearingDate: h.hearingDate,
                        existingNotes: h.notes,
                        onSaved:
                            () => ref.invalidate(
                              caseHearingsProvider(widget.caseId),
                            ),
                      ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: rowColor,
                  border: const Border(
                    top: BorderSide(color: AppTheme.darkBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            df.format(h.hearingDate),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                              color:
                                  isFuture
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF1E293B),
                            ),
                          ),
                          if (isFuture)
                            Text(
                              'UPCOMING',
                              style: TextStyle(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF59E0B),
                                letterSpacing: 0.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.purpose ?? h.stage ?? 'Standard Hearing',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (h.notes?.isNotEmpty == true)
                            Text(
                              h.notes!,
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Color(0xFF94A3B8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Expanded(flex: 2, child: StatusBadge(status: h.status)),
                    const Icon(
                      Icons.edit_note_rounded,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hearingsAsync = ref.watch(caseHearingsProvider(widget.caseId));

    return DossierSection(
      icon: Icons.history_rounded,
      title: 'Case History',
      color: const Color(0xFF3B82F6),
      trailing: DossierHelper.addButton(() => _showAddHearingDialog()),
      children: [
        hearingsAsync.when(
          data: (hearings) {
            if (hearings.isEmpty) {
              return DossierHelper.emptyHint(
                'No hearing records yet. Schedule your first hearing.',
              );
            }
            // Sort chronologically — oldest first
            final sorted = List<Hearing>.from(hearings)
              ..sort((a, b) => a.hearingDate.compareTo(b.hearingDate));
            return _buildCaseHistoryTable(sorted);
          },
          loading:
              () => Padding(
                padding: EdgeInsets.all(16.r),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          error: (e, _) => DossierHelper.emptyHint('Error loading history'),
        ),
      ],
    );
  }
}
