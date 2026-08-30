import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';
import '../theme/cf_decorations.dart';
import 'dialogs/reset_workspace_dialog.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow Quick Access Sheet
///
/// Streamlined access to practice modules, communication, and
/// account settings. Triggered from dashboard app bar menu icon.
///
/// Organized into semantic categories instead of a flat grid.
/// ══════════════════════════════════════════════════════════════

class MobileMoreSheet extends ConsumerWidget {
  const MobileMoreSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CfColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),

          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textDisabled,
              borderRadius: CfSpacing.borderRadiusFull,
            ),
          ),

          const SizedBox(height: 20),

          // Header
          Padding(
            padding: CfSpacing.pageHorizontal,
            child: Row(
              children: [
                Text(
                  'Quick Access',
                  style: CfTypography.headingLg.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── Practice Management ─────────────────────────
          _SectionLabel(label: 'Practice Management'),
          const SizedBox(height: 8),
          Padding(
            padding: CfSpacing.pageHorizontal,
            child: Row(
              children: [
                Expanded(child: _QuickTile(
                  icon: Icons.people_outline_rounded,
                  label: 'Clients',
                  color: const Color(0xFF3B82F6),
                  onTap: () => _navigate(context, '/clients'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _QuickTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Payments',
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _navigate(context, '/payments'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _QuickTile(
                  icon: Icons.assignment_ind_outlined,
                  label: 'Commissions',
                  color: const Color(0xFF7C3AED),
                  onTap: () => _navigate(context, '/commissions'),
                )),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: CfSpacing.pageHorizontal,
            child: Row(
              children: [
                Expanded(child: _QuickTile(
                  icon: Icons.gavel_outlined,
                  label: 'Caveats',
                  color: const Color(0xFFEA580C),
                  onTap: () => _navigate(context, '/caveats'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _QuickTile(
                  icon: Icons.copy_outlined,
                  label: 'CC Copies',
                  color: const Color(0xFFF59E0B),
                  onTap: () => _navigate(context, '/certified-copies'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _QuickTile(
                  icon: Icons.description_outlined,
                  label: 'E-Filing',
                  color: CfColors.success,
                  onTap: () => _navigate(context, '/efiling'),
                )),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── Communication & Info ────────────────────────
          _SectionLabel(label: 'Communication'),
          const SizedBox(height: 8),
          Padding(
            padding: CfSpacing.pageHorizontal,
            child: Row(
              children: [
                Expanded(child: _QuickTile(
                  icon: Icons.account_balance_outlined,
                  label: 'Portals',
                  color: const Color(0xFF4F46E5),
                  onTap: () => _navigate(context, '/portals'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _QuickTile(
                  icon: Icons.account_balance_rounded,
                  label: 'My Bar',
                  color: const Color(0xFF0891B2),
                  onTap: () => _navigate(context, '/bar-association'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _QuickTile(
                  icon: Icons.newspaper_outlined,
                  label: 'Legal Pulse',
                  color: const Color(0xFFDC2626),
                  onTap: () => _navigate(context, '/legal-pulse'),
                )),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── Account ─────────────────────────────────────
          Divider(color: colors.border, height: 1),
          _AccountTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () => _navigate(context, '/notifications'),
          ),
          _AccountTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => _navigate(context, '/settings'),
          ),
          Divider(color: colors.border, height: 1),
          _AccountTile(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            isDestructive: true,
            onTap: () async {
              Navigator.pop(context);
              await SupabaseService.signOut();
            },
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    Navigator.pop(context);
    context.go(route);
  }
}

// ─── Section Label ───────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);
    return Padding(
      padding: CfSpacing.pageHorizontal,
      child: Text(
        label.toUpperCase(),
        style: CfTypography.captionSm.copyWith(
          color: colors.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Quick Tile (icon + label grid item) ─────────────────────

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: CfSpacing.borderRadiusMd,
          border: Border.all(color: colors.borderSubtle, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: CfSpacing.borderRadiusMd,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: CfTypography.captionSm.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Account List Tile ───────────────────────────────────────

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _AccountTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);
    final tileColor = isDestructive ? CfColors.error : colors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: tileColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: CfTypography.bodyMd.copyWith(
                color: tileColor,
                fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (!isDestructive)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: colors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
