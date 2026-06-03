import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../models/case_dossier_models.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';

import 'dossier/dossier_shared.dart';
import 'dossier/party_intelligence_section.dart';
import 'dossier/acts_section.dart';
import 'dossier/ia_section.dart';
import 'dossier/case_history_section.dart';
import 'dossier/interim_orders_section.dart';
import 'dossier/human_capital_section.dart';

/// eCourt-style unified Case File Dossier tab.
/// Shows all case intelligence in collapsible sections on a single scrollable page.
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
  final fmt = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final caseData = widget.caseData;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        children: [
          // ─── 1. CASE DETAILS ─────────────────────────
          DossierSection(
            icon: Icons.description_rounded,
            title: "Case Details",
            color: const Color(0xFF6C63FF),
            initiallyExpanded: true,
            children: [
              DossierHelper.dossierRow(
                "CASE TYPE",
                caseData.caseType ?? "NOT DEFINED",
              ),
              DossierHelper.dossierRow(
                "CASE NUMBER",
                caseData.caseNumber ?? "NOT ASSIGNED",
              ),
              DossierHelper.dossierRow(
                "FILING DATE",
                caseData.filingDate != null
                    ? fmt.format(caseData.filingDate!)
                    : "PENDING",
              ),
              DossierHelper.dossierRow(
                "CNR NUMBER",
                caseData.cnrNumber ?? "NOT AVAILABLE",
              ),
              DossierHelper.dossierRow(
                "COURT",
                caseData.courtName ?? "UNSPECIFIED FORUM",
              ),
              DossierHelper.dossierRow(
                "STATE / DISTRICT",
                "${caseData.state ?? '—'} / ${caseData.district ?? '—'}",
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ─── 2. OPERATIONAL STATUS ───────────────────
          DossierSection(
            icon: Icons.insights_rounded,
            title: "Case Status",
            color: const Color(0xFF3B82F6),
            badgeText: caseData.status.label.toUpperCase(),
            badgeColor:
                caseData.status == CaseStatus.active
                    ? AppTheme.success
                    : caseData.status == CaseStatus.disposed
                    ? AppTheme.error
                    : AppTheme.warning,
            initiallyExpanded: true,
            children: [
              DossierHelper.dossierRow(
                "FIRST HEARING",
                caseData.filingDate != null
                    ? fmt.format(caseData.filingDate!)
                    : "—",
              ),
              DossierHelper.dossierRow(
                "NEXT HEARING",
                caseData.nextHearingDate != null
                    ? fmt.format(caseData.nextHearingDate!)
                    : "NOT SCHEDULED",
              ),
              DossierHelper.dossierRow(
                "CASE STAGE",
                caseData.stage.label.toUpperCase(),
              ),
              DossierHelper.dossierRow(
                "COURT TYPE",
                caseData.courtType.label.toUpperCase(),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ─── 3. PARTY INTELLIGENCE ───────────────────
          PartyIntelligenceSection(caseData: caseData),

          const SizedBox(height: 10),

          // ─── 4. CLIENT INTELLIGENCE ──────────────────
          DossierSection(
            icon: Icons.person_search_rounded,
            title: "Client Intelligence",
            color: const Color(0xFF8B5CF6),
            children: [
              DossierHelper.dossierRow(
                "ENTITY NAME",
                caseData.clientName ?? "ANONYMOUS",
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ─── 5. ACTS & SECTIONS ──────────────────────
          ActsSection(caseId: widget.caseId),

          const SizedBox(height: 10),

          // ─── 6. IA STATUS ────────────────────────────
          IASection(caseId: widget.caseId),

          const SizedBox(height: 10),

          // ─── 7. CASE HISTORY ─────────────────────────
          CaseHistorySection(
            caseId: widget.caseId,
            caseTitle: caseData.caseTitle,
          ),

          const SizedBox(height: 10),

          // ─── 8. INTERIM ORDERS ───────────────────────
          InterimOrdersSection(caseId: widget.caseId),

          const SizedBox(height: 10),

          // ─── 9. QUICK STATS BAR ──────────────────────
          Row(
            children: [
              Expanded(
                child: DossierHelper.statMini(
                  "HEARINGS",
                  ref
                          .watch(caseHearingsProvider(widget.caseId))
                          .value
                          ?.length ??
                      0,
                  Icons.gavel_rounded,
                  AppTheme.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DossierHelper.statMini(
                  "RECORDS",
                  ref
                          .watch(caseDocumentsProvider(widget.caseId))
                          .value
                          ?.length ??
                      0,
                  Icons.folder_zip_rounded,
                  AppTheme.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DossierHelper.statMini(
                  "FINANCE",
                  ref
                          .watch(casePaymentsProvider(widget.caseId))
                          .value
                          ?.length ??
                      0,
                  Icons.account_balance_wallet_rounded,
                  AppTheme.success,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ─── 10. HUMAN CAPITAL ASSIGNMENT ────────────
          HumanCapitalSection(caseId: widget.caseId, caseData: caseData),
        ],
      ),
    );
  }
}
