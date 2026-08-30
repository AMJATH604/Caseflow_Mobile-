import 'package:flutter/material.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow Section Header
///
/// Consistent section title with optional "See All" action.
/// Used across dashboard, cases, hearings, tools screens.
///
/// Usage:
///   CfSectionHeader(
///     title: 'Today\'s Hearings',
///     icon: Icons.calendar_today_rounded,
///     trailing: '3 hearings',
///     onSeeAll: () => context.push('/hearings'),
///   )
/// ══════════════════════════════════════════════════════════════

class CfSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? trailing;
  final VoidCallback? onSeeAll;
  final String seeAllLabel;
  final EdgeInsetsGeometry? padding;

  const CfSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    this.onSeeAll,
    this.seeAllLabel = 'See All',
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);

    return Padding(
      padding: padding ?? const EdgeInsets.only(bottom: CfSpacing.md),
      child: Row(
        children: [
          // Icon
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: CfColors.brand.withValues(alpha: 0.10),
                borderRadius: CfSpacing.borderRadiusSm,
              ),
              child: Icon(
                icon,
                size: 16,
                color: CfColors.brand,
              ),
            ),
            const SizedBox(width: CfSpacing.sm),
          ],

          // Title
          Text(
            title,
            style: CfTypography.headingMd.copyWith(
              color: colors.textPrimary,
            ),
          ),

          // Trailing count/badge
          if (trailing != null) ...[
            const SizedBox(width: CfSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CfSpacing.sm,
                vertical: CfSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: CfSpacing.borderRadiusFull,
              ),
              child: Text(
                trailing!,
                style: CfTypography.captionSm.copyWith(
                  color: colors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          const Spacer(),

          // See All button
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    seeAllLabel,
                    style: CfTypography.labelMd.copyWith(
                      color: CfColors.brand,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 11,
                    color: CfColors.brand,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
