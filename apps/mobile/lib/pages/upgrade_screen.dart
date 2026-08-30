import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';
import '../theme/cf_decorations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ══════════════════════════════════════════════════════════════
/// Upgrade / Plan Screen — Sprint 3 Redesign
///
/// Communicates beta period with all features unlocked.
/// Uses premium gradient hero and token-based styling.
/// ══════════════════════════════════════════════════════════════

class UpgradeScreen extends ConsumerStatefulWidget {
  const UpgradeScreen({super.key});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Plan Information',
          style: CfTypography.headingSm.copyWith(color: colors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: CfSpacing.pagePadding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ─── Hero Icon with Gradient Glow ────────
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      CfColors.brand.withValues(alpha: 0.15),
                      CfColors.brand.withValues(alpha: 0.03),
                    ],
                    radius: 0.8,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  size: 64,
                  color: CfColors.brand,
                ),
              ),
              const SizedBox(height: 28),

              // ─── Title ──────────────────────────────
              Text(
                'All Features Unlocked!',
                style: CfTypography.headingLg.copyWith(
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // ─── Subtitle ──────────────────────────
              Text(
                'Welcome to the CaseFlow Beta Phase. All Professional and Business features are free for all users during this period.',
                style: CfTypography.bodyMd.copyWith(
                  color: colors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              // ─── Features List Card ────────────────
              _buildBetaFeatureList(colors, isDark),
              const SizedBox(height: 36),

              // ─── CTA Button ────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Go to Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CfColors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CfSpacing.radiusLg),
                    ),
                    elevation: 0,
                    textStyle: CfTypography.labelLg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBetaFeatureList(CfColorScheme colors, bool isDark) {
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: CfSpacing.borderRadiusXl,
        border: Border.all(
          color: CfColors.brand.withValues(alpha: 0.15),
        ),
        boxShadow: CfDecorations.shadowSm(isDark),
      ),
      child: Column(
        children: features.map((f) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: CfColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: CfColors.success,
                  size: 14,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                f,
                style: CfTypography.bodyMd.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}
