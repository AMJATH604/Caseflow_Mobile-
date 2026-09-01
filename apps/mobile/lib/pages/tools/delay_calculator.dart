import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DelayCalculator extends StatefulWidget {
  const DelayCalculator({super.key});

  @override
  State<DelayCalculator> createState() => _DelayCalculatorState();
}

class _DelayCalculatorState extends State<DelayCalculator> {
  DateTime? _dateOfOrder;
  DateTime? _dateOfFiling;

  // Section 12 — Certified Copy exclusion dates
  DateTime? _dateCopyApplied;
  DateTime? _dateCopyReceived;
  bool _useCopyExclusion = false;


  String? _selectedPreset;

  // Expanded legal-specific presets with statutory references
  final List<Map<String, dynamic>> _presets = [
    {
      'days': 30,
      'label': '30 days',
      'desc': 'DVC Appeal (DVC Act §29)',
      'icon': Icons.gavel,
    },
    {
      'days': 30,
      'label': '30 days',
      'desc': 'First Appeal (CPC O.41 R.1)',
      'icon': Icons.looks_one_outlined,
    },
    {
      'days': 30,
      'label': '30 days',
      'desc': 'NI Act §138 Complaint',
      'icon': Icons.credit_card,
    },
    {
      'days': 30,
      'label': '30 days',
      'desc': 'CrLMP / Criminal Appeal',
      'icon': Icons.balance,
    },
    {
      'days': 60,
      'label': '60 days',
      'desc': 'Family Court Appeal',
      'icon': Icons.family_restroom,
    },
    {
      'days': 90,
      'label': '90 days',
      'desc': 'Second Appeal (CPC §100)',
      'icon': Icons.looks_two_outlined,
    },
    {
      'days': 90,
      'label': '90 days',
      'desc': 'Revision (CPC §115)',
      'icon': Icons.replay,
    },
    {
      'days': 120,
      'label': '120 days',
      'desc': 'Suit (Specific Relief)',
      'icon': Icons.article,
    },
  ];

  Map<String, dynamic>? _result;

  void _calculate() {
    if (_dateOfOrder == null || _dateOfFiling == null) return;

    // Get the limitation days from selected preset or custom
    int limitationDays = 0;
    if (_selectedPreset != null) {
      final parts = _selectedPreset!.split('|');
      limitationDays = int.parse(parts[0]);
    }

    // Section 12 — Exclude time taken to obtain certified copy
    int sec12ExcludedDays = 0;
    String sec12Note = '';
    if (_useCopyExclusion &&
        _dateCopyApplied != null &&
        _dateCopyReceived != null) {
      sec12ExcludedDays =
          _dateCopyReceived!.difference(_dateCopyApplied!).inDays;
      if (sec12ExcludedDays < 0) sec12ExcludedDays = 0;
      sec12Note =
          '\n\nSection 12 Exclusion: ${sec12ExcludedDays} day${sec12ExcludedDays != 1 ? "s" : ""} excluded '
          '(copy applied: ${DateFormat("dd-MM-yyyy").format(_dateCopyApplied!)} '
          'to copy received: ${DateFormat("dd-MM-yyyy").format(_dateCopyReceived!)})';
    }

    // Adjusted due date = order date + limitation + Section 12 excluded days
    final dueDate = _dateOfOrder!.add(
      Duration(days: limitationDays + sec12ExcludedDays),
    );
    final delay = _dateOfFiling!.difference(dueDate).inDays;
    final totalDays = _dateOfFiling!.difference(_dateOfOrder!).inDays;

    final fmtOrder = DateFormat('dd-MM-yyyy (EEEE)').format(_dateOfOrder!);
    final fmtFiling = DateFormat('dd-MM-yyyy (EEEE)').format(_dateOfFiling!);
    final fmtDue = DateFormat('dd-MM-yyyy (EEEE)').format(dueDate);

    String status;
    Color statusColor;
    IconData statusIcon;
    if (delay <= 0) {
      status = 'WITHIN TIME — No condonation needed';
      statusColor = const Color(0xFF059669);
      statusIcon = Icons.check_circle_rounded;
    } else {
      status = "DELAYED by $delay DAY${delay == 1 ? '' : 'S'}";
      statusColor = const Color(0xFFDC2626);
      statusIcon = Icons.warning_rounded;
    }

    // Affidavit text
    final presetLabel =
        _selectedPreset != null
            ? _presets.firstWhere(
              (p) => "${p['days']}|${p['desc']}" == _selectedPreset,
            )['desc']
            : 'prescribed period';

    final sec12Para = (_useCopyExclusion && sec12ExcludedDays > 0)
        ? '\n\n3. The petitioner applied for a certified copy of the impugned order/judgment on ${DateFormat("dd-MM-yyyy").format(_dateCopyApplied!)} and the same was made ready/received on ${DateFormat("dd-MM-yyyy").format(_dateCopyReceived!)}. The time of $sec12ExcludedDays day${sec12ExcludedDays != 1 ? "s" : ""} spent in obtaining the certified copy is liable to be excluded under Section 12 of the Limitation Act, 1963.\n\n4. After excluding the said $sec12ExcludedDays day${sec12ExcludedDays != 1 ? "s" : ""} under Section 12, the adjusted last date for filing was $fmtDue.'
        : '';

    final actualDelay = delay > 0 ? delay : 0;
    final delayParaNum = (_useCopyExclusion && sec12ExcludedDays > 0) ? '5' : '3';
    final causeParaNum = (_useCopyExclusion && sec12ExcludedDays > 0) ? '6' : '4';
    final bonaFideNum = (_useCopyExclusion && sec12ExcludedDays > 0) ? '7' : '5';

    final affidavitText =
        """AFFIDAVIT IN SUPPORT OF APPLICATION U/S 5 OF THE LIMITATION ACT, 1963

I, _____________ S/o/D/o/W/o _____________, aged about ___ years, residing at _____________, do hereby solemnly affirm and state as follows:

1. The impugned order/judgment was passed on $fmtOrder.

2. The limitation for filing the appeal/petition ($presetLabel) is ${limitationDays} days.$sec12Para

$delayParaNum. The present appeal/petition is being filed on $fmtFiling, i.e., after a delay of $actualDelay day${actualDelay != 1 ? 's' : ''}.

$causeParaNum. The delay of $actualDelay day${actualDelay != 1 ? 's' : ''} in filing the present appeal/petition was occasioned due to _____________ [state sufficient cause, e.g., bonafide belief, illness, legal advice, etc.].

$bonaFideNum. The delay was neither intentional nor deliberate. The petitioner had a bona fide intention to file the appeal/petition within the prescribed time and there was sufficient cause for not filing it within the limitation period.

PRAYER: The petitioner therefore most humbly prays that this Honourable Court may be pleased to condone the delay of $actualDelay day${actualDelay != 1 ? 's' : ''} in filing the present appeal/petition in the interest of justice and admit the same for adjudication on merits.

VERIFICATION: Verified at _____________ on this the ___ day of _____________ that the contents of the above affidavit are true and correct to the best of my knowledge and belief and nothing material has been concealed therefrom.

DEPONENT""";

    setState(() {
      _result = {
        'delay': actualDelay,
        'totalDays': totalDays,
        'limitationDays': limitationDays,
        'sec12Days': sec12ExcludedDays,
        'dueDate': fmtDue,
        'status': status,
        'statusColor': statusColor,
        'statusIcon': statusIcon,
        'isDelayed': delay > 0,
        'affidavitText': affidavitText,
        'sec12Note': sec12Note,
      };
    });
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
            icon: Icons.schedule_rounded,
            iconColor: Colors.red,
            title: 'Delay Parameters',
            children: [
              Text(
                'Select the limitation period and dates to calculate delay under Section 5, Limitation Act 1963',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              ),
              Divider(height: 20.h),

              // Limitation Period Presets
              Text(
                'LIMITATION PERIOD',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 10.h),
              ...(_presets.map((p) {
                final key = "${p['days']}|${p['desc']}";
                final isSelected = _selectedPreset == key;
                return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedPreset = key);
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
                          Icon(
                            p['icon'] as IconData,
                            size: 18,
                            color:
                                isSelected ? AppTheme.accent : Colors.grey[400],
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['desc'],
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
                                  p['label'],
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

              SizedBox(height: 20.h),

              // Date pickers
              Row(
                children: [
                  Expanded(
                    child: _buildDatePicker(
                      'Date of Order/Judgment',
                      _dateOfOrder,
                      isDark,
                      (d) => setState(() {
                        _dateOfOrder = d;
                        _calculate();
                      }),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildDatePicker(
                      'Date of Filing',
                      _dateOfFiling,
                      isDark,
                      (d) => setState(() {
                        _dateOfFiling = d;
                        _calculate();
                      }),
                    ),
                  ),
                ],
              ),

              // ─── Section 12 Exclusion Toggle ──
              SizedBox(height: 20.h),
              Container(
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.indigo.withValues(alpha: 0.08)
                      : const Color(0xFFF0F0FF),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Colors.indigo.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description_rounded,
                          size: 18,
                          color: Colors.indigo[400],
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Section 12 — Certified Copy Exclusion',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.indigo[900],
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: _useCopyExclusion,
                            activeColor: AppTheme.accent,
                            onChanged: (v) {
                              setState(() {
                                _useCopyExclusion = v;
                                if (!v) {
                                  _dateCopyApplied = null;
                                  _dateCopyReceived = null;
                                }
                              });
                              _calculate();
                            },
                          ),
                        ),
                      ],
                    ),
                    if (!_useCopyExclusion)
                      Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Text(
                          'Enable to exclude time spent obtaining certified copy (Sec 12, Limitation Act)',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    if (_useCopyExclusion) ...[
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePicker(
                              'Copy Applied On',
                              _dateCopyApplied,
                              isDark,
                              (d) => setState(() {
                                _dateCopyApplied = d;
                                _calculate();
                              }),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildDatePicker(
                              'Copy Received On',
                              _dateCopyReceived,
                              isDark,
                              (d) => setState(() {
                                _dateCopyReceived = d;
                                _calculate();
                              }),
                            ),
                          ),
                        ],
                      ),
                      if (_dateCopyApplied != null && _dateCopyReceived != null)
                        Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 14,
                                  color: Colors.green[700],
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  '${_dateCopyReceived!.difference(_dateCopyApplied!).inDays} days will be excluded under Sec 12',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),

              // Section 4 note
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.amber[700],
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Sec 4: If due date falls on a court holiday, period extends to next working day.\nSec 12: Time spent obtaining certified copy is excluded from limitation.',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.amber[800],
                          fontWeight: FontWeight.w500,
                          height: 1.4.h,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ─── Result Card ──
          if (_result != null) ...[
            SizedBox(height: 16.h),

            // Status banner
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: (_result!['statusColor'] as Color).withValues(
                  alpha: 0.08,
                ),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: (_result!['statusColor'] as Color).withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _result!['statusIcon'],
                    color: _result!['statusColor'],
                    size: 28,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _result!['status'],
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                            color: _result!['statusColor'],
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "Last date: ${_result!['dueDate']}",
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Stats
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _buildStatBlock(
                    'Limitation',
                    "${_result!['limitationDays']} days",
                    Colors.blue,
                    isDark,
                  ),
                ),
                if ((_result!['sec12Days'] as int) > 0) ...[
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildStatBlock(
                      'Sec 12',
                      "${_result!['sec12Days']} days",
                      Colors.indigo,
                      isDark,
                    ),
                  ),
                ],
                SizedBox(width: 8.w),
                Expanded(
                  child: _buildStatBlock(
                    'Elapsed',
                    "${_result!['totalDays']} days",
                    Colors.orange,
                    isDark,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _buildStatBlock(
                    'Delay',
                    "${_result!['delay']} days",
                    _result!['isDelayed'] ? Colors.red : Colors.green,
                    isDark,
                  ),
                ),
              ],
            ),

            // Affidavit text (only show if delayed)
            if (_result!['isDelayed']) ...[
              SizedBox(height: 16.h),
              _buildCard(
                isDark,
                icon: Icons.description_rounded,
                iconColor: Colors.indigo,
                title: 'Affidavit Draft',
                trailing: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _result!['affidavitText']),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Affidavit text copied!')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: Text('Copy', style: TextStyle(fontSize: 12.sp)),
                ),
                children: [
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
                    child: Text(
                      _result!['affidavitText'],
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 11.sp,
                        height: 1.6.h,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
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

  Widget _buildStatBlock(String label, String value, Color color, bool isDark) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
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
