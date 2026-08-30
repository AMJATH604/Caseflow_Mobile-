import 'package:flutter/material.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow Stat Tile
///
/// Compact stat display with icon, value, label, and optional
/// trend indicator. Used on dashboard for KPI summaries.
///
/// Usage:
///   CfStatTile(
///     icon: Icons.folder_rounded,
///     iconColor: CfColors.brand,
///     value: '24',
///     label: 'Active Cases',
///     trend: '+3 this week',
///     trendUp: true,
///   )
/// ══════════════════════════════════════════════════════════════

class CfStatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String? trend;
  final bool? trendUp; // true = up/good, false = down/bad, null = neutral
  final VoidCallback? onTap;

  const CfStatTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.trend,
    this.trendUp,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: CfSpacing.cardPadding,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: CfSpacing.borderRadiusLg,
          border: Border.all(color: colors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: CfSpacing.borderRadiusMd,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),

            const SizedBox(height: CfSpacing.md),

            // Value
            Text(
              value,
              style: CfTypography.statMd.copyWith(
                color: colors.textPrimary,
              ),
            ),

            const SizedBox(height: CfSpacing.xxs),

            // Label
            Text(
              label,
              style: CfTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Trend
            if (trend != null) ...[
              const SizedBox(height: CfSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (trendUp != null)
                    Icon(
                      trendUp! ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 14,
                      color: trendUp! ? CfColors.success : CfColors.error,
                    ),
                  if (trendUp != null) const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      trend!,
                      style: CfTypography.captionSm.copyWith(
                        color: trendUp == null
                            ? colors.textTertiary
                            : (trendUp! ? CfColors.success : CfColors.error),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
