import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../components/commission/cm_kit.dart';
import '../../models/commission_models.dart';
import '../../services/commission_service.dart';
import '../../theme/app_theme.dart';
import 'commission_data.dart';

/// The commission fee (batta) fixed by the court — who deposited it, what
/// has been received — and every expense, for the memo of costs.
class CommissionFeesScreen extends ConsumerWidget {
  final String commissionId;
  const CommissionFeesScreen({super.key, required this.commissionId});

  void _refresh(WidgetRef ref) => ref.invalidate(commissionBundleProvider(commissionId));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(commissionBundleProvider(commissionId));
    return CmScaffold(
      title: 'Fee & expenses',
      bottom: CmButton('Add expense', icon: Icons.add_rounded, onPressed: async.valueOrNull == null ? null : () => _addExpense(context, ref)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load: $e')),
        data: (b) {
          final c = b.commission;
          final bal = c.feeBalance;
          return ListView(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
            children: [
              CmCard(
                onTap: () => _editFee(context, ref, c),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Expanded(child: CmLabel('Commission fee')), Icon(Icons.edit_outlined, size: 18.r, color: Cm.faint)]),
                    SizedBox(height: 8.h),
                    if (c.feeFixed == null)
                      Text('Tap to enter the fee fixed by the court, and what has been received.', style: Cm.body(context))
                    else ...[
                      CmFacts([
                        ('Fixed by court', cmRupees(c.feeFixed)),
                        if (c.feeDepositedBy != null) ('Deposited by', c.feeDepositedBy!),
                        ('Received', '${cmRupees(c.feeReceived ?? 0)}${c.feeReceivedOn != null ? ' · ${cmDate(c.feeReceivedOn)}' : ''}'),
                      ]),
                      if (bal != null) ...[
                        SizedBox(height: 8.h),
                        Text(
                          bal <= 0 ? 'Fully received' : 'Balance ${cmRupees(bal)} — ask for it with the report',
                          style: Cm.title(context, size: 14).copyWith(color: bal <= 0 ? AppTheme.success : AppTheme.error),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              CmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: CmLabel('Expenses')),
                        Text(cmRupees(b.expenseTotal), style: Cm.title(context, size: 15)),
                      ],
                    ),
                    if (b.expenses.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 8.h),
                        child: Text('Travel, surveyor or chain man, photo prints, stamp paper — add each as it is spent.', style: Cm.body(context)),
                      )
                    else
                      for (final e in b.expenses)
                        Dismissible(
                          key: ValueKey(e.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: 16.w),
                            color: AppTheme.error.withValues(alpha: 0.12),
                            child: const Icon(Icons.delete_outline, color: AppTheme.error),
                          ),
                          confirmDismiss: (_) async => await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete this expense?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                              ],
                            ),
                          ),
                          onDismissed: (_) async {
                            await CommissionService.deleteExpense(e.id);
                            _refresh(ref);
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 10.h),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.expenseType.label, style: Cm.title(context, size: 14)),
                                      Text([if (e.description != null) e.description!, cmDate(e.expenseDate)].join(' · '),
                                          style: Cm.body(context, size: 12)),
                                    ],
                                  ),
                                ),
                                Text(cmRupees(e.amount), style: Cm.title(context, size: 14)),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              if (b.expenses.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text('Swipe an expense left to delete it.', style: Cm.body(context, size: 12, color: Cm.faint)),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _editFee(BuildContext context, WidgetRef ref, Commission c) async {
    String n(double? v) => v == null ? '' : v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    final fixed = TextEditingController(text: n(c.feeFixed));
    final by = TextEditingController(text: c.feeDepositedBy ?? '');
    final rec = TextEditingController(text: n(c.feeReceived));
    DateTime? on = c.feeReceivedOn;
    final saved = await showCmSheet<bool>(
      context,
      title: 'Commission fee',
      builder: (ctx, ss) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CmField(fixed, 'Fixed by the court (₹)', keyboard: const TextInputType.numberWithOptions(decimal: true)),
          SizedBox(height: 10.h),
          CmField(by, 'Deposited by', hint: 'Plaintiff'),
          SizedBox(height: 10.h),
          CmField(rec, 'Received so far (₹)', keyboard: const TextInputType.numberWithOptions(decimal: true)),
          SizedBox(height: 10.h),
          CmDateField(label: 'Received on', value: on, onPicked: (d) => ss(() => on = d)),
          SizedBox(height: 16.h),
          CmButton('Save', icon: Icons.check_rounded, onPressed: () async {
            await CommissionService.updateCommission(c.id, {
              'fee_fixed': double.tryParse(fixed.text.replaceAll(',', '')),
              'fee_deposited_by': by.text.trim().isEmpty ? null : by.text.trim(),
              'fee_received': double.tryParse(rec.text.replaceAll(',', '')),
              'fee_received_on': on?.toIso8601String().split('T').first,
            });
            if (ctx.mounted) Navigator.pop(ctx, true);
          }),
        ],
      ),
    );
    if (saved == true) _refresh(ref);
  }

  Future<void> _addExpense(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController();
    final desc = TextEditingController();
    var type = ExpenseType.travel;
    DateTime on = DateTime.now();
    String? err;
    final saved = await showCmSheet<bool>(
      context,
      title: 'Add expense',
      builder: (ctx, ss) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in ExpenseType.values)
                ChoiceChip(label: Text(t.label), selected: type == t, onSelected: (_) => ss(() => type = t)),
            ],
          ),
          SizedBox(height: 10.h),
          CmField(amount, 'Amount (₹)', keyboard: const TextInputType.numberWithOptions(decimal: true)),
          SizedBox(height: 10.h),
          CmField(desc, 'What for', hint: 'Tenkasi ↔ Idaikal, 2nd visit'),
          SizedBox(height: 10.h),
          CmDateField(label: 'Date', value: on, onPicked: (d) => ss(() => on = d)),
          if (err != null) ...[SizedBox(height: 10.h), Text(err!, style: Cm.body(ctx, color: AppTheme.error))],
          SizedBox(height: 16.h),
          CmButton('Add', icon: Icons.check_rounded, onPressed: () async {
            final a = double.tryParse(amount.text.replaceAll(',', ''));
            if (a == null || a <= 0) return ss(() => err = 'Enter the amount');
            await CommissionService.createExpense({
              'commission_id': commissionId,
              'expense_type': type.dbValue,
              'amount': a,
              'description': desc.text.trim().isEmpty ? null : desc.text.trim(),
              'expense_date': on.toIso8601String().split('T').first,
            });
            if (ctx.mounted) Navigator.pop(ctx, true);
          }),
        ],
      ),
    );
    if (saved == true) _refresh(ref);
  }
}
