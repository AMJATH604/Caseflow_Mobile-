import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/commission_models.dart';
import '../services/commission_service.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';
import '../theme/cf_decorations.dart';
import '../components/cf_shimmer_loader.dart';
import '../components/cf_empty_state.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

final commissionsProvider = FutureProvider<List<Commission>>((ref) async {
  ref.watch(authStateProvider);
  ref.watch(dataRefreshProvider);
  return CommissionService.fetchCommissions();
});

class CommissionsScreen extends ConsumerStatefulWidget {
  const CommissionsScreen({super.key});
  @override
  ConsumerState<CommissionsScreen> createState() => _CommissionsScreenState();
}

class _CommissionsScreenState extends ConsumerState<CommissionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final _filters = [
    'All',
    'Pending',
    'Active',
    'Done',
    'Drafting',
    'Submitted',
    'Closed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Commission> _filter(List<Commission> all, int tab) {
    final map = {
      1: CommissionStatus.pending,
      2: CommissionStatus.inProgress,
      3: CommissionStatus.visitCompleted,
      4: CommissionStatus.reportDrafting,
      5: CommissionStatus.submitted,
      6: CommissionStatus.closed,
    };
    var list = tab == 0 ? all : all.where((c) => c.status == map[tab]).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list =
          list
              .where(
                (c) =>
                    (c.caseTitle?.toLowerCase().contains(q) ?? false) ||
                    (c.caseNumberRef?.toLowerCase().contains(q) ?? false) ||
                    (c.surveyNumber?.toLowerCase().contains(q) ?? false) ||
                    (c.district?.toLowerCase().contains(q) ?? false),
              )
              .toList();
    }
    return list;
  }

  Color _statusColor(CommissionStatus s) => switch (s) {
    CommissionStatus.pending => CfColors.warning,
    CommissionStatus.inProgress => CfColors.info,
    CommissionStatus.visitCompleted => CfColors.success,
    CommissionStatus.reportDrafting => const Color(0xFF8B5CF6),
    CommissionStatus.submitted => CfColors.success,
    CommissionStatus.objections => CfColors.error,
    CommissionStatus.closed => const Color(0xFF64748B),
  };
  IconData _typeIcon(CommissionType t) => switch (t) {
    CommissionType.localInvestigation => Icons.search_rounded,
    CommissionType.partition => Icons.grid_view_rounded,
    CommissionType.survey => Icons.straighten_rounded,
    CommissionType.recordingEvidence => Icons.mic_rounded,
    CommissionType.sale => Icons.gavel_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(commissionsProvider);
    final dk = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(dk, data),
            SizedBox(height: 8.h),
            _search(dk),
            SizedBox(height: 4.h),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: (_) => setState(() {}),
              indicatorColor: CfColors.brand,
              labelColor: CfColors.brand,
              unselectedLabelColor: dk ? Colors.white38 : Colors.black38,
              labelStyle: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              tabs: _filters.map((f) => Tab(text: f)).toList(),
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: data.when(
                data:
                    (list) => AnimatedBuilder(
                      animation: _tabController,
                      builder: (c, _) {
                        final fl = _filter(list, _tabController.index);
                        if (fl.isEmpty) return _empty(dk);
                        return RefreshIndicator(
                          onRefresh:
                              () async => ref.invalidate(commissionsProvider),
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            itemCount: fl.length,
                            itemBuilder: (c, i) => _card(dk, fl[i]),
                          ),
                        );
                      },
                    ),
                loading: () => CfShimmerLoader.list(),
                error:
                    (e, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.error,
                            size: 48,
                          ),
                          SizedBox(height: 12.h),
                          const Text('Error loading commissions'),
                          TextButton(
                            onPressed:
                                () => ref.invalidate(commissionsProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Commission'),
        backgroundColor: CfColors.brand,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _header(bool dk, AsyncValue<List<Commission>> data) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    padding: EdgeInsets.all(20.r),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20.r),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: const Icon(
                Icons.assignment_ind_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Advocate Commissioner',
                    style: GoogleFonts.outfit(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Commission Management & Field Kit',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        data.when(
          data:
              (list) => Row(
                children: [
                  _stat('Total', '${list.length}', Colors.white),
                  SizedBox(width: 8.w),
                  _stat(
                    'Active',
                    '${list.where((c) => c.status == CommissionStatus.inProgress).length}',
                    const Color(0xFF34D399),
                  ),
                  SizedBox(width: 8.w),
                  _stat(
                    'Pending',
                    '${list.where((c) => c.status == CommissionStatus.pending).length}',
                    const Color(0xFFFBBF24),
                  ),
                  SizedBox(width: 8.w),
                  _stat(
                    'Overdue',
                    '${list.where((c) => c.isOverdue).length}',
                    const Color(0xFFF87171),
                  ),
                ],
              ),
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        ),
      ],
    ),
  );

  Widget _stat(String l, String v, Color c) => Container(
    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20.r),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          v,
          style: GoogleFonts.outfit(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: c,
          ),
        ),
        SizedBox(width: 4.w),
        Text(l, style: GoogleFonts.inter(fontSize: 10.sp, color: Colors.white70)),
      ],
    ),
  );

  Widget _search(bool dk) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16.w),
    child: TextField(
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Search commissions...',
        hintStyle: GoogleFonts.inter(
          fontSize: 13.sp,
          color: dk ? Colors.white38 : Colors.black38,
        ),
        prefixIcon: Icon(
          Icons.search,
          size: 20,
          color: dk ? Colors.white38 : Colors.black38,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor:
            dk
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    ),
  );

  Widget _card(bool dk, Commission c) {
    final sc = _statusColor(c.status);
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: dk ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color:
              c.isOverdue
                  ? AppTheme.error.withValues(alpha: 0.4)
                  : (dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight),
          width: c.isOverdue ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                c.isOverdue
                    ? AppTheme.error.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/commissions/${c.id}'),
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        _typeIcon(c.commissionType),
                        color: sc,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.commissionType.label,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 15.sp,
                              color:
                                  dk ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          if (c.caseTitle != null || c.caseNumberRef != null)
                            Text(
                              c.caseTitle ?? c.caseNumberRef ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 12.sp,
                                color: dk ? Colors.white54 : Colors.black45,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Deadline countdown badge (Phase 2)
                    if (c.daysRemaining != null) _deadlineBadge(c),
                    if (c.daysRemaining == null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: sc.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          c.status.label,
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: sc,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 12.h),
                if (c.locationSummary != 'No location specified')
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: dk ? Colors.white38 : Colors.black38,
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          c.locationSummary,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: dk ? Colors.white54 : Colors.black45,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (c.surveyNumber != null && c.surveyNumber!.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 14,
                        color: dk ? Colors.white38 : Colors.black38,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'S.No: ${c.surveyNumber}',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: dk ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 12.h),
                Row(
                  children: [
                    if (c.warrantDate != null) ...[
                      _dateChip('Warrant', c.warrantDate!, dk),
                      SizedBox(width: 8.w),
                    ],
                    if (c.deadlineDate != null)
                      _dateChip(
                        'Deadline',
                        c.deadlineDate!,
                        dk,
                        over: c.isOverdue,
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        c.status.label,
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: sc,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _deadlineBadge(Commission c) {
    final days = c.daysRemaining!;
    final isOverdue = c.isOverdue;
    Color bgColor;
    Color textColor;
    String text;

    if (isOverdue) {
      bgColor = AppTheme.error;
      textColor = Colors.white;
      text = 'OVERDUE';
    } else if (days <= 3) {
      bgColor = const Color(0xFFF97316);
      textColor = Colors.white;
      text = '${days}D LEFT';
    } else if (days <= 7) {
      bgColor = AppTheme.warning;
      textColor = const Color(0xFF1E293B);
      text = '${days}D LEFT';
    } else {
      bgColor = AppTheme.success;
      textColor = Colors.white;
      text = '${days}D';
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow:
            isOverdue
                ? [
                  BoxShadow(
                    color: AppTheme.error.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ]
                : null,
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _dateChip(String l, DateTime d, bool dk, {bool over = false}) =>
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color:
              over
                  ? AppTheme.error.withValues(alpha: 0.1)
                  : (dk
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          '$l: ${DateFormat('dd MMM').format(d)}',
          style: GoogleFonts.inter(
            fontSize: 10.sp,
            fontWeight: FontWeight.w500,
            color:
                over ? AppTheme.error : (dk ? Colors.white54 : Colors.black45),
          ),
        ),
      );

  Widget _empty(bool dk) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(24.r),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.assignment_ind_outlined,
            size: 48,
            color: AppTheme.accent.withValues(alpha: 0.5),
          ),
        ),
        SizedBox(height: 20.h),
        Text(
          'No Commissions Yet',
          style: GoogleFonts.outfit(
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            color: dk ? Colors.white70 : Colors.black54,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Tap + to create your first commission',
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            color: dk ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    ),
  );

  void _showCreate(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    CommissionType selType = CommissionType.localInvestigation;
    final caseNum = TextEditingController(),
        court = TextEditingController(),
        scope = TextEditingController(),
        prop = TextEditingController(),
        survey = TextEditingController(),
        village = TextEditingController(),
        taluk = TextEditingController(),
        district = TextEditingController(),
        pet = TextEditingController(),
        resp = TextEditingController();
    DateTime? wDate, dDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, ss) => Container(
                  height: MediaQuery.of(ctx).size.height * 0.9,
                  decoration: BoxDecoration(
                    color: dk ? const Color(0xFF1E1E2E) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24.r),
                      topRight: Radius.circular(24.r),
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: 12.h),
                      Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(20.r),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'New Commission',
                              style: GoogleFonts.outfit(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w700,
                                color:
                                    dk ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          children: [
                            Text(
                              'Commission Type',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: dk ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  CommissionType.values
                                      .map(
                                        (t) => ChoiceChip(
                                          label: Text(
                                            t.label,
                                            style: GoogleFonts.inter(
                                              fontSize: 12.sp,
                                            ),
                                          ),
                                          selected: selType == t,
                                          onSelected:
                                              (v) => ss(() => selType = t),
                                          selectedColor: AppTheme.accent
                                              .withValues(alpha: 0.15),
                                        ),
                                      )
                                      .toList(),
                            ),
                            SizedBox(height: 20.h),
                            _field('Case Number', caseNum, dk),
                            _field('Court Name', court, dk),
                            Row(
                              children: [
                                Expanded(
                                  child: _datePick(
                                    'Warrant Date',
                                    wDate,
                                    dk,
                                    (d) => ss(() => wDate = d),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: _datePick(
                                    'Deadline',
                                    dDate,
                                    dk,
                                    (d) => ss(() => dDate = d),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'Property Details',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: dk ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            _field('Description', prop, dk, ml: 2),
                            _field('Survey No.', survey, dk),
                            Row(
                              children: [
                                Expanded(child: _field('Village', village, dk)),
                                SizedBox(width: 12.w),
                                Expanded(child: _field('Taluk', taluk, dk)),
                              ],
                            ),
                            _field('District', district, dk),
                            SizedBox(height: 16.h),
                            Text(
                              'Parties',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: dk ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            _field('Petitioner', pet, dk),
                            _field('Respondent', resp, dk),
                            _field('Scope of Work', scope, dk, ml: 3),
                            SizedBox(height: 80.h),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(20.r),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: dk ? Colors.white10 : AppTheme.borderLight,
                            ),
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                await CommissionService.createCommission({
                                  'commission_type': selType.dbValue,
                                  'case_number_ref':
                                      caseNum.text.isNotEmpty
                                          ? caseNum.text
                                          : null,
                                  'court_name':
                                      court.text.isNotEmpty ? court.text : null,
                                  'warrant_date':
                                      wDate?.toIso8601String().split('T')[0],
                                  'deadline_date':
                                      dDate?.toIso8601String().split('T')[0],
                                  'scope_of_work':
                                      scope.text.isNotEmpty ? scope.text : null,
                                  'property_description':
                                      prop.text.isNotEmpty ? prop.text : null,
                                  'survey_number':
                                      survey.text.isNotEmpty
                                          ? survey.text
                                          : null,
                                  'village':
                                      village.text.isNotEmpty
                                          ? village.text
                                          : null,
                                  'taluk':
                                      taluk.text.isNotEmpty ? taluk.text : null,
                                  'district':
                                      district.text.isNotEmpty
                                          ? district.text
                                          : null,
                                  'party_petitioner':
                                      pet.text.isNotEmpty ? pet.text : null,
                                  'party_respondent':
                                      resp.text.isNotEmpty ? resp.text : null,
                                });
                                ref.invalidate(commissionsProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Commission created!',
                                      ),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: AppTheme.error,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                            ),
                            child: Text(
                              'Create Commission',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _field(String l, TextEditingController c, bool dk, {int ml = 1}) =>
      Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: TextField(
          controller: c,
          maxLines: ml,
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            color: dk ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            labelText: l,
            labelStyle: GoogleFonts.inter(
              fontSize: 13.sp,
              color: dk ? Colors.white38 : Colors.black38,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: dk ? Colors.white10 : AppTheme.borderLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: dk ? Colors.white10 : AppTheme.borderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: AppTheme.accent),
            ),
            filled: true,
            fillColor:
                dk
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.02),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      );

  Widget _datePick(String l, DateTime? d, bool dk, Function(DateTime) cb) =>
      Padding(
        padding: EdgeInsets.only(bottom: 12.h),
        child: InkWell(
          onTap: () async {
            final p = await showDatePicker(
              context: context,
              initialDate: d ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (p != null) cb(p);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l,
              labelStyle: GoogleFonts.inter(
                fontSize: 13.sp,
                color: dk ? Colors.white38 : Colors.black38,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: dk ? Colors.white10 : AppTheme.borderLight,
                ),
              ),
              filled: true,
              fillColor:
                  dk
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.02),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              suffixIcon: Icon(
                Icons.calendar_today,
                size: 16,
                color: dk ? Colors.white38 : Colors.black38,
              ),
            ),
            child: Text(
              d != null ? DateFormat('dd MMM yyyy').format(d) : 'Select',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color:
                    d != null
                        ? (dk ? Colors.white : const Color(0xFF1E293B))
                        : (dk ? Colors.white38 : Colors.black38),
              ),
            ),
          ),
        ),
      );
}
