import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../components/hearing_notes_dialog.dart';
import 'evidence_lab_screen.dart';
import '../services/firm_service.dart';
import '../services/collaborator_service.dart';
import '../components/status_badge.dart';

import '../components/case_dossier_tab.dart';
import '../components/case_discussion_tab.dart';

class CaseDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const CaseDetailScreen({super.key, required this.id});

  @override
  ConsumerState<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends ConsumerState<CaseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caseAsync = ref.watch(caseDetailProvider(widget.id));

    return Scaffold(
      backgroundColor: AppTheme.primaryLight,
      body: caseAsync.when(
        data: (caseData) {
          if (caseData == null) return const Center(child: Text("Case not found."));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(caseData),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicator: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.black,
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                  tabs: const [
                    Tab(text: "DOSSIER"),
                    Tab(text: "DISCUSSION"),
                    Tab(text: "DOCUMENTS"),
                    Tab(text: "PAYMENTS"),
                    Tab(text: "EVIDENCE"),
                    Tab(text: "WITNESSES"),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    CaseDossierTab(caseId: widget.id, caseData: caseData),
                    CaseDiscussionTab(caseId: widget.id, firmId: caseData.firmId ?? caseData.createdBy),
                    _buildDocuments(widget.id),
                    _buildPayments(widget.id),
                    EvidenceLabScreen(caseId: widget.id),
                    const Center(child: Text("Witnesses Tab", style: TextStyle(color: Color(0xFF1E293B)))),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: Color(0xFF1E293B)))),
      ),
    );
  }

  // ─── HEADER ─────────────────────────────────────────
  Widget _buildHeader(CaseModel caseData) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "CASE FILE DOSSIER",
                        style: TextStyle(color: AppTheme.accent.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        caseData.caseTitle,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(status: caseData.status.name),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _headerChip(Icons.tag_rounded, caseData.caseNumber ?? 'NO IDENTIFIER'),
                _headerChip(Icons.account_balance_rounded, caseData.courtName ?? 'UNSPECIFIED FORUM'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String text) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppTheme.accent.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text.toUpperCase(), 
                style: const TextStyle(
                  color: Color(0xFF64748B), 
                  fontSize: 10, 
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(CaseModel caseData) {
    final fmt = DateFormat('dd MMM yyyy');
    final profile = ref.watch(userProfileProvider).value;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _infoCard("Operational Status", Icons.insights_rounded, [
            _infoRow("CASE CLASSIFICATION", caseData.caseType ?? "NOT DEFINED"),
            _infoRow("LEGAL STAGE", caseData.stage.name.toUpperCase()),
            _infoRow("DOCKET DATE", caseData.filingDate != null ? fmt.format(caseData.filingDate!) : "PENDING"),
            _infoRow("NEXT HEARING", caseData.nextHearingDate != null ? fmt.format(caseData.nextHearingDate!) : "NOT SCHEDULED"),
          ]),
          const SizedBox(height: 12),
          // Party Details Card (Our Role vs Opponent)
          _buildPartyDetailsCard(caseData),
          const SizedBox(height: 12),
          // Client Info Card
          _infoCard("Client Intelligence", Icons.person_search_rounded, [
            _infoRow("ENTITY NAME", caseData.clientName ?? "ANONYMOUS"),
          ]),
          const SizedBox(height: 12),
          // Quick Stats
          Row(
            children: [
              Expanded(child: _statMini("HEARINGS", ref.watch(caseHearingsProvider(widget.id)).value?.length ?? 0, Icons.gavel_rounded, AppTheme.accent)),
              const SizedBox(width: 8),
              Expanded(child: _statMini("RECORDS", ref.watch(caseDocumentsProvider(widget.id)).value?.length ?? 0, Icons.folder_zip_rounded, AppTheme.info)),
              const SizedBox(width: 8),
              Expanded(child: _statMini("FINANCE", ref.watch(casePaymentsProvider(widget.id)).value?.length ?? 0, Icons.account_balance_wallet_rounded, AppTheme.success)),
            ],
          ),
          const SizedBox(height: 12),
          // Team Assignment
          _infoCard("Human Capital Assignment", Icons.hub_rounded, [
            _infoRow("SUPERVISING LAWYER", caseData.createdBy == caseData.firmId ? "SENIOR PARTNER" : "FIRM ARCHITECT"),
            _infoRow("ACTIVE ADVOCATE", caseData.assignedTo == null ? "CASE OWNER (YOU)" : "FIRM ASSOCIATE"),
            if ((profile?.isFirmOwner ?? false) && (profile?.id == caseData.firmId || profile?.id == caseData.createdBy))
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showReassignDialog(caseData), 
                    icon: const Icon(Icons.sync_alt_rounded, size: 16),
                    label: const Text("TRANSFER OWNERSHIP", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.3)),
                      foregroundColor: AppTheme.accent,
                    ),
                  ),
                ),
              ),
            if ((profile?.isFirmOwner ?? false) && (profile?.id == caseData.firmId || profile?.id == caseData.createdBy))
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 0),
                child: TextButton.icon(
                  onPressed: () => _showShareDialog(caseData), 
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text("SHARE WITH COLLEAGUE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildCollaboratorsList(caseData),
            ]),
          ],
        ),
      );
    }

    Widget _buildPartyDetailsCard(CaseModel caseData) {
    final isCriminal = (caseData.caseType ?? '').toLowerCase().contains('criminal');
    final partyALabel = isCriminal ? 'PETITIONER' : 'PLAINTIFF';
    final partyBLabel = isCriminal ? 'ACCUSED' : 'DEFENDANT';
    final isRepresentingPetitioner = caseData.representationType == RepresentationType.petitioner;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.architecture_rounded, size: 20, color: AppTheme.accent),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Party Intelligence",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -0.5),
                ),
              ),
              IconButton(
                onPressed: () => _showEditPartyDetailsSheet(caseData),
                icon: const Icon(Icons.settings_input_component_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF64748B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _partyColumn(
                partyALabel,
                isRepresentingPetitioner ? (caseData.clientName ?? 'Unknown') : (caseData.opposingParty ?? 'Not Set'),
                isRepresentingPetitioner,
                const Color(0xFF2563EB),
                subtitle: isRepresentingPetitioner ? 'Your Client' : 'Opposing Side',
              ),
              const SizedBox(width: 2),
              _partyColumn(
                partyBLabel,
                isRepresentingPetitioner ? (caseData.opposingParty ?? 'Not Set') : (caseData.clientName ?? 'Unknown'),
                !isRepresentingPetitioner,
                const Color(0xFFDC2626),
                subtitle: !isRepresentingPetitioner ? 'Your Client' : 'Opposing Side',
              ),
            ],
          ),
          const Divider(height: 48, color: Color(0xFFE2E8F0)),
          // ─── COUNSEL DETAILS ───
          _counselRow(
            label: isRepresentingPetitioner ? "PLAINTIFF ADVOCATE" : "DEFENDANT ADVOCATE",
            name: caseData.petitionerAdvocate,
            phone: caseData.petitionerAdvocatePhone,
            icon: Icons.gavel_rounded,
            color: isRepresentingPetitioner ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
          ),
          const SizedBox(height: 16),
          _counselRow(
            label: isRepresentingPetitioner ? "DEFENDANT ADVOCATE" : "PLAINTIFF ADVOCATE",
            name: caseData.opposingAdvocate,
            phone: caseData.opposingAdvocatePhone,
            icon: Icons.security_rounded,
            color: isRepresentingPetitioner ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }

  Widget _counselRow({
    required String label,
    required String? name,
    required String? phone,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              Text(
                name?.isNotEmpty == true ? name! : "NOT SET",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), letterSpacing: -0.5),
              ),
            ],
          ),
        ),
        if (phone?.isNotEmpty ?? false)
          IconButton(
            onPressed: () => launchUrl(Uri.parse("tel:$phone")),
            icon: const Icon(Icons.call_made_rounded, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ],
    );
  }

  void _showEditPartyDetailsSheet(CaseModel caseData) {
    final isCriminal = (caseData.caseType ?? '').toLowerCase().contains('criminal');
    String caseCategory = isCriminal ? 'Criminal' : 'Civil';
    CourtType selectedCourt = caseData.courtType;
    RepresentationType selectedRole = caseData.representationType;

    // Petitioner / Plaintiff controllers
    final petitionerNameCtrl = TextEditingController(text: caseData.clientName ?? '');
    final petitionerAdvCtrl = TextEditingController(text: caseData.petitionerAdvocate ?? '');
    final petitionerPhoneCtrl = TextEditingController(text: caseData.petitionerAdvocatePhone ?? '');

    // Opposing party controllers
    final opposingPartyCtrl = TextEditingController(text: caseData.opposingParty ?? '');
    final opposingAdvCtrl = TextEditingController(text: caseData.opposingAdvocate ?? '');
    final opposingPhoneCtrl = TextEditingController(text: caseData.opposingAdvocatePhone ?? '');

    String partyALabel() {
      if (caseCategory == 'Criminal') return 'Petitioner / Complainant';
      return selectedCourt == CourtType.trial ? 'Plaintiff' : 'Petitioner';
    }

    String partyBLabel() {
      if (caseCategory == 'Criminal') return 'Accused / Respondent';
      return selectedCourt == CourtType.trial ? 'Defendant' : 'Respondent';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              left: 24, right: 24, top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Edit Party Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Playfair Display')),
                  const SizedBox(height: 4),
                  Text("Update both party & advocate details", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 24),

                  // Case Category
                  const Text("CASE CATEGORY", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Civil', label: Text('Civil', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'Criminal', label: Text('Criminal', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {caseCategory},
                    onSelectionChanged: (val) => setSheetState(() => caseCategory = val.first),
                  ),
                  const SizedBox(height: 20),

                  // Court Type
                  const Text("COURT TYPE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  SegmentedButton<CourtType>(
                    segments: CourtType.values.map((t) => ButtonSegment(
                      value: t,
                      label: Text(t.label, style: const TextStyle(fontSize: 12)),
                    )).toList(),
                    selected: {selectedCourt},
                    onSelectionChanged: (val) => setSheetState(() => selectedCourt = val.first),
                  ),
                  const SizedBox(height: 24),

                  // Representation Role
                  const Text("WHO ARE YOU REPRESENTING?", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  SegmentedButton<RepresentationType>(
                    segments: [
                      ButtonSegment(value: RepresentationType.petitioner, label: Text(partyALabel(), style: const TextStyle(fontSize: 12))),
                      ButtonSegment(value: RepresentationType.respondent, label: Text(partyBLabel(), style: const TextStyle(fontSize: 12))),
                    ],
                    selected: {selectedRole},
                    onSelectionChanged: (val) => setSheetState(() => selectedRole = val.first),
                  ),
                  const SizedBox(height: 24),

                  // ─── PETITIONER / PLAINTIFF SECTION ───
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${partyALabel()} Details', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF2563EB))),
                            Text(selectedRole == RepresentationType.petitioner ? 'Your Client' : 'Opposing Side', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: petitionerNameCtrl,
                    decoration: InputDecoration(
                      labelText: '${partyALabel()} Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: petitionerAdvCtrl,
                    decoration: InputDecoration(
                      labelText: '${partyALabel()} Advocate Name',
                      prefixIcon: const Icon(Icons.gavel_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: petitionerPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: '${partyALabel()} Advocate Phone',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── DEFENDANT / ACCUSED SECTION ───
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person_off_rounded, color: Color(0xFFDC2626), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${partyBLabel()} Details', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFDC2626))),
                            Text(selectedRole == RepresentationType.respondent ? 'Your Client' : 'Opposing Side', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: opposingPartyCtrl,
                    decoration: InputDecoration(
                      labelText: '${partyBLabel()} Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: opposingAdvCtrl,
                    decoration: InputDecoration(
                      labelText: '${partyBLabel()} Advocate Name',
                      prefixIcon: const Icon(Icons.gavel_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: opposingPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: '${partyBLabel()} Advocate Phone',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await SupabaseService.updateCase(caseData.id, {
                            'case_type': caseCategory,
                            'court_type': selectedCourt.name,
                            'representation_type': selectedRole.name,
                            'petitioner_advocate': petitionerAdvCtrl.text,
                            'petitioner_advocate_phone': petitionerPhoneCtrl.text,
                            'opposing_party': opposingPartyCtrl.text,
                            'opposing_advocate': opposingAdvCtrl.text,
                            'opposing_advocate_phone': opposingPhoneCtrl.text,
                          });

                          // Update Client Name
                          await SupabaseService.client
                              .from('clients')
                              .update({'name': petitionerNameCtrl.text})
                              .eq('id', caseData.clientId);

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text("Case details updated successfully")),
                            );
                            // Refresh the case data
                            ref.invalidate(caseDetailProvider(widget.id));
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text("Save Party Details"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _partyColumn(String label, String name, bool isHighlight, Color color, {String? subtitle}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.5),
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollaboratorsList(CaseModel caseData) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAllCollaborators(caseData),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        
        final collabs = snapshot.data!;
        // Separate firm colleagues and external collaborators
        final colleagues = collabs.where((c) => c['type'] == 'colleague').toList();
        final externals = collabs.where((c) => c['type'] == 'external').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            if (colleagues.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text("FIRM COLLEAGUES", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Color(0xFF64748B))),
              ),
              ...colleagues.map((c) => _buildCollaboratorTile(c)),
            ],
            if (externals.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text("EXTERNAL COLLABORATORS", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Color(0xFF64748B))),
              ),
              ...externals.map((c) => _buildCollaboratorTile(c)),
            ],
          ],
        );
      },
    );
  }

  /// Fetches both firm colleagues and external collaborators for this case
  Future<List<Map<String, dynamic>>> _fetchAllCollaborators(CaseModel caseData) async {
    final List<Map<String, dynamic>> result = [];

    // 1. Fetch external collaborators (from case_collaborations table)
    final externals = await CollaboratorService.fetchCaseCollaborators(caseData.id);
    for (final c in externals) {
      result.add({
        ...c,
        'type': 'external',
        'display_name': c['collaborator_email'] ?? 'Unknown',
      });
    }

    // 2. Fetch firm colleagues who have access (from firm_members table)
    try {
      if (caseData.firmId != null && caseData.firmId!.isNotEmpty) {
        final firmMembers = await FirmService.fetchFirmMembers();
        for (final member in firmMembers) {
          // Don't duplicate if already in external list
          final alreadyListed = externals.any((e) => 
            e['collaborator_email'] == member.memberEmail ||
            e['collaborator_id'] == member.memberId
          );
          if (!alreadyListed && member.memberId != caseData.createdBy) {
            result.add({
              'id': member.memberId,
              'collaborator_email': member.memberEmail,
              'status': member.status,
              'type': 'colleague',
              'display_name': member.memberName ?? member.memberEmail,
            });
          }
        }
      }
    } catch (_) {
      // Firm service may fail if user is not part of a firm — silently ignore
    }

    return result;
  }

  Widget _buildCollaboratorTile(Map<String, dynamic> c) {
    final email = c['collaborator_email'] ?? c['display_name'] ?? 'Unknown';
    final displayName = c['display_name'] ?? email;
    final status = c['status'] ?? 'pending';
    final isColleague = c['type'] == 'colleague';
    final statusColor = status == 'accepted' ? AppTheme.success : AppTheme.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(
            isColleague 
                ? Icons.people_alt_rounded 
                : (status == 'accepted' ? Icons.check_circle_rounded : Icons.pending_rounded),
            size: 14,
            color: isColleague ? AppTheme.accentViolet : statusColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName, 
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                ),
                if (displayName != email)
                  Text(
                    email,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isColleague ? AppTheme.accentViolet : statusColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isColleague ? 'COLLEAGUE' : status.toString().toUpperCase(), 
              style: TextStyle(
                fontSize: 9, 
                fontWeight: FontWeight.w900, 
                color: isColleague ? AppTheme.accentViolet : statusColor,
              ),
            ),
          ),
          if (!isColleague) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
              onPressed: () => _revokeCollaboration(c['id'], email),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "Revoke Access",
            ),
          ],
        ],
      ),
    );
  }

  void _revokeCollaboration(String id, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Revoke Access?"),
        content: Text("Are you sure you want to remove $email from this case? They will no longer be able to see it."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text("REVOKE"),
          ),
        ],
      )
    );

    if (confirmed == true) {
      try {
        await CollaboratorService.deleteCollaboration(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Access revoked for $email")));
          setState(() {}); // Refresh the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  void _showShareDialog(CaseModel caseData) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryLight,
        title: Text("Share with Colleague", style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Invite a colleague outside your firm to collaborate on this specific case. They must accept the invitation to see it.",
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "Colleague's Email",
                hintText: "advocate@example.com",
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.accent, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains('@')) return;
              
              try {
                await CollaboratorService.inviteCollaborator(caseData.id, email);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Invitation sent to $email"),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  setState(() {}); // Refresh list
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("SEND INVITATION", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Future<void> _showReassignDialog(CaseModel caseData) async {
    final members = await FirmService.fetchFirmMembers();
    final acceptedMembers = members.where((m) => m.status == 'accepted').toList();
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Reassign Case", style: TextStyle(fontFamily: 'Playfair Display')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...acceptedMembers.map((m) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person, size: 16)),
                title: Text(m.memberName ?? m.memberEmail),
                onTap: () async {
                  await FirmService.assignCase(caseData.id, m.memberId);
                  ref.invalidate(caseDetailProvider(caseData.id));
                  if (context.mounted) Navigator.pop(context);
                },
              )),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.grey, child: Icon(Icons.person, size: 16, color: Colors.white)),
                title: const Text("Assign to Myself"),
                onTap: () async {
                  await FirmService.assignCase(caseData.id, null);
                  ref.invalidate(caseDetailProvider(caseData.id));
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _infoCard(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 12),
              Text(
                title.toUpperCase(), 
                style: const TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.w900, 
                  color: Color(0xFF64748B),
                  letterSpacing: 1,
                )
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600)),
          Text(
            value, 
            style: const TextStyle(
              fontWeight: FontWeight.w900, 
              fontSize: 13,
              color: Color(0xFF1E293B),
              letterSpacing: -0.3,
            )
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
          Text(
            "$count", 
            style: const TextStyle(
              fontSize: 24, 
              fontWeight: FontWeight.w900, 
              color: Color(0xFF1E293B),
              letterSpacing: -1
            )
          ),
          Text(
            label, 
            style: TextStyle(
              fontSize: 9, 
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            )
          ),
        ],
      ),
    );
  }

  // ─── DOCUMENTS TAB ──────────────────────────────────
  Widget _buildDocuments(String caseId) {
    return Consumer(
      builder: (context, ref, _) {
        final docsAsync = ref.watch(caseDocumentsProvider(caseId));
        return Stack(
          children: [
            docsAsync.when(
              data: (docs) => docs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_shared_rounded, size: 48, color: const Color(0xFFE2E8F0)),
                          const SizedBox(height: 24),
                          Text(
                            "RECORDS VAULT EMPTY",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 2),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final name = doc['name'] as String? ?? 'Unknown';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.darkBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(_docIcon(name), color: const Color(0xFF94A3B8), size: 20),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name, 
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 14,
                                        color: Color(0xFF1E293B)
                                      ), 
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "SECURE VAULT", 
                                      style: TextStyle(
                                        color: const Color(0xFF94A3B8), 
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5
                                      )
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.download_rounded, color: AppTheme.accent, size: 22),
                                tooltip: "Download",
                                onPressed: () async {
                                  final url = doc['url'] as String?;
                                  if (url != null) {
                                    final uri = Uri.parse(url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_sweep_rounded, color: AppTheme.error.withValues(alpha: 0.7), size: 22),
                                tooltip: "Delete",
                                onPressed: () => _deleteDocument(caseId, name),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
              error: (e, s) => Center(child: Text("Error: $e", style: const TextStyle(color: Color(0xFF1E293B)))),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: FloatingActionButton(
                heroTag: "upload_doc",
                onPressed: () => _uploadDocument(caseId),
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                elevation: 8,
                child: const Icon(Icons.add_rounded, size: 30),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _docIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['jpg', 'jpeg', 'png'].contains(ext)) return Icons.image;
    if (['doc', 'docx'].contains(ext)) return Icons.description;
    return Icons.insert_drive_file;
  }



  Future<void> _uploadDocument(String caseId) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    try {
      await SupabaseService.uploadDocument(caseId, file.bytes!, file.name);
      ref.invalidate(caseDocumentsProvider(caseId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("\"${file.name}\" uploaded successfully")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
      }
    }
  }

  Future<void> _deleteDocument(String caseId, String fileName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Document?"),
        content: Text("Are you sure you want to delete \"$fileName\"?"),
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
      await SupabaseService.deleteDocument(caseId, fileName);
      ref.invalidate(caseDocumentsProvider(caseId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("\"$fileName\" deleted")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
      }
    }
  }

  // ─── HEARINGS TAB ───────────────────────────────────
  Widget _buildHearings(AsyncValue<List<Hearing>> hearingsAsync, String caseId, String title) {
    return Stack(
      children: [
        hearingsAsync.when(
          data: (hearings) => hearings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.gavel_rounded, size: 54, color: const Color(0xFFCBD5E1)),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "No Scheduled Hearings", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Track court dates and hearing notes", 
                        style: TextStyle(color: const Color(0xFF64748B), fontSize: 13)
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: hearings.length,
                  itemBuilder: (context, index) {
                    final h = hearings[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.calendar_month_rounded, size: 24, color: AppTheme.accent),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('dd MMM yyyy').format(h.hearingDate).toUpperCase(), 
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B), letterSpacing: 0.5)
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (h.purpose ?? h.stage ?? "STANDARD HEARING").toUpperCase(), 
                                  style: TextStyle(
                                    color: AppTheme.accent.withValues(alpha: 0.7), 
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1
                                  )
                                ),
                                if (h.notes?.isNotEmpty ?? false) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.sticky_note_2_rounded, size: 14, color: AppTheme.accent.withValues(alpha: 0.6)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            h.notes!,
                                            style: TextStyle(fontSize: 11, color: const Color(0xFF64748B)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusBadge(status: h.status),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (_) => HearingNotesDialog(
                                      hearingId: h.id,
                                      caseTitle: title,
                                      hearingDate: h.hearingDate,
                                      existingNotes: h.notes,
                                      onSaved: () => ref.invalidate(caseHearingsProvider(caseId)),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.edit_note_rounded, size: 20, color: const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
          error: (err, stack) => Center(child: Text("Error: $err", style: const TextStyle(color: Color(0xFF1E293B)))),
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            heroTag: "add_hearing",
            onPressed: () => _showAddHearingDialog(caseId),
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.black,
            child: const Icon(Icons.add_rounded, size: 30),
          ),
        ),
      ],
    );
  }

  void _showAddHearingDialog(String caseId) {
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
                      'case_id': caseId,
                      'hearing_date': selectedDate.toIso8601String(),
                      'purpose': purpose.isNotEmpty ? purpose : null,
                      'status': 'scheduled',
                    });
                    

                    
                    ref.invalidate(caseHearingsProvider(caseId));
                    ref.invalidate(hearingsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hearing scheduled!")));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
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


  // ─── PAYMENTS TAB ───────────────────────────────────
  Widget _buildPayments(String caseId) {
    return Consumer(
      builder: (context, ref, _) {
        final paymentsAsync = ref.watch(casePaymentsProvider(caseId));
        return Stack(
          children: [
            paymentsAsync.when(
              data: (payments) => payments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.account_balance_wallet_rounded, size: 54, color: const Color(0xFFCBD5E1)),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "No Payment Records", 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Financial tracking and billing history", 
                            style: TextStyle(color: const Color(0xFF64748B), fontSize: 13)
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: payments.length,
                      itemBuilder: (context, index) {
                        final p = payments[index];
                        final cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.receipt_long_rounded, size: 24, color: AppTheme.success),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Paid: ${cur.format(p.paidAmount)}", 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Balance: ${cur.format(p.balanceAmount)}", 
                                      style: TextStyle(color: AppTheme.error.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold)
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                p.paidDate != null ? DateFormat('dd MMM').format(p.paidDate!) : "—",
                                style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
              error: (e, s) => Center(child: Text("Error: $e", style: const TextStyle(color: Color(0xFF1E293B)))),
            ),
            Positioned(
              bottom: 24,
              right: 24,
              child: FloatingActionButton(
                heroTag: "add_payment",
                onPressed: () => _showAddPaymentDialog(caseId),
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                child: const Icon(Icons.add_rounded, size: 30),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddPaymentDialog(String caseId) {
    double totalFee = 0, paidAmount = 0;
    String mode = "Cash";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Log Payment"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: "Total Fee (₹)"),
                keyboardType: TextInputType.number,
                onChanged: (v) => totalFee = double.tryParse(v) ?? 0,
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(labelText: "Paid Amount (₹)"),
                keyboardType: TextInputType.number,
                onChanged: (v) => paidAmount = double.tryParse(v) ?? 0,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: "Payment Mode"),
                items: ["Cash", "UPI", "Bank Transfer", "Cheque"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => mode = v ?? "Cash",
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
                await SupabaseService.createPayment({
                  'case_id': caseId,
                  'total_fee': totalFee,
                  'paid_amount': paidAmount,
                  'balance_amount': totalFee - paidAmount,
                  'payment_mode': mode,
                  'paid_date': DateTime.now().toIso8601String(),
                });
                ref.invalidate(casePaymentsProvider(caseId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment logged!")));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
