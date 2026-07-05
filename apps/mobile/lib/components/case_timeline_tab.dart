import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A visual timeline showing the complete journey of a case:
/// filing → hearings → adjournments → payments → e-filings → judgment.
class CaseTimelineTab extends ConsumerWidget {
  final String caseId;
  final CaseModel caseData;
  const CaseTimelineTab({
    super.key,
    required this.caseId,
    required this.caseData,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hearingsAsync = ref.watch(caseHearingsProvider(caseId));
    final paymentsAsync = ref.watch(casePaymentsProvider(caseId));
    final efilingsAsync = ref.watch(caseEfilingProvider(caseId));
    return hearingsAsync.when(
      data: (hearings) {
        final payments = paymentsAsync.value ?? [];
        final efilings = efilingsAsync.value ?? [];
        final events = _buildEvents(caseData, hearings, payments, efilings);

        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timeline_rounded,
                  size: 48,
                  color: Color(0xFFE2E8F0),
                ),
                SizedBox(height: 24.h),
                Text(
                  'NO TEMPORAL DATA',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11.sp,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 100),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final isFirst = index == 0;
            final isLast = index == events.length - 1;
            final isFuture = event.date.isAfter(DateTime.now());

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Timeline Line + Dot ───
                  SizedBox(
                    width: 32.w,
                    child: Column(
                      children: [
                        // Top connector line
                        if (!isFirst)
                          Container(
                            width: 1.w,
                            height: 8.h,
                            color: const Color(0xFFE2E8F0),
                          ),
                        // Dot
                        Container(
                          width: 16.w,
                          height: 16.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFuture ? Colors.transparent : event.color,
                            border: Border.all(
                              color: event.color.withValues(alpha: 0.5),
                              width: 1.w,
                            ),
                            boxShadow:
                                isFuture
                                    ? null
                                    : [
                                      BoxShadow(
                                        color: event.color.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                          ),
                        ),
                        // Bottom connector line
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 1.w,
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  // ─── Event Card ───
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date + Badge row
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: event.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Icon(
                                  event.icon,
                                  size: 18,
                                  color: event.color,
                                ),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14.sp,
                                        color: Color(0xFF1E293B),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      DateFormat(
                                        'dd MMM yyyy, EEEE',
                                      ).format(event.date),
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isFuture)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: event.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    'UPCOMING',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.bold,
                                      color: event.color,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              if (event.type == _EventType.filing && !isFuture)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    'STARTED',
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Subtitle / Details
                          if (event.subtitle != null) ...[
                            SizedBox(height: 10.h),
                            Container(
                              padding: EdgeInsets.all(10.r),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.notes_rounded,
                                    size: 12,
                                    color: Color(0xFFE2E8F0),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      event.subtitle!,
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
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
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // ─── Build Timeline Events ────────────────────────────

  List<_TimelineEvent> _buildEvents(
    CaseModel caseData,
    List<Hearing> hearings,
    List<Payment> payments,
    List<EFilingRecord> efilings,
  ) {
    final events = <_TimelineEvent>[];

    // 1. Filing date
    if (caseData.filingDate != null) {
      events.add(
        _TimelineEvent(
          date: caseData.filingDate!,
          title: 'Case Filed',
          subtitle:
              "Filed at ${caseData.courtName ?? 'Court'} • ${caseData.caseNumber ?? ''}",
          icon: Icons.gavel_rounded,
          color: const Color(0xFF6C63FF),
          type: _EventType.filing,
        ),
      );
    }

    // 2. Hearings
    for (final h in hearings) {
      final isAdjourned = h.status.toLowerCase() == 'adjourned';
      final isCompleted = h.status.toLowerCase() == 'completed';
      events.add(
        _TimelineEvent(
          date: h.hearingDate,
          title:
              isAdjourned
                  ? 'Adjourned'
                  : isCompleted
                  ? 'Hearing Completed'
                  : 'Hearing',
          subtitle: [
            if (h.purpose != null) h.purpose!,
            if (h.stage != null) 'Stage: ${h.stage}',
            if (h.notes != null && h.notes!.isNotEmpty) h.notes!,
          ].join(' • '),
          icon:
              isAdjourned ? Icons.update_rounded : Icons.calendar_today_rounded,
          color:
              isAdjourned
                  ? const Color(0xFFF59E0B)
                  : isCompleted
                  ? const Color(0xFF10B981)
                  : const Color(0xFF3B82F6),
          type: isAdjourned ? _EventType.adjournment : _EventType.hearing,
        ),
      );
    }

    // 3. Payments
    for (final p in payments) {
      if (p.paidDate != null) {
        events.add(
          _TimelineEvent(
            date: p.paidDate!,
            title: 'Payment Received',
            subtitle:
                "₹${p.paidAmount.toStringAsFixed(0)} via ${p.paymentMode ?? 'Unknown'}",
            icon: Icons.payment_rounded,
            color: const Color(0xFF10B981),
            type: _EventType.payment,
          ),
        );
      }
    }

    // 4. E-Filings
    for (final e in efilings) {
      if (e.filingDate != null) {
        events.add(
          _TimelineEvent(
            date: e.filingDate!,
            title: 'E-Filing: ${e.documentType}',
            subtitle: 'Status: ${e.status.name}',
            icon: Icons.cloud_upload_rounded,
            color: const Color(0xFF8B5CF6),
            type: _EventType.efiling,
          ),
        );
      }
    }

    // 5. Next hearing date (from case data, if not already in hearings)
    if (caseData.nextHearingDate != null) {
      final alreadyHas = hearings.any(
        (h) =>
            h.hearingDate.year == caseData.nextHearingDate!.year &&
            h.hearingDate.month == caseData.nextHearingDate!.month &&
            h.hearingDate.day == caseData.nextHearingDate!.day,
      );
      if (!alreadyHas) {
        events.add(
          _TimelineEvent(
            date: caseData.nextHearingDate!,
            title: 'Next Hearing',
            subtitle: "Scheduled at ${caseData.courtName ?? 'Court'}",
            icon: Icons.event_rounded,
            color: const Color(0xFFEC4899),
            type: _EventType.hearing,
          ),
        );
      }
    }

    // Sort chronologically
    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }
}

// ─── Timeline Event Model ────────────────────────────

enum _EventType { filing, hearing, adjournment, payment, efiling }

class _TimelineEvent {
  final DateTime date;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final _EventType type;

  _TimelineEvent({
    required this.date,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.type,
  });
}
