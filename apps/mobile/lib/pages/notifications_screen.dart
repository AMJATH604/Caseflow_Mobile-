import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../models/models.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';
import '../theme/cf_decorations.dart';
import '../components/cf_shimmer_loader.dart';
import '../components/cf_empty_state.dart';
import '../components/cf_section_header.dart';
import '../components/error_state_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ══════════════════════════════════════════════════════════════
/// Notifications / Updates Screen — Sprint 3 Redesign
///
/// Shows recent activity across the user's practice.
/// Uses new design tokens, CfEmptyState, and CfShimmerLoader.
/// ══════════════════════════════════════════════════════════════

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(casesProvider);
    final colors = CfColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: CfSectionHeader(
              title: 'Updates',
              icon: Icons.notifications_active_rounded,
              trailing: 'Recent activity',
            ),
          ),

          // Content
          Expanded(
            child: casesAsync.when(
              data: (cases) => _buildActivityFeed(context, cases, colors, isDark),
              loading: () => CfShimmerLoader.list(),
              error: (err, stack) => ErrorStateWidget(
                error: err,
                onRetry: () => ref.invalidate(casesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed(
    BuildContext context,
    List<CaseModel> items,
    CfColorScheme colors,
    bool isDark,
  ) {
    if (items.isEmpty) {
      return const CfEmptyState(
        icon: Icons.notifications_off_outlined,
        title: 'No Recent Updates',
        description: 'Activity from cases, clients, and payments will appear here.',
      );
    }

    return ListView.builder(
      padding: CfSpacing.pageHorizontal,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final statusInfo = _statusInfo(item.status);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: CfSpacing.borderRadiusLg,
            border: Border.all(color: colors.border, width: 1),
            boxShadow: CfDecorations.shadowSm(isDark),
          ),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusInfo.color.withValues(alpha: 0.10),
                  borderRadius: CfSpacing.borderRadiusMd,
                ),
                child: Icon(statusInfo.icon, color: statusInfo.color, size: 20),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.caseTitle,
                      style: CfTypography.labelLg.copyWith(
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Updated to ${item.status.name}',
                      style: CfTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Time
              Text(
                DateFormat('HH:mm').format(DateTime.now()),
                style: CfTypography.captionSm.copyWith(
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _StatusInfo _statusInfo(CaseStatus status) {
    final name = status.toString().split('.').last;
    switch (name) {
      case 'active':
        return _StatusInfo(Icons.gavel_rounded, CfColors.warning);
      case 'closed':
      case 'disposed':
        return _StatusInfo(Icons.check_circle_rounded, CfColors.success);
      case 'dismissed':
        return _StatusInfo(Icons.cancel_rounded, const Color(0xFF64748B));
      default:
        return _StatusInfo(Icons.info_outline_rounded, CfColors.info);
    }
  }
}

class _StatusInfo {
  final IconData icon;
  final Color color;
  const _StatusInfo(this.icon, this.color);
}
