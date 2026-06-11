import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../components/case_dossier_tab.dart';
import '../components/case_discussion_tab.dart';
import '../components/case_documents_tab.dart';
import '../components/case_payments_tab.dart';
import '../components/case_witnesses_tab.dart';
import 'evidence_lab_screen.dart';

import '../components/case_header.dart';

class CaseDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const CaseDetailScreen({super.key, required this.id});

  @override
  ConsumerState<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends ConsumerState<CaseDetailScreen>
    with SingleTickerProviderStateMixin {
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
          if (caseData == null) {
            return const Center(child: Text('Case not found.'));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CaseHeader(
                caseData: caseData,
                onBack: () => Navigator.pop(context),
              ),
              const SizedBox(height: 16),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    CaseDossierTab(caseId: widget.id, caseData: caseData),
                    CaseDiscussionTab(
                      caseId: widget.id,
                      firmId: caseData.firmId ?? caseData.createdBy,
                    ),
                    CaseDocumentsTab(caseId: widget.id),
                    CasePaymentsTab(caseId: widget.id),
                    EvidenceLabScreen(caseId: widget.id),
                    CaseWitnessesTab(caseId: widget.id),
                  ],
                ),
              ),
            ],
          );
        },
        loading:
            () => const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
        error:
            (err, stack) => Center(
              child: Text(
                'Error: $err',
                style: const TextStyle(color: Color(0xFF1E293B)),
              ),
            ),
      ),
    );
  }

  // ─── TAB BAR ─────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
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
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        tabs: const [
          Tab(text: 'DOSSIER'),
          Tab(text: 'DISCUSSION'),
          Tab(text: 'DOCUMENTS'),
          Tab(text: 'PAYMENTS'),
          Tab(text: 'EVIDENCE'),
          Tab(text: 'WITNESSES'),
        ],
      ),
    );
  }
}
