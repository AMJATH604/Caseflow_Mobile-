import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class CourtFeeCalculator extends StatefulWidget {
  const CourtFeeCalculator({super.key});

  @override
  State<CourtFeeCalculator> createState() => _CourtFeeCalculatorState();
}

class _CourtFeeCalculatorState extends State<CourtFeeCalculator> {
  final formatCurrency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final TextEditingController _amountController = TextEditingController();

  String _category = 'money_suit';
  String _courtType = 'sub_court';
  String _partitionType = 'joint_possession'; // NEW: joint vs excluded
  String _appealType = 'decree'; // NEW: from decree vs from order

  int? _fee2017;
  int? _fee1955;
  String _legalBasis = '';
  List<String> _notes = [];

  // ─── Categories (expanded per 2017 Amendment Act) ──────
  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'money_suit',
      'label': 'Money Suit (Recovery)',
      'icon': Icons.account_balance_wallet_outlined,
    },
    {
      'id': 'immovable_property',
      'label': 'Immovable Property',
      'icon': Icons.home_outlined,
    },
    {
      'id': 'partition',
      'label': 'Partition Suit',
      'icon': Icons.vertical_split_outlined,
    },
    {
      'id': 'probate',
      'label': 'Probate / Letters of Admin',
      'icon': Icons.description_outlined,
    },
    {'id': 'appeal', 'label': 'Appeal', 'icon': Icons.gavel_outlined},
    {
      'id': 'writ',
      'label': 'Writ Petition (Art. 226)',
      'icon': Icons.article_outlined,
    },
    {
      'id': 'application',
      'label': 'Interim Application / IA',
      'icon': Icons.assignment_outlined,
    },
    {
      'id': 'ni_act',
      'label': 'NI Act §138 Petition',
      'icon': Icons.credit_card_outlined,
    },
    {
      'id': 'revision',
      'label': 'Revision Petition',
      'icon': Icons.replay_outlined,
    },
    {'id': 'caveat', 'label': 'Caveat', 'icon': Icons.warning_amber_rounded},
    {'id': 'vakalat', 'label': 'Vakalat Filing', 'icon': Icons.badge_outlined},
  ];

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

  // ─── CORE CALCULATION (TN Court Fees & Suits Valuation Act, as amended 2017) ──
  void _calculateFee() {
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    double fee2017 = 0;
    double fee1955 = 0;
    String basis = '';
    final List<String> notes = [];

    switch (_category) {
      case 'money_suit':
      case 'immovable_property':
        // Schedule I, Article 1 — "Three per cent of the amount or value"
        fee2017 = amount * 0.03;
        fee1955 = amount * 0.01;
        basis = 'Schedule I, Art. 1 — 3% of subject matter value';
        if (amount > 0 && fee2017 < 200) {
          fee2017 = 200;
          notes.add('Minimum court fee of ₹200 applied.');
        }
        break;

      case 'partition':
        if (_partitionType == 'joint_possession') {
          // Section 37(2) — plaintiff in joint possession
          fee2017 = _courtType == 'high_court' ? 10000 : 5000;
          fee1955 = _courtType == 'high_court' ? 1000 : 750;
          basis = '§37(2) — Plaintiff in joint possession (flat fee)';
          notes.add(
            _courtType == 'high_court'
                ? 'High Court Original Side: ₹10,000'
                : 'District/Sub Court: ₹5,000',
          );
        } else {
          // Section 37(1) — plaintiff excluded from possession
          fee2017 = amount * 0.03;
          fee1955 = amount * 0.01;
          basis =
              "§37(1) — Plaintiff excluded from possession (3% of plaintiff's share value)";
          notes.add("Enter the market value of the plaintiff's share claimed.");
          if (amount > 0 && fee2017 < 200) {
            fee2017 = 200;
            notes.add('Minimum court fee of ₹200 applied.');
          }
        }
        break;

      case 'probate':
        fee2017 = (amount * 0.03).clamp(0, 25000);
        fee1955 = amount * 0.03;
        basis = 'Schedule I — 3% of estate value, max ₹25,000';
        break;

      case 'appeal':
        if (_appealType == 'decree') {
          // Schedule I Art. 1 includes memoranda of appeal
          fee2017 = amount * 0.03;
          fee1955 = amount * 0.01;
          basis =
              'Schedule I, Art. 1 — Appeal from decree: 3% of subject matter';
        } else {
          // Schedule II Art. 3 — appeal from order
          fee2017 = _courtType == 'high_court' ? 2000 : 100;
          fee1955 = _courtType == 'high_court' ? 200 : 15;
          basis = 'Schedule II, Art. 3 — Appeal from order';
          notes.add(
            _courtType == 'high_court'
                ? 'To High Court: ₹2,000'
                : 'To courts other than HC: ₹100',
          );
        }
        break;

      case 'writ':
        fee2017 = 1000;
        fee1955 = 200;
        basis = 'Schedule II — Writ Petition under Art. 226: ₹1,000';
        break;

      case 'application':
        fee2017 = 20;
        fee1955 = 2;
        basis =
            'Schedule II, Art. 11(h) — Application for temporary injunction: ₹20';
        notes.add(
          'Note: This is the statutory prescribed fee per the 2017 Amendment Act.',
        );
        break;

      case 'ni_act':
        fee2017 = (amount * 0.03).clamp(0, 100000);
        fee1955 = amount * 0.01;
        basis = 'NI Act §138 complaint — 3% of cheque amount, max ₹1,00,000';
        break;

      case 'revision':
        fee2017 = 200;
        fee1955 = 15;
        basis = 'Revision Petition to District Court: ₹200';
        break;

      case 'caveat':
        fee2017 = 20;
        fee1955 = 5;
        basis = 'Caveat filing: ₹20';
        break;

      case 'vakalat':
        fee2017 = 10;
        fee1955 = 2;
        basis = 'Vakalat / Memo of Appearance: ₹10';
        break;
    }

    setState(() {
      _fee2017 = fee2017.round();
      _fee1955 = fee1955.round();
      _legalBasis = basis;
      _notes = notes;
    });
  }

  bool get _needsAmountInput =>
      [
        'money_suit',
        'immovable_property',
        'probate',
        'ni_act',
      ].contains(_category) ||
      (_category == 'partition' && _partitionType == 'excluded') ||
      (_category == 'appeal' && _appealType == 'decree');

  // ─── COPY TO CLIPBOARD ──────────────────────────────
  void _copyMemo() {
    final catLabel =
        _categories.firstWhere((c) => c['id'] == _category)['label'];
    final sb = StringBuffer();
    sb.writeln('══════════════════════════════════════');
    sb.writeln('  COURT FEE CALCULATION MEMO');
    sb.writeln('══════════════════════════════════════');
    sb.writeln('Case Type     : $catLabel');
    if (_needsAmountInput) {
      sb.writeln(
        "Subject Value : ${formatCurrency.format(double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0)}",
      );
    }
    sb.writeln('──────────────────────────────────────');
    sb.writeln(
      'Court Fee (2017 Act) : ${formatCurrency.format(_fee2017 ?? 0)}',
    );
    sb.writeln(
      'Court Fee (1955 Act) : ${formatCurrency.format(_fee1955 ?? 0)}',
    );
    sb.writeln('──────────────────────────────────────');
    sb.writeln('Legal Basis: $_legalBasis');
    for (var n in _notes) {
      sb.writeln('Note: $n');
    }
    sb.writeln('──────────────────────────────────────');
    sb.writeln(
      "Generated by CaseFlow on ${DateFormat('dd.MM.yyyy').format(DateTime.now())}",
    );

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Court fee memo copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // ─── BUILD UI (Premium card-based, matches Partition) ─
  // ═══════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Case Parameters Card ──
          _buildCard(
            isDark,
            icon: Icons.gavel,
            iconColor: AppTheme.accent,
            title: 'Case Parameters',
            children: [
              Text(
                'Select the type of case to calculate court fee as per TN Court Fees & Suits Valuation Act',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const Divider(height: 20),

              // Category selector chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _categories.map((cat) {
                      final isSelected = _category == cat['id'];
                      return InkWell(
                        onTap: () {
                          setState(() => _category = cat['id']);
                          _calculateFee();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? AppTheme.accent.withValues(alpha: 0.1)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : Colors.grey[50]),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? AppTheme.accent.withValues(alpha: 0.4)
                                      : (isDark
                                          ? Colors.white10
                                          : Colors.grey[200]!),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat['icon'],
                                size: 16,
                                color:
                                    isSelected
                                        ? AppTheme.accent
                                        : Colors.grey[400],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat['label'],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                  color:
                                      isSelected
                                          ? AppTheme.accent
                                          : (isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[700]),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: AppTheme.accent,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),

              // ─── Sub-options ──
              if (_category == 'partition') ...[
                const SizedBox(height: 16),
                _buildSegmentedToggle(
                  label: 'Possession Status (§37)',
                  options: {
                    'joint_possession': 'Joint Possession',
                    'excluded': 'Excluded from Possession',
                  },
                  selected: _partitionType,
                  onChanged: (v) {
                    setState(() => _partitionType = v);
                    _calculateFee();
                  },
                ),
                if (_partitionType == 'joint_possession') ...[
                  const SizedBox(height: 12),
                  _buildSegmentedToggle(
                    label: 'Court Type',
                    options: {
                      'sub_court': 'District / Sub Court',
                      'high_court': 'High Court (OS)',
                    },
                    selected: _courtType,
                    onChanged: (v) {
                      setState(() => _courtType = v);
                      _calculateFee();
                    },
                  ),
                ],
              ],

              if (_category == 'appeal') ...[
                const SizedBox(height: 16),
                _buildSegmentedToggle(
                  label: 'Appeal Type',
                  options: {
                    'decree': 'Appeal from Decree',
                    'order': 'Appeal from Order',
                  },
                  selected: _appealType,
                  onChanged: (v) {
                    setState(() => _appealType = v);
                    _calculateFee();
                  },
                ),
                if (_appealType == 'order') ...[
                  const SizedBox(height: 12),
                  _buildSegmentedToggle(
                    label: 'Court',
                    options: {
                      'sub_court': 'Courts other than HC',
                      'high_court': 'High Court',
                    },
                    selected: _courtType,
                    onChanged: (v) {
                      setState(() => _courtType = v);
                      _calculateFee();
                    },
                  ),
                ],
              ],

              // ─── Amount Input ──
              if (_needsAmountInput) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        _category == 'partition'
                            ? "Plaintiff's Share Value (₹)"
                            : 'Subject Matter Value / Claim Amount (₹)',
                    prefixText: '₹ ',
                    prefixStyle: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // ─── Result Card ──
          if (_fee2017 != null && (_fee2017! > 0 || !_needsAmountInput))
            _buildCard(
              isDark,
              icon: Icons.receipt_long_rounded,
              iconColor: Colors.green,
              title: 'Court Fee Result',
              trailing: TextButton.icon(
                onPressed: _copyMemo,
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy Memo', style: TextStyle(fontSize: 12)),
              ),
              children: [
                // Fee comparison
                Row(
                  children: [
                    Expanded(
                      child: _buildFeeCard(
                        '2017 Amendment',
                        formatCurrency.format(_fee2017 ?? 0),
                        true,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFeeCard(
                        '1955 Act (Old)',
                        formatCurrency.format(_fee1955 ?? 0),
                        false,
                        isDark,
                      ),
                    ),
                  ],
                ),

                // Legal basis
                if (_legalBasis.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.bookmark,
                              size: 14,
                              color: AppTheme.accent,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Legal Basis',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _legalBasis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1.5,
                          ),
                        ),
                        for (var note in _notes) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Colors.orange[400],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  note,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ─── Fee Result Card ──
  Widget _buildFeeCard(
    String label,
    String value,
    bool isPrimary,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient:
            isPrimary
                ? LinearGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.08),
                    AppTheme.primary.withValues(alpha: 0.04),
                  ],
                )
                : null,
        color:
            isPrimary
                ? null
                : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.grey[50]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isPrimary
                  ? AppTheme.accent.withValues(alpha: 0.2)
                  : (isDark ? Colors.white10 : Colors.grey[200]!),
          width: isPrimary ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isPrimary ? AppTheme.accent : Colors.grey[500],
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color:
                  isPrimary
                      ? AppTheme.accent
                      : (isDark ? Colors.white : const Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Segmented Toggle ──
  Widget _buildSegmentedToggle({
    required String label,
    required Map<String, String> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children:
                options.entries.map((e) {
                  final isActive = selected == e.key;
                  return Expanded(
                    child: InkWell(
                      onTap: () => onChanged(e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow:
                              isActive
                                  ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Text(
                          e.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                            color:
                                isActive ? AppTheme.accent : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── REUSABLE CARD (matching Partition calculator) ──
  Widget _buildCard(
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(isDark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
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
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
