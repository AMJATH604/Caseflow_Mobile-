import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';
import '../theme/cf_decorations.dart';
import '../components/cf_shimmer_loader.dart';
import '../components/case_dossier_tab.dart';
import '../components/case_strategy_tab.dart';
import '../components/case_discussion_tab.dart';
import '../components/case_documents_tab.dart';
import '../components/case_payments_tab.dart';
import '../components/case_witnesses_tab.dart';
import 'evidence_lab_screen.dart';
import '../components/case_header.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ══════════════════════════════════════════════════════════════
/// Case Detail Screen — Premium Tabbed Layout
///
/// Redesigned for Sprint 3 with:
/// - Semantic color tokens throughout
/// - Shimmer loading instead of spinner
/// - Premium pill-style tab bar
/// - Error state with retry
/// ══════════════════════════════════════════════════════════════

class CaseDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const CaseDetailScreen({super.key, required this.id});

  @override
  ConsumerState<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends ConsumerState<CaseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    _TabDef(icon: Icons.description_outlined, label: 'Dossier'),
    _TabDef(icon: Icons.psychology_outlined, label: 'Strategy'),
    _TabDef(icon: Icons.forum_outlined, label: 'Discussion'),
    _TabDef(icon: Icons.folder_outlined, label: 'Documents'),
    _TabDef(icon: Icons.payment_outlined, label: 'Payments'),
    _TabDef(icon: Icons.biotech_outlined, label: 'Evidence'),
    _TabDef(icon: Icons.people_outline, label: 'Witnesses'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caseAsync = ref.watch(caseDetailProvider(widget.id));
    final colors = CfColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: caseAsync.when(
        data: (caseData) {
          if (caseData == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_off_outlined, size: 48, color: colors.textTertiary),
                  const SizedBox(height: 12),
                  Text(
                    'Case not found',
                    style: CfTypography.headingMd.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CaseHeader(
                caseData: caseData,
                onBack: () => Navigator.pop(context),
              ),
              const SizedBox(height: 12),
              _buildTabBar(colors, isDark),
              Expanded(
                child: TabBarView(
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
                    EvidenceLabScreen(caseId: widget.id),
                    CaseWitnessesTab(caseId: widget.id),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => CfShimmerLoader.card(),
        error: (err, stack) => Center(
          child: Padding(
            padding: CfSpacing.pagePadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: CfColors.error),
                const SizedBox(height: 12),
                Text(
                  'Failed to load case',
                  style: CfTypography.headingMd.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '$err',
                  style: CfTypography.caption.copyWith(color: colors.textTertiary),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(caseDetailProvider(widget.id)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CfColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CfSpacing.radiusMd),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Premium Pill Tab Bar ──────────────────────────────
  Widget _buildTabBar(CfColorScheme colors, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: CfSpacing.borderRadiusMd,
        border: Border.all(color: colors.border, width: 1),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicator: BoxDecoration(
          color: CfColors.brand,
          borderRadius: BorderRadius.circular(CfSpacing.radiusSm),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: colors.textTertiary,
        labelStyle: CfTypography.labelMd.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: CfTypography.labelMd.copyWith(
          fontWeight: FontWeight.w600,
        ),
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.all(3),
        tabs: _tabs.map((t) => Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(t.icon, size: 14),
              const SizedBox(width: 4),
              Text(t.label.toUpperCase()),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _TabDef {
  final IconData icon;
  final String label;
  const _TabDef({required this.icon, required this.label});
}
