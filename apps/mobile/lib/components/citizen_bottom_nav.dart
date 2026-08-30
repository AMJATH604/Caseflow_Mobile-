import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';
import '../theme/cf_decorations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow Bottom Navigation — Citizen Mode
///
/// Premium 4-tab navigation: Home | Track Case | Legal Tools | AI Help
/// Uses emerald accent to differentiate from advocate indigo.
/// ══════════════════════════════════════════════════════════════

class CitizenBottomNav extends ConsumerWidget {
  const CitizenBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final isGuest = location.startsWith('/guest');
    final colors = CfColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabs = [
      _NavTab(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
        route: isGuest ? '/guest-home' : '/citizen-home',
      ),
      _NavTab(
        icon: Icons.search_outlined,
        activeIcon: Icons.search_rounded,
        label: 'Track Case',
        route: isGuest ? '/guest-track-case' : '/track-case',
      ),
      _NavTab(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
        label: 'Legal Tools',
        route: isGuest ? '/guest-tools' : '/citizen-tools',
      ),
      _NavTab(
        icon: Icons.auto_awesome_outlined,
        activeIcon: Icons.auto_awesome_rounded,
        label: 'AI Help',
        route: '/ai-chat',
        requiresAuth: true,
      ),
    ];

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
            children: List.generate(tabs.length, (index) {
              final tab = tabs[index];
              final isActive = _isTabActive(location, tab, isGuest);

              return Expanded(
                child: _CitizenNavItem(
                  tab: tab,
                  isActive: isActive,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (tab.requiresAuth && isGuest) {
                      _showAuthRequiredDialog(context, tab.label);
                    } else {
                      context.go(tab.route);
                    }
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  bool _isTabActive(String location, _NavTab tab, bool isGuest) {
    if (location == tab.route) return true;
    if (tab.label == 'Home' && location == '/' && !isGuest) return true;
    return false;
  }

  void _showAuthRequiredDialog(BuildContext context, String featureName) {
    final colors = CfColors.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CfSpacing.radiusXl),
        ),
        backgroundColor: colors.surface,
        title: Text(
          'Sign In Required',
          style: CfTypography.headingLg.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'You need to sign in or create an account to use $featureName.\n\nIt takes less than a minute and unlocks personalized legal tools, saved cases, and AI legal help.',
          style: CfTypography.bodyMd.copyWith(
            color: colors.textSecondary,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: CfTypography.labelLg.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/login?role=citizen');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CfColors.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CfSpacing.radiusMd),
              ),
              elevation: 0,
            ),
            child: Text(
              'Sign In / Sign Up',
              style: CfTypography.labelLg.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _CitizenNavItem extends StatelessWidget {
  final _NavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _CitizenNavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  // Citizen uses emerald accent instead of indigo
  static const _activeColor = CfColors.success;

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
              color: _activeColor,
              borderRadius: CfSpacing.borderRadiusFull,
            ),
          ),

          // Icon
          AnimatedSwitcher(
            duration: CfDecorations.durationFast,
            child: Icon(
              isActive ? tab.activeIcon : tab.icon,
              key: ValueKey(isActive),
              size: 22,
              color: isActive ? _activeColor : colors.textTertiary,
            ),
          ),

          const SizedBox(height: 4),

          // Label
          AnimatedDefaultTextStyle(
            duration: CfDecorations.durationFast,
            style: CfTypography.captionSm.copyWith(
              color: isActive ? _activeColor : colors.textTertiary,
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
  final bool requiresAuth;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    this.requiresAuth = false,
  });
}
