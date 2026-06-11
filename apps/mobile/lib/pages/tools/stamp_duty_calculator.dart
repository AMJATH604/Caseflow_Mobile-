import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class StampDutyCalculator extends StatefulWidget {
  const StampDutyCalculator({super.key});

  @override
  State<StampDutyCalculator> createState() => _StampDutyCalculatorState();
}

class _StampDutyCalculatorState extends State<StampDutyCalculator>
    with SingleTickerProviderStateMixin {
  String? _selectedState;
  String? _selectedDocType;
  final _valueController = TextEditingController();
  bool _isFemale = false;
  Map<String, double>? _result;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ─── Stamp duty rates: state → docType → {duty%, regFee%, surcharge%} ───
  static final Map<String, Map<String, Map<String, double>>> _rates = {
    'Tamil Nadu': {
      'Sale Deed': {'duty': 7.0, 'reg': 1.0, 'surcharge': 0.0},
      'Gift Deed': {'duty': 7.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 1.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 4.0, 'reg': 1.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 4.0, 'reg': 1.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 4.0, 'reg': 1.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 4.0, 'reg': 1.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 7.0, 'reg': 1.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 7.0, 'reg': 1.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 7.0, 'reg': 1.0, 'surcharge': 0.0},
    },
    'Maharashtra': {
      'Sale Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 1.0},
      'Gift Deed': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 0.25, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
    },
    'Karnataka': {
      'Sale Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Gift Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 0.5, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 2.0, 'reg': 1.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
    },
    'Kerala': {
      'Sale Deed': {'duty': 8.0, 'reg': 2.0, 'surcharge': 0.0},
      'Gift Deed': {'duty': 5.0, 'reg': 2.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 1.0, 'reg': 2.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 5.0, 'reg': 2.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 8.0, 'reg': 2.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 5.0, 'reg': 2.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 3.0, 'reg': 2.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 8.0, 'reg': 2.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 8.0, 'reg': 2.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 5.0, 'reg': 2.0, 'surcharge': 0.0},
    },
    'Andhra Pradesh': {
      'Sale Deed': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
      'Gift Deed': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 0.5, 'reg': 0.5, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 2.0, 'reg': 0.5, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
      'Partition Deed': {'duty': 2.0, 'reg': 0.5, 'surcharge': 0.0},
      'Release Deed': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
    },
    'Telangana': {
      'Sale Deed': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
      'Gift Deed': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 0.5, 'reg': 0.5, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 2.0, 'reg': 0.5, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
      'Partition Deed': {'duty': 2.0, 'reg': 0.5, 'surcharge': 0.0},
      'Release Deed': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 5.0, 'reg': 0.5, 'surcharge': 0.0},
    },
    'Delhi': {
      'Sale Deed (Male)': {'duty': 6.0, 'reg': 1.0, 'surcharge': 0.0},
      'Sale Deed (Female)': {'duty': 4.0, 'reg': 1.0, 'surcharge': 0.0},
      'Gift Deed': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 2.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 6.0, 'reg': 1.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 2.0, 'reg': 1.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 6.0, 'reg': 1.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
    },
    'Uttar Pradesh': {
      'Sale Deed (Male)': {'duty': 7.0, 'reg': 1.0, 'surcharge': 0.0},
      'Sale Deed (Female)': {'duty': 6.0, 'reg': 1.0, 'surcharge': 0.0},
      'Gift Deed': {'duty': 7.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 2.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 2.0, 'reg': 1.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 7.0, 'reg': 1.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 7.0, 'reg': 1.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
    },
    'Rajasthan': {
      'Sale Deed (Male)': {'duty': 6.0, 'reg': 1.0, 'surcharge': 0.0},
      'Sale Deed (Female)': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Gift Deed': {'duty': 2.5, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 1.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 4.0, 'reg': 1.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 2.0, 'reg': 1.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
    },
    'Gujarat': {
      'Sale Deed': {'duty': 4.9, 'reg': 1.0, 'surcharge': 0.0},
      'Gift Deed': {'duty': 4.9, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 1.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 4.9, 'reg': 1.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 4.9, 'reg': 1.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 2.0, 'reg': 1.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 4.9, 'reg': 1.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 4.9, 'reg': 1.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 4.9, 'reg': 1.0, 'surcharge': 0.0},
    },
    'West Bengal': {
      'Sale Deed': {'duty': 6.0, 'reg': 1.0, 'surcharge': 0.0},
      'Gift Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 0.5, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 2.0, 'reg': 1.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 6.0, 'reg': 1.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
    },
    'Madhya Pradesh': {
      'Sale Deed': {'duty': 7.5, 'reg': 1.0, 'surcharge': 0.0},
      'Gift Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 1.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 4.0, 'reg': 1.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 7.5, 'reg': 1.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
    },
    'Punjab': {
      'Sale Deed (Male)': {'duty': 7.0, 'reg': 1.0, 'surcharge': 0.0},
      'Sale Deed (Female)': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Gift Deed': {'duty': 6.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 1.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 6.0, 'reg': 1.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 6.0, 'reg': 1.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 6.0, 'reg': 1.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
    },
    'Haryana': {
      'Sale Deed (Male)': {'duty': 7.0, 'reg': 1.0, 'surcharge': 0.0},
      'Sale Deed (Female)': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Gift Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 1.5, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 4.0, 'reg': 1.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 6.0, 'reg': 1.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 3.0, 'reg': 1.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 6.0, 'reg': 1.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
    },
    'Bihar': {
      'Sale Deed': {'duty': 6.0, 'reg': 2.0, 'surcharge': 0.0},
      'Gift Deed': {'duty': 6.0, 'reg': 2.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 1.0, 'reg': 2.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 3.0, 'reg': 2.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 6.0, 'reg': 2.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 5.0, 'reg': 2.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 3.0, 'reg': 2.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 6.0, 'reg': 2.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 6.0, 'reg': 2.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 6.0, 'reg': 2.0, 'surcharge': 0.0},
    },
    'Odisha': {
      'Sale Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Gift Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (< 3 yrs)': {'duty': 0.5, 'reg': 1.0, 'surcharge': 0.0},
      'Lease Deed (> 3 yrs)': {'duty': 2.0, 'reg': 1.0, 'surcharge': 0.0},
      'Mortgage Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Power of Attorney (GPA)': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Partition Deed': {'duty': 2.0, 'reg': 1.0, 'surcharge': 0.0},
      'Release Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Exchange Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
      'Settlement Deed': {'duty': 5.0, 'reg': 1.0, 'surcharge': 0.0},
    },
  };

  List<String> get _states => _rates.keys.toList();

  List<String> get _docTypes {
    if (_selectedState == null) return [];
    final stateDocs = _rates[_selectedState!]!;
    // For states with gendered sale deeds, show the right one
    return stateDocs.keys.where((key) {
      if (key == 'Sale Deed (Male)' && _isFemale) return false;
      if (key == 'Sale Deed (Female)' && !_isFemale) return false;
      return true;
    }).toList();
  }

  bool get _stateHasGenderRates {
    if (_selectedState == null) return false;
    return _rates[_selectedState!]!.containsKey('Sale Deed (Male)');
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _valueController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (_selectedState == null || _selectedDocType == null) return;
    final value = double.tryParse(_valueController.text.replaceAll(',', ''));
    if (value == null || value <= 0) return;

    final rate = _rates[_selectedState!]![_selectedDocType!]!;
    final duty = value * rate['duty']! / 100;
    final reg = value * rate['reg']! / 100;
    final surcharge = value * rate['surcharge']! / 100;

    setState(() {
      _result = {
        'value': value,
        'dutyRate': rate['duty']!,
        'duty': duty,
        'regRate': rate['reg']!,
        'reg': reg,
        'surchargeRate': rate['surcharge']!,
        'surcharge': surcharge,
        'total': duty + reg + surcharge,
      };
    });
    _animController.forward(from: 0);
  }

  void _reset() {
    setState(() {
      _selectedState = null;
      _selectedDocType = null;
      _valueController.clear();
      _isFemale = false;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInputCard(),
          if (_result != null) ...[
            const SizedBox(height: 16),
            FadeTransition(opacity: _fadeAnim, child: _buildResultCard()),
          ],
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF1E293B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Stamp Duty Calculator',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // State dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedState,
            decoration: InputDecoration(
              labelText: 'Select State',
              prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items:
                _states
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
            onChanged: (val) {
              setState(() {
                _selectedState = val;
                _selectedDocType = null;
                _result = null;
              });
            },
          ),
          const SizedBox(height: 16),

          // Gender toggle (only for states with gender-based rates)
          if (_stateHasGenderRates)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: Color(0xFF764ba2),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Buyer Gender:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  ChoiceChip(
                    label: const Text('Male'),
                    selected: !_isFemale,
                    onSelected:
                        (_) => setState(() {
                          _isFemale = false;
                          _selectedDocType = null;
                          _result = null;
                        }),
                    selectedColor: const Color(0xFF667eea),
                    labelStyle: TextStyle(
                      color: !_isFemale ? Colors.white : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Female'),
                    selected: _isFemale,
                    onSelected:
                        (_) => setState(() {
                          _isFemale = true;
                          _selectedDocType = null;
                          _result = null;
                        }),
                    selectedColor: const Color(0xFF764ba2),
                    labelStyle: TextStyle(
                      color: _isFemale ? Colors.white : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (_stateHasGenderRates) const SizedBox(height: 16),

          // Document type dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedDocType,
            decoration: InputDecoration(
              labelText: 'Document Type',
              prefixIcon: const Icon(Icons.description_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items:
                _docTypes
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
            onChanged:
                _selectedState == null
                    ? null
                    : (val) => setState(() {
                      _selectedDocType = val;
                      _result = null;
                    }),
          ),
          const SizedBox(height: 16),

          // Property value
          TextFormField(
            controller: _valueController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Property / Transaction Value (₹)',
              prefixIcon: const Icon(Icons.currency_rupee_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _calculate,
                  icon: const Icon(Icons.calculate_rounded, size: 18),
                  label: const Text('Calculate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _reset,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final cur = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final r = _result!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF1E293B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stamp Duty Breakdown',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$_selectedState • $_selectedDocType',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Breakdown rows
          _resultRow('Property Value', cur.format(r['value']), null),
          _divider(),
          _resultRow(
            "Stamp Duty (${r['dutyRate']}%)",
            cur.format(r['duty']),
            Icons.receipt_outlined,
          ),
          _resultRow(
            "Registration Fee (${r['regRate']}%)",
            cur.format(r['reg']),
            Icons.app_registration_outlined,
          ),
          if (r['surcharge']! > 0)
            _resultRow(
              "Surcharge (${r['surchargeRate']}%)",
              cur.format(r['surcharge']),
              Icons.add_circle_outline,
            ),
          _divider(),

          // Total
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL PAYABLE',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  cur.format(r['total']),
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Text(
            "Note: Rates are approximate. Check your state's official gazette for the latest rates.",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value, IconData? icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
    );
  }
}
