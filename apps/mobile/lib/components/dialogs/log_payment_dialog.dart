import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';

class LogPaymentDialog extends ConsumerStatefulWidget {
  const LogPaymentDialog({super.key});

  @override
  ConsumerState<LogPaymentDialog> createState() => _LogPaymentDialogState();
}

class _LogPaymentDialogState extends ConsumerState<LogPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCaseId;
  final _totalFeeController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _transactionType = 'revenue'; // 'revenue' (Payment) or 'expense'
  String _paymentMode = 'upi';
  DateTime? _date = DateTime.now();
  bool _isSaving = false;

  // Existing payment data for this case
  bool _isLoadingSummary = false;
  bool _hasExistingPayments = false;
  double _existingTotalFee = 0;
  double _existingTotalPaid = 0;
  double _existingTotalExpenses = 0;
  double _existingBalance = 0;

  @override
  void dispose() {
    _totalFeeController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// When a case is selected, check for existing payments
  Future<void> _onCaseSelected(String? caseId) async {
    setState(() {
      _selectedCaseId = caseId;
      _hasExistingPayments = false;
      _existingTotalFee = 0;
      _existingTotalPaid = 0;
      _existingTotalExpenses = 0;
      _existingBalance = 0;
      _totalFeeController.clear();
      _amountController.clear();
      _notesController.clear();
    });

    if (caseId == null) return;

    setState(() => _isLoadingSummary = true);
    try {
      final summary = await SupabaseService.fetchCasePaymentSummary(caseId);
      if (!mounted) return;

      if (summary['total_fee']! > 0) {
        setState(() {
          _hasExistingPayments = true;
          _existingTotalFee = summary['total_fee']!;
          _existingTotalPaid = summary['total_paid']!;
          _existingTotalExpenses = summary['total_expenses'] ?? 0;
          _existingBalance = summary['balance']!;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingSummary = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedCaseId == null) return;

    setState(() => _isSaving = true);
    try {
      final amount = double.tryParse(_amountController.text) ?? 0;

      if (_hasExistingPayments) {
        // ─── ADD LEDGER ENTRY ───
        await SupabaseService.addPaymentInstallment({
          'case_id': _selectedCaseId,
          'total_fee': _existingTotalFee,
          'paid_amount': amount,
          'transaction_type': _transactionType,
          'notes': _notesController.text.trim(),
          'payment_mode': _paymentMode,
          'paid_date': DateFormat('yyyy-MM-dd').format(_date!),
        });
      } else {
        // ─── INITIAL RECORD ───
        final total = double.tryParse(_totalFeeController.text) ?? 0;

        await SupabaseService.createPayment({
          'case_id': _selectedCaseId,
          'total_fee': total,
          'paid_amount': amount,
          'transaction_type': _transactionType,
          'notes': _notesController.text.trim(),
          'payment_mode': _paymentMode,
          'paid_date': DateFormat('yyyy-MM-dd').format(_date!),
        });
      }

      ref.invalidate(paymentsProvider);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(casesProvider);
    final fmt = NumberFormat('#,##,###');
    final isExpense = _transactionType == 'expense';
    final themeColor = isExpense ? AppTheme.error : AppTheme.success;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Header ───
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: themeColor.withValues(alpha: 0.1),
                    child: Icon(
                      isExpense
                          ? Icons.outbound_rounded
                          : Icons.payments_rounded,
                      color: themeColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    isExpense
                        ? 'Log Office Expense'
                        : (_hasExistingPayments
                            ? 'Add Payment'
                            : 'New Financial Record'),
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Transaction Type Toggle ───
                      if (_hasExistingPayments) ...[
                        Text(
                          'Transaction Type',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildTypeOption(
                              'revenue',
                              'Payment Received',
                              Icons.call_received_rounded,
                              AppTheme.success,
                            ),
                            const SizedBox(width: 12),
                            _buildTypeOption(
                              'expense',
                              'Expense Incurred',
                              Icons.call_made_rounded,
                              AppTheme.error,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ─── Case Selector ───
                      casesAsync.when(
                        data:
                            (cases) => DropdownButtonFormField<String>(
                              initialValue: _selectedCaseId,
                              style: GoogleFonts.inter(
                                color: AppTheme.primary,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Select Case',
                                prefixIcon: const Icon(
                                  Icons.folder_shared_outlined,
                                ),
                                filled: true,
                                fillColor: AppTheme.background.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              items:
                                  cases
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(
                                            c.caseTitle.isEmpty
                                                ? (c.caseNumber ??
                                                    'Case #${c.id.substring(0, 4)}')
                                                : c.caseTitle,
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: _onCaseSelected,
                              validator: (v) => v == null ? 'Required' : null,
                            ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, s) => Text('Error: $e'),
                      ),
                      const SizedBox(height: 20),

                      // ─── Summary Snapshot ───
                      if (_hasExistingPayments && !_isLoadingSummary)
                        _buildSummarySnapshot(fmt),

                      // ─── Amount & Fee Fields ───
                      if (!_hasExistingPayments &&
                          !_isLoadingSummary &&
                          _selectedCaseId != null) ...[
                        TextFormField(
                          controller: _totalFeeController,
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            labelText: 'Agreed Total Fee (₹)',
                            prefixIcon: Icon(
                              Icons.account_balance_wallet_outlined,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator:
                              (v) => v!.isEmpty ? 'Total fee required' : null,
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (_selectedCaseId != null && !_isLoadingSummary)
                        TextFormField(
                          controller: _amountController,
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                isExpense
                                    ? 'Expense Amount (₹)'
                                    : 'Payment Amount (₹)',
                            prefixIcon: Icon(
                              isExpense
                                  ? Icons.remove_circle_outline
                                  : Icons.add_circle_outline,
                              color: themeColor,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator:
                              (v) =>
                                  (double.tryParse(v ?? '') ?? 0) <= 0
                                      ? 'Enter valid amount'
                                      : null,
                        ),

                      const SizedBox(height: 20),

                      // ─── Notes ───
                      if (_selectedCaseId != null && !_isLoadingSummary)
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notes / Description',
                            hintText: 'e.g. Court Fee, Xerox, Advance...',
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // ─── Mode & Date ───
                      if (_selectedCaseId != null && !_isLoadingSummary)
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                initialValue: _paymentMode,
                                decoration: const InputDecoration(
                                  labelText: 'Mode',
                                ),
                                items:
                                    ['upi', 'cash', 'bank_transfer', 'cheque']
                                        .map(
                                          (m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(m.toUpperCase()),
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (v) => setState(() => _paymentMode = v!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _date ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setState(() => _date = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Date',
                                  ),
                                  child: Text(
                                    DateFormat('dd MMM').format(_date!),
                                  ),
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

            // ─── Actions ───
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child:
                          _isSaving
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Text(
                                isExpense ? 'Log Expense' : 'Save Record',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(
    String type,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _transactionType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _transactionType = type),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : AppTheme.border),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : color, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySnapshot(NumberFormat fmt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _summaryLine(
            'Agreed Fee',
            '₹${fmt.format(_existingTotalFee)}',
            AppTheme.primary,
          ),
          const SizedBox(height: 8),
          _summaryLine(
            'Total Paid',
            '₹${fmt.format(_existingTotalPaid)}',
            AppTheme.success,
          ),
          const SizedBox(height: 8),
          _summaryLine(
            'Total Expenses',
            '₹${fmt.format(_existingTotalExpenses)}',
            AppTheme.error,
          ),
          const Divider(height: 20),
          _summaryLine(
            'Current Owed',
            '₹${fmt.format(_existingBalance)}',
            _existingBalance > 0 ? AppTheme.error : AppTheme.success,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
