import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Self-contained Payments tab for a case.
/// Displays payment history with a FAB to log new payments.
class CasePaymentsTab extends ConsumerWidget {
  final String caseId;
  const CasePaymentsTab({super.key, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Financial tracking and billing history",
                        style: TextStyle(color: const Color(0xFF64748B), fontSize: 13),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Balance: ${cur.format(p.balanceAmount)}",
                                  style: TextStyle(color: AppTheme.error.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold),
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
            onPressed: () => _showAddPaymentDialog(context, ref),
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.black,
            child: const Icon(Icons.add_rounded, size: 30),
          ),
        ),
      ],
    );
  }

  void _showAddPaymentDialog(BuildContext context, WidgetRef ref) {
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
                items: ["Cash", "UPI", "Bank Transfer", "Cheque"]
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
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
