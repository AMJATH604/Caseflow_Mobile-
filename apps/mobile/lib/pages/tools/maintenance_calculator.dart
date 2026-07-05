import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MaintenanceCalculator extends StatefulWidget {
  const MaintenanceCalculator({super.key});

  @override
  State<MaintenanceCalculator> createState() => _MaintenanceCalculatorState();
}

class _MaintenanceCalculatorState extends State<MaintenanceCalculator> {
  final fmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  // ─── Inputs ──
  final TextEditingController _husbandIncomeCtrl = TextEditingController();
  final TextEditingController _wifeIncomeCtrl = TextEditingController();
  int _childCount = 0;
  String _maintenanceType = 'Interim'; // Interim or Final
  String _lawType = 'Sec 144 BNSS'; // or Hindu or Muslim
  final bool _wifeWorkingCapable = false;

  // ─── Output ──
  final List<Map<String, dynamic>> _results = [];
  final List<String> _steps = [];
  bool _showResults = false;
  double _totalMaintenance = 0;

  @override
  void dispose() {
    _husbandIncomeCtrl.dispose();
    _wifeIncomeCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    _results.clear();
    _steps.clear();
    _totalMaintenance = 0;

    final double husbandIncome =
        double.tryParse(_husbandIncomeCtrl.text.replaceAll(',', '')) ?? 0;
    final double wifeIncome =
        double.tryParse(_wifeIncomeCtrl.text.replaceAll(',', '')) ?? 0;

    if (husbandIncome <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the husband\'s monthly income'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double netHusbandIncome = husbandIncome;

    _steps.add('⚖️ Maintenance Calculation');
    _steps.add('Law: $_lawType');
    _steps.add('Type: $_maintenanceType Maintenance');
    if (_lawType == 'Sec 144 BNSS') {
      _steps.add('Authority: Rajnesh v. Neha (2021) 1 SCC 55');
    } else if (_lawType == 'Hindu (HAMA)') {
      _steps.add('Authority: Hindu Adoptions & Maintenance Act, 1956');
    } else {
      _steps.add(
        'Authority: Muslim Personal Law (Shariat) Application Act, 1937',
      );
    }
    _steps.add('');

    // Step 1: Husband's Net Income
    _steps.add("Step 1: Determine Husband's Net Monthly Income");
    _steps.add('  Gross monthly income = ${fmt.format(husbandIncome)}');

    // Rajnesh v. Neha: Deduct tax and essential expenses (approx 10%)
    final double taxDeduction = husbandIncome * 0.10;
    netHusbandIncome = husbandIncome - taxDeduction;
    _steps.add('  Less estimated tax/PF (10%) = ${fmt.format(taxDeduction)}');
    _steps.add('  Net monthly income = ${fmt.format(netHusbandIncome)}');
    _steps.add('');

    // Step 2: Wife's Maintenance
    _steps.add("Step 2: Calculate Wife's Maintenance");

    double wifeMaintenancePct;
    if (_maintenanceType == 'Interim') {
      wifeMaintenancePct = 0.25; // 25% for interim
      _steps.add('  Interim maintenance rate: 25% of net income');
      _steps.add('  (Rajnesh v. Neha: 20%-25% typical for interim)');
    } else {
      wifeMaintenancePct = 0.30; // 30% for final
      _steps.add('  Final maintenance rate: 30% of net income');
      _steps.add('  (Courts typically award 25%-33% as permanent)');
    }

    final double wifeMaintenanceGross = netHusbandIncome * wifeMaintenancePct;

    // Deduct wife's own income if she's earning
    double wifeMaintenanceFinal = wifeMaintenanceGross;
    if (wifeIncome > 0) {
      wifeMaintenanceFinal =
          wifeMaintenanceGross -
          (wifeIncome * 0.5); // Deduct 50% of wife's income
      if (wifeMaintenanceFinal < 0) wifeMaintenanceFinal = 0;
      _steps.add(
        '  Gross wife maintenance = ${fmt.format(netHusbandIncome)} × ${(wifeMaintenancePct * 100).toStringAsFixed(0)}% = ${fmt.format(wifeMaintenanceGross)}',
      );
      _steps.add("  Wife's own income = ${fmt.format(wifeIncome)}");
      _steps.add(
        "  Less 50% of wife's income = ${fmt.format(wifeIncome * 0.5)}",
      );
      _steps.add(
        '  Net wife maintenance = ${fmt.format(wifeMaintenanceFinal)}',
      );
    } else {
      _steps.add(
        '  Wife maintenance = ${fmt.format(netHusbandIncome)} × ${(wifeMaintenancePct * 100).toStringAsFixed(0)}% = ${fmt.format(wifeMaintenanceFinal)}',
      );
      _steps.add('  Wife has no independent income.');
    }

    _results.add({
      'head': 'Wife\'s Maintenance',
      'amount': wifeMaintenanceFinal,
      'details':
          '${(wifeMaintenancePct * 100).toStringAsFixed(0)}% of ${fmt.format(netHusbandIncome)}',
    });
    _totalMaintenance += wifeMaintenanceFinal;
    _steps.add('');

    // Step 3: Children's Maintenance
    if (_childCount > 0) {
      _steps.add("Step 3: Calculate Children's Maintenance");

      double childPct;
      if (_maintenanceType == 'Interim') {
        childPct = 0.075; // 7.5% per child for interim
        _steps.add('  Interim: 7.5% of net income per child');
      } else {
        childPct = 0.10; // 10% per child for final
        _steps.add('  Final: 10% of net income per child');
      }

      // Cap total children's maintenance at 25%
      double totalChildPct = childPct * _childCount;
      if (totalChildPct > 0.25) {
        totalChildPct = 0.25;
        _steps.add("  ⚠️ Total children's share capped at 25% of net income");
      }

      final double perChild = (netHusbandIncome * totalChildPct) / _childCount;
      final double totalChildren = perChild * _childCount;

      _steps.add('  Per child = ${fmt.format(perChild)}/month');
      _steps.add(
        '  Total for $_childCount child(ren) = ${fmt.format(totalChildren)}/month',
      );

      for (int i = 1; i <= _childCount; i++) {
        _results.add({
          'head':
              _childCount == 1 ? 'Child Maintenance' : 'Child $i Maintenance',
          'amount': perChild,
          'details':
              '${(childPct * 100).toStringAsFixed(1)}% of ${fmt.format(netHusbandIncome)}',
        });
      }
      _totalMaintenance += totalChildren;
      _steps.add('');
    }

    // Capping check
    _steps.add(
      "Step ${_childCount > 0 ? '4' : '3'}: Total Maintenance Cap Check",
    );
    final double capPct = _totalMaintenance / netHusbandIncome;
    _steps.add('  Total maintenance = ${fmt.format(_totalMaintenance)}/month');
    _steps.add('  As % of net income = ${(capPct * 100).toStringAsFixed(1)}%');

    if (capPct > 0.50) {
      final double cappedTotal = netHusbandIncome * 0.50;
      _steps.add('  ⚠️ Exceeds 50% cap. Courts generally do not award > 50%.');
      _steps.add('  Recommended cap = ${fmt.format(cappedTotal)}/month');
      // Proportional reduction
      final double scale = cappedTotal / _totalMaintenance;
      for (var r in _results) {
        r['amount'] = (r['amount'] as double) * scale;
      }
      _totalMaintenance = cappedTotal;
    } else {
      _steps.add('  ✅ Within acceptable range (courts allow up to 50%)');
    }

    _steps.add('');
    _steps.add('═══════════════════════════════════════');
    _steps.add('TOTAL MONTHLY MAINTENANCE = ${fmt.format(_totalMaintenance)}');
    _steps.add('ANNUAL MAINTENANCE = ${fmt.format(_totalMaintenance * 12)}');

    // Muslim specific note
    if (_lawType == 'Muslim') {
      _steps.add('');
      _steps.add('Note: Under Muslim law, maintenance (Nafaqah) is during');
      _steps.add('marriage + Iddat period. Post-Iddat, wife may claim under');
      _steps.add('Sec 125 CrPC / Sec 144 BNSS (Shah Bano / Danial Latifi).');
    }

    setState(() => _showResults = true);
  }

  void _copyToClipboard() {
    final StringBuffer sb = StringBuffer();
    sb.writeln('═══════════════════════════════════════════');
    sb.writeln('   MAINTENANCE CALCULATION MEMO');
    sb.writeln('═══════════════════════════════════════════');
    sb.writeln('Law Applied       : $_lawType');
    sb.writeln('Type              : $_maintenanceType');
    sb.writeln("Husband's Income  : ${_husbandIncomeCtrl.text}");
    sb.writeln(
      "Wife's Income     : ${_wifeIncomeCtrl.text.isEmpty ? 'Nil' : _wifeIncomeCtrl.text}",
    );
    sb.writeln('Children          : $_childCount');
    sb.writeln('───────────────────────────────────────────\n');
    sb.writeln('MAINTENANCE SCHEDULE:\n');
    int sno = 1;
    for (var r in _results) {
      sb.writeln(
        "${sno.toString().padLeft(2)}. ${r['head'].toString().padRight(24)} ${fmt.format(r['amount'])}/month",
      );
      sno++;
    }
    sb.writeln('──────────────────────────────────────────');
    sb.writeln('   TOTAL PER MONTH:          ${fmt.format(_totalMaintenance)}');
    sb.writeln(
      '   TOTAL PER YEAR:           ${fmt.format(_totalMaintenance * 12)}',
    );
    sb.writeln('\nCOMPUTATION:\n');
    for (var s in _steps) {
      if (s.isNotEmpty) sb.writeln('  $s');
    }
    sb.writeln('\n═══════════════════════════════════════════');
    sb.writeln(
      "Generated by CaseFlow on ${DateFormat('dd.MM.yyyy').format(DateTime.now())}",
    );

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8.w),
            Text('Maintenance memo copied!'),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        children: [
          // ─── Inputs ──
          _card(
            isDark,
            Icons.family_restroom,
            Colors.pink,
            'Maintenance Parameters',
            children: [
              DropdownButtonFormField<String>(
                initialValue: _lawType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Applicable Law',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Sec 144 BNSS',
                    child: Text('Sec 144 BNSS (Criminal Maintenance)'),
                  ),
                  DropdownMenuItem(
                    value: 'Hindu (HAMA)',
                    child: Text('Hindu Adoptions & Maintenance Act'),
                  ),
                  DropdownMenuItem(
                    value: 'Muslim',
                    child: Text('Muslim Personal Law'),
                  ),
                ],
                onChanged:
                    (v) => setState(() {
                      _lawType = v!;
                      _showResults = false;
                    }),
              ),
              SizedBox(height: 12.h),
              if (isMobile) ...[
                DropdownButtonFormField<String>(
                  initialValue: _maintenanceType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Maintenance Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Interim',
                      child: Text('Interim (Pendente Lite)'),
                    ),
                    DropdownMenuItem(
                      value: 'Final',
                      child: Text('Final / Permanent'),
                    ),
                  ],
                  onChanged:
                      (v) => setState(() {
                        _maintenanceType = v!;
                        _showResults = false;
                      }),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _husbandIncomeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Husband\'s Monthly Income (₹)',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _wifeIncomeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Wife\'s Monthly Income (₹) — if any',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _maintenanceType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Maintenance Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Interim',
                            child: Text('Interim (Pendente Lite)'),
                          ),
                          DropdownMenuItem(
                            value: 'Final',
                            child: Text('Final / Permanent'),
                          ),
                        ],
                        onChanged:
                            (v) => setState(() {
                              _maintenanceType = v!;
                              _showResults = false;
                            }),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: TextField(
                        controller: _husbandIncomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Husband\'s Monthly Income (₹)',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _wifeIncomeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Wife\'s Monthly Income (₹) — if any',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    const Expanded(
                      child: SizedBox(),
                    ), // Placeholder for alignment
                  ],
                ),
              ],
              SizedBox(height: 12.h),

              // Children counter
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Number of Children',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.r),
                        color:
                            isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey[100],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed:
                                _childCount > 0
                                    ? () => setState(() {
                                      _childCount--;
                                      _showResults = false;
                                    })
                                    : null,
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 22,
                            ),
                            color: Colors.red[400],
                            visualDensity: VisualDensity.compact,
                          ),
                          SizedBox(
                            width: 32.w,
                            child: Text(
                              _childCount.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed:
                                () => setState(() {
                                  _childCount++;
                                  _showResults = false;
                                }),
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 22,
                            ),
                            color: Colors.green[400],
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton.icon(
                  onPressed: _calculate,
                  icon: const Icon(Icons.calculate_rounded, size: 20),
                  label: const Text(
                    'CALCULATE MAINTENANCE',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_showResults) ...[
            SizedBox(height: 16.h),

            // ─── Results ──
            _card(
              isDark,
              Icons.account_balance_wallet,
              Colors.green,
              'Maintenance Award',
              trailing: TextButton.icon(
                onPressed: _copyToClipboard,
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy', style: TextStyle(fontSize: 12.sp)),
              ),
              children: [
                // Total
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20.r),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.pink.withValues(alpha: 0.1),
                        AppTheme.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'TOTAL MONTHLY MAINTENANCE',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.sp,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        fmt.format(_totalMaintenance),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 28.sp,
                          color: Colors.pink,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'per month (${fmt.format(_totalMaintenance * 12)}/year)',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),

                ..._results.map(
                  (r) => Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    padding: EdgeInsets.all(14.r),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.grey[50],
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.h,
                          decoration: BoxDecoration(
                            color: Colors.pink.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.pink,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['head'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.sp,
                                ),
                              ),
                              if (r['details'] != null)
                                Text(
                                  r['details'],
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.grey[500],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          "${fmt.format(r['amount'])}/mo",
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.sp,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16.h),

            // ─── How It Was Calculated ──
            _card(
              isDark,
              Icons.school_rounded,
              Colors.deepPurple,
              'How It Was Calculated',
              children: [
                Text(
                  'Step-by-step computation based on court guidelines:',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                ),
                SizedBox(height: 12.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        _steps.map((s) {
                          if (s.isEmpty) return SizedBox(height: 8.h);
                          final bool isHeader =
                              s.startsWith('Step') ||
                              s.startsWith('⚖') ||
                              s.startsWith('Authority') ||
                              s.startsWith('═') ||
                              s.startsWith('TOTAL') ||
                              s.startsWith('ANNUAL');
                          return Padding(
                            padding: EdgeInsets.only(bottom: 3.h),
                            child: Text(
                              s,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight:
                                    isHeader
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                color:
                                    isDark
                                        ? (isHeader
                                            ? Colors.white
                                            : Colors.grey[300])
                                        : (isHeader
                                            ? Colors.black87
                                            : Colors.grey[700]),
                                height: 1.5.h,
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: 100.h),
        ],
      ),
    );
  }

  Widget _card(
    bool isDark,
    IconData icon,
    Color iconColor,
    String title, {
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: AppTheme.cardDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: 16.h),
          ...children,
        ],
      ),
    );
  }
}
