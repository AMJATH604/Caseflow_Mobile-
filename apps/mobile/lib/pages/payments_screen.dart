import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/providers.dart';
import '../services/paginated_providers.dart';
import '../services/supabase_service.dart';
import '../components/error_state_widget.dart';
import '../theme/app_theme.dart';
import '../components/dialogs/log_payment_dialog.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(paginatedPaymentsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginatedState = ref.watch(paginatedPaymentsProvider);
    final payments = paginatedState.items;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: paginatedState.isLoading && payments.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              )
            : paginatedState.error != null && payments.isEmpty
                ? ErrorStateWidget(
                    error: paginatedState.error!,
                    onRetry: () => ref.read(paginatedPaymentsProvider.notifier).refresh(),
                  )
                : RefreshIndicator(
                    color: AppTheme.accent,
                    onRefresh: () => ref.read(paginatedPaymentsProvider.notifier).refresh(),
                    child: _buildContent(context, ref, isMobile, payments, paginatedState),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPaymentDialog(context),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Log Entry',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    bool isMobile,
    List<Payment> payments,
    dynamic paginatedState,
  ) {
    final clientCards = _buildPerClientCards(context, ref, payments);

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ─── Header ───
        SliverToBoxAdapter(child: _buildHeader(context)),

        // ─── Content ───
        if (payments.isEmpty)
          SliverFillRemaining(child: _buildEmptyStateWithGuide(context))
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 32,
              vertical: 8,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate(clientCards),
            ),
          ),

        // Loading more indicator
        if (paginatedState.hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: paginatedState.isLoadingMore
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16.r,
                            height: 16.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accent,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Loading more payments...',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),

        // Bottom padding for FAB
        SliverToBoxAdapter(child: SizedBox(height: 100.h)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
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
                  'Financial Ledger',
                  style: GoogleFonts.outfit(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Per-client fee tracking & receivables',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          // How it works button
          Material(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12.r),
            child: InkWell(
              onTap: () => _showHowItWorks(context),
              borderRadius: BorderRadius.circular(12.r),
              child: Padding(
                padding: EdgeInsets.all(10.r),
                child: Icon(
                  Icons.help_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ─── PER-CLIENT CARDS ─────────────────────────────────
  // ═══════════════════════════════════════════════════════

  List<Widget> _buildPerClientCards(
    BuildContext context,
    WidgetRef ref,
    List<Payment> payments,
  ) {
    // Group all payments by case (client)
    final grouped = <String, List<Payment>>{};
    for (var p in payments) {
      final key = p.caseId;
      grouped.putIfAbsent(key, () => []).add(p);
    }

    return grouped.entries.map((entry) {
      final casePayments = entry.value;
      // Sort by date ascending for timeline display
      casePayments.sort(
        (a, b) => (a.paidDate ?? DateTime.now()).compareTo(
          b.paidDate ?? DateTime.now(),
        ),
      );

      final caseTitle = casePayments.first.caseTitle ?? 'Unknown Case';
      final agreedFee = casePayments.first.totalFee;

      // Calculate per-client stats
      double totalReceived = 0;
      double totalExpenses = 0;
      for (var p in casePayments) {
        if (p.transactionType == 'revenue') {
          totalReceived += p.paidAmount;
        } else {
          totalExpenses += p.paidAmount;
        }
      }
      final yetToReceive = agreedFee - totalReceived;
      final isSettled = yetToReceive <= 0;
      final fmt = NumberFormat('#,##,###');

      return Container(
        margin: EdgeInsets.only(bottom: 20.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Client/Case Header ───
            Padding(
              padding: EdgeInsets.all(20.r),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accent.withValues(alpha: 0.1),
                          AppTheme.accentViolet.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 22,
                      color: AppTheme.accent,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          caseTitle,
                          style: GoogleFonts.outfit(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Agreed Fee: ₹${fmt.format(agreedFee)}',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(isSettled, yetToReceive, fmt),
                ],
              ),
            ),

            // ─── Per-Client Financial Summary ───
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20.w),
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: AppTheme.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                children: [
                  // Row 1: Received & Expenses
                  Row(
                    children: [
                      _buildMiniStat(
                        '💰 Received',
                        '₹${fmt.format(totalReceived)}',
                        AppTheme.success,
                      ),
                      Container(
                        width: 1.w,
                        height: 32.h,
                        color: AppTheme.border.withValues(alpha: 0.5),
                      ),
                      _buildMiniStat(
                        '📤 Expenses',
                        '₹${fmt.format(totalExpenses)}',
                        AppTheme.error,
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  // Row 2: Yet to Receive (prominent)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSettled
                              ? AppTheme.success.withValues(alpha: 0.08)
                              : AppTheme.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color:
                            isSettled
                                ? AppTheme.success.withValues(alpha: 0.2)
                                : AppTheme.warning.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isSettled ? '🎉 Fully Settled' : '⏳ Yet to Receive',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color:
                                isSettled ? AppTheme.success : AppTheme.warning,
                          ),
                        ),
                        Text(
                          isSettled ? '₹0' : '₹${fmt.format(yetToReceive)}',
                          style: GoogleFonts.outfit(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color:
                                isSettled ? AppTheme.success : AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // ─── Payment Timeline Header ───
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                'PAYMENT TIMELINE',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[400],
                  letterSpacing: 1,
                ),
              ),
            ),
            SizedBox(height: 8.h),

            // ─── Timeline Entries ───
            ...casePayments.asMap().entries.map((entry) {
              final idx = entry.key;
              final p = entry.value;
              final isLast = idx == casePayments.length - 1;

              // Calculate running balance at this point
              double runningReceived = 0;
              for (int i = 0; i <= idx; i++) {
                if (casePayments[i].transactionType == 'revenue') {
                  runningReceived += casePayments[i].paidAmount;
                }
              }
              final runningBalance = agreedFee - runningReceived;

              return _buildTimelineEntry(
                context,
                ref,
                p,
                isLast,
                runningBalance,
                fmt,
              );
            }),

            SizedBox(height: 12.h),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildTimelineEntry(
    BuildContext context,
    WidgetRef ref,
    Payment p,
    bool isLast,
    double runningBalance,
    NumberFormat fmt,
  ) {
    final isRevenue = p.transactionType == 'revenue';
    final color = isRevenue ? AppTheme.success : AppTheme.error;
    final date = p.paidDate ?? DateTime.now();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // ─── Timeline Line + Dot ───
            SizedBox(
              width: 32.w,
              child: Column(
                children: [
                  Container(
                    width: 12.w,
                    height: 12.h,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2.w,
                        color: AppTheme.border.withValues(alpha: 0.4),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            // ─── Entry Content ───
            Expanded(
              child: Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : 4),
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: color.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date & Delete Row
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            DateFormat('dd MMM yyyy, EEEE').format(date),
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (p.paymentMode != null)
                          Container(
                            margin: EdgeInsets.only(right: 8.w),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              p.paymentMode!.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[500],
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        // Delete button
                        InkWell(
                          onTap: () => _confirmDeletePayment(context, ref, p),
                          borderRadius: BorderRadius.circular(8.r),
                          child: Padding(
                            padding: EdgeInsets.all(4.r),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),

                    // Amount & Type Row
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            isRevenue
                                ? Icons.south_west_rounded
                                : Icons.north_east_rounded,
                            color: color,
                            size: 14,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.notes?.isNotEmpty == true
                                    ? p.notes!
                                    : (isRevenue
                                        ? 'Payment Received'
                                        : 'Office Expense'),
                                style: GoogleFonts.inter(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isRevenue)
                                Text(
                                  'Balance after: ₹${fmt.format(runningBalance > 0 ? runningBalance : 0)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          "${isRevenue ? '+' : '-'} ₹${fmt.format(p.paidAmount)}",
                          style: GoogleFonts.outfit(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePayment(BuildContext context, WidgetRef ref, Payment p) {
    final fmt = NumberFormat('#,##,###');
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.r),
            ),
            title: Text(
              'Delete Entry?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete this entry?',
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    height: 1.5.h,
                  ),
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(14.r),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        p.transactionType == 'revenue'
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        color:
                            p.transactionType == 'revenue'
                                ? AppTheme.success
                                : AppTheme.error,
                        size: 18,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.notes?.isNotEmpty == true
                                  ? p.notes!
                                  : (p.transactionType == 'revenue'
                                      ? 'Payment'
                                      : 'Expense'),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.sp,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'dd MMM yyyy',
                              ).format(p.paidDate ?? DateTime.now()),
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${fmt.format(p.paidAmount)}',
                        style: GoogleFonts.outfit(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color:
                              p.transactionType == 'revenue'
                                  ? AppTheme.success
                                  : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  "⚠️ This will affect the client's balance calculation.",
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
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
                  await SupabaseService.deletePayment(p.id);
                  ref.invalidate(paymentsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
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

  Widget _buildStatusBadge(
    bool isSettled,
    double yetToReceive,
    NumberFormat fmt,
  ) {
    final color = isSettled ? AppTheme.success : AppTheme.warning;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isSettled ? '✓ SETTLED' : '₹${fmt.format(yetToReceive)} DUE',
        style: GoogleFonts.inter(
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 4.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 17.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ─── EMPTY STATE WITH GUIDE ────────────────────────────
  // ═══════════════════════════════════════════════════════

  Widget _buildEmptyStateWithGuide(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Column(
        children: [
          SizedBox(height: 32.h),
          Container(
            padding: EdgeInsets.all(28.r),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.success.withValues(alpha: 0.08),
                  AppTheme.accent.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 56,
              color: AppTheme.success.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'No Transactions Yet',
            style: GoogleFonts.outfit(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "Track finances per client. Here's how it works:",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: Colors.grey[500],
              height: 1.5.h,
            ),
          ),
          SizedBox(height: 32.h),
          _buildGuideStep(
            '1',
            'Set Agreed Fee',
            "When logging the first record for a client's case, set the total agreed fee (e.g., ₹50,000).",
            Icons.handshake_rounded,
            const Color(0xFF3B82F6),
          ),
          _buildGuideStep(
            '2',
            'Log Initial Payment',
            "Client pays ₹15,000 initially → System shows 'Yet to Receive': ₹35,000 for this client.",
            Icons.south_west_rounded,
            AppTheme.success,
          ),
          _buildGuideStep(
            '3',
            'Track Subsequent Payments',
            'Each time the client pays, log it. Balance auto-decreases per client (e.g., ₹35,000 → ₹20,000 → ₹0).',
            Icons.timeline_rounded,
            AppTheme.warning,
          ),
          _buildGuideStep(
            '4',
            'Track Client Expenses',
            "Court fees, xerox, travel — log as 'Expense'. Tracked separately under each client's card.",
            Icons.north_east_rounded,
            AppTheme.error,
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildGuideStep(
    String number,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.outfit(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                    height: 1.5.h,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ─── HOW IT WORKS BOTTOM SHEET ─────────────────────────
  // ═══════════════════════════════════════════════════════

  void _showHowItWorks(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      backgroundColor: Colors.white,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder:
                (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(28.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),

                      // Title
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            child: const Icon(
                              Icons.lightbulb_rounded,
                              color: AppTheme.accent,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'How the Ledger Works',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                Text(
                                  'Per-client financial tracking',
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
                      SizedBox(height: 28.h),

                      // Example walkthrough
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20.r),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.accent.withValues(alpha: 0.05),
                              AppTheme.accentViolet.withValues(alpha: 0.03),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '📋 Example: Client X',
                              style: GoogleFonts.outfit(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            _buildExampleRow(
                              '01 Jan',
                              'Agreed Fee set',
                              '₹50,000',
                              Colors.grey[600]!,
                            ),
                            _buildExampleRow(
                              '01 Jan',
                              'Initial Payment',
                              '+ ₹15,000',
                              AppTheme.success,
                            ),
                            _buildExampleDivider('Yet to Receive: ₹35,000'),
                            _buildExampleRow(
                              '15 Jan',
                              'Court Fee (Expense)',
                              '- ₹500',
                              AppTheme.error,
                            ),
                            _buildExampleRow(
                              '01 Feb',
                              '2nd Payment',
                              '+ ₹10,000',
                              AppTheme.success,
                            ),
                            _buildExampleDivider('Yet to Receive: ₹25,000'),
                            _buildExampleRow(
                              '15 Mar',
                              '3rd Payment',
                              '+ ₹25,000',
                              AppTheme.success,
                            ),
                            _buildExampleDivider('✓ SETTLED — Balance: ₹0'),
                          ],
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // Formula
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20.r),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '💡 Formula',
                              style: GoogleFonts.outfit(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16.r),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              child: Text(
                                "Yet to Receive = Agreed Fee − Total Received\n\nExpenses are tracked separately\n(Court fees, travel, xerox etc.)\nThey don't affect the client balance.",
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12.sp,
                                  color: AppTheme.primary,
                                  height: 1.7.h,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // Key points
                      _buildGuideStep(
                        '1',
                        'Each Client Has Own Card',
                        'Revenue, expenses, and balance are tracked independently per case/client. No global mixing.',
                        Icons.person_rounded,
                        const Color(0xFF3B82F6),
                      ),
                      _buildGuideStep(
                        '2',
                        'Timeline with Dates',
                        'Every payment or expense is logged with exact date and shows in chronological order.',
                        Icons.timeline_rounded,
                        AppTheme.success,
                      ),
                      _buildGuideStep(
                        '3',
                        'Running Balance',
                        "After each payment, you can see the remaining 'Yet to Receive' amount at that point in time.",
                        Icons.analytics_rounded,
                        AppTheme.warning,
                      ),
                      _buildGuideStep(
                        '4',
                        'Auto SETTLED Badge',
                        "When all fees are collected (balance = ₹0), the client card automatically shows 'SETTLED'.",
                        Icons.verified_rounded,
                        const Color(0xFF6366F1),
                      ),

                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildExampleRow(
    String date,
    String description,
    String amount,
    Color color,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          SizedBox(
            width: 60.w,
            child: Text(
              date,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary,
              ),
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.outfit(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleDivider(String label) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: AppTheme.warning,
        ),
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LogPaymentDialog(),
    );
  }
}
