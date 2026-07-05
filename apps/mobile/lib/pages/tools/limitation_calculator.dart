import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LimitationCalculator extends StatefulWidget {
  const LimitationCalculator({super.key});

  @override
  State<LimitationCalculator> createState() => _LimitationCalculatorState();
}

class _LimitationCalculatorState extends State<LimitationCalculator> {
  DateTime? _accrualDate;
  String? _selectedArticle;
  final _customPeriodController = TextEditingController();
  String _customUnit = 'days';

  Map<String, dynamic>? _result;

  // Limitation Act Schedule of Articles (common ones)
  final List<Map<String, dynamic>> _articles = [
    {
      'id': 'art58',
      'article': 'Art. 58',
      'desc': 'Specific Performance of Contract',
      'days': 1095,
      'label': '3 years',
    },
    {
      'id': 'art65',
      'article': 'Art. 65',
      'desc': 'Suit for Possession (12 years)',
      'days': 4380,
      'label': '12 years',
    },
    {
      'id': 'art113',
      'article': 'Art. 113',
      'desc': 'Personal Suit (Residuary)',
      'days': 1095,
      'label': '3 years',
    },
    {
      'id': 'art137',
      'article': 'Art. 137',
      'desc': 'Any Application (Residuary)',
      'days': 1095,
      'label': '3 years',
    },
    {
      'id': 'art54',
      'article': 'Art. 54',
      'desc': 'Suit for Injunction',
      'days': 1095,
      'label': '3 years',
    },
    {
      'id': 'art62',
      'article': 'Art. 62',
      'desc': 'Declaratory Suit',
      'days': 1095,
      'label': '3 years',
    },
    {
      'id': 'art36',
      'article': 'Art. 36',
      'desc': 'Execution of Decree',
      'days': 4380,
      'label': '12 years',
    },
    {
      'id': 'ni138',
      'article': 'NI Act §138',
      'desc': 'Cheque Bounce Complaint',
      'days': 30,
      'label': '30 days',
    },
    {
      'id': 'consumer',
      'article': 'Consumer',
      'desc': 'Consumer Complaint (CDPA 2019)',
      'days': 730,
      'label': '2 years',
    },
    {
      'id': 'mact',
      'article': 'MACT',
      'desc': 'Motor Accident Claim',
      'days': 180,
      'label': '6 months',
    },
    {
      'id': 'art116',
      'article': 'Art. 116',
      'desc': 'Suit by Landlord for Eviction',
      'days': 4380,
      'label': '12 years',
    },
    {
      'id': 'art55',
      'article': 'Art. 55',
      'desc': 'Suit for Compensation (tort)',
      'days': 365,
      'label': '1 year',
    },
    {
      'id': 'custom',
      'article': 'Custom',
      'desc': 'Enter custom period',
      'days': 0,
      'label': 'Custom',
    },
  ];

  // ─── FIX: Proper month arithmetic (no overflow bug) ──
  DateTime _addMonths(DateTime date, int months) {
    final int targetYear = date.year + ((date.month + months - 1) ~/ 12);
    final int targetMonth = ((date.month + months - 1) % 12) + 1;
    int targetDay = date.day;
    // Clamp day to valid range for the target month
    final int maxDay = DateTime(targetYear, targetMonth + 1, 0).day;
    if (targetDay > maxDay) targetDay = maxDay;
    return DateTime(targetYear, targetMonth, targetDay);
  }

  DateTime _addPeriod(DateTime from, int value, String unit) {
    switch (unit) {
      case 'days':
        return from.add(Duration(days: value));
      case 'months':
        return _addMonths(from, value);
      case 'years':
        return _addMonths(from, value * 12);
      default:
        return from.add(Duration(days: value));
    }
  }

  void _calculate() {
    if (_accrualDate == null || _selectedArticle == null) return;

    int periodDays = 0;
    String periodLabel = '';
    String articleRef = '';

    if (_selectedArticle == 'custom') {
      final customVal = int.tryParse(_customPeriodController.text);
      if (customVal == null || customVal <= 0) return;

      final expiryDate = _addPeriod(_accrualDate!, customVal, _customUnit);
      periodDays = expiryDate.difference(_accrualDate!).inDays;
      periodLabel = '$customVal $_customUnit';
      articleRef = 'Custom Period';

      _buildResult(expiryDate, periodDays, periodLabel, articleRef);
    } else {
      final article = _articles.firstWhere((a) => a['id'] == _selectedArticle);
      periodDays = article['days'];
      periodLabel = article['label'];
      articleRef = "${article['article']} — ${article['desc']}";

      final expiryDate = _accrualDate!.add(Duration(days: periodDays));
      _buildResult(expiryDate, periodDays, periodLabel, articleRef);
    }
  }

  void _buildResult(
    DateTime expiryDate,
    int periodDays,
    String periodLabel,
    String articleRef,
  ) {
    final now = DateTime.now();
    final daysRemaining = expiryDate.difference(now).inDays;
    final isExpired = daysRemaining < 0;

    setState(() {
      _result = {
        'expiryDate': expiryDate,
        'daysRemaining': daysRemaining,
        'isExpired': isExpired,
        'periodDays': periodDays,
        'periodLabel': periodLabel,
        'articleRef': articleRef,
      };
    });
  }

  @override
  void dispose() {
    _customPeriodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        children: [
          // ─── Input Card ──
          _buildCard(
            isDark,
            icon: Icons.timer_rounded,
            iconColor: Colors.teal,
            title: 'Limitation Period',
            children: [
              Text(
                'Select the article from the Limitation Act, 1963 or enter a custom period.',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              ),
              Divider(height: 20.h),

              // Date of Accrual
              _buildDatePicker(
                'Date of Cause of Action / Accrual',
                _accrualDate,
                isDark,
                (d) => setState(() {
                  _accrualDate = d;
                  _calculate();
                }),
              ),
              SizedBox(height: 20.h),

              // Article Selection
              Text(
                'LIMITATION ACT ARTICLE',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 10.h),

              ...(_articles.map((art) {
                final isSelected = _selectedArticle == art['id'];
                return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedArticle = art['id']);
                      _calculate();
                    },
                    borderRadius: BorderRadius.circular(10.r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppTheme.accent.withValues(alpha: 0.08)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.grey[50]),
                        borderRadius: BorderRadius.circular(10.r),
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
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? AppTheme.accent.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              art['article'],
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w800,
                                color:
                                    isSelected
                                        ? AppTheme.accent
                                        : Colors.grey[500],
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  art['desc'],
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isSelected
                                            ? AppTheme.accent
                                            : (isDark
                                                ? Colors.white
                                                : Colors.black87),
                                  ),
                                ),
                                Text(
                                  art['label'],
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: AppTheme.accent,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              })),

              // Custom period inputs
              if (_selectedArticle == 'custom') ...[
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _customPeriodController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => _calculate(),
                        decoration: const InputDecoration(
                          labelText: 'Period Value',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _customUnit,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Unit',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'days', child: Text('Days')),
                          DropdownMenuItem(
                            value: 'months',
                            child: Text('Months'),
                          ),
                          DropdownMenuItem(
                            value: 'years',
                            child: Text('Years'),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _customUnit = v!);
                          _calculate();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),

          // ─── Result ──
          if (_result != null) ...[
            SizedBox(height: 16.h),

            // Expiry Banner
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      _result!['isExpired']
                          ? [
                            const Color(0xFFDC2626).withValues(alpha: 0.08),
                            const Color(0xFFDC2626).withValues(alpha: 0.03),
                          ]
                          : [
                            const Color(0xFF059669).withValues(alpha: 0.08),
                            const Color(0xFF059669).withValues(alpha: 0.03),
                          ],
                ),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color:
                      _result!['isExpired']
                          ? const Color(0xFFDC2626).withValues(alpha: 0.3)
                          : const Color(0xFF059669).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _result!['isExpired']
                        ? Icons.error_rounded
                        : Icons.verified_rounded,
                    color:
                        _result!['isExpired']
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF059669),
                    size: 40,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    _result!['isExpired']
                        ? 'LIMITATION EXPIRED'
                        : 'WITHIN LIMITATION',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                      color:
                          _result!['isExpired']
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF059669),
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    _result!['isExpired']
                        ? "Expired ${(-_result!['daysRemaining'])} day${(-_result!['daysRemaining']) == 1 ? '' : 's'} ago"
                        : "${_result!['daysRemaining']} day${_result!['daysRemaining'] == 1 ? '' : 's'} remaining",
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                      color:
                          _result!['isExpired']
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF059669),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    "Expiry: ${DateFormat('dd MMMM yyyy (EEEE)').format(_result!['expiryDate'])}",
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // Info card
            SizedBox(height: 12.h),
            _buildCard(
              isDark,
              icon: Icons.bookmark_rounded,
              iconColor: AppTheme.accent,
              title: 'Legal Reference',
              trailing: TextButton.icon(
                onPressed: () {
                  final text =
                      "Limitation: ${_result!['articleRef']}\nPeriod: ${_result!['periodLabel']}\nDate of Accrual: ${DateFormat('dd-MM-yyyy').format(_accrualDate!)}\nExpiry: ${DateFormat('dd-MM-yyyy').format(_result!['expiryDate'])}\n${_result!['isExpired'] ? 'EXPIRED ${(-_result!['daysRemaining'])} days ago' : '${_result!['daysRemaining']} days remaining'}\n\nGenerated by CaseFlow";
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Limitation memo copied!')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: Text('Copy', style: TextStyle(fontSize: 12.sp)),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(14.r),
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
                    children: [
                      _buildInfoRow('Article', _result!['articleRef']),
                      SizedBox(height: 8.h),
                      _buildInfoRow('Period', _result!['periodLabel']),
                      SizedBox(height: 8.h),
                      _buildInfoRow(
                        'From',
                        DateFormat('dd MMMM yyyy').format(_accrualDate!),
                      ),
                      SizedBox(height: 8.h),
                      _buildInfoRow(
                        'Expires',
                        DateFormat(
                          'dd MMMM yyyy',
                        ).format(_result!['expiryDate']),
                      ),
                    ],
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: Colors.grey[500],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ],
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
            width: double.infinity,
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
                      ? 'Select date'
                      : DateFormat('dd MMM yyyy').format(value),
                  style: TextStyle(
                    fontSize: 14.sp,
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
