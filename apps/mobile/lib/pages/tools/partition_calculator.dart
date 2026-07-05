import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PartitionCalculator extends StatefulWidget {
  const PartitionCalculator({super.key});

  @override
  State<PartitionCalculator> createState() => _PartitionCalculatorState();
}

class _PartitionCalculatorState extends State<PartitionCalculator> {
  final formatCurrency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  // Selection State
  String _selectedLaw = 'Muslim (Hanafi)';
  String _deceasedGender = 'Male';

  // Estate Inputs
  final TextEditingController _estateCtrl = TextEditingController();
  final TextEditingController _debtsCtrl = TextEditingController();

  // Heir Counts
  int _wifeCount = 0;
  int _husbandCount = 0;
  int _sonCount = 0;
  int _daughterCount = 0;
  bool _fatherAlive = false;
  bool _motherAlive = false;

  // Output
  final List<Map<String, dynamic>> _results = [];
  final List<String> _calculationSteps = [];
  bool _showResults = false;

  @override
  void dispose() {
    _estateCtrl.dispose();
    _debtsCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    // Validate inputs
    final double estate =
        double.tryParse(_estateCtrl.text.replaceAll(',', '')) ?? 0.0;
    final double debts = double.tryParse(_debtsCtrl.text.replaceAll(',', '')) ?? 0.0;
    final double netEstate = estate - debts;

    if (estate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the total value of assets'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _results.clear();
    _calculationSteps.clear();

    if (netEstate <= 0) {
      setState(() {
        _calculationSteps.add(
          'Net estate is zero or negative after deducting debts. No distribution possible.',
        );
        _showResults = true;
      });
      return;
    }

    // Check at least one heir is selected
    final bool hasHeirs =
        _wifeCount > 0 ||
        _husbandCount > 0 ||
        _sonCount > 0 ||
        _daughterCount > 0 ||
        _fatherAlive ||
        _motherAlive;
    if (!hasHeirs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one legal heir'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _calculationSteps.add(
      'Net Estate = ${formatCurrency.format(estate)} − ${formatCurrency.format(debts)} = ${formatCurrency.format(netEstate)}',
    );
    _calculationSteps.add('');

    if (_selectedLaw == 'Muslim (Hanafi)') {
      _calculateMuslimHanafi(netEstate);
    } else {
      _calculateHinduSuccession(netEstate);
    }

    setState(() => _showResults = true);
  }

  // ─── HINDU SUCCESSION ACT ────────────────────────────
  void _calculateHinduSuccession(double netEstate) {
    _calculationSteps.add('📜 Hindu Succession Act, 1956');
    _calculationSteps.add('');

    int totalShares = 0;

    if (_deceasedGender == 'Male') {
      _calculationSteps.add(
        'Rule: Under Section 8, Class I heirs of a Hindu male take the property simultaneously and in equal shares per capita.',
      );
      _calculationSteps.add('');

      // Under Hindu Succession Act, all widows COLLECTIVELY share ONE unit
      // (not one share each). They split one share equally among themselves.
      final int widowUnit = _wifeCount > 0 ? 1 : 0;
      final int mother = _motherAlive ? 1 : 0;

      totalShares = widowUnit + mother + _sonCount + _daughterCount;

      if (totalShares == 0) {
        _calculationSteps.add(
          '⚠️ No Class I heirs selected. Please add heirs or refer to Class II schedule.',
        );
        return;
      }

      final double valuePerShare = netEstate / totalShares;
      _calculationSteps.add('Step 1: Count Class I heirs (per capita):');
      if (widowUnit > 0) {
        _calculationSteps.add(
          "  Widow(s): $_wifeCount widow${_wifeCount > 1 ? 's' : ''} share 1 unit collectively",
        );
        if (_wifeCount > 1) {
          _calculationSteps.add(
            '  (Multiple widows under §8 take ONE share together, then split equally)',
          );
        }
      }
      if (mother > 0) _calculationSteps.add('  Mother: 1');
      if (_sonCount > 0) _calculationSteps.add('  Son(s): $_sonCount');
      if (_daughterCount > 0) {
        _calculationSteps.add('  Daughter(s): $_daughterCount');
      }
      _calculationSteps.add('  Total units = $totalShares');
      _calculationSteps.add('');
      _calculationSteps.add('Step 2: Each unit gets an equal share:');
      _calculationSteps.add(
        '  ${formatCurrency.format(netEstate)} ÷ $totalShares = ${formatCurrency.format(valuePerShare)} per unit',
      );

      if (widowUnit > 0) {
        final double widowTotal = valuePerShare;
        final double perWidow = widowTotal / _wifeCount;
        if (_wifeCount > 1) {
          _calculationSteps.add('');
          _calculationSteps.add('Step 3: Widow share subdivision:');
          _calculationSteps.add(
            '  ${formatCurrency.format(widowTotal)} ÷ $_wifeCount widows = ${formatCurrency.format(perWidow)} each',
          );
        }
        for (int i = 1; i <= _wifeCount; i++) {
          _results.add({
            'heir': _wifeCount == 1 ? 'Widow' : 'Widow $i',
            'fraction':
                _wifeCount == 1
                    ? '1/$totalShares'
                    : '1/${totalShares * _wifeCount}',
            'amount': perWidow,
          });
        }
      }
      if (mother > 0) {
        _results.add({
          'heir': 'Mother',
          'fraction': '1/$totalShares',
          'amount': valuePerShare,
        });
      }
      for (int i = 1; i <= _sonCount; i++) {
        _results.add({
          'heir': _sonCount == 1 ? 'Son' : 'Son $i',
          'fraction': '1/$totalShares',
          'amount': valuePerShare,
        });
      }
      for (int i = 1; i <= _daughterCount; i++) {
        _results.add({
          'heir': _daughterCount == 1 ? 'Daughter' : 'Daughter $i',
          'fraction': '1/$totalShares',
          'amount': valuePerShare,
        });
      }
    } else {
      // Female deceased (Section 15)
      _calculationSteps.add(
        'Rule: Under Section 15(1)(a), property of a Hindu female devolves upon sons, daughters, and husband in equal shares.',
      );
      _calculationSteps.add('');

      final int husband = _husbandCount > 0 ? 1 : 0;
      totalShares = husband + _sonCount + _daughterCount;

      if (totalShares == 0) {
        _calculationSteps.add(
          '⚠️ No Section 15(1)(a) heirs selected. Property may devolve to heirs of the husband or father.',
        );
        return;
      }

      final double valuePerShare = netEstate / totalShares;
      _calculationSteps.add('Step 1: Count heirs:');
      if (husband > 0) _calculationSteps.add('  Husband: 1');
      if (_sonCount > 0) _calculationSteps.add('  Son(s): $_sonCount');
      if (_daughterCount > 0) {
        _calculationSteps.add('  Daughter(s): $_daughterCount');
      }
      _calculationSteps.add('  Total heirs = $totalShares');
      _calculationSteps.add('');
      _calculationSteps.add('Step 2: Each heir gets an equal share:');
      _calculationSteps.add(
        '  ${formatCurrency.format(netEstate)} ÷ $totalShares = ${formatCurrency.format(valuePerShare)} per heir',
      );

      if (husband > 0) {
        _results.add({
          'heir': 'Husband',
          'fraction': '1/$totalShares',
          'amount': valuePerShare,
        });
      }
      for (int i = 1; i <= _sonCount; i++) {
        _results.add({
          'heir': _sonCount == 1 ? 'Son' : 'Son $i',
          'fraction': '1/$totalShares',
          'amount': valuePerShare,
        });
      }
      for (int i = 1; i <= _daughterCount; i++) {
        _results.add({
          'heir': _daughterCount == 1 ? 'Daughter' : 'Daughter $i',
          'fraction': '1/$totalShares',
          'amount': valuePerShare,
        });
      }
    }
  }

  // ─── MUSLIM LAW (HANAFI) ─────────────────────────────
  void _calculateMuslimHanafi(double netEstate) {
    _calculationSteps.add('☪ Muslim Personal Law (Hanafi School)');
    _calculationSteps.add('');
    _calculationSteps.add(
      "Step 1: Determine Fixed Quranic Shares (Dhawu'l-Furud)",
    );
    _calculationSteps.add('');
    final bool hasChildren = _sonCount > 0 || _daughterCount > 0;

    double totalFixedFractions = 0.0;
    double remainingFraction = 1.0;

    // ── Fixed Fractions ──
    double wifeFraction = 0.0;
    if (_deceasedGender == 'Male' && _wifeCount > 0) {
      wifeFraction = hasChildren ? (1 / 8) : (1 / 4);
      totalFixedFractions += wifeFraction;
      _calculationSteps.add(
        "  Wife → ${hasChildren ? '1/8 (children exist)' : '1/4 (no children)'} = ${formatCurrency.format(netEstate * wifeFraction)}",
      );
    }

    double husbandFraction = 0.0;
    if (_deceasedGender == 'Female' && _husbandCount > 0) {
      husbandFraction = hasChildren ? (1 / 4) : (1 / 2);
      totalFixedFractions += husbandFraction;
      _calculationSteps.add(
        "  Husband → ${hasChildren ? '1/4 (children exist)' : '1/2 (no children)'} = ${formatCurrency.format(netEstate * husbandFraction)}",
      );
    }

    double fatherFraction = 0.0;
    if (_fatherAlive) {
      if (hasChildren) {
        fatherFraction = 1 / 6;
        totalFixedFractions += fatherFraction;
        _calculationSteps.add(
          '  Father → 1/6 fixed (children exist) = ${formatCurrency.format(netEstate * fatherFraction)}',
        );
      } else {
        _calculationSteps.add(
          '  Father → No fixed share; will take as residuary (Asaba)',
        );
      }
    }

    double motherFraction = 0.0;
    if (_motherAlive) {
      if (hasChildren) {
        motherFraction = 1 / 6;
      } else {
        // Umariyyatain rule: when spouse exists + no children,
        // mother gets 1/3 of RESIDUE (not 1/3 of estate)
        final bool hasSpouse =
            (_deceasedGender == 'Male' && _wifeCount > 0) ||
            (_deceasedGender == 'Female' && _husbandCount > 0);
        if (hasSpouse && _fatherAlive) {
          // Mother gets 1/3 of residue after spouse's share
          double spouseFrac = 0;
          if (_deceasedGender == 'Male' && _wifeCount > 0) spouseFrac = 1 / 4;
          if (_deceasedGender == 'Female' && _husbandCount > 0) {
            spouseFrac = 1 / 2;
          }
          final double residue = 1.0 - spouseFrac;
          motherFraction = residue / 3;
          _calculationSteps.add(
            '  Mother → Umariyyatain rule: 1/3 of residue after spouse = ${(motherFraction * 100).toStringAsFixed(2)}% = ${formatCurrency.format(netEstate * motherFraction)}',
          );
        } else {
          motherFraction = 1 / 3;
        }
      }
      totalFixedFractions += motherFraction;
      if (!(_fatherAlive &&
          !hasChildren &&
          ((_deceasedGender == 'Male' && _wifeCount > 0) ||
              (_deceasedGender == 'Female' && _husbandCount > 0)))) {
        _calculationSteps.add(
          "  Mother → ${hasChildren ? '1/6 (children exist)' : '1/3 (no children)'} = ${formatCurrency.format(netEstate * motherFraction)}",
        );
      }
    }

    // Check for Aul (Oversubscription)
    if (totalFixedFractions > 1.0) {
      _calculationSteps.add('');
      _calculationSteps.add(
        '⚠️ Aul condition: Fixed shares exceed the estate.',
      );
      _calculationSteps.add('Shares will be proportionally reduced.');
      // Proportional reduction
      final double scale = 1.0 / totalFixedFractions;
      if (wifeFraction > 0) {
        final double amount = netEstate * wifeFraction * scale;
        _results.add({'heir': 'Wife', 'fraction': 'Reduced', 'amount': amount});
      }
      if (husbandFraction > 0) {
        final double amount = netEstate * husbandFraction * scale;
        _results.add({
          'heir': 'Husband',
          'fraction': 'Reduced',
          'amount': amount,
        });
      }
      if (fatherFraction > 0) {
        final double amount = netEstate * fatherFraction * scale;
        _results.add({
          'heir': 'Father',
          'fraction': 'Reduced',
          'amount': amount,
        });
      }
      if (motherFraction > 0) {
        final double amount = netEstate * motherFraction * scale;
        _results.add({
          'heir': 'Mother',
          'fraction': 'Reduced',
          'amount': amount,
        });
      }
      return;
    }

    // Record Fixed Amounts
    if (wifeFraction > 0) {
      final double amount = netEstate * wifeFraction;
      _results.add({
        'heir': _wifeCount > 1 ? 'Wives (×$_wifeCount, split)' : 'Wife',
        'fraction': hasChildren ? '1/8' : '1/4',
        'amount': amount,
      });
    }
    if (husbandFraction > 0) {
      final double amount = netEstate * husbandFraction;
      _results.add({
        'heir': 'Husband',
        'fraction': hasChildren ? '1/4' : '1/2',
        'amount': amount,
      });
    }
    if (fatherFraction > 0) {
      final double amount = netEstate * fatherFraction;
      _results.add({'heir': 'Father', 'fraction': '1/6', 'amount': amount});
    }
    if (motherFraction > 0) {
      final double amount = netEstate * motherFraction;
      _results.add({
        'heir': 'Mother',
        'fraction': hasChildren ? '1/6' : '1/3',
        'amount': amount,
      });
    }

    // ── Residuary Calculation ──
    remainingFraction = 1.0 - totalFixedFractions;
    _calculationSteps.add('');
    _calculationSteps.add('Step 2: Residuary Distribution (Asaba)');

    if (remainingFraction > 0.001) {
      double remainingAmount = netEstate * remainingFraction;
      _calculationSteps.add(
        '  Remaining after fixed shares = ${formatCurrency.format(remainingAmount)}',
      );
      _calculationSteps.add('');

      if (_sonCount > 0) {
        final int totalParts = (_sonCount * 2) + _daughterCount;
        _calculationSteps.add(
          '  Rule: Son gets 2 parts, Daughter gets 1 part.',
        );
        _calculationSteps.add(
          '  Parts = ($_sonCount sons × 2) + ($_daughterCount daughters × 1) = $totalParts parts',
        );

        final double valuePerPart = remainingAmount / totalParts;
        _calculationSteps.add(
          '  Each part = ${formatCurrency.format(remainingAmount)} ÷ $totalParts = ${formatCurrency.format(valuePerPart)}',
        );
        _calculationSteps.add('');

        for (int i = 1; i <= _sonCount; i++) {
          final double amt = valuePerPart * 2;
          _calculationSteps.add(
            "  ${_sonCount == 1 ? 'Son' : 'Son $i'} = 2 × ${formatCurrency.format(valuePerPart)} = ${formatCurrency.format(amt)}",
          );
          _results.add({
            'heir': _sonCount == 1 ? 'Son' : 'Son $i',
            'fraction': '2/$totalParts res.',
            'amount': amt,
          });
        }
        for (int i = 1; i <= _daughterCount; i++) {
          _calculationSteps.add(
            "  ${_daughterCount == 1 ? 'Daughter' : 'Daughter $i'} = 1 × ${formatCurrency.format(valuePerPart)} = ${formatCurrency.format(valuePerPart)}",
          );
          _results.add({
            'heir': _daughterCount == 1 ? 'Daughter' : 'Daughter $i',
            'fraction': '1/$totalParts res.',
            'amount': valuePerPart,
          });
        }
      } else if (_daughterCount > 0) {
        final double daughtersFixedFraction = _daughterCount == 1 ? 0.5 : (2 / 3);
        final String fracLabel = _daughterCount == 1 ? '1/2' : '2/3';

        if (remainingFraction >= daughtersFixedFraction) {
          final double totalDaughtersAmount = netEstate * daughtersFixedFraction;
          final double perDaughter = totalDaughtersAmount / _daughterCount;
          _calculationSteps.add(
            '  Daughters (no sons): Fixed share = $fracLabel = ${formatCurrency.format(totalDaughtersAmount)}',
          );
          for (int i = 1; i <= _daughterCount; i++) {
            _results.add({
              'heir': _daughterCount == 1 ? 'Daughter' : 'Daughter $i',
              'fraction': fracLabel,
              'amount': perDaughter,
            });
          }
          remainingFraction -= daughtersFixedFraction;
          remainingAmount = netEstate * remainingFraction;
        }

        if (_fatherAlive && remainingFraction > 0.001) {
          _calculationSteps.add(
            '  Father takes remaining as residuary = ${formatCurrency.format(remainingAmount)}',
          );
          final fatherRecord =
              _results.where((e) => e['heir'] == 'Father').firstOrNull;
          if (fatherRecord != null) {
            fatherRecord['amount'] =
                (fatherRecord['amount'] as double) + remainingAmount;
            fatherRecord['fraction'] = '1/6 + res.';
          } else {
            _results.add({
              'heir': 'Father',
              'fraction': 'Residuary',
              'amount': remainingAmount,
            });
          }
        }
      } else if (_fatherAlive) {
        _calculationSteps.add(
          '  Father takes all residuary = ${formatCurrency.format(remainingAmount)}',
        );
        final fatherRecord =
            _results.where((e) => e['heir'] == 'Father').firstOrNull;
        if (fatherRecord != null) {
          fatherRecord['amount'] =
              (fatherRecord['amount'] as double) + remainingAmount;
          fatherRecord['fraction'] = '1/6 + res.';
        } else {
          _results.add({
            'heir': 'Father',
            'fraction': 'Residuary',
            'amount': remainingAmount,
          });
        }
      } else {
        _calculationSteps.add(
          '  ⚠️ No residuary heirs. Remainder (${formatCurrency.format(remainingAmount)}) may revert via Radd.',
        );
      }
    } else {
      _calculationSteps.add('  Fixed heirs fully exhaust the estate.');
    }
  }

  // ─── COPY TO CLIPBOARD ──────────────────────────────
  void _copyToClipboard() {
    if (_results.isEmpty) return;

    final double estate =
        double.tryParse(_estateCtrl.text.replaceAll(',', '')) ?? 0.0;
    final double debts = double.tryParse(_debtsCtrl.text.replaceAll(',', '')) ?? 0.0;

    final StringBuffer sb = StringBuffer();
    sb.writeln('═══════════════════════════════════════════');
    sb.writeln('   PARTITION SHARE CALCULATION MEMO');
    sb.writeln('   Law: $_selectedLaw');
    sb.writeln('═══════════════════════════════════════════');
    sb.writeln('Deceased Gender : $_deceasedGender');
    sb.writeln('Total Estate    : ${formatCurrency.format(estate)}');
    if (debts > 0) {
      sb.writeln('Less Debts      : ${formatCurrency.format(debts)}');
    }
    sb.writeln('Net Estate      : ${formatCurrency.format(estate - debts)}');
    sb.writeln('───────────────────────────────────────────\n');
    sb.writeln('SCHEDULE OF SHARES:\n');

    int sno = 1;
    for (var res in _results) {
      sb.writeln(
        "${sno.toString().padLeft(2)}. ${res['heir'].toString().padRight(20)} | ${res['fraction'].toString().padRight(14)} | ${formatCurrency.format(res['amount'])}",
      );
      sno++;
    }

    sb.writeln('\n───────────────────────────────────────────');
    sb.writeln('\nSTEPS OF COMPUTATION:\n');
    for (var step in _calculationSteps) {
      if (step.isNotEmpty) sb.writeln('  $step');
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
            Text('Partition memo copied! Paste in your plaint draft.'),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // ─── BUILD UI ──────────────────────────────────────────
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Law & Deceased Selection ──
          _buildCard(
            isDark,
            icon: Icons.gavel,
            iconColor: AppTheme.accent,
            title: 'Case Parameters',
            children: [
              if (isMobile) ...[
                _buildDropdown(
                  'Applicable Personal Law',
                  _selectedLaw,
                  [
                    const DropdownMenuItem(
                      value: 'Muslim (Hanafi)',
                      child: Text('☪ Muslim Law (Hanafi)'),
                    ),
                    const DropdownMenuItem(
                      value: 'Hindu Succession',
                      child: Text('🕉 Hindu Succession Act'),
                    ),
                  ],
                  (val) {
                    setState(() {
                      _selectedLaw = val!;
                      _results.clear();
                      _calculationSteps.clear();
                      _showResults = false;
                      _husbandCount = 0;
                      _wifeCount = 0;
                    });
                  },
                ),
                SizedBox(height: 12.h),
                _buildDropdown(
                  'Gender of Deceased',
                  _deceasedGender,
                  [
                    const DropdownMenuItem(value: 'Male', child: Text('Male')),
                    const DropdownMenuItem(
                      value: 'Female',
                      child: Text('Female'),
                    ),
                  ],
                  (val) {
                    setState(() {
                      _deceasedGender = val!;
                      _results.clear();
                      _calculationSteps.clear();
                      _showResults = false;
                      if (val == 'Male') {
                        _husbandCount = 0;
                      } else {
                        _wifeCount = 0;
                      }
                    });
                  },
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        'Applicable Personal Law',
                        _selectedLaw,
                        [
                          const DropdownMenuItem(
                            value: 'Muslim (Hanafi)',
                            child: Text('☪ Muslim Law (Hanafi)'),
                          ),
                          const DropdownMenuItem(
                            value: 'Hindu Succession',
                            child: Text('🕉 Hindu Succession Act'),
                          ),
                        ],
                        (val) {
                          setState(() {
                            _selectedLaw = val!;
                            _results.clear();
                            _calculationSteps.clear();
                            _showResults = false;
                            _husbandCount = 0;
                            _wifeCount = 0;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildDropdown(
                        'Gender of Deceased',
                        _deceasedGender,
                        [
                          const DropdownMenuItem(
                            value: 'Male',
                            child: Text('Male'),
                          ),
                          const DropdownMenuItem(
                            value: 'Female',
                            child: Text('Female'),
                          ),
                        ],
                        (val) {
                          setState(() {
                            _deceasedGender = val!;
                            _results.clear();
                            _calculationSteps.clear();
                            _showResults = false;
                            if (val == 'Male') {
                              _husbandCount = 0;
                            } else {
                              _wifeCount = 0;
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),

              SizedBox(height: 16.h),

              if (isMobile) ...[
                TextField(
                  controller: _estateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Total Assets (₹)',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _debtsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Debts / Funeral (₹)',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _estateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Total Assets (₹)',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: TextField(
                        controller: _debtsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Debts / Funeral (₹)',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          SizedBox(height: 16.h),

          // ─── Heirs Selection ──
          _buildCard(
            isDark,
            icon: Icons.family_restroom,
            iconColor: Colors.orange,
            title: 'Surviving Legal Heirs',
            children: [
              Text(
                _selectedLaw == 'Muslim (Hanafi)'
                    ? 'Select primary heirs under Hanafi Mohammedan Law'
                    : 'Select Class I heirs under Hindu Succession Act, 1956',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              ),
              const Divider(height: 20.h),

              if (_deceasedGender == 'Male')
                _buildCounterRow(
                  'Wife / Widow(s)',
                  _wifeCount,
                  (v) => setState(() {
                    _wifeCount = v;
                    _showResults = false;
                  }),
                ),

              if (_deceasedGender == 'Female')
                _buildCounterRow(
                  'Husband',
                  _husbandCount,
                  (v) => setState(() {
                    _husbandCount = v > 1 ? 1 : v;
                    _showResults = false;
                  }),
                ),

              _buildCounterRow(
                'Sons',
                _sonCount,
                (v) => setState(() {
                  _sonCount = v;
                  _showResults = false;
                }),
              ),
              _buildCounterRow(
                'Daughters',
                _daughterCount,
                (v) => setState(() {
                  _daughterCount = v;
                  _showResults = false;
                }),
              ),

              SizedBox(height: 4.h),
              SwitchListTile(
                title: const Text(
                  'Father Alive',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _selectedLaw == 'Muslim (Hanafi)'
                      ? 'Gets 1/6 fixed + residuary'
                      : 'Not a Class I heir for male deceased',
                  style: const TextStyle(fontSize: 11.sp),
                ),
                value: _fatherAlive,
                onChanged:
                    (v) => setState(() {
                      _fatherAlive = v;
                      _showResults = false;
                    }),
                activeThumbColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text(
                  'Mother Alive',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _selectedLaw == 'Muslim (Hanafi)'
                      ? 'Gets 1/6 or 1/3 fixed share'
                      : 'Class I heir for male deceased',
                  style: const TextStyle(fontSize: 11.sp),
                ),
                value: _motherAlive,
                onChanged:
                    (v) => setState(() {
                      _motherAlive = v;
                      _showResults = false;
                    }),
                activeThumbColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
              ),

              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton.icon(
                  onPressed: _calculate,
                  icon: const Icon(Icons.calculate_rounded, size: 20),
                  label: const Text(
                    'COMPUTE PARTITION SHARES',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ─── Results Section ──
          if (_showResults) ...[
            SizedBox(height: 16.h),

            // Results Table
            if (_results.isNotEmpty)
              _buildCard(
                isDark,
                icon: Icons.pie_chart_rounded,
                iconColor: Colors.green,
                title: 'Partition Result',
                trailing: TextButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text(
                    'Copy Memo',
                    style: TextStyle(fontSize: 12.sp),
                  ),
                ),
                children: [
                  // Net estate summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accent.withValues(alpha: 0.1),
                          AppTheme.primary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Net Distributable Estate',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          formatCurrency.format(
                            (double.tryParse(
                                      _estateCtrl.text.replaceAll(',', ''),
                                    ) ??
                                    0) -
                                (double.tryParse(
                                      _debtsCtrl.text.replaceAll(',', ''),
                                    ) ??
                                    0),
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18.sp,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Share cards
                  ..._results.map(
                    (row) => Container(
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
                              color: AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: AppTheme.accent,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row['heir'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.sp,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  "Share: ${row['fraction']}",
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatCurrency.format(row['amount']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16.sp,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

            // How It Was Calculated
            if (_calculationSteps.isNotEmpty) ...[
              SizedBox(height: 16.h),
              _buildCard(
                isDark,
                icon: Icons.school_rounded,
                iconColor: Colors.deepPurple,
                title: 'How It Was Calculated',
                children: [
                  Text(
                    'Step-by-step legal reasoning used to arrive at the above figures:',
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
                        color:
                            isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          _calculationSteps.map((step) {
                            if (step.isEmpty) return SizedBox(height: 8.h);
                            final bool isHeader =
                                step.startsWith('Step') ||
                                step.startsWith('📜') ||
                                step.startsWith('☪') ||
                                step.startsWith('Rule:');
                            return Padding(
                              padding: EdgeInsets.only(bottom: 4.h),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isHeader && !step.startsWith('⚠'))
                                    Padding(
                                      padding: EdgeInsets.only(
                                        top: 3.h,
                                        right: 6.w,
                                      ),
                                      child: Icon(
                                        Icons.arrow_right,
                                        size: 16,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                  if (isHeader)
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        top: 3.h,
                                        right: 6.w,
                                      ),
                                      child: Icon(
                                        Icons.bookmark,
                                        size: 14,
                                        color: AppTheme.accent,
                                      ),
                                    ),
                                  if (step.startsWith('⚠'))
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        top: 3.h,
                                        right: 6.w,
                                      ),
                                      child: Icon(
                                        Icons.warning_amber,
                                        size: 14,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      step,
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
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ],

          SizedBox(height: 100.h),
        ],
      ),
    );
  }

  // ─── REUSABLE CARD WIDGET ──
  Widget _buildCard(
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
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

  // ─── REUSABLE DROPDOWN ──
  Widget _buildDropdown(
    String label,
    String value,
    List<DropdownMenuItem<String>> items,
    void Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items,
      onChanged: onChanged,
      isExpanded: true,
    );
  }

  // ─── COUNTER ROW ──
  Widget _buildCounterRow(String label, int value, Function(int) onChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15.sp),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.r),
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey[100],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: value > 0 ? () => onChanged(value - 1) : null,
                  icon: const Icon(Icons.remove_circle_outline, size: 22),
                  color: Colors.red[400],
                  visualDensity: VisualDensity.compact,
                ),
                SizedBox(
                  width: 32.w,
                  child: Text(
                    value.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onChanged(value + 1),
                  icon: const Icon(Icons.add_circle_outline, size: 22),
                  color: Colors.green[400],
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
