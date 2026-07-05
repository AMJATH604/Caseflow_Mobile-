import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/payment_capture_service.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A rich bottom sheet that lets the user select a payment type
/// and launches the official eCourts ePay portal.
///
/// Now integrates with PaymentCaptureService to auto-popup
/// a payment sync dialog when the user returns from the portal.
///
/// Usage:
///   EPayCourtFeeSheet.show(context);
///   EPayCourtFeeSheet.show(context, caseId: 'xxx', caseTitle: 'Ram vs Shyam');
class EPayCourtFeeSheet extends ConsumerStatefulWidget {
  final String? caseId;
  final String? caseTitle;
  final String? courtName;

  const EPayCourtFeeSheet({
    super.key,
    this.caseId,
    this.caseTitle,
    this.courtName,
  });

  /// Convenience method to show the sheet from anywhere.
  static void show(
    BuildContext context, {
    String? caseId,
    String? caseTitle,
    String? courtName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => EPayCourtFeeSheet(
            caseId: caseId,
            caseTitle: caseTitle,
            courtName: courtName,
          ),
    );
  }

  @override
  ConsumerState<EPayCourtFeeSheet> createState() => _EPayCourtFeeSheetState();
}

class _EPayCourtFeeSheetState extends ConsumerState<EPayCourtFeeSheet>
    with SingleTickerProviderStateMixin {
  String? _selectedPaymentType;
  String? _selectedCaseId;
  String? _selectedCaseTitle;
  bool _isLaunching = false;
  late AnimationController _shimmerCtrl;

  // eCourts ePay base URL – works for all of India
  static const _epayBaseUrl = 'https://pay.ecourts.gov.in/epay/';

  final List<_PaymentTypeOption> _paymentTypes = const [
    _PaymentTypeOption(
      id: 'court_fee',
      title: 'Court Fee',
      subtitle: 'Filing fee, vakalatnama, petition stamp',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF2563EB),
    ),
    _PaymentTypeOption(
      id: 'fine',
      title: 'Fine / Penalty',
      subtitle: 'Criminal fine, traffic challan, penalty',
      icon: Icons.gavel_rounded,
      color: Color(0xFFDC2626),
    ),
    _PaymentTypeOption(
      id: 'judicial_deposit',
      title: 'Judicial Deposit',
      subtitle: 'Fixed deposit, rent deposit, surplus',
      icon: Icons.savings_rounded,
      color: Color(0xFF059669),
    ),
    _PaymentTypeOption(
      id: 'process_fee',
      title: 'Process Fee',
      subtitle: 'Summons, warrant, notice charges',
      icon: Icons.mail_rounded,
      color: Color(0xFFF59E0B),
    ),
    _PaymentTypeOption(
      id: 'copy_fee',
      title: 'Certified Copy Fee',
      subtitle: 'Judgment copy, order copy, CC fee',
      icon: Icons.file_copy_rounded,
      color: Color(0xFF8B5CF6),
    ),
    _PaymentTypeOption(
      id: 'miscellaneous',
      title: 'Miscellaneous',
      subtitle: 'Other court-related payments',
      icon: Icons.more_horiz_rounded,
      color: Color(0xFF6B7280),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCaseId = widget.caseId;
    _selectedCaseTitle = widget.caseTitle;
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchEPay() async {
    setState(() => _isLaunching = true);
    try {
      // ── Smart Sync: Set pending payment before leaving ──
      if (_selectedCaseId != null && _selectedCaseTitle != null) {
        final purpose =
            _paymentTypes
                .firstWhere(
                  (pt) => pt.id == _selectedPaymentType,
                  orElse: () => _paymentTypes.first,
                )
                .title;

        await PaymentCaptureService().setPendingPayment(
          caseId: _selectedCaseId!,
          caseTitle: _selectedCaseTitle!,
          purpose: purpose,
        );
      }

      final uri = Uri.parse(_epayBaseUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open eCourts ePay portal'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(casesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder:
          (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Drag Handle ───
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 20.h),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),

                  // ─── Header Banner ───
                  _buildHeaderBanner(),
                  SizedBox(height: 24.h),

                  // ─── Case Selector (NEW — Smart Sync) ───
                  Text(
                    'SELECT CASE',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[400],
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  casesAsync.when(
                    data:
                        (cases) => Container(
                          decoration: BoxDecoration(
                            color:
                                _selectedCaseId != null
                                    ? const Color(0xFFF0FDF4)
                                    : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color:
                                  _selectedCaseId != null
                                      ? const Color(
                                        0xFF059669,
                                      ).withValues(alpha: 0.3)
                                      : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedCaseId,
                            isExpanded: true,
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Link a case for auto-sync...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 13.sp,
                                color: Colors.grey[400],
                              ),
                              prefixIcon: Icon(
                                _selectedCaseId != null
                                    ? Icons.check_circle_rounded
                                    : Icons.folder_shared_outlined,
                                color:
                                    _selectedCaseId != null
                                        ? const Color(0xFF059669)
                                        : Colors.grey[400],
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                            items:
                                cases
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(
                                          c.caseTitle.isEmpty
                                              ? (c.caseNumber ?? 'Case')
                                              : c.caseTitle,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              final selected = cases.firstWhere(
                                (c) => c.id == val,
                              );
                              setState(() {
                                _selectedCaseId = val;
                                _selectedCaseTitle =
                                    selected.caseTitle.isEmpty
                                        ? (selected.caseNumber ?? 'Case')
                                        : selected.caseTitle;
                              });
                            },
                          ),
                        ),
                    loading: () => const LinearProgressIndicator(),
                    error:
                        (_, __) => Text(
                          'Could not load cases',
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                  ),

                  // Smart Sync hint
                  if (_selectedCaseId != null) ...[
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 14,
                          color: Color(0xFF059669),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Smart Sync ON — payment will auto-link when you return',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: const Color(0xFF059669),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],

                  SizedBox(height: 24.h),

                  // ─── Case Context (if provided) ───
                  if (widget.caseTitle != null && _selectedCaseId == null) ...[
                    _buildCaseContext(),
                    SizedBox(height: 20.h),
                  ],

                  // ─── Payment Type Selector ───
                  Text(
                    'SELECT PAYMENT TYPE',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[400],
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  ..._paymentTypes.map((pt) => _buildPaymentTypeCard(pt)),

                  SizedBox(height: 24.h),

                  // ─── Launch Button ───
                  _buildLaunchButton(),
                  SizedBox(height: 16.h),

                  // ─── Info Footer ───
                  _buildInfoFooter(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'eCourts ePay',
                  style: GoogleFonts.outfit(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Official court fee payment portal for all India',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              'GOV',
              style: GoogleFonts.inter(
                fontSize: 10.sp,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseContext() {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder_rounded,
            size: 18,
            color: AppTheme.accent.withValues(alpha: 0.7),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paying for',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.caseTitle!,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.courtName != null)
                  Text(
                    widget.courtName!,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTypeCard(_PaymentTypeOption pt) {
    final isSelected = _selectedPaymentType == pt.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentType = pt.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: isSelected ? pt.color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color:
                isSelected
                    ? pt.color.withValues(alpha: 0.4)
                    : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: pt.color.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: pt.color.withValues(alpha: isSelected ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(pt.icon, color: pt.color, size: 22),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pt.title,
                    style: GoogleFonts.inter(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? pt.color : AppTheme.primary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    pt.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22.w,
              height: 22.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? pt.color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? pt.color : Colors.grey[300]!,
                  width: 2.w,
                ),
              ),
              child:
                  isSelected
                      ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaunchButton() {
    final canLaunch = _selectedPaymentType != null && !_isLaunching;
    return SizedBox(
      width: double.infinity,
      height: 56.h,
      child: ElevatedButton(
        onPressed: canLaunch ? _launchEPay : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: canLaunch ? 6 : 0,
          shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          disabledBackgroundColor: Colors.grey[200],
        ),
        child:
            _isLaunching
                ? SizedBox(
                  height: 24.h,
                  width: 24.w,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.launch_rounded, size: 20),
                    SizedBox(width: 10.w),
                    Text(
                      'Open eCourts ePay Portal',
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildInfoFooter() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Color(0xFF92400E),
              ),
              SizedBox(width: 8.w),
              Text(
                'Smart Sync Enabled',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF92400E),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          _buildInfoStep('1', 'Select your case above for automatic tracking'),
          _buildInfoStep(
            '2',
            "You'll be redirected to the official eCourts ePay portal",
          ),
          _buildInfoStep('3', 'Pay via Net Banking / UPI / Card on the portal'),
          _buildInfoStep(
            '4',
            "Return to CaseFlow — we'll ask for the amount & receipt",
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(
                Icons.verified_user_rounded,
                size: 14,
                color: Colors.green[700],
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Secured by Government of India — National Informatics Centre (NIC)',
                  style: GoogleFonts.inter(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[800],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStep(String number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18.w,
            height: 18.h,
            margin: EdgeInsets.only(right: 8.w, top: 1.h),
            decoration: BoxDecoration(
              color: const Color(0xFF92400E).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF92400E),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                color: const Color(0xFF78350F),
                height: 1.4.h,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTypeOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _PaymentTypeOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
