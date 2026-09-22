import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../components/case_dossier_tab.dart';
import '../components/case_strategy_tab.dart';
import '../components/case_discussion_tab.dart';
import '../components/case_documents_tab.dart';
import '../components/case_payments_tab.dart';
import '../components/case_witnesses_tab.dart';
import 'evidence_lab_screen.dart';

import '../components/case_header.dart';
import '../components/pinned_header_delegate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
    // Five tabs: Evidence and Witnesses were removed from the case view.
    // Both features remain intact — the Evidence Lab is still reachable from
    // Tools, and no data or database table was touched.
    _tabController = TabController(length: 5, vsync: this);
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
          // One scroll for the whole dossier: the case header scrolls away and
          // the tab bar sticks to the top. Previously the header and tab bar
          // were fixed and each tab scrolled only in the space left below.
          return SafeArea(
            bottom: false,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: CaseHeader(
                    caseData: caseData,
                    onBack: () => Navigator.pop(context),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: PinnedHeaderDelegate(
                    height: 72.h,
                    backgroundColor: AppTheme.primaryLight,
                    child: Padding(
                      padding: EdgeInsets.only(top: 16.h, bottom: 12.h),
                      child: Row(
                        children: [
                          // With the header scrolled away its back button is
                          // gone too, so the pinned bar carries one — plus the
                          // case number, so it is clear which case this is.
                          if (innerBoxIsScrolled) ...[
                            IconButton(
                              tooltip: 'Back',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18.sp,
                                color: AppTheme.primary,
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 96.w),
                              child: Text(
                                caseData.caseNumber ?? caseData.caseTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                          Expanded(child: _buildTabBar()),
                          _buildOverflowMenu(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                  controller: _tabController,
                  children: [
                    CaseDossierTab(caseId: widget.id, caseData: caseData),
                    CaseStrategyTab(caseId: widget.id),
                    CaseDiscussionTab(
                      caseId: widget.id,
                      firmId: caseData.firmId ?? caseData.createdBy,
                    ),
                    CaseDocumentsTab(caseId: widget.id),
                    CasePaymentsTab(caseId: widget.id),
                  ],
                ),
            ),
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
      margin: EdgeInsets.only(left: 16.w),
      height: 44.h,
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          color: AppTheme.accent,
          borderRadius: BorderRadius.circular(8.r),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 11.sp,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11.sp,
        ),
        tabs: const [
          Tab(text: 'DOSSIER'),
          Tab(text: 'STRATEGY'),
          Tab(text: 'DISCUSSION'),
          Tab(text: 'DOCUMENTS'),
          Tab(text: 'PAYMENTS'),
        ],
      ),
    );
  }

  /// Evidence Lab and Witnesses moved off the tab bar to keep the case view
  /// focused, but both are per-case screens with no other entry point in the
  /// app — so they live here rather than being orphaned.
  Widget _buildOverflowMenu() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8.w),
      height: 44.h,
      width: 44.w,
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: PopupMenuButton<String>(
        icon: const Icon(
          Icons.more_vert_rounded,
          size: 20,
          color: Color(0xFF64748B),
        ),
        tooltip: 'More case tools',
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        onSelected: (value) {
          final page = value == 'evidence'
              ? EvidenceLabScreen(caseId: widget.id)
              : CaseWitnessesTab(caseId: widget.id);
          final title = value == 'evidence' ? 'Evidence Lab' : 'Witnesses';

          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                backgroundColor: AppTheme.primaryLight,
                appBar: AppBar(
                  title: Text(title),
                  backgroundColor: AppTheme.darkCard,
                  foregroundColor: const Color(0xFF1E293B),
                  elevation: 0,
                ),
                body: page,
              ),
            ),
          );
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'evidence',
            child: Row(
              children: [
                Icon(Icons.science_rounded, size: 18, color: Color(0xFF64748B)),
                SizedBox(width: 12),
                Text('Evidence Lab'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'witnesses',
            child: Row(
              children: [
                Icon(Icons.record_voice_over_rounded,
                    size: 18, color: Color(0xFF64748B)),
                SizedBox(width: 12),
                Text('Witnesses'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
