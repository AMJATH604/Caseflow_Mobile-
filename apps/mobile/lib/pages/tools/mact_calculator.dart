import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class MactCalculator extends StatefulWidget {
  const MactCalculator({super.key});

  @override
  State<MactCalculator> createState() => _MactCalculatorState();
}

class _MactCalculatorState extends State<MactCalculator> {
  final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  // ─── Inputs ──
  final TextEditingController _incomeCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _medicalCtrl = TextEditingController();
  String _employmentType = 'Salaried'; // Salaried or Self-Employed
  String _dependentCategory = '2-3 Dependents';
  bool _isDeathCase = true; // Death or Permanent Disability

  // ─── Output ──
  List<Map<String, dynamic>> _results = [];
  List<String> _steps = [];
  bool _showResults = false;
  double _totalCompensation = 0;

  // ─── Sarla Verma Multiplier Table (2009) 4 SCC 422 ──
  int _getMultiplier(int age) {
    if (age <= 15) return 15;
    if (age <= 20) return 18;
    if (age <= 25) return 17;
    if (age <= 30) return 16;
    if (age <= 35) return 15;
    if (age <= 40) return 14;
    if (age <= 45) return 13;
    if (age <= 50) return 12;
    if (age <= 55) return 11;
    if (age <= 60) return 9;
    if (age <= 65) return 7;
    return 5;
  }

  // ─── Pranay Sethi Future Prospects % (2017) 16 SCC 680 ──
  double _getFutureProspects(int age) {
    if (_employmentType == 'Salaried') {
      if (age < 40) return 0.50;
      if (age <= 50) return 0.30;
      return 0.15;
    } else {
      if (age < 40) return 0.40;
      if (age <= 50) return 0.25;
      return 0.10;
    }
  }

  String _getFutureProspectsLabel(int age) {
    if (_employmentType == 'Salaried') {
      if (age < 40) return '50% (Salaried, below 40)';
      if (age <= 50) return '30% (Salaried, 40-50)';
      return '15% (Salaried, above 50)';
    } else {
      if (age < 40) return '40% (Self-employed, below 40)';
      if (age <= 50) return '25% (Self-employed, 40-50)';
      return '10% (Self-employed, above 50)';
    }
  }

  // ─── Personal Expense Deduction (Sarla Verma) ──
  double _getDeductionFraction() {
    switch (_dependentCategory) {
      case 'Bachelor / No Dependents': return 0.50;
      case '2-3 Dependents': return 1/3;
      case '4-6 Dependents': return 0.25;
      case '6+ Dependents': return 0.20;
      default: return 1/3;
    }
  }

  String _getDeductionLabel() {
    switch (_dependentCategory) {
      case 'Bachelor / No Dependents': return '1/2 (50%)';
      case '2-3 Dependents': return '1/3 (33.33%)';
      case '4-6 Dependents': return '1/4 (25%)';
      case '6+ Dependents': return '1/5 (20%)';
      default: return '1/3';
    }
  }

  void _calculate() {
    _results.clear();
    _steps.clear();
    _totalCompensation = 0;

    double monthlyIncome = double.tryParse(_incomeCtrl.text.replaceAll(',', '')) ?? 0;
    int age = int.tryParse(_ageCtrl.text) ?? 0;
    double medicalExp = double.tryParse(_medicalCtrl.text.replaceAll(',', '')) ?? 0;

    if (monthlyIncome <= 0 || age <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter income and age of the deceased/injured'), backgroundColor: Colors.red),
      );
      return;
    }

    double annualIncome = monthlyIncome * 12;
    int multiplier = _getMultiplier(age);
    double futureProspectsPct = _getFutureProspects(age);
    double deductionFraction = _getDeductionFraction();

    _steps.add("🚗 MACT Compensation Calculation");
    _steps.add("Authority: Sarla Verma v. Delhi Transport Corp. (2009) 6 SCC 121");
    _steps.add("Future Prospects: National Insurance Co. v. Pranay Sethi (2017) 16 SCC 680");
    _steps.add("");

    // Step 1: Annual Income
    _steps.add("Step 1: Determine Annual Income");
    _steps.add("  Monthly income = ${fmt.format(monthlyIncome)}");
    _steps.add("  Annual income = ${fmt.format(monthlyIncome)} × 12 = ${fmt.format(annualIncome)}");
    _steps.add("");

    // Step 2: Future Prospects
    double futureProspectsAmount = annualIncome * futureProspectsPct;
    double incomeWithFP = annualIncome + futureProspectsAmount;
    _steps.add("Step 2: Add Future Prospects (Pranay Sethi)");
    _steps.add("  Age: $age years → Addition: ${_getFutureProspectsLabel(age)}");
    _steps.add("  Future prospects = ${fmt.format(annualIncome)} × ${(futureProspectsPct * 100).toStringAsFixed(0)}% = ${fmt.format(futureProspectsAmount)}");
    _steps.add("  Income after future prospects = ${fmt.format(incomeWithFP)}");
    _steps.add("");

    // Step 3: Deduction for Personal Expenses
    double deductionAmount = incomeWithFP * deductionFraction;
    double netAnnualDependency = incomeWithFP - deductionAmount;
    _steps.add("Step 3: Deduct Personal Expenses");
    _steps.add("  Category: $_dependentCategory → Deduction: ${_getDeductionLabel()}");
    _steps.add("  Deduction = ${fmt.format(incomeWithFP)} × ${_getDeductionLabel()} = ${fmt.format(deductionAmount)}");
    _steps.add("  Net annual dependency = ${fmt.format(netAnnualDependency)}");
    _steps.add("");

    // Step 4: Apply Multiplier
    double lossOfDependency = netAnnualDependency * multiplier;
    _steps.add("Step 4: Apply Multiplier (Sarla Verma Table)");
    _steps.add("  Age: $age years → Multiplier: $multiplier");
    _steps.add("  Loss of dependency = ${fmt.format(netAnnualDependency)} × $multiplier = ${fmt.format(lossOfDependency)}");
    _steps.add("");

    _results.add({'head': 'Loss of Dependency', 'amount': lossOfDependency, 'details': '${fmt.format(netAnnualDependency)}/yr × $multiplier'});
    _totalCompensation += lossOfDependency;

    // Step 5: Conventional Heads (Pranay Sethi)
    _steps.add("Step 5: Add Conventional Heads (Pranay Sethi)");

    // Funeral Expenses
    double funeral = 15000;
    _steps.add("  Funeral expenses = ${fmt.format(funeral)}");
    _results.add({'head': 'Funeral Expenses', 'amount': funeral, 'details': 'Pranay Sethi standard'});
    _totalCompensation += funeral;

    // Loss of Estate
    double lossOfEstate = 15000;
    _steps.add("  Loss of estate = ${fmt.format(lossOfEstate)}");
    _results.add({'head': 'Loss of Estate', 'amount': lossOfEstate, 'details': 'Pranay Sethi standard'});
    _totalCompensation += lossOfEstate;

    // Loss of Consortium
    double consortium = 40000;
    if (_dependentCategory != 'Bachelor / No Dependents') {
      _steps.add("  Loss of consortium (spouse) = ${fmt.format(consortium)}");
      _results.add({'head': 'Loss of Consortium', 'amount': consortium, 'details': 'For spouse'});
      _totalCompensation += consortium;

      // Filial consortium for minor children (Magma General Insurance v. Nanu Ram, 2018)
      double filialConsortium = 40000;
      _steps.add("  Filial consortium (children) = ${fmt.format(filialConsortium)}");
      _results.add({'head': 'Filial Consortium', 'amount': filialConsortium, 'details': 'For minor children'});
      _totalCompensation += filialConsortium;
    }

    // Medical Expenses
    if (medicalExp > 0) {
      _steps.add("  Medical expenses = ${fmt.format(medicalExp)}");
      _results.add({'head': 'Medical Expenses', 'amount': medicalExp, 'details': 'As per bills'});
      _totalCompensation += medicalExp;
    }

    _steps.add("");
    _steps.add("═══════════════════════════════════════");
    _steps.add("TOTAL COMPENSATION = ${fmt.format(_totalCompensation)}");

    setState(() => _showResults = true);
  }

  void _copyToClipboard() {
    StringBuffer sb = StringBuffer();
    sb.writeln("═══════════════════════════════════════════");
    sb.writeln("   MACT COMPENSATION CALCULATION MEMO");
    sb.writeln("═══════════════════════════════════════════");
    sb.writeln("Deceased/Injured Age: ${_ageCtrl.text} years");
    sb.writeln("Monthly Income     : ${_incomeCtrl.text}");
    sb.writeln("Employment Type    : $_employmentType");
    sb.writeln("Dependents         : $_dependentCategory");
    sb.writeln("───────────────────────────────────────────\n");
    sb.writeln("SCHEDULE OF COMPENSATION:\n");
    int sno = 1;
    for (var r in _results) {
      sb.writeln("${sno.toString().padLeft(2)}. ${r['head'].toString().padRight(24)} ${fmt.format(r['amount'])}");
      sno++;
    }
    sb.writeln("──────────────────────────────────────────");
    sb.writeln("   TOTAL:                    ${fmt.format(_totalCompensation)}");
    sb.writeln("\nCOMPUTATION STEPS:\n");
    for (var s in _steps) {
      if (s.isNotEmpty) sb.writeln("  $s");
    }
    sb.writeln("\n═══════════════════════════════════════════");
    sb.writeln("Authority: Sarla Verma v. DTC (2009) 6 SCC 121");
    sb.writeln("           NICL v. Pranay Sethi (2017) 16 SCC 680");
    sb.writeln("Generated by CaseFlow on ${DateFormat('dd.MM.yyyy').format(DateTime.now())}");

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 18), SizedBox(width: 8), Text('MACT memo copied!')]),
        backgroundColor: Colors.green[700], behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() { _incomeCtrl.dispose(); _ageCtrl.dispose(); _medicalCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ─── Inputs ──
          _card(isDark, Icons.directions_car, Colors.red, "Accident Details", children: [
            if (isMobile) ...[
              TextField(controller: _ageCtrl, decoration: const InputDecoration(labelText: 'Age of Deceased/Injured', border: OutlineInputBorder(), suffixText: 'years'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: _incomeCtrl, decoration: const InputDecoration(labelText: 'Monthly Income (₹)', border: OutlineInputBorder(), prefixText: '₹ '), keyboardType: TextInputType.number),
            ] else
              Row(children: [
                Expanded(child: TextField(controller: _ageCtrl, decoration: const InputDecoration(labelText: 'Age of Deceased/Injured', border: OutlineInputBorder(), suffixText: 'years'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _incomeCtrl, decoration: const InputDecoration(labelText: 'Monthly Income (₹)', border: OutlineInputBorder(), prefixText: '₹ '), keyboardType: TextInputType.number)),
              ]),
            const SizedBox(height: 12),
            if (isMobile) ...[
              DropdownButtonFormField<String>(
                value: _employmentType, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Employment Type', border: OutlineInputBorder()),
                items: const [DropdownMenuItem(value: 'Salaried', child: Text('Salaried / Govt.')), DropdownMenuItem(value: 'Self-Employed', child: Text('Self-Employed / Business'))],
                onChanged: (v) => setState(() => _employmentType = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _dependentCategory, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Dependents', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Bachelor / No Dependents', child: Text('Bachelor / No Dependents')),
                  DropdownMenuItem(value: '2-3 Dependents', child: Text('2-3 Dependents (Spouse + Children)')),
                  DropdownMenuItem(value: '4-6 Dependents', child: Text('4-6 Dependents')),
                  DropdownMenuItem(value: '6+ Dependents', child: Text('6+ Dependents')),
                ],
                onChanged: (v) => setState(() => _dependentCategory = v!),
              ),
            ] else
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _employmentType, isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Employment Type', border: OutlineInputBorder()),
                  items: const [DropdownMenuItem(value: 'Salaried', child: Text('Salaried / Govt.')), DropdownMenuItem(value: 'Self-Employed', child: Text('Self-Employed / Business'))],
                  onChanged: (v) => setState(() => _employmentType = v!),
                )),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(
                  value: _dependentCategory, isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Dependents', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Bachelor / No Dependents', child: Text('Bachelor / No Dependents')),
                    DropdownMenuItem(value: '2-3 Dependents', child: Text('2-3 Dependents')),
                    DropdownMenuItem(value: '4-6 Dependents', child: Text('4-6 Dependents')),
                    DropdownMenuItem(value: '6+ Dependents', child: Text('6+ Dependents')),
                  ],
                  onChanged: (v) => setState(() => _dependentCategory = v!),
                )),
              ]),
            const SizedBox(height: 12),
            TextField(controller: _medicalCtrl, decoration: const InputDecoration(labelText: 'Medical Expenses (₹) — Optional', border: OutlineInputBorder(), prefixText: '₹ '), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate_rounded, size: 20),
                label: const Text("CALCULATE COMPENSATION", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),

          if (_showResults) ...[
            const SizedBox(height: 16),

            // ─── Multiplier Reference ──
            _card(isDark, Icons.table_chart, Colors.blue, "Sarla Verma Multiplier Applied", children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.red.withValues(alpha: 0.08), Colors.orange.withValues(alpha: 0.04)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statBubble("Age", "${_ageCtrl.text} yrs", Colors.blue),
                    _statBubble("Multiplier", "${_getMultiplier(int.tryParse(_ageCtrl.text) ?? 0)}×", Colors.red),
                    _statBubble("Future Prospects", "${(_getFutureProspects(int.tryParse(_ageCtrl.text) ?? 0) * 100).toStringAsFixed(0)}%", Colors.green),
                    _statBubble("Deduction", _getDeductionLabel().split(' ')[0], Colors.orange),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // ─── Results ──
            _card(isDark, Icons.receipt_long, Colors.green, "Compensation Breakdown", trailing: TextButton.icon(
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy_rounded, size: 14), label: const Text("Copy", style: TextStyle(fontSize: 12)),
            ), children: [
              // Total
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.withValues(alpha: 0.1), AppTheme.primary.withValues(alpha: 0.05)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL COMPENSATION", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(fmt.format(_totalCompensation), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.green)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              ..._results.map((r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r['head'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      if (r['details'] != null) Text(r['details'], style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ])),
                    Text(fmt.format(r['amount']), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.primary)),
                  ],
                ),
              )),
            ]),

            const SizedBox(height: 16),

            // ─── How It Was Calculated ──
            _card(isDark, Icons.school_rounded, Colors.deepPurple, "How It Was Calculated", children: [
              Text("Step-by-step computation based on Supreme Court judgments:", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _steps.map((s) {
                    if (s.isEmpty) return const SizedBox(height: 8);
                    bool isHeader = s.startsWith("Step") || s.startsWith("🚗") || s.startsWith("Authority") || s.startsWith("═");
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(s, style: TextStyle(
                        fontSize: 13, fontWeight: isHeader ? FontWeight.w700 : FontWeight.normal,
                        color: isDark ? (isHeader ? Colors.white : Colors.grey[300]) : (isHeader ? Colors.black87 : Colors.grey[700]),
                        height: 1.5,
                      )),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _statBubble(String label, String value, Color color) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500])),
    ]);
  }

  Widget _card(bool isDark, IconData icon, Color iconColor, String title, {Widget? trailing, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(isDark: isDark),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          if (trailing != null) trailing,
        ]),
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }
}
