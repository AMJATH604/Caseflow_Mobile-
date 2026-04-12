import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';

class InterestCalculator extends StatefulWidget {
  const InterestCalculator({super.key});

  @override
  State<InterestCalculator> createState() => _InterestCalculatorState();
}

class _InterestCalculatorState extends State<InterestCalculator> {
  final _principalController = TextEditingController();
  final _customRateController = TextEditingController();
  String _rate = "12";
  DateTime? _fromDate;
  DateTime? _toDate;
  String _interestType = "simple";

  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _principalController.addListener(_calculate);
    _customRateController.addListener(_calculate);
  }

  @override
  void dispose() {
    _principalController.dispose();
    _customRateController.dispose();
    super.dispose();
  }

  void _calculate() {
    final principal = double.tryParse(_principalController.text);
    final rateValue = _rate == "custom" ? double.tryParse(_customRateController.text) : double.tryParse(_rate);

    if (principal == null || rateValue == null || _fromDate == null || _toDate == null) return;

    final days = _toDate!.difference(_fromDate!).inDays;
    if (days < 0) return;

    final timeInYears = days / 365.25;
    double interest = 0;

    if (_interestType == "simple") {
      interest = (principal * rateValue * days) / 36500;
    } else {
      // Compound interest (Annually)
      interest = (principal * (double.parse((1 + rateValue / 100).toString()) * (timeInYears == 0 ? 1 : (principal * 0)))) - principal;
      // Fixed Compound Formula: P * (1 + r/n)^(nt)
      // For annual: P(1 + r)^t - P
      final amount = principal * math.pow((1 + rateValue / 100), timeInYears);
      interest = amount - principal;
    }

    final total = principal + interest;
    
    final formattedPrincipal = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(principal);
    final formattedInterest = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(interest);
    final formattedTotal = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(total);
    final formattedFrom = DateFormat('dd-MM-yyyy').format(_fromDate!);
    final formattedTo = DateFormat('dd-MM-yyyy').format(_toDate!);

    final text = "Interest on $formattedPrincipal/- from $formattedFrom to $formattedTo ($days days) at $rateValue% p.a. is $formattedInterest/-. Total amount payable: $formattedTotal/-";

    setState(() {
      _result = {
        "days": days,
        "interest": interest,
        "total": total,
        "text": text,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPrincipalInput(),
          const SizedBox(height: 16),
          _buildRateSelector(),
          const SizedBox(height: 16),
          _buildDateRange(),
          const SizedBox(height: 16),
          _buildInterestTypeSelector(),
          const SizedBox(height: 24),
          if (_result != null) _buildResultView(),
        ],
      ),
    );
  }

  Widget _buildPrincipalInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Principal Amount (₹)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: _principalController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.currency_rupee, size: 18),
            hintText: "Ex. 100000",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
          ),
        ),
      ],
    );
  }

  Widget _buildRateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Interest Rate (% p.a.)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _rate,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: "6", child: Text("6% (Civil)")),
                      DropdownMenuItem(value: "9", child: Text("9% (NI Act)")),
                      DropdownMenuItem(value: "12", child: Text("12% (Comm)")),
                      DropdownMenuItem(value: "18", child: Text("18% (Pvt)")),
                      DropdownMenuItem(value: "24", child: Text("24%")),
                      DropdownMenuItem(value: "custom", child: Text("Custom")),
                    ],
                    onChanged: (val) {
                      setState(() => _rate = val!);
                      _calculate();
                    },
                  ),
                ),
              ),
            ),
            if (_rate == "custom") ...[
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _customRateController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "Rate %",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.border)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDateRange() {
    return Row(
      children: [
        Expanded(child: _buildDatePicker("From Date", _fromDate, (d) => setState(() { _fromDate = d; _calculate(); }))),
        const SizedBox(width: 16),
        Expanded(child: _buildDatePicker("To Date", _toDate, (d) => setState(() { _toDate = d; _calculate(); }))),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(value == null ? "Select" : DateFormat('dd-MM-yyyy').format(value)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInterestTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Interest Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              _buildTypeTab("simple", "Simple"),
              _buildTypeTab("compound", "Compound"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeTab(String type, String label) {
    bool isSelected = _interestType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _interestType = type);
          _calculate();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppTheme.primary : Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildResultView() {
    final cur = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat("Days", _result!['days'].toString()),
                  _buildStat("Interest", cur.format(_result!['interest'])),
                  _buildStat("Total", cur.format(_result!['total'])),
                ],
              ),
              const Divider(height: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Plaint Text (Ready to Copy)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
                    child: Text(_result!['text'], style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _result!['text']));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard")));
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text("Copy Text"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
