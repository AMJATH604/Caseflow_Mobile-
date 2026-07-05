import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../components/status_badge.dart';
import '../components/epay_court_fee_sheet.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CaseHeader extends StatelessWidget {
  final CaseModel caseData;
  final VoidCallback onBack;

  const CaseHeader({super.key, required this.caseData, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: const BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: onBack,
                  child: Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF1E293B),
                      size: 16,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CASE FILE DOSSIER',
                        style: TextStyle(
                          color: AppTheme.accent.withValues(alpha: 0.7),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        caseData.caseTitle,
                        style: GoogleFonts.inter(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                StatusBadge(status: caseData.status.name),
              ],
            ),
            SizedBox(height: 20.h),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _headerChip(
                  context,
                  Icons.tag_rounded,
                  caseData.caseNumber ?? 'NO IDENTIFIER',
                ),
                _headerChip(
                  context,
                  Icons.account_balance_rounded,
                  caseData.courtName ?? 'UNSPECIFIED FORUM',
                ),
                _buildPayCourtFeeChip(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayCourtFeeChip(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            () => EPayCourtFeeSheet.show(
              context,
              caseTitle: caseData.caseTitle,
              courtName: caseData.courtName,
            ),
        borderRadius: BorderRadius.circular(6.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2563EB).withValues(alpha: 0.1),
                const Color(0xFF3B82F6).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(6.r),
            border: Border.all(
              color: const Color(0xFF2563EB).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.payment_rounded,
                size: 12,
                color: const Color(0xFF2563EB).withValues(alpha: 0.8),
              ),
              SizedBox(width: 6.w),
              const Text(
                'PAY COURT FEE',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                Icons.open_in_new_rounded,
                size: 10,
                color: const Color(0xFF2563EB).withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerChip(BuildContext context, IconData icon, String text) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppTheme.accent.withValues(alpha: 0.7)),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                text.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
