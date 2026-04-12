import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class CourtFeeCalculator extends StatefulWidget {
  const CourtFeeCalculator({super.key});

  @override
  State<CourtFeeCalculator> createState() => _CourtFeeCalculatorState();
}

class _CourtFeeCalculatorState extends State<CourtFeeCalculator> {
  String _category = "money_suit";
  String _courtType = "sub_court";
  final TextEditingController _amountController = TextEditingController();
  int? _fee2017;
  int? _fee1955;

  final Map<String, String> _categories = {
    "money_suit": "Money Suit (Recovery of Money)",
    "immovable_property": "Immovable Property Dispute",
    "partition": "Partition Suit",
    "probate": "Probate / Letters of Administration",
    "appeal": "Appeal",
    "writ": "Writ Petition",
    "application": "Interim Application",
  };

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_calculateFee);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _calculateFee() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    double calculatedFee2017 = 0;
    double calculatedFee1955 = 0;

    switch (_category) {
      case "money_suit":
      case "immovable_property":
      case "appeal":
        calculatedFee2017 = amount * 0.03;
        calculatedFee1955 = amount * 0.01;
        break;
      case "partition":
        if (_courtType == "high_court") {
          calculatedFee2017 = 10000;
          calculatedFee1955 = 1000;
        } else {
          calculatedFee2017 = 5000;
          calculatedFee1955 = 750;
        }
        break;
      case "probate":
        calculatedFee2017 = (amount * 0.03).clamp(0, 25000);
        calculatedFee1955 = amount * 0.03;
        break;
      case "writ":
        calculatedFee2017 = 1000;
        calculatedFee1955 = 200;
        break;
      case "application":
        calculatedFee2017 = 20;
        calculatedFee1955 = 2;
        break;
      default:
        calculatedFee2017 = 0;
        calculatedFee1955 = 0;
    }

    setState(() {
      _fee2017 = calculatedFee2017.round();
      _fee1955 = calculatedFee1955.round();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdown(
            label: "Case Category",
            value: _category,
            items: _categories,
            onChanged: (val) {
              setState(() => _category = val!);
              _calculateFee();
            },
          ),
          const SizedBox(height: 16),
          if (["money_suit", "immovable_property", "probate", "appeal"].contains(_category))
            _buildAmountInput(),
          if (_category == "partition")
            _buildDropdown(
              label: "Court Type",
              value: _courtType,
              items: {
                "high_court": "High Court (Original Side)",
                "sub_court": "District / Subordinate Courts",
              },
              onChanged: (val) {
                setState(() => _courtType = val!);
                _calculateFee();
              },
            ),
          const SizedBox(height: 24),
          _buildResultGrid(),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    // Category icon mapping for visual clarity
    final Map<String, IconData> categoryIcons = {
      "money_suit": Icons.account_balance_wallet_outlined,
      "immovable_property": Icons.home_outlined,
      "partition": Icons.vertical_split_outlined,
      "probate": Icons.description_outlined,
      "appeal": Icons.gavel_outlined,
      "writ": Icons.article_outlined,
      "application": Icons.assignment_outlined,
      "high_court": Icons.account_balance_outlined,
      "sub_court": Icons.business_outlined,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF64748B),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderLight, width: 1.5),
            borderRadius: BorderRadius.circular(14),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.accent,
                  size: 20,
                ),
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              selectedItemBuilder: (BuildContext context) {
                return items.entries.map((e) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Icon(
                          categoryIcons[e.key] ?? Icons.label_outlined,
                          size: 18,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
              items: items.entries.map((e) {
                final isSelected = e.key == value;
                return DropdownMenuItem(
                  value: e.key,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accent.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accent.withValues(alpha: 0.15)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            categoryIcons[e.key] ?? Icons.label_outlined,
                            size: 16,
                            color: isSelected ? AppTheme.accent : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.accent
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_rounded, size: 18, color: AppTheme.accent),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "SUBJECT MATTER VALUE / CLAIM AMOUNT (₹)",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Color(0xFF64748B),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.currency_rupee, size: 18, color: AppTheme.accent),
            hintText: "Enter amount",
            hintStyle: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontWeight: FontWeight.w400,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.borderLight, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.borderLight, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTheme.accent, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildResultGrid() {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Row(
      children: [
        Expanded(
          child: _buildResultCard(
            label: "Old Fee (1955 Act)",
            value: currencyFormat.format(_fee1955 ?? 0),
            subtitle: "(Approx. Pre-2017)",
            isPrimary: false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildResultCard(
            label: "New Fee (2017 Act)",
            value: currencyFormat.format(_fee2017 ?? 0),
            subtitle: "(As per Amendment)",
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard({
    required String label,
    required String value,
    required String subtitle,
    required bool isPrimary,
  }) {
    final color = isPrimary ? AppTheme.accent : const Color(0xFF64748B);
    final bgColor = isPrimary
        ? AppTheme.accent.withValues(alpha: 0.06)
        : const Color(0xFFF8FAFC);
    final borderColor = isPrimary
        ? AppTheme.accent.withValues(alpha: 0.2)
        : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isPrimary ? AppTheme.accent : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
