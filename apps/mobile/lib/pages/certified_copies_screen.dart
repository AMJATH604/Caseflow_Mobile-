import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';
import '../components/error_state_widget.dart';
import '../components/dialogs/log_cc_dialog.dart';
import '../components/dialogs/payment_capture_overlay.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CertifiedCopiesScreen extends ConsumerWidget {
  const CertifiedCopiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copiesAsync = ref.watch(certifiedCopiesProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: copiesAsync.when(
        data: (copies) => _buildBody(context, ref, isMobile, copies),
        loading:
            () => const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
        error:
            (err, stack) => ErrorStateWidget(
              error: err,
              onRetry: () => ref.invalidate(certifiedCopiesProvider),
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCCDialog(context),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'New Application',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    bool isMobile,
    List<CertifiedCopy> copies,
  ) {
    // Calculate summary stats
    int pending = 0, memoFiled = 0, ready = 0, collected = 0;
    for (var c in copies) {
      switch (c.status) {
        case 'box_drop':
          pending++;
          break;
        case 'memo_filed':
          memoFiled++;
          break;
        case 'ready':
          ready++;
          break;
        case 'collected':
          collected++;
          break;
      }
    }

    return CustomScrollView(
      slivers: [
        // ─── Premium Header ───
        SliverToBoxAdapter(
          child: Container(
            margin: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 32,
              vertical: 16,
            ),
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E40AF),
                  Color(0xFF3B82F6),
                  Color(0xFF0EA5E9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
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
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Certified Copies',
                            style: GoogleFonts.outfit(
                              fontSize: 26.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Track your CC applications in real-time',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                // Stats Row
                Row(
                  children: [
                    _buildHeaderStat('📦', 'Box Drop', pending.toString()),
                    _buildHeaderStat('📋', 'Memo', memoFiled.toString()),
                    _buildHeaderStat('✅', 'Ready', ready.toString()),
                    _buildHeaderStat('🤝', 'Collected', collected.toString()),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ─── Cards List ───
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32,
            vertical: 8,
          ),
          sliver:
              copies.isEmpty
                  ? SliverFillRemaining(child: _buildEmptyState())
                  : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildCCCard(context, ref, copies[index], isMobile),
                      childCount: copies.length,
                    ),
                  ),
        ),

        // Bottom padding for FAB
        const SliverToBoxAdapter(child: SizedBox(height: 100.h)),
      ],
    );
  }

  Widget _buildHeaderStat(String emoji, String label, String count) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18.sp)),
            SizedBox(height: 4.h),
            Text(
              count,
              style: GoogleFonts.outfit(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(28.r),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accent.withValues(alpha: 0.08),
                  AppTheme.info.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description_outlined,
              size: 60,
              color: AppTheme.accent.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'No CC Applications Yet',
            style: GoogleFonts.outfit(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Track your certified copy status real-time.\nTap the + button to log your first application.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.grey[500],
              height: 1.6.h,
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCCCard(
    BuildContext context,
    WidgetRef ref,
    CertifiedCopy c,
    bool isMobile,
  ) {
    final statusColor = _getStatusColor(c.status);
    final statusLabel = _getStatusLabel(c.status);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Card Header ───
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
            child: Row(
              children: [
                // Status indicator dot
                Container(
                  width: 10.w,
                  height: 10.h,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.caseTitle ?? 'Unknown Case',
                        style: GoogleFonts.outfit(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          if (c.caNumber != null && c.caNumber!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                'CA: ${c.caNumber}',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[500],
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                          ],
                          Text(
                            'Filed: ${_formatDate(c.boxDropDate)}',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                // NEW: Paid Badge
                if (c.paidAmount != null) ...[
                  SizedBox(width: 8.w),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: const Color(0xFF059669).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: Color(0xFF059669),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'PAID',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF059669),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _buildActionsMenu(context, ref, c),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // ─── Timeline Stepper ───
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: _buildTimelineStepper(c),
          ),

          SizedBox(height: 16.h),

          // ─── Bottom Info Row ───
          _buildBottomSection(context, ref, c, statusColor),
        ],
      ),
    );
  }

  Widget _buildTimelineStepper(CertifiedCopy c) {
    final stages = ['box_drop', 'memo_filed', 'ready', 'collected'];
    final stageLabels = ['Box Drop', 'Memo Filed', 'Ready', 'Collected'];
    final stageIcons = [
      Icons.inventory_2_rounded,
      Icons.assignment_rounded,
      Icons.verified_rounded,
      Icons.handshake_rounded,
    ];
    final stageDates = [
      c.boxDropDate,
      c.memoDate,
      c.readyDate,
      c.collectedDate,
    ];

    final int currentIdx = stages.indexOf(c.status);

    return Row(
      children: List.generate(stages.length, (index) {
        final isCompleted = index < currentIdx;
        final isCurrent = index == currentIdx;
        final isActive = index <= currentIdx;
        final color =
            isActive ? _getStatusColor(stages[index]) : Colors.grey[300]!;

        return Expanded(
          child: Row(
            children: [
              // Step circle + label
              Expanded(
                child: Column(
                  children: [
                    // Circle
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isCurrent ? 44 : 38,
                      height: isCurrent ? 44 : 38,
                      decoration: BoxDecoration(
                        gradient:
                            isCurrent
                                ? LinearGradient(
                                  colors: [color, color.withValues(alpha: 0.7)],
                                )
                                : null,
                        color:
                            isCurrent
                                ? null
                                : (isCompleted
                                    ? color.withValues(alpha: 0.12)
                                    : AppTheme.background),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive ? color : Colors.grey[300]!,
                          width: isCurrent ? 0 : 2,
                        ),
                        boxShadow:
                            isCurrent
                                ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                                : null,
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_rounded : stageIcons[index],
                        size: isCurrent ? 20 : 16,
                        color:
                            isCurrent
                                ? Colors.white
                                : (isActive ? color : Colors.grey[400]),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    // Label
                    Text(
                      stageLabels[index],
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? AppTheme.primary : Colors.grey[400],
                      ),
                    ),
                    // Date
                    if (stageDates[index] != null)
                      Text(
                        DateFormat('dd MMM').format(stageDates[index]!),
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      SizedBox(height: 12.h),
                  ],
                ),
              ),
              // Connector line
              if (index < stages.length - 1)
                Container(
                  width: 16.w,
                  height: 2.5.h,
                  margin: EdgeInsets.only(bottom: 24.h),
                  decoration: BoxDecoration(
                    color:
                        index < currentIdx
                            ? _getStatusColor(stages[index])
                            : Colors.grey[250],
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildBottomSection(
    BuildContext context,
    WidgetRef ref,
    CertifiedCopy c,
    Color statusColor,
  ) {
    final expectedDate = _getExpectedDate(c);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          // Info row
          Row(
            children: [
              if (expectedDate != null && c.status != 'collected') ...[
                const Icon(Icons.schedule_rounded, size: 14, color: AppTheme.warning),
                SizedBox(width: 6.w),
                Text(
                  "Expected: ${DateFormat('dd MMM yyyy').format(expectedDate)}",
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  ),
                ),
                const Spacer(),
              ],
              Icon(Icons.update_rounded, size: 14, color: Colors.grey[400]),
              SizedBox(width: 6.w),
              Text(
                'Updated: ${_formatDate(_getLastUpdateDate(c))}',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (expectedDate == null || c.status == 'collected')
                const Spacer(),
            ],
          ),
          // Link Payment Button (NEW — Manual Fix)
          if (c.paidAmount == null) ...[
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  PaymentCaptureOverlay.show(
                    context,
                    caseId: c.caseId,
                    caseTitle: c.caseTitle ?? 'CC Application',
                    purpose: 'Certified Copy Fee',
                    certifiedCopyId: c.id,
                  );
                },
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text(
                  'Link Payment & Update Ledger',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF059669),
                  side: BorderSide(
                    color: const Color(0xFF059669).withValues(alpha: 0.4),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
            ),
          ],
          // Update Stage Button
          if (c.status != 'collected') ...[
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showUpdateStatusDialog(context, ref, c),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  'Advance to ${_getNextStageLabel(c.status)}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionsMenu(
    BuildContext context,
    WidgetRef ref,
    CertifiedCopy c,
  ) {
    return PopupMenuButton(
      icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      itemBuilder:
          (context) => [
            PopupMenuItem(
              onTap: () => _confirmDelete(context, ref, c),
              child: const Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  SizedBox(width: 12.w),
                  Text('Delete Entry', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'box_drop':
        return 'BOX DROP';
      case 'memo_filed':
        return 'MEMO FILED';
      case 'ready':
        return 'READY';
      case 'collected':
        return 'COLLECTED';
      default:
        return 'PENDING';
    }
  }

  String _getNextStageLabel(String status) {
    switch (status) {
      case 'box_drop':
        return 'Memo Filed';
      case 'memo_filed':
        return 'Ready';
      case 'ready':
        return 'Collected';
      default:
        return 'Next Stage';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ready':
        return const Color(0xFF10B981);
      case 'memo_filed':
        return const Color(0xFFF59E0B);
      case 'box_drop':
        return const Color(0xFF0EA5E9);
      case 'collected':
        return const Color(0xFF6366F1);
      default:
        return Colors.grey;
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CertifiedCopy c) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.r),
            ),
            title: Text(
              'Delete Record?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to delete this Certified Copy record? This action cannot be undone.',
              style: GoogleFonts.inter(color: Colors.grey[600], height: 1.5.h),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  await SupabaseService.deleteCertifiedCopy(c.id);
                  ref.invalidate(certifiedCopiesProvider);
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Delete',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  DateTime? _getExpectedDate(CertifiedCopy c) {
    if (c.status == 'box_drop' && c.boxDropDate != null) {
      return c.boxDropDate!.add(const Duration(days: 8));
    }
    if (c.status == 'memo_filed' && c.memoDate != null) {
      return c.memoDate!.add(const Duration(days: 7));
    }
    return null;
  }

  DateTime? _getLastUpdateDate(CertifiedCopy c) {
    return c.collectedDate ?? c.readyDate ?? c.memoDate ?? c.boxDropDate;
  }

  void _showUpdateStatusDialog(
    BuildContext context,
    WidgetRef ref,
    CertifiedCopy c,
  ) {
    String nextStatus = 'collected';
    String dateLabel = 'Collected On';
    String dbField = 'collected_date';
    String headerTitle = 'Mark as Collected';

    if (c.status == 'box_drop') {
      nextStatus = 'memo_filed';
      dateLabel = 'Memo Filed Date';
      dbField = 'memo_date';
      headerTitle = 'Advance to Memo Filed';
    } else if (c.status == 'memo_filed') {
      nextStatus = 'ready';
      dateLabel = 'Ready Date';
      dbField = 'ready_date';
      headerTitle = 'Mark as Ready';
    }

    final nextColor = _getStatusColor(nextStatus);
    DateTime selectedDate = DateTime.now();
    final caController = TextEditingController(text: c.caNumber);

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28.r),
                  ),
                  backgroundColor: Colors.white,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Container(
                          padding: EdgeInsets.all(24.r),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                nextColor.withValues(alpha: 0.12),
                                nextColor.withValues(alpha: 0.03),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28.r),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10.r),
                                decoration: BoxDecoration(
                                  color: nextColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                child: Icon(
                                  Icons.upgrade_rounded,
                                  color: nextColor,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      headerTitle,
                                      style: GoogleFonts.outfit(
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      'Update the stage for this CC application',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.sp,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Body
                        Padding(
                          padding: EdgeInsets.all(24.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // CA Number
                              Text(
                                'CA NUMBER',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[400],
                                  letterSpacing: 1,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              TextField(
                                controller: caController,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'e.g. CA/123/2026',
                                  prefixIcon: const Icon(
                                    Icons.numbers_rounded,
                                    color: AppTheme.accent,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.background.withValues(
                                    alpha: 0.5,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                    borderSide: const BorderSide(
                                      color: AppTheme.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                    borderSide: const BorderSide(
                                      color: AppTheme.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                    borderSide: const BorderSide(
                                      color: AppTheme.accent,
                                      width: 1.5.w,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 20.h),
                              // Date
                              Text(
                                dateLabel.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[400],
                                  letterSpacing: 1,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setState(() => selectedDate = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(14.r),
                                child: Container(
                                  padding: EdgeInsets.all(16.r),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background.withValues(
                                      alpha: 0.5,
                                    ),
                                    borderRadius: BorderRadius.circular(14.r),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        color: nextColor,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12.w),
                                      Text(
                                        DateFormat(
                                          'dd MMMM yyyy',
                                        ).format(selectedDate),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15.sp,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.edit_calendar_rounded,
                                        size: 16,
                                        color: Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Actions
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.r),
                                    ),
                                    side: const BorderSide(color: AppTheme.border),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Update Stage',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () async {
                                    await SupabaseService.updateCertifiedCopy(
                                      c.id,
                                      {
                                        'status': nextStatus,
                                        'ca_number': caController.text.trim(),
                                        dbField:
                                            selectedDate
                                                .toIso8601String()
                                                .split('T')[0],
                                      },
                                    );
                                    ref.invalidate(certifiedCopiesProvider);
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: nextColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.r),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
  }

  void _showAddCCDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const LogCCDialog());
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd MMM yyyy').format(date);
  }
}
