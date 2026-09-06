import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';

import 'dossier/dossier_shared.dart';
import 'dossier/party_intelligence_section.dart';
import 'dossier/acts_section.dart';
import 'dossier/ia_section.dart';
import 'dossier/case_history_section.dart';
import 'dossier/interim_orders_section.dart';
import 'dossier/human_capital_section.dart';

/// Shared by the hero card and the quick-facts strip.
final DateFormat _dossierDateFmt = DateFormat('dd MMM yyyy');

/// Case File Dossier — hero summary plus progressive disclosure.
///
/// The previous layout stacked eight equally-weighted accordions, all
/// collapsed, which buried the one thing an advocate opens a case to check:
/// when it is next listed. This surfaces the status permanently and moves
/// everything else behind a single tap.
///
/// The detail sections themselves ([ActsSection], [IASection], and the rest)
/// are reused unchanged — they render inside a [DossierEmbedScope] so their
/// internal [DossierSection] drops its accordion chrome in the sheet.
class CaseDossierTab extends ConsumerStatefulWidget {
  final String caseId;
  final CaseModel caseData;

  const CaseDossierTab({
    super.key,
    required this.caseId,
    required this.caseData,
  });

  @override
  ConsumerState<CaseDossierTab> createState() => _CaseDossierTabState();
}

class _CaseDossierTabState extends ConsumerState<CaseDossierTab> {

  @override
  Widget build(BuildContext context) {
    final caseData = widget.caseData;

    // Counts drive the row badges, so an empty section is obvious without
    // opening it. `valueOrNull` keeps this non-blocking while data loads.
    final acts = ref.watch(caseActsProvider(widget.caseId)).valueOrNull;
    final ias = ref.watch(caseIAProvider(widget.caseId)).valueOrNull;
    final orders =
        ref.watch(caseInterimOrdersProvider(widget.caseId)).valueOrNull;
    final hearings = ref.watch(caseHearingsProvider(widget.caseId)).valueOrNull;
    final documents =
        ref.watch(caseDocumentsProvider(widget.caseId)).valueOrNull;
    final payments = ref.watch(casePaymentsProvider(widget.caseId)).valueOrNull;

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 100.h),
      children: [
        _HeroCard(caseData: caseData),
        SizedBox(height: 14.h),
        _QuickFacts(caseData: caseData),
        SizedBox(height: 20.h),
        _sectionLabel('CASE FILE'),
        SizedBox(height: 8.h),
        _RowGroup(children: [
        _DossierRow(
          icon: Icons.groups_rounded,
          color: const Color(0xFF6366F1),
          label: 'Parties',
          count: _partyCount(caseData),
          onTap: () => _openSheet(
            title: 'Parties',
            icon: Icons.groups_rounded,
            color: const Color(0xFF6366F1),
            body: PartyIntelligenceSection(caseData: caseData),
          ),
        ),
        _DossierRow(
          icon: Icons.gavel_rounded,
          color: const Color(0xFF8B5CF6),
          label: 'Acts & Sections',
          count: acts?.length,
          onTap: () => _openSheet(
            title: 'Acts & Sections',
            icon: Icons.gavel_rounded,
            color: const Color(0xFF8B5CF6),
            body: ActsSection(caseId: widget.caseId),
          ),
        ),
        _DossierRow(
          icon: Icons.layers_rounded,
          color: const Color(0xFFF59E0B),
          label: 'IA Applications',
          count: ias?.length,
          onTap: () => _openSheet(
            title: 'IA Applications',
            icon: Icons.layers_rounded,
            color: const Color(0xFFF59E0B),
            body: IASection(caseId: widget.caseId),
          ),
        ),
        _DossierRow(
          icon: Icons.history_rounded,
          color: AppTheme.info,
          label: 'Case History',
          count: hearings?.length,
          onTap: () => _openSheet(
            title: 'Case History',
            icon: Icons.history_rounded,
            color: AppTheme.info,
            body: CaseHistorySection(
              caseId: widget.caseId,
              caseTitle: caseData.caseTitle,
            ),
          ),
        ),
        _DossierRow(
          icon: Icons.receipt_long_rounded,
          color: AppTheme.error,
          label: 'Interim Orders',
          count: orders?.length,
          onTap: () => _openSheet(
            title: 'Interim Orders',
            icon: Icons.receipt_long_rounded,
            color: AppTheme.error,
            body: InterimOrdersSection(caseId: widget.caseId),
          ),
        ),
        _DossierRow(
          icon: Icons.badge_rounded,
          color: AppTheme.success,
          label: 'Team',
          onTap: () => _openSheet(
            title: 'Team',
            icon: Icons.badge_rounded,
            color: AppTheme.success,
            body: HumanCapitalSection(
              caseId: widget.caseId,
              caseData: caseData,
            ),
          ),
          isLast: true,
        ),
        ]),
        SizedBox(height: 20.h),
        _sectionLabel('AT A GLANCE'),
        SizedBox(height: 8.h),
        _StatsRow(
          hearings: hearings?.length ?? 0,
          documents: documents?.length ?? 0,
          payments: payments?.length ?? 0,
        ),
      ],
    );
  }

  /// Petitioner plus respondent when both are known.
  int? _partyCount(CaseModel c) {
    final hasClient = (c.clientName ?? '').isNotEmpty;
    final hasOpposing = (c.opposingParty ?? '').isNotEmpty;
    if (!hasClient && !hasOpposing) return null;
    return (hasClient ? 1 : 0) + (hasOpposing ? 1 : 0);
  }

  Widget _sectionLabel(String text) => Padding(
        padding: EdgeInsets.only(left: 4.w),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: const Color(0xFF94A3B8),
          ),
        ),
      );

  Future<void> _openSheet({
    required String title,
    required IconData icon,
    required Color color,
    required Widget body,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
          ),
          child: Column(
            children: [
              SizedBox(height: 10.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 8.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(9.r),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: const Color(0xFF94A3B8),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Expanded(
                // The scope is what lets the existing section widgets render
                // here without their accordion wrapper.
                child: DossierEmbedScope(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
                    children: [body],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Hero ────────────────────────────────────────────────

/// Always-visible status block: what the case is, and when it is next listed.
class _HeroCard extends StatelessWidget {
  final CaseModel caseData;

  const _HeroCard({required this.caseData});

  @override
  Widget build(BuildContext context) {
    final status = caseData.status;
    final statusColor = status == CaseStatus.active
        ? AppTheme.success
        : status == CaseStatus.disposed
            ? AppTheme.error
            : AppTheme.warning;

    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if ((caseData.caseNumber ?? '').isNotEmpty)
                Flexible(
                  child: Text(
                    caseData.caseNumber!,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.robotoMono(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      status.label.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            caseData.caseTitle,
            style: GoogleFonts.inter(
              fontSize: 19.sp,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 16.h),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          SizedBox(height: 14.h),
          _NextHearing(date: caseData.nextHearingDate),
          if ((caseData.courtName ?? '').isNotEmpty) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                const Icon(
                  Icons.account_balance_rounded,
                  size: 14,
                  color: Color(0xFF94A3B8),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    caseData.courtName!,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Next listing with a plain-language countdown.
class _NextHearing extends StatelessWidget {
  final DateTime? date;

  const _NextHearing({required this.date});

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return Row(
        children: [
          const Icon(
            Icons.event_busy_rounded,
            size: 16,
            color: Color(0xFFCBD5E1),
          ),
          SizedBox(width: 8.w),
          Text(
            'No hearing scheduled',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      );
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final target = DateUtils.dateOnly(date!);
    final days = target.difference(today).inDays;

    final overdueBy = -days;
    final overdueUnit = overdueBy == 1 ? 'day' : 'days';

    final (String relative, Color tone) = switch (days) {
      < 0 => ('Overdue by $overdueBy $overdueUnit', AppTheme.error),
      0 => ('Today', AppTheme.error),
      1 => ('Tomorrow', AppTheme.warning),
      < 8 => ('In $days days', AppTheme.warning),
      _ => ('In $days days', AppTheme.success),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEXT HEARING',
              style: GoogleFonts.inter(
                fontSize: 9.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: const Color(0xFF94A3B8),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              _dossierDateFmt.format(date!),
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            relative,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: tone,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Quick facts ─────────────────────────────────────────

/// The reference fields an advocate quotes on the phone — visible without a tap.
class _QuickFacts extends StatelessWidget {
  final CaseModel caseData;

  const _QuickFacts({required this.caseData});

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      ('TYPE', caseData.caseType ?? '—'),
      ('STAGE', caseData.stage.label),
      ('CNR', caseData.cnrNumber ?? '—'),
      (
        'FILED',
        caseData.filingDate != null
            ? _dossierDateFmt.format(caseData.filingDate!)
            : '—',
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Wrap(
        runSpacing: 14.h,
        children: [
          for (final (label, value) in entries)
            SizedBox(
              width: 0.5.sw - 32.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Navigation row ──────────────────────────────────────

/// Rounded card that holds the navigation rows as one grouped surface.
///
/// `clipBehavior` matters: each row paints its own background, which would
/// otherwise square off the corners of the card.
class _RowGroup extends StatelessWidget {
  final List<Widget> children;

  const _RowGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(children: children),
    );
  }
}

/// One tappable line into a detail sheet. The count is the point: an empty
/// section reads as empty without being opened.
class _DossierRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int? count;
  final VoidCallback onTap;
  final bool isLast;

  const _DossierRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.count,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: AppTheme.darkCard,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9.r),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  SizedBox(width: 13.w),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (count != null)
                    Container(
                      constraints: BoxConstraints(minWidth: 22.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 7.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: count == 0
                            ? const Color(0xFFF1F5F9)
                            : color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        '$count',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: count == 0
                              ? const Color(0xFF94A3B8)
                              : color,
                        ),
                      ),
                    ),
                  SizedBox(width: 6.w),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xFFCBD5E1),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Container(
            color: AppTheme.darkCard,
            padding: EdgeInsets.only(left: 53.w),
            child: const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
      ],
    );
  }
}

// ─── Stats ───────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int hearings;
  final int documents;
  final int payments;

  const _StatsRow({
    required this.hearings,
    required this.documents,
    required this.payments,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DossierHelper.statMini(
            'HEARINGS',
            hearings,
            Icons.gavel_rounded,
            AppTheme.accent,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: DossierHelper.statMini(
            'RECORDS',
            documents,
            Icons.folder_zip_rounded,
            AppTheme.info,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: DossierHelper.statMini(
            'FINANCE',
            payments,
            Icons.account_balance_wallet_rounded,
            AppTheme.success,
          ),
        ),
      ],
    );
  }
}
