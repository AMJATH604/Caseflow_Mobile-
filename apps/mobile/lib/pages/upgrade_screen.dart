import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Plan Information',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(32.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Premium gradient icon container
              Container(
                padding: EdgeInsets.all(28.r),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.12),
                      AppTheme.accentViolet.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.coloredShadow(AppTheme.accent),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  size: 64,
                  color: AppTheme.accent,
                ),
              ),
              SizedBox(height: 32.h),
              Text(
                'All Features Unlocked!',
                style: GoogleFonts.outfit(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.8,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                'Welcome to the CaseFlow Beta Phase. We have decided to make all Professional and Business features free for all users during this period.',
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  color: const Color(0xFF64748B),
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),
              _buildBetaFeatureList(),
              SizedBox(height: 48.h),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  gradient: AppTheme.primaryGradient,
                  boxShadow: AppTheme.coloredShadow(AppTheme.accent),
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(
                    'Go to Dashboard',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15.sp,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBetaFeatureList() {
    final features = [
      'Unlimited Case Management',
      'Full OCR & PDF Document Tools',
      'Team Collaboration & Case Chat',
      'Firm-wide Notice Board',
      'Priority Cloud Storage',
      'Bulk eCourts Data Import',
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.1),
        ),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        children:
            features
                .map(
                  (f) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4.r),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: AppTheme.success,
                            size: 16,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Text(
                          f,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            fontSize: 14.sp,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}
