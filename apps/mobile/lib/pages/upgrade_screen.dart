import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        title: const Text(
          'Plan Information',
          style: TextStyle(fontWeight: FontWeight.bold),
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
              Container(
                padding: EdgeInsets.all(24.r),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  size: 64,
                  color: AppTheme.accent,
                ),
              ),
              SizedBox(height: 32.h),
              const Text(
                'All Features Unlocked!',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Playfair Display',
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              const Text(
                'Welcome to the CaseFlow Beta Phase. We have decided to make all Professional and Business features free for all users during this period.',
                style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),
              _buildBetaFeatureList(),
              SizedBox(height: 48.h),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Go to Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children:
            features
                .map(
                  (f) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          f,
                          style: const TextStyle(fontWeight: FontWeight.w500),
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
