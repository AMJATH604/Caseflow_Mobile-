import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/bar_association_models.dart';
import '../../services/providers.dart';
import '../../services/repositories/bar_association_repository.dart';

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
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: const Color(0xFF0F172A)),
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
              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 12),
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
        padding: const EdgeInsets.all(16),
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
              borderRadius: BorderRadius.circular(20),
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
            padding: const EdgeInsets.all(24),
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
                    const SizedBox(width: 12),
                    Text(
                      isPaid ? 'Fee Paid ✅' : 'Payment Due',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
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
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${assoc.annualFee.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 28,
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
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currentYear — ${currentYear + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 16,
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _processing
                          ? null
                          : () => _initiatePayment(assoc, member),
                      icon: _processing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
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
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFD97706),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
                if (isPaid) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Valid until ${currentYear + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
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
          const SizedBox(height: 24),

          // ── Payment History ──
          Text(
            'Payment History',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),

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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          size: 40,
                          color: Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No payment history',
                          style: GoogleFonts.inter(
                            fontSize: 14,
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(BarFeePayment payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: payment.isPaid
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Annual Fee ${payment.feeYear}-${payment.feeYear + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                if (payment.receiptNumber != null)
                  Text(
                    'Receipt: ${payment.receiptNumber}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                if (payment.paidAt != null)
                  Text(
                    'Paid on ${DateFormat('dd/MM/yyyy').format(payment.paidAt!)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
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
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: payment.isPaid
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  payment.isPaid ? 'Paid' : payment.status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
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
