import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Premium Payments Tab — Financial dashboard header, color-striped transaction
/// cards, mode-specific icons, and a bottom-sheet for adding payments.
class CasePaymentsTab extends ConsumerWidget {
  final String caseId;
  const CasePaymentsTab({super.key, required this.caseId});

  static final _cur = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  static final _dateFmt = DateFormat('dd MMM yyyy');

  static const _modeIcons = <String, IconData>{
    'Cash': Icons.payments_rounded,
    'UPI': Icons.smartphone_rounded,
    'Bank Transfer': Icons.account_balance_rounded,
    'Cheque': Icons.receipt_long_rounded,
    'Online': Icons.language_rounded,
  };

  static const _modeColors = <String, Color>{
    'Cash': Color(0xFF10B981),
    'UPI': Color(0xFF8B5CF6),
    'Bank Transfer': Color(0xFF0EA5E9),
    'Cheque': Color(0xFFF59E0B),
    'Online': Color(0xFF6366F1),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(casePaymentsProvider(caseId));

    return Stack(
      children: [
        paymentsAsync.when(
          data: (payments) {
            if (payments.isEmpty) return _buildEmptyState(context, ref);
            return _buildPaymentsList(context, ref, payments);
          },
          loading:
              () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
          error:
              (e, s) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Color(0xFF1E293B)),
                ),
              ),
        ),
        // FAB
        Positioned(bottom: 24.h, right: 20.w, child: _buildAddFab(context, ref)),
      ],
    );
  }

  // ─── PAYMENTS LIST WITH SUMMARY ──────────────────────
  Widget _buildPaymentsList(
    BuildContext context,
    WidgetRef ref,
    List<Payment> payments,
  ) {
    final totalRevenue = payments
        .where((p) => p.transactionType == 'revenue')
        .fold(0.0, (s, p) => s + p.paidAmount);
    final totalExpense = payments
        .where((p) => p.transactionType == 'expense')
        .fold(0.0, (s, p) => s + p.paidAmount);
    final outstanding = payments.fold(0.0, (s, p) => s + p.balanceAmount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ─── FINANCIAL SUMMARY CARD ─────────────────
        Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'Financial Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  _summaryMetric(
                    'Revenue',
                    _cur.format(totalRevenue),
                    const Color(0xFF34D399),
                    Icons.trending_up_rounded,
                  ),
                  SizedBox(width: 12.w),
                  _summaryMetric(
                    'Expenses',
                    _cur.format(totalExpense),
                    const Color(0xFFF87171),
                    Icons.trending_down_rounded,
                  ),
                  SizedBox(width: 12.w),
                  _summaryMetric(
                    'Pending',
                    _cur.format(outstanding),
                    const Color(0xFFFBBF24),
                    Icons.schedule_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 20.h),

        // Section Title
        Row(
          children: [
            Text(
              'Transactions',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15.sp,
                color: Color(0xFF0F172A),
              ),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                '${payments.length} Records',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),

        // ─── TRANSACTION CARDS ──────────────────────
        ...payments.map((p) => _buildTransactionCard(p)),
      ],
    );
  }

  Widget _summaryMetric(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                SizedBox(width: 4.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TRANSACTION CARD ────────────────────────────────
  Widget _buildTransactionCard(Payment p) {
    final isExpense = p.transactionType == 'expense';
    final modeLabel = p.paymentMode ?? 'Cash';
    final modeIcon = _modeIcons[modeLabel] ?? Icons.payments_rounded;
    final modeColor = _modeColors[modeLabel] ?? const Color(0xFF10B981);
    final stripeColor =
        isExpense ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final hasBalance = p.balanceAmount > 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Color Stripe
            Container(
              width: 4.w,
              decoration: BoxDecoration(
                color: stripeColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  bottomLeft: Radius.circular(16.r),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  children: [
                    // Mode Icon
                    Container(
                      width: 44.w,
                      height: 44.h,
                      decoration: BoxDecoration(
                        color: modeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(modeIcon, color: modeColor, size: 22),
                    ),
                    SizedBox(width: 14.w),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "${isExpense ? '−' : '+'}${_cur.format(p.paidAmount)}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16.sp,
                                    color: stripeColor,
                                  ),
                                ),
                              ),
                              // Status chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      hasBalance
                                          ? const Color(0xFFFEF3C7)
                                          : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  hasBalance ? 'PARTIAL' : 'PAID',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w900,
                                    color:
                                        hasBalance
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF16A34A),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              // Total Fee
                              Text(
                                'Total: ${_cur.format(p.totalFee)}',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (hasBalance) ...[
                                const Text(
                                  ' • ',
                                  style: TextStyle(color: Color(0xFFCBD5E1)),
                                ),
                                Text(
                                  'Due: ${_cur.format(p.balanceAmount)}',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 6.h),
                          Row(
                            children: [
                              // Mode badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: modeColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  modeLabel.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w800,
                                    color: modeColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Date
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 11,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                p.paidDate != null
                                    ? _dateFmt.format(p.paidDate!)
                                    : 'No Date',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          // Notes
                          if (p.notes != null && p.notes!.isNotEmpty) ...[
                            SizedBox(height: 6.h),
                            Text(
                              p.notes!,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Color(0xFF64748B),
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
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

  // ─── EMPTY STATE ─────────────────────────────────────
  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(28.r),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 48,
              color: Color(0xFF10B981),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'No Payment Records',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17.sp,
              color: Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Track fees, expenses, and billing\nfor this case',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13.sp,
              height: 1.4.h,
            ),
          ),
        ],
      ),
    );
  }

  // ─── ADD FAB ─────────────────────────────────────────
  Widget _buildAddFab(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showAddPaymentSheet(context, ref),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF34D399)],
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8.w),
            Text(
              'Log Payment',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ADD PAYMENT BOTTOM SHEET ────────────────────────
  void _showAddPaymentSheet(BuildContext context, WidgetRef ref) {
    double totalFee = 0, paidAmount = 0;
    String mode = 'Cash';
    String type = 'revenue';
    String notes = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setSheetState) {
              return Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),

                      // Title
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF34D399)],
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Log Payment',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18.sp,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Record a financial transaction',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      // Type Selector (Revenue vs Expense)
                      Text(
                        'Transaction Type',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.sp,
                          color: Color(0xFF334155),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          _typeChip(
                            'Revenue',
                            'revenue',
                            Icons.trending_up_rounded,
                            const Color(0xFF10B981),
                            type == 'revenue',
                            () => setSheetState(() => type = 'revenue'),
                          ),
                          SizedBox(width: 10.w),
                          _typeChip(
                            'Expense',
                            'expense',
                            Icons.trending_down_rounded,
                            const Color(0xFFEF4444),
                            type == 'expense',
                            () => setSheetState(() => type = 'expense'),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      // Total Fee
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Total Fee (₹)',
                          prefixIcon: const Icon(
                            Icons.currency_rupee_rounded,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => totalFee = double.tryParse(v) ?? 0,
                      ),
                      SizedBox(height: 12.h),

                      // Paid Amount
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Paid Amount (₹)',
                          prefixIcon: const Icon(
                            Icons.payments_rounded,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => paidAmount = double.tryParse(v) ?? 0,
                      ),
                      SizedBox(height: 16.h),

                      // Payment Mode Chips
                      Text(
                        'Payment Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.sp,
                          color: Color(0xFF334155),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            ['Cash', 'UPI', 'Bank Transfer', 'Cheque'].map((m) {
                              final sel = mode == m;
                              final color = _modeColors[m]!;
                              return GestureDetector(
                                onTap: () => setSheetState(() => mode = m),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient:
                                        sel
                                            ? LinearGradient(
                                              colors: [
                                                color,
                                                color.withValues(alpha: 0.8),
                                              ],
                                            )
                                            : null,
                                    color: sel ? null : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12.r),
                                    border:
                                        sel
                                            ? null
                                            : Border.all(
                                              color: const Color(0xFFE2E8F0),
                                            ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _modeIcons[m],
                                        size: 16,
                                        color:
                                            sel
                                                ? Colors.white
                                                : const Color(0xFF64748B),
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        m,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              sel
                                                  ? Colors.white
                                                  : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      SizedBox(height: 16.h),

                      // Notes
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Notes (Optional)',
                          prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        onChanged: (v) => notes = v,
                      ),
                      SizedBox(height: 24.h),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 52.h,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await SupabaseService.createPayment({
                                'case_id': caseId,
                                'total_fee': totalFee,
                                'paid_amount': paidAmount,
                                'balance_amount': totalFee - paidAmount,
                                'payment_mode': mode,
                                'paid_date': DateTime.now().toIso8601String(),
                                'transaction_type': type,
                                'notes': notes.isNotEmpty ? notes : null,
                              });
                              ref.invalidate(casePaymentsProvider(caseId));
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Payment logged!'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Save Payment',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.sp,
                            ),
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

  static Widget _typeChip(
    String label,
    String value,
    IconData icon,
    Color color,
    bool selected,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            gradient:
                selected
                    ? LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                    )
                    : null,
            color: selected ? null : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14.r),
            border:
                selected ? null : Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : const Color(0xFF64748B),
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.sp,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
