import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/bar_association_models.dart';
import '../../services/providers.dart';
import '../../services/repositories/bar_association_repository.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BarFeePaymentScreen extends ConsumerStatefulWidget {
  final String associationId;
  const BarFeePaymentScreen({super.key, required this.associationId});

  @override
  ConsumerState<BarFeePaymentScreen> createState() =>
      _BarFeePaymentScreenState();
}

class _BarFeePaymentScreenState extends ConsumerState<BarFeePaymentScreen> {
  bool _processing = false;

  @override
  Widget build(BuildContext context) {
    final assocAsync =
        ref.watch(barAssociationDetailProvider(widget.associationId));
    final memberAsync =
        ref.watch(barMembershipProvider(widget.associationId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Membership Fees',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20.sp, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: assocAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
              SizedBox(height: 12.h),
              Text('Failed to load data', style: GoogleFonts.inter()),
            ],
          ),
        ),
        data: (assoc) {
          if (assoc == null) {
            return const Center(child: Text('Association not found'));
          }
          return memberAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (member) {
              if (member == null) {
                return const Center(child: Text('Membership not found'));
              }
              return _buildContent(assoc, member);
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(BarAssociation assoc, BarMember member) {
    final currentYear = DateTime.now().year;
    final isPaid = member.isFeePaidForCurrentYear;
    final feeHistoryAsync = ref.watch(barFeeHistoryProvider(member.id));

    return RefreshIndicator(
      color: const Color(0xFF4F46E5),
      onRefresh: () async {
        ref.invalidate(barMembershipProvider(widget.associationId));
        ref.invalidate(barFeeHistoryProvider(member.id));
      },
      child: ListView(
        padding: EdgeInsets.all(16.r),
        children: [
          // ── Fee Status Card ──
          Container(
            decoration: BoxDecoration(
              gradient: isPaid
                  ? const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF10B981)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: (isPaid
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: EdgeInsets.all(24.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isPaid
                          ? Icons.check_circle_rounded
                          : Icons.pending_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      isPaid ? 'Fee Paid ✅' : 'Payment Due',
                      style: GoogleFonts.inter(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Annual Fee',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '₹${assoc.annualFee.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 28.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Period',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '$currentYear — ${currentYear + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isPaid) ...[
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton.icon(
                      onPressed: _processing
                          ? null
                          : () => _initiatePayment(assoc, member),
                      icon: _processing
                          ? SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFF59E0B),
                              ),
                            )
                          : const Icon(Icons.payment_rounded),
                      label: Text(
                        _processing ? 'Processing...' : 'Pay Now via Razorpay',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 15.sp,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFD97706),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                    ),
                  ),
                ],
                if (isPaid) ...[
                  SizedBox(height: 16.h),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Valid until ${currentYear + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // ── Payment History ──
          Text(
            'Payment History',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 12.h),

          feeHistoryAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Failed to load history',
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
              ),
            ),
            data: (payments) {
              if (payments.isEmpty) {
                return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
                  padding: EdgeInsets.all(32.r),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 40,
                          color: Color(0xFFCBD5E1),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'No payment history',
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: payments.map((p) => _buildPaymentItem(p)).toList(),
              );
            },
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(BarFeePayment payment) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: EdgeInsets.all(16.r),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: payment.isPaid
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              payment.isPaid
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: payment.isPaid
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              size: 22,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Annual Fee ${payment.feeYear}-${payment.feeYear + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 2.h),
                if (payment.receiptNumber != null)
                  Text(
                    'Receipt: ${payment.receiptNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                if (payment.paidAt != null)
                  Text(
                    'Paid on ${DateFormat('dd/MM/yyyy').format(payment.paidAt!)}',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${payment.amount.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: payment.isPaid
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  payment.isPaid ? 'Paid' : payment.status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: payment.isPaid
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _initiatePayment(
    BarAssociation assoc,
    BarMember member,
  ) async {
    setState(() => _processing = true);

    try {
      // 1. Create pending payment record
      final payment = await BarAssociationRepository.createFeePayment(
        associationId: assoc.id,
        memberId: member.id,
        amount: assoc.annualFee,
        feeYear: DateTime.now().year,
      );

      // 2. TODO: Launch Razorpay checkout with existing razorpay_flutter
      // For now, simulate a successful payment
      // In production, you'd call:
      // final razorpay = Razorpay();
      // razorpay.open({
      //   'key': EnvConfig.razorpayKey,
      //   'amount': (assoc.annualFee * 100).toInt(),
      //   'name': assoc.name,
      //   'description': 'Annual Membership Fee ${DateTime.now().year}',
      //   'prefill': {'contact': member.mobile, 'email': member.email},
      //   'notes': {'payment_id': payment.id, 'association_id': assoc.id},
      // });

      // 3. Mark as paid (this would normally happen in Razorpay callback)
      await BarAssociationRepository.updateFeePayment(
        paymentId: payment.id,
        razorpayPaymentId: 'pay_simulated_${DateTime.now().millisecondsSinceEpoch}',
        razorpayOrderId: 'order_simulated_${DateTime.now().millisecondsSinceEpoch}',
        status: 'paid',
      );

      // 4. Refresh data
      ref.invalidate(barMembershipProvider(widget.associationId));
      ref.invalidate(barFeeHistoryProvider(member.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Fee paid successfully! Receipt: ${payment.receiptNumber}',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Payment failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}
