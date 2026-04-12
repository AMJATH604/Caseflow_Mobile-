import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class LimitationCalculator extends StatefulWidget {
  const LimitationCalculator({super.key});

  @override
  State<LimitationCalculator> createState() => _LimitationCalculatorState();
}

class _LimitationCalculatorState extends State<LimitationCalculator> {
  DateTime? _startDate;
  final TextEditingController _periodController = TextEditingController();
  String _unit = "days";
  DateTime? _resultDate;

  @override
  void initState() {
    super.initState();
    _periodController.addListener(_calculate);
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (_startDate == null || _periodController.text.isEmpty) return;

    final amount = int.tryParse(_periodController.text) ?? 0;
    DateTime end;

    if (_unit == "days") {
      end = _startDate!.add(Duration(days: amount));
    } else if (_unit == "months") {
      // Basic month addition
      end = DateTime(_startDate!.year, _startDate!.month + amount, _startDate!.day);
    } else {
      end = DateTime(_startDate!.year + amount, _startDate!.month, _startDate!.day);
    }

    setState(() {
      _resultDate = end;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDatePicker(),
          const SizedBox(height: 16),
          _buildPeriodInput(),
          const SizedBox(height: 24),
          if (_resultDate != null) _buildResultView(),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Event Date (Judgment/Order)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
            if (picked != null) {
              setState(() => _startDate = picked);
              _calculate();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(_startDate == null ? "Select Date" : DateFormat('dd MMM yyyy').format(_startDate!)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodInput() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Period", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _periodController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: "Ex. 90", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Unit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: const [
                  DropdownMenuItem(value: "days", child: Text("Days")),
                  DropdownMenuItem(value: "months", child: Text("Months")),
                  DropdownMenuItem(value: "years", child: Text("Years")),
                ],
                onChanged: (v) {
                  setState(() => _unit = v!);
                  _calculate();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1))),
      child: Column(
        children: [
          const Text("DEADLINE DATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(DateFormat('dd MMM yyyy').format(_resultDate!), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary)),
        ],
      ),
    );
  }
}
