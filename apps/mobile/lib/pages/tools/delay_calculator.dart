import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class DelayCalculator extends StatefulWidget {
  const DelayCalculator({super.key});

  @override
  State<DelayCalculator> createState() => _DelayCalculatorState();
}

class _DelayCalculatorState extends State<DelayCalculator> {
  DateTime? _orderDate;
  DateTime? _filingDate = DateTime.now();
  String _limitationDays = "30";
  final TextEditingController _customDaysController = TextEditingController();

  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _customDaysController.addListener(_calculate);
  }

  @override
  void dispose() {
    _customDaysController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (_orderDate == null || _filingDate == null) return;

    final int days = _limitationDays == "custom" 
        ? int.tryParse(_customDaysController.text) ?? 0 
        : int.parse(_limitationDays);

    final dueDate = _orderDate!.add(Duration(days: days));
    final isDelayed = _filingDate!.isAfter(dueDate);
    final delayDays = isDelayed ? _filingDate!.difference(dueDate).inDays : 0;

    final fmt = DateFormat('dd.MM.yyyy');
    final formattedOrder = fmt.format(_orderDate!);
    final formattedDue = fmt.format(dueDate);
    final formattedFiling = fmt.format(_filingDate!);

    String text = "";
    if (isDelayed) {
      text = "The order was passed on $formattedOrder. The limitation of $days days expired on $formattedDue. However, the petition is being filed on $formattedFiling. Accordingly, there is a delay of $delayDays days in filing the above petition.";
    } else {
      text = "The order was passed on $formattedOrder. The limitation of $days days expires on $formattedDue. The petition is being filed on $formattedFiling, which is within the period of limitation.";
    }

    setState(() {
      _result = {
        "dueDate": dueDate,
        "delayDays": delayDays,
        "isDelayed": isDelayed,
        "text": text,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildParamCard(),
          const SizedBox(height: 24),
          if (_result != null) _buildResultCard(),
        ],
      ),
    );
  }

  Widget _buildParamCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Delay Parameters", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
          const SizedBox(height: 16),
          _buildDatePicker("Date of Order / Judgment", _orderDate, (d) => setState(() { _orderDate = d; _calculate(); })),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildLimitationSelector()),
              if (_limitationDays == "custom") ...[
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _customDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Enter Days", border: OutlineInputBorder()),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _buildDatePicker("Actual / Proposed Filing Date", _filingDate, (d) => setState(() { _filingDate = d; _calculate(); })),
        ],
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
            onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(value == null ? "Select Date" : DateFormat('dd MMM yyyy').format(value)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLimitationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Limitation Period", style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _limitationDays,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: "30", child: Text("30 Days")),
            DropdownMenuItem(value: "60", child: Text("60 Days")),
            DropdownMenuItem(value: "90", child: Text("90 Days")),
            DropdownMenuItem(value: "custom", child: Text("Custom")),
          ],
          onChanged: (v) => setState(() { _limitationDays = v!; _calculate(); }),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    bool delayed = _result!['isDelayed'];
    Color color = delayed ? Colors.red : Colors.green;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(delayed ? Icons.error_outline : Icons.check_circle_outline, color: color),
              const SizedBox(width: 8),
              Text(delayed ? "Delay Detected" : "Within Limitation", style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoItem("Due Date", DateFormat('dd MMM yyyy').format(_result!['dueDate']))),
              Expanded(child: _buildInfoItem("Days of Delay", "${_result!['delayDays']} Days", valueColor: color)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Align(alignment: Alignment.centerLeft, child: Text("Affidavit Text", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.border)),
            child: Text(_result!['text'], style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _result!['text']));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard")));
              },
              icon: const Icon(Icons.copy),
              label: const Text("Copy Affidavit Text"),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor)),
      ],
    );
  }
}
