import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../models/case_dossier_models.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../services/firm_service.dart';
import '../services/collaborator_service.dart';
import '../theme/app_theme.dart';
import '../components/hearing_notes_dialog.dart';
import '../components/status_badge.dart';


/// eCourt-style unified Case File Dossier tab.
/// Shows all case intelligence in collapsible sections on a single scrollable page.
class CaseDossierTab extends ConsumerStatefulWidget {
  final String caseId;
  final CaseModel caseData;

  const CaseDossierTab({super.key, required this.caseId, required this.caseData});

  @override
  ConsumerState<CaseDossierTab> createState() => _CaseDossierTabState();
}

class _CaseDossierTabState extends ConsumerState<CaseDossierTab> {
  final fmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
  }


  void _addCnrNumber() async {
    final controller = TextEditingController(text: widget.caseData.cnrNumber);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter CNR Number", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: "CNR Number",
                hintText: "e.g. MHPU010012342023",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              try {
                await SupabaseService.updateCaseCnr(widget.caseId, controller.text.trim());
                ref.invalidate(caseDetailProvider(widget.caseId));
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update CNR")));
                }
              }
            },
            child: const Text("LINK CNR"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hearingsAsync = ref.watch(caseHearingsProvider(widget.caseId));
    final actsAsync = ref.watch(caseActsProvider(widget.caseId));
    final iaAsync = ref.watch(caseIAProvider(widget.caseId));
    final ordersAsync = ref.watch(caseInterimOrdersProvider(widget.caseId));
    final profile = ref.watch(userProfileProvider).value;
    final caseData = widget.caseData;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        children: [

          // ─── 1. CASE DETAILS ─────────────────────────
          _DossierSection(
            icon: Icons.description_rounded,
            title: "Case Details",
            color: const Color(0xFF6C63FF),
            initiallyExpanded: true,
            children: [
              _dossierRow("CASE TYPE", caseData.caseType ?? "NOT DEFINED"),
              _dossierRow("CASE NUMBER", caseData.caseNumber ?? "NOT ASSIGNED"),
              _dossierRow("FILING DATE", caseData.filingDate != null ? fmt.format(caseData.filingDate!) : "PENDING"),
              _dossierRow("CNR NUMBER", caseData.cnrNumber ?? "NOT AVAILABLE"),
              _dossierRow("COURT", caseData.courtName ?? "UNSPECIFIED FORUM"),
              _dossierRow("STATE / DISTRICT", "${caseData.state ?? '—'} / ${caseData.district ?? '—'}"),
            ],
          ),

          const SizedBox(height: 10),

          // ─── 2. OPERATIONAL STATUS ───────────────────
          _DossierSection(
            icon: Icons.insights_rounded,
            title: "Case Status",
            color: const Color(0xFF3B82F6),
            badgeText: caseData.status.label.toUpperCase(),
            badgeColor: caseData.status == CaseStatus.active
                ? AppTheme.success
                : caseData.status == CaseStatus.disposed
                    ? AppTheme.error
                    : AppTheme.warning,
            initiallyExpanded: true,
            children: [
              _dossierRow("FIRST HEARING", caseData.filingDate != null ? fmt.format(caseData.filingDate!) : "—"),
              _dossierRow("NEXT HEARING", caseData.nextHearingDate != null ? fmt.format(caseData.nextHearingDate!) : "NOT SCHEDULED"),
              _dossierRow("CASE STAGE", caseData.stage.label.toUpperCase()),
              _dossierRow("COURT TYPE", caseData.courtType.label.toUpperCase()),
            ],
          ),

          const SizedBox(height: 10),

          // ─── 3. PARTY INTELLIGENCE ───────────────────
          _buildPartySection(caseData),

          const SizedBox(height: 10),

          // ─── 4. CLIENT INTELLIGENCE ──────────────────
          _DossierSection(
            icon: Icons.person_search_rounded,
            title: "Client Intelligence",
            color: const Color(0xFF8B5CF6),
            children: [
              _dossierRow("ENTITY NAME", caseData.clientName ?? "ANONYMOUS"),
            ],
          ),

          const SizedBox(height: 10),

          // ─── 5. ACTS & SECTIONS ──────────────────────
          _buildActsSection(actsAsync),

          const SizedBox(height: 10),

          // ─── 6. IA STATUS ────────────────────────────
          _buildIASection(iaAsync),

          const SizedBox(height: 10),

          // ─── 7. CASE HISTORY ─────────────────────────
          _buildCaseHistorySection(hearingsAsync),

          const SizedBox(height: 10),


          // ─── 8. INTERIM ORDERS ───────────────────────
          _buildInterimOrdersSection(ordersAsync),

          const SizedBox(height: 10),

          // ─── 9. QUICK STATS BAR ──────────────────────
          Row(
            children: [
              Expanded(child: _statMini("HEARINGS", ref.watch(caseHearingsProvider(widget.caseId)).value?.length ?? 0, Icons.gavel_rounded, AppTheme.accent)),
              const SizedBox(width: 8),
              Expanded(child: _statMini("RECORDS", ref.watch(caseDocumentsProvider(widget.caseId)).value?.length ?? 0, Icons.folder_zip_rounded, AppTheme.info)),
              const SizedBox(width: 8),
              Expanded(child: _statMini("FINANCE", ref.watch(casePaymentsProvider(widget.caseId)).value?.length ?? 0, Icons.account_balance_wallet_rounded, AppTheme.success)),
            ],
          ),

          const SizedBox(height: 10),

          // ─── 10. HUMAN CAPITAL ASSIGNMENT ────────────
          _DossierSection(
            icon: Icons.hub_rounded,
            title: "Human Capital Assignment",
            color: const Color(0xFF64748B),
            children: [
              _dossierRow("SUPERVISING LAWYER", caseData.createdBy == caseData.firmId ? "SENIOR PARTNER" : "FIRM ARCHITECT"),
              _dossierRow("ACTIVE ADVOCATE", caseData.assignedTo == null ? "CASE OWNER (YOU)" : "FIRM ASSOCIATE"),
              if ((profile?.isFirmOwner ?? false) && (profile?.id == caseData.firmId || profile?.id == caseData.createdBy)) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showReassignDialog(caseData),
                    icon: const Icon(Icons.sync_alt_rounded, size: 16),
                    label: const Text("TRANSFER OWNERSHIP", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.3)),
                      foregroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => _showShareDialog(),
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text("SHARE WITH COLLEAGUE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accent,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _buildCollaboratorsList(),
            ],
          ),
        ],
      ),
    );
  }


  Widget _dossierRowMini(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
          ),
        ],
      ),
    );
  }

  // ─── PARTY INTELLIGENCE SECTION ──────────────────────
  Widget _buildPartySection(CaseModel caseData) {
    final isCriminal = (caseData.caseType ?? '').toLowerCase().contains('criminal');
    final partyALabel = isCriminal ? 'PETITIONER' : 'PLAINTIFF';
    final partyBLabel = isCriminal ? 'ACCUSED' : 'DEFENDANT';
    final isRepPet = caseData.representationType == RepresentationType.petitioner;

    return _DossierSection(
      icon: Icons.architecture_rounded,
      title: "Party Intelligence",
      color: const Color(0xFF2563EB),
      initiallyExpanded: true,
      children: [
        // Party A
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(partyALabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(
                      isRepPet ? (caseData.clientName ?? 'Unknown') : (caseData.opposingParty ?? 'Not Set'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    if (caseData.petitionerAdvocate?.isNotEmpty == true)
                      Text("Adv. ${caseData.petitionerAdvocate}", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isRepPet ? "YOUR CLIENT" : "OPPOSING",
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF2563EB), letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Party B
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_off_rounded, size: 16, color: Color(0xFFDC2626)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(partyBLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(
                      isRepPet ? (caseData.opposingParty ?? 'Not Set') : (caseData.clientName ?? 'Unknown'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    ),
                    if (caseData.opposingAdvocate?.isNotEmpty == true)
                      Text("Adv. ${caseData.opposingAdvocate}", style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  !isRepPet ? "YOUR CLIENT" : "OPPOSING",
                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFDC2626), letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── ACTS & SECTIONS ────────────────────────────────
  Widget _buildActsSection(AsyncValue<List<CaseAct>> actsAsync) {
    return _DossierSection(
      icon: Icons.gavel_rounded,
      title: "Statutory Acts",
      color: const Color(0xFF6366F1),
      initiallyExpanded: actsAsync.value?.isNotEmpty == true,
      trailing: _addButton(() => _showAddActDialog()),
      children: [
        actsAsync.when(
          data: (acts) => acts.isEmpty
              ? _emptyHint("No acts added yet. Tap + to add applicable acts.")
              : Column(
                  children: acts.map((act) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(act.actName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                              if (act.sectionNumber != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text("SECTION ${act.sectionNumber}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF6366F1), letterSpacing: 0.5)),
                                ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _deleteItem("act", act.id, () => ref.invalidate(caseActsProvider(widget.caseId))),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
          loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, _) => _emptyHint("Error loading acts"),
        ),
      ],
    );
  }


  // ─── IA STATUS ──────────────────────────────────────
  Widget _buildIASection(AsyncValue<List<CaseIAApplication>> iaAsync) {
    return _DossierSection(
      icon: Icons.layers_rounded,
      title: "IA Applications",
      color: const Color(0xFFF59E0B),
      initiallyExpanded: iaAsync.value?.isNotEmpty == true,
      trailing: _addButton(() => _showAddIADialog()),
      children: [
        iaAsync.when(
          data: (ias) => ias.isEmpty
              ? _emptyHint("No Interlocutory Applications. Tap + to add.")
              : Column(
                  children: ias.map((ia) {
                    final statusColor = ia.iaStatus == 'disposed'
                        ? const Color(0xFF10B981)
                        : ia.iaStatus == 'pending'
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF3B82F6);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ia.iaNumber, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                                const SizedBox(height: 2),
                                if (ia.party != null)
                                  Text(ia.party!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (ia.filingDate != null)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 12),
                                        child: Text("FILED: ${DateFormat('dd MMM').format(ia.filingDate!)}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8))),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                      child: Text(ia.iaStatus.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 0.5)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _deleteItem("IA", ia.id, () => ref.invalidate(caseIAProvider(widget.caseId))),
                            child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFCBD5E1)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
          loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, _) => _emptyHint("Error loading IAs"),
        ),
      ],
    );
  }

  // ─── CASE HISTORY (merged Timeline + Hearings) ──────
  Widget _buildCaseHistorySection(AsyncValue<List<Hearing>> hearingsAsync) {
    return _DossierSection(
      icon: Icons.history_rounded,
      title: "Case History",
      color: const Color(0xFF3B82F6),
      trailing: _addButton(() => _showAddHearingDialog()),
      children: [
        hearingsAsync.when(
          data: (hearings) {
            if (hearings.isEmpty) return _emptyHint("No hearing records yet. Schedule your first hearing.");
            // Sort chronologically — oldest first
            final sorted = List<Hearing>.from(hearings)..sort((a, b) => a.hearingDate.compareTo(b.hearingDate));
            return _buildCaseHistoryTable(sorted);
          },
          loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, _) => _emptyHint("Error loading history"),
        ),
      ],
    );
  }

  Widget _buildCaseHistoryTable(List<Hearing> hearings) {
    final df = DateFormat('dd-MM-yyyy');
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text("HEARING DATE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 3, child: Text("PURPOSE OF HEARING", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("STATUS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5))),
                SizedBox(width: 30),
              ],
            ),
          ),
          ...hearings.map((h) {
            final isFuture = h.hearingDate.isAfter(DateTime.now());
            final isAdjourned = h.status.toLowerCase() == 'adjourned';
            final isCompleted = h.status.toLowerCase() == 'completed';
            final rowColor = isFuture
                ? const Color(0xFFFFF7ED)
                : isCompleted
                    ? const Color(0xFFF0FDF4)
                    : Colors.transparent;

            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => HearingNotesDialog(
                    hearingId: h.id,
                    caseTitle: widget.caseData.caseTitle,
                    hearingDate: h.hearingDate,
                    existingNotes: h.notes,
                    onSaved: () => ref.invalidate(caseHearingsProvider(widget.caseId)),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: rowColor,
                  border: Border(top: BorderSide(color: AppTheme.darkBorder)),
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
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isFuture ? const Color(0xFFD97706) : const Color(0xFF1E293B),
                            ),
                          ),
                          if (isFuture)
                            const Text("UPCOMING", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFF59E0B), letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.purpose ?? h.stage ?? "Standard Hearing",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (h.notes?.isNotEmpty == true)
                            Text(h.notes!, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: StatusBadge(status: h.status),
                    ),
                    const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── INTERIM ORDERS ─────────────────────────────────
  Widget _buildInterimOrdersSection(AsyncValue<List<CaseInterimOrder>> ordersAsync) {
    return _DossierSection(
      icon: Icons.receipt_long_rounded,
      title: "Interim Orders",
      color: const Color(0xFFDC2626),
      trailing: _addButton(() => _showAddInterimOrderDialog()),
      children: [
        ordersAsync.when(
          data: (orders) => orders.isEmpty
              ? _emptyHint("No interim orders recorded. Tap + to add depositions.")
              : _buildInterimOrdersTable(orders),
          loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, _) => _emptyHint("Error loading orders"),
        ),
      ],
    );
  }

  Widget _buildInterimOrdersTable(List<CaseInterimOrder> orders) {
    final df = DateFormat('dd-MM-yyyy');
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 1, child: Text("ORDER #", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text("ORDER DATE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5))),
                Expanded(flex: 3, child: Text("DETAILS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 0.5))),
                SizedBox(width: 24),
              ],
            ),
          ),
          ...orders.asMap().entries.map((entry) {
            final idx = entry.key;
            final order = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.darkBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text("${order.orderNumber ?? idx + 1}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(df.format(order.orderDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  ),
                  Expanded(
                    flex: 3,
                    child: order.documentUrl != null
                        ? GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(order.documentUrl!);
                              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                            },
                            child: Text(
                              order.orderSummary ?? "Copy Of ${order.orderType == 'deposition' ? 'Deposition' : 'Order'}",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669), decoration: TextDecoration.underline),
                            ),
                          )
                        : Text(
                            order.orderSummary ?? "Copy Of ${order.orderType == 'deposition' ? 'Deposition' : 'Order'}",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                  ),
                  GestureDetector(
                    onTap: () => _deleteItem("order", order.id, () => ref.invalidate(caseInterimOrdersProvider(widget.caseId))),
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── DIALOGS ────────────────────────────────────────

  void _showAddActDialog() {
    final actCtrl = TextEditingController();
    final sectionCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text("Add Applicable Act", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
            const SizedBox(height: 4),
            Text("e.g., Code of Civil Procedure — Or.7.R.1", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 20),
            TextField(
              controller: actCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "Act Name",
                hintText: "Code of Civil Procedure",
                prefixIcon: const Icon(Icons.menu_book_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sectionCtrl,
              decoration: InputDecoration(
                labelText: "Section / Order / Rule",
                hintText: "Or.7.R.1",
                prefixIcon: const Icon(Icons.tag_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (actCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await SupabaseService.createCaseAct({
                      'case_id': widget.caseId,
                      'act_name': actCtrl.text.trim(),
                      'section_number': sectionCtrl.text.trim().isNotEmpty ? sectionCtrl.text.trim() : null,
                    });
                    ref.invalidate(caseActsProvider(widget.caseId));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text("Add Act", style: TextStyle(fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddIADialog() {
    final iaNumberCtrl = TextEditingController();
    final partyCtrl = TextEditingController();
    final classCtrl = TextEditingController();
    DateTime? filingDate;
    String status = 'pending';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text("Add IA Application", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                const SizedBox(height: 20),
                TextField(
                  controller: iaNumberCtrl,
                  autofocus: true,
                  decoration: InputDecoration(labelText: "IA Number", hintText: "IA/1/2023", prefixIcon: const Icon(Icons.tag_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: partyCtrl,
                  decoration: InputDecoration(labelText: "Party Name", prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: classCtrl,
                  decoration: InputDecoration(labelText: "Classification", hintText: "Injunction / Stay", prefixIcon: const Icon(Icons.category_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Filing Date"),
                  subtitle: Text(filingDate != null ? DateFormat('dd MMM yyyy').format(filingDate!) : "Select date"),
                  trailing: const Icon(Icons.calendar_today, color: AppTheme.accent),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setSheetState(() => filingDate = d);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: InputDecoration(labelText: "Status", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: ['pending', 'disposed', 'allowed', 'dismissed'].map((s) => DropdownMenuItem(value: s, child: Text(s[0].toUpperCase() + s.substring(1)))).toList(),
                  onChanged: (v) => status = v ?? 'pending',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (iaNumberCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      try {
                        await SupabaseService.createCaseIA({
                          'case_id': widget.caseId,
                          'ia_number': iaNumberCtrl.text.trim(),
                          'party': partyCtrl.text.trim().isNotEmpty ? partyCtrl.text.trim() : null,
                          'classification': classCtrl.text.trim().isNotEmpty ? classCtrl.text.trim() : null,
                          'filing_date': filingDate?.toIso8601String().split('T')[0],
                          'ia_status': status,
                        });
                        ref.invalidate(caseIAProvider(widget.caseId));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("Add IA", style: TextStyle(fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddHearingDialog() {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    String purpose = "";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Schedule Hearing"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Hearing Date"),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                    trailing: const Icon(Icons.calendar_today, color: AppTheme.accent),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (date != null) setDialogState(() => selectedDate = date);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(labelText: "Purpose / Stage"),
                    onChanged: (v) => purpose = v,
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
                    await SupabaseService.createHearing({
                      'case_id': widget.caseId,
                      'hearing_date': selectedDate.toIso8601String(),
                      'purpose': purpose.isNotEmpty ? purpose : null,
                      'status': 'scheduled',
                    });
                    ref.invalidate(caseHearingsProvider(widget.caseId));
                    ref.invalidate(hearingsProvider);
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                },
                child: const Text("Schedule"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddInterimOrderDialog() {
    final summaryCtrl = TextEditingController();
    DateTime orderDate = DateTime.now();
    String orderType = 'deposition';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text("Add Interim Order", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Order Date"),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(orderDate)),
                  trailing: const Icon(Icons.calendar_today, color: AppTheme.accent),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: orderDate, firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setSheetState(() => orderDate = d);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: orderType,
                  decoration: InputDecoration(labelText: "Order Type", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: ['deposition', 'interim_order', 'stay_order'].map((s) {
                    final label = s.replaceAll('_', ' ');
                    return DropdownMenuItem(value: s, child: Text(label[0].toUpperCase() + label.substring(1)));
                  }).toList(),
                  onChanged: (v) => orderType = v ?? 'deposition',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: summaryCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(labelText: "Order Summary / Notes", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        // Get current order count for auto numbering
                        final existing = ref.read(caseInterimOrdersProvider(widget.caseId)).value ?? [];
                        await SupabaseService.createInterimOrder({
                          'case_id': widget.caseId,
                          'order_number': existing.length + 1,
                          'order_date': orderDate.toIso8601String().split('T')[0],
                          'order_type': orderType,
                          'order_summary': summaryCtrl.text.trim().isNotEmpty ? summaryCtrl.text.trim() : null,
                        });
                        ref.invalidate(caseInterimOrdersProvider(widget.caseId));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("Add Order", style: TextStyle(fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── HELPER METHODS ─────────────────────────────────

  void _deleteItem(String type, String id, VoidCallback onDone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete $type?"),
        content: Text("Are you sure you want to remove this $type entry?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      if (type == "act") await SupabaseService.deleteCaseAct(id);
      if (type == "IA") await SupabaseService.deleteCaseIA(id);
      if (type == "order") await SupabaseService.deleteInterimOrder(id);
      onDone();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _addButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.add_rounded, size: 18, color: AppTheme.accent),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: const Color(0xFFCBD5E1)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic))),
        ],
      ),
    );
  }

  Widget _dossierRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B), letterSpacing: -0.3),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statMini(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFCBD5E1), size: 16),
          const SizedBox(height: 12),
          Text("$count", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -1)),
          Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, letterSpacing: 1)),
        ],
      ),
    );
  }

  // ─── SHARING & REASSIGNMENT DIALOGS ─────────────────

  void _showShareDialog() {
    String email = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Share with Colleague"),
        content: TextField(
          decoration: const InputDecoration(labelText: "Colleague Email"),
          keyboardType: TextInputType.emailAddress,
          onChanged: (v) => email = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (email.isEmpty) return;
              Navigator.pop(context);
              try {
                await CollaboratorService.inviteCollaborator(widget.caseId, email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invitation sent!")));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("Send Invite"),
          ),
        ],
      ),
    );
  }

  void _showReassignDialog(CaseModel caseData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Transfer Ownership"),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<FirmMember>>(
            future: FirmService.fetchFirmMembers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("No firm members found to transfer to.");
              
              return ListView.builder(
                shrinkWrap: true,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final member = snapshot.data![index];
                  return ListTile(
                    title: Text(member.memberName ?? member.memberEmail),
                    subtitle: Text(member.memberEmail),
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await FirmService.assignCase(widget.caseId, member.memberId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Case reassigned!")));
                          // We might need to refresh the case info. 
                          // Since CaseDetailScreen watches caseDetailProvider, it should update.
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCollaboratorsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: CollaboratorService.fetchCaseCollaborators(widget.caseId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("COLLABORATORS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1)),
            const SizedBox(height: 8),
            ...snapshot.data!.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Text(c['profiles']?['full_name'] ?? c['collaborator_email'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: (c['status'] == 'accepted' ? Colors.green : Colors.orange).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(c['status'].toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: c['status'] == 'accepted' ? Colors.green : Colors.orange)),
                  ),
                ],
              ),
            )),
          ],
        );
      },
    );
  }

}

// ─── REUSABLE COLLAPSIBLE SECTION WIDGET ──────────────

class _DossierSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;
  final bool initiallyExpanded;
  final String? badgeText;
  final Color? badgeColor;
  final Widget? trailing;

  const _DossierSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
    this.initiallyExpanded = false,
    this.badgeText,
    this.badgeColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -0.3),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? color).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: badgeColor ?? color, letterSpacing: 0.5),
                  ),
                ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          children: children,
        ),
      ),
    );
  }
}

