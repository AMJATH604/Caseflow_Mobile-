import 'package:flutter/material.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';
import '../theme/cf_decorations.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow Empty State
///
/// Beautiful illustrated empty state with contextual message
/// and call-to-action. Replaces the basic text-only empty states.
///
/// Usage:
///   CfEmptyState(
///     icon: Icons.folder_open_rounded,
///     title: 'No Cases Yet',
///     description: 'Add your first case to get started',
///     actionLabel: '+ Add Case',
///     onAction: () => showNewCaseDialog(context),
///   )
/// ══════════════════════════════════════════════════════════════

class CfEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double iconSize;
  final bool compact;

  const CfEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.iconSize = 64,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: CfSpacing.xxl,
          vertical: compact ? CfSpacing.xl : CfSpacing.huge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustrated icon with gradient background
            Container(
              width: compact ? 72 : 100,
              height: compact ? 72 : 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CfColors.brand.withValues(alpha: 0.08),
                    CfColors.brand.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: CfColors.brand.withValues(alpha: 0.10),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                size: compact ? 32 : iconSize * 0.6,
                color: CfColors.brand.withValues(alpha: 0.50),
              ),
            ),

            SizedBox(height: compact ? CfSpacing.base : CfSpacing.xl),

            // Title
            Text(
              title,
              style: (compact ? CfTypography.headingSm : CfTypography.headingLg)
                  .copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: CfSpacing.sm),

            // Description
            SizedBox(
              width: 280,
              child: Text(
                description,
                style: CfTypography.bodyMd.copyWith(
                  color: colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // CTA Button
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? CfSpacing.lg : CfSpacing.xl),
              _CfActionButton(
                label: actionLabel!,
                onTap: onAction!,
                compact: compact,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Common Presets ──────────────────────────────────────

  /// No cases empty state
  static Widget noCases({VoidCallback? onAdd}) => CfEmptyState(
    icon: Icons.folder_open_rounded,
    title: 'No Cases Yet',
    description: 'Add your first case to start managing your legal practice efficiently.',
    actionLabel: '+ Add Case',
    onAction: onAdd,
  );

  /// No hearings empty state
  static Widget noHearings({VoidCallback? onSchedule}) => CfEmptyState(
    icon: Icons.calendar_today_rounded,
    title: 'No Hearings Scheduled',
    description: 'Schedule hearings to keep track of your court appearances.',
    actionLabel: '+ Schedule Hearing',
    onAction: onSchedule,
  );

  /// No results (search) empty state
  static Widget noResults() => const CfEmptyState(
    icon: Icons.search_off_rounded,
    title: 'No Results Found',
    description: 'Try adjusting your search or filter criteria.',
    compact: true,
  );

  /// No clients empty state
  static Widget noClients({VoidCallback? onAdd}) => CfEmptyState(
    icon: Icons.people_outline_rounded,
    title: 'No Clients Yet',
    description: 'Add clients to manage their cases and track payments.',
    actionLabel: '+ Add Client',
    onAction: onAdd,
  );

  /// No payments empty state
  static Widget noPayments() => const CfEmptyState(
    icon: Icons.account_balance_wallet_outlined,
    title: 'No Payments Recorded',
    description: 'Financial records will appear here once you log payments.',
    compact: true,
  );

  /// Network error
  static Widget networkError({VoidCallback? onRetry}) => CfEmptyState(
    icon: Icons.wifi_off_rounded,
    title: 'Connection Issue',
    description: 'Please check your internet connection and try again.',
    actionLabel: 'Retry',
    onAction: onRetry,
  );
}

/// Premium CTA button for empty states
class _CfActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool compact;

  const _CfActionButton({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: CfSpacing.borderRadiusFull,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? CfSpacing.lg : CfSpacing.xl,
            vertical: compact ? CfSpacing.md : 14,
          ),
          decoration: BoxDecoration(
            gradient: CfColors.brandGradient,
            borderRadius: CfSpacing.borderRadiusFull,
            boxShadow: CfDecorations.glowShadow(CfColors.brand),
          ),
          child: Text(
            label,
            style: CfTypography.labelLg.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
