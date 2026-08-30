import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/providers.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';
import '../theme/cf_decorations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow Bottom Navigation — Advocate Mode
///
/// Premium 4-tab navigation: Home | Cases | Calendar | Tools
/// Features:
/// - Animated active indicator with brand color
/// - Haptic feedback on tap
/// - Smooth icon transitions
/// - Notification badge support
/// ══════════════════════════════════════════════════════════════

class MobileBottomNav extends ConsumerWidget {
  const MobileBottomNav({super.key});

  static const _tabs = [
    _NavTab(icon: Icons.space_dashboard_rounded, activeIcon: Icons.space_dashboard_rounded, label: 'Home', route: '/'),
    _NavTab(icon: Icons.folder_outlined, activeIcon: Icons.folder_rounded, label: 'Cases', route: '/cases'),
    _NavTab(icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today_rounded, label: 'Calendar', route: '/hearings'),
    _NavTab(icon: Icons.apps_rounded, activeIcon: Icons.apps_rounded, label: 'Tools', route: '/tools'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CfColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = ref.watch(navigationIndexProvider);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border, width: 0.5),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64.h,
          child: Row(
            children: List.generate(_tabs.length, (index) {
              return Expanded(
                child: _NavItem(
                  tab: _tabs[index],
                  isActive: currentIndex == index,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(navigationIndexProvider.notifier).state = index;
                    context.go(_tabs[index].route);
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _NavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Active indicator pill
          AnimatedContainer(
            duration: CfDecorations.durationFast,
            curve: CfDecorations.curveDefault,
            height: 3,
            width: isActive ? 20 : 0,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: CfColors.brand,
              borderRadius: CfSpacing.borderRadiusFull,
            ),
          ),

          // Icon with animated transition
          AnimatedSwitcher(
            duration: CfDecorations.durationFast,
            child: Icon(
              isActive ? tab.activeIcon : tab.icon,
              key: ValueKey(isActive),
              size: 22,
              color: isActive ? CfColors.brand : colors.textTertiary,
            ),
          ),

          const SizedBox(height: 4),

          // Label
          AnimatedDefaultTextStyle(
            duration: CfDecorations.durationFast,
            style: CfTypography.captionSm.copyWith(
              color: isActive ? CfColors.brand : colors.textTertiary,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(tab.label),
          ),
        ],
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}
