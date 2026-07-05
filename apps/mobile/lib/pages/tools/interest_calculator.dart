import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class InterestCalculator extends StatefulWidget {
  const InterestCalculator({super.key});

  @override
  State<InterestCalculator> createState() => _InterestCalculatorState();
}

class _InterestCalculatorState extends State<InterestCalculator> {
  final formatCurrency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final _principalController = TextEditingController();
  final _customRateController = TextEditingController();

  String _rate = '12';
  DateTime? _fromDate;
  DateTime? _toDate;
  String _interestType = 'simple';
  String _phase = 'pre_suit'; // NEW: pre_suit, pendente_lite, post_decree

  Map<String, dynamic>? _result;

  // Rate presets with corrected legal labels
  final List<Map<String, dynamic>> _ratePresets = [
    {
      'value': '6',
      'label': '6%',
      'desc': 'Post-Decree (CPC §34)',
      'color': const Color(0xFF3B82F6),
    },
    {
      'value': '9',
      'label': '9%',
      'desc': 'General Civil',
      'color': const Color(0xFF8B5CF6),
    },
    {
      'value': '12',
      'label': '12%',
      'desc': 'Commercial',
      'color': const Color(0xFFF59E0B),
    },
    {
      'value': '18',
      'label': '18%',
      'desc': 'Private Lending',
      'color': const Color(0xFFEF4444),
    },
    {
      'value': '24',
      'label': '24%',
      'desc': 'Usurious',
      'color': const Color(0xFFDC2626),
    },
    {
      'value': 'custom',
      'label': 'Custom',
      'desc': 'Enter rate',
      'color': Colors.grey,
    },
  ];

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
    final principal = double.tryParse(
      _principalController.text.replaceAll(',', ''),
    );
    final rateValue =
        _rate == 'custom'
            ? double.tryParse(_customRateController.text)
            : double.tryParse(_rate);

    if (principal == null ||
        rateValue == null ||
        _fromDate == null ||
        _toDate == null) {
      return;
    }

    final days = _toDate!.difference(_fromDate!).inDays;
    if (days < 0) return;

    final timeInYears = days / 365.25;
    double interest;

    if (_interestType == 'simple') {
      interest = (principal * rateValue * days) / 36500;
    } else {
      // Compound interest: P(1 + r)^t - P (dead code removed)
      final amount = principal * math.pow((1 + rateValue / 100), timeInYears);
      interest = amount - principal;
    }

    final total = principal + interest;
    final fmtP = formatCurrency.format(principal);
    final fmtI = formatCurrency.format(interest);
    final fmtT = formatCurrency.format(total);
    final fmtFrom = DateFormat('dd-MM-yyyy').format(_fromDate!);
    final fmtTo = DateFormat('dd-MM-yyyy').format(_toDate!);

    // Phase-aware plaint text
    String phaseLabel;
    String text;
    switch (_phase) {
      case 'pendente_lite':
        phaseLabel = 'Pendente lite interest';
        text =
            '$phaseLabel on $fmtP/- from $fmtFrom to $fmtTo ($days days) at $rateValue% p.a. (during pendency of the suit) amounts to $fmtI/-. Total: $fmtT/-.';
        break;
      case 'post_decree':
        phaseLabel = 'Post-decree interest';
        text =
            '$phaseLabel on $fmtP/- from $fmtFrom (date of decree) to $fmtTo ($days days) at $rateValue% p.a. under Section 34 CPC amounts to $fmtI/-. Total payable: $fmtT/-.';
        break;
      default:
        phaseLabel = 'Pre-suit interest';
        text =
            '$phaseLabel on $fmtP/- from $fmtFrom (date of cause of action) to $fmtTo ($days days) at $rateValue% p.a. amounts to $fmtI/-. Total claim: $fmtT/-.';
    }

    setState(() {
      _result = {
        'days': days,
        'interest': interest,
        'total': total,
        'text': text,
        'phaseLabel': phaseLabel,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Input Card ──
          _buildCard(
            isDark,
            icon: Icons.percent_rounded,
            iconColor: Colors.purple,
            title: 'Interest Parameters',
            children: [
              // Principal
              TextField(
                controller: _principalController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  labelText: 'Principal Amount (₹)',
                  prefixText: '₹ ',
                  prefixStyle: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20.h),

              // Rate Chips
              Text(
                'INTEREST RATE (% P.A.)',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 10.h),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _ratePresets.map((rp) {
                      final isSelected = _rate == rp['value'];
                      return InkWell(
                        onTap: () {
                          setState(() => _rate = rp['value']);
                          _calculate();
                        },
                        borderRadius: BorderRadius.circular(10.r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? (rp['color'] as Color).withValues(
                                      alpha: 0.1,
                                    )
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.04)
                                        : Colors.grey[50]),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? (rp['color'] as Color).withValues(
                                        alpha: 0.5,
                                      )
                                      : (isDark
                                          ? Colors.white10
                                          : Colors.grey[200]!),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                rp['label'],
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isSelected
                                          ? rp['color']
                                          : (isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[700]),
                                ),
                              ),
                              Text(
                                rp['desc'],
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),

              if (_rate == 'custom') ...[
                SizedBox(height: 12.h),
                TextField(
                  controller: _customRateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Custom Rate (%)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              SizedBox(height: 20.h),

              // Interest Phase Toggle (NEW)
              Text(
                'INTEREST PHASE',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    _buildPhaseTab('pre_suit', 'Pre-Suit'),
                    _buildPhaseTab('pendente_lite', 'Pendente Lite'),
                    _buildPhaseTab('post_decree', 'Post-Decree'),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // Date Range
              Row(
                children: [
                  Expanded(
                    child: _buildDatePicker(
                      'From Date',
                      _fromDate,
                      isDark,
                      (d) => setState(() {
                        _fromDate = d;
                        _calculate();
                      }),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildDatePicker(
                      'To Date',
                      _toDate,
                      isDark,
                      (d) => setState(() {
                        _toDate = d;
                        _calculate();
                      }),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              // Interest Type Toggle
              Container(
                padding: EdgeInsets.all(4.r),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    _buildTypeTab('simple', 'Simple Interest'),
                    _buildTypeTab('compound', 'Compound (Annual)'),
                  ],
                ),
              ),
            ],
          ),

          // ─── Result Card ──
          if (_result != null) ...[
            SizedBox(height: 16.h),
            _buildCard(
              isDark,
              icon: Icons.pie_chart_rounded,
              iconColor: Colors.green,
              title: 'Calculation Result',
              trailing: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _result!['text']));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Plaint text copied!')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy', style: TextStyle(fontSize: 12.sp)),
              ),
              children: [
                // Stats Row
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accent.withValues(alpha: 0.08),
                        AppTheme.primary.withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'Days',
                        _result!['days'].toString(),
                        Colors.blue,
                      ),
                      Container(width: 1.w, height: 40.h, color: Colors.grey[300]),
                      _buildStatItem(
                        'Interest',
                        formatCurrency.format(_result!['interest']),
                        Colors.orange,
                      ),
                      Container(width: 1.w, height: 40.h, color: Colors.grey[300]),
                      _buildStatItem(
                        'Total',
                        formatCurrency.format(_result!['total']),
                        Colors.green,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // Plaint Text
                Container(
                  padding: EdgeInsets.all(4.r),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 8.w),
                      const Icon(
                        Icons.label_important_rounded,
                        size: 14,
                        color: AppTheme.accent,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        _result!['phaseLabel'],
                        style: const TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
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
                  child: Text(
                    _result!['text'],
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontStyle: FontStyle.italic,
                      height: 1.6.h,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
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

  Widget _buildPhaseTab(String value, String label) {
    final bool isActive = _phase == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _phase = value);
          _calculate();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow:
                isActive
                    ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? AppTheme.accent : Colors.grey[500],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeTab(String type, String label) {
    final bool isSelected = _interestType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _interestType = type);
          _calculate();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.primary : Colors.grey[500],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? value,
    bool isDark,
    ValueChanged<DateTime?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8.h),
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
          borderRadius: BorderRadius.circular(10.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey[300]!,
              ),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AppTheme.accent,
                ),
                SizedBox(width: 8.w),
                Text(
                  value == null
                      ? 'Select'
                      : DateFormat('dd MMM yyyy').format(value),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight:
                        value != null ? FontWeight.w600 : FontWeight.w400,
                    color: value != null ? null : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9.sp,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

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
}
