import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';
import '../theme/cf_decorations.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../components/cf_shimmer_loader.dart';
import '../components/cf_section_header.dart';
import '../components/cf_stat_tile.dart';
import '../components/task_widget.dart';
import '../components/profile_avatar.dart';
import '../components/dashboard_court_diary.dart';
import '../components/daily_board_widget.dart';
import '../components/error_state_widget.dart';
import '../components/mobile_more_sheet.dart';
import '../components/dialogs/schedule_hearing_dialog.dart';
import '../components/dialogs/new_case_dialog.dart';
import '../components/dialogs/add_client_dialog.dart';
import '../components/dialogs/log_cc_dialog.dart';
import '../services/analytics_service.dart';
import 'citizen_home_screen.dart';
import '../utils/responsive.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// ══════════════════════════════════════════════════════════════
/// CaseFlow Dashboard — "Command Center"
///
/// Redesigned for Sprint 2 with:
/// - Contextual greeting with time-of-day awareness
/// - Today's summary card as hero element
/// - Today's hearings as prominent cards with quick actions
/// - Horizontal quick action pills
/// - Clean task checklist
/// - Shimmer loading instead of spinner
/// ══════════════════════════════════════════════════════════════

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AnalyticsService.logScreenView('Dashboard');

    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;

    if (profileAsync.isLoading && !profileAsync.hasValue) {
      return Scaffold(body: CfShimmerLoader.dashboard());
    }

    if (profile != null && profile.isCitizen) {
      return const CitizenHomeScreen();
    }

    final isMobile = MediaQuery.of(context).size.width < 768;
    final statsAsync = ref.watch(dashboardStatsProvider);
    final firstName = profile?.fullName?.split(' ').first;
    final userName =
        firstName != null && firstName.isNotEmpty ? firstName : 'Advocate';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: isMobile ? _buildChatFab(context) : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(dataRefreshProvider.notifier).state++;
          ref.invalidate(userProfileProvider);
          await ref.read(dashboardStatsProvider.future);
        },
        color: CfColors.brand,
        child: SingleChildScrollView(
          key: const PageStorageKey('dashboard_scroll_view'),
          physics: const AlwaysScrollableScrollPhysics(),
          child: statsAsync.when(
            skipLoadingOnRefresh: true,
            data: (stats) => isMobile
                ? _MobileDashboard(
                    stats: stats,
                    userName: userName,
                    profileAsync: profileAsync,
                  )
                : _DesktopDashboard(
                    stats: stats,
                    userName: userName,
                    profileAsync: profileAsync,
                  ),
            loading: () => CfShimmerLoader.dashboard(),
            error: (err, stack) => ErrorStateWidget(
              error: err,
              onRetry: () => ref.invalidate(dashboardStatsProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatFab(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: CfColors.brandGradient,
        boxShadow: CfDecorations.glowShadow(CfColors.brand),
      ),
      child: FloatingActionButton(
        onPressed: () => context.push('/chat-hub'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        heroTag: 'chat_fab',
        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MOBILE DASHBOARD
// ═══════════════════════════════════════════════════════════════

class _MobileDashboard extends ConsumerWidget {
  final Map<String, dynamic> stats;
  final String userName;
  final AsyncValue<UserProfile> profileAsync;

  const _MobileDashboard({
    required this.stats,
    required this.userName,
    required this.profileAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CfColors.of(context);
    final todayHearings = stats['todayHearings'] as List<Hearing>? ?? [];
    final greeting = _getGreeting();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Hero Greeting Card ─────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: CfColors.heroGradient,
              borderRadius: BorderRadius.circular(CfSpacing.radiusXxl),
              boxShadow: CfDecorations.glowShadow(CfColors.brandDark),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting,',
                            style: CfTypography.bodyMd.copyWith(
                              color: Colors.white.withValues(alpha: 0.70),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Adv. $userName 👋',
                            style: CfTypography.displaySm.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Menu icon to open Quick Access
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const MobileMoreSheet(),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: CfSpacing.borderRadiusMd,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: const Icon(
                          Icons.grid_view_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Today's summary row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: CfSpacing.borderRadiusMd,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _HeroStat(
                        value: '${todayHearings.length}',
                        label: 'Hearings Today',
                        icon: Icons.gavel_rounded,
                      ),
                      Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.15)),
                      _HeroStat(
                        value: '${stats['activeCasesCount'] ?? 0}',
                        label: 'Active Cases',
                        icon: Icons.folder_rounded,
                      ),
                      Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.15)),
                      _HeroStat(
                        value: '${stats['pendingPaymentsCount'] ?? 0}',
                        label: 'Pending ₹',
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ─── Profile Nudge ──────────────────────────────────
        if (profileAsync.valueOrNull != null &&
            profileAsync.valueOrNull!.avatarUrl == null)
          _ProfileNudge(profile: profileAsync.valueOrNull!),

        // ─── Quick Actions ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickActionPill(
                  icon: Icons.add_rounded,
                  label: 'New Case',
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => const NewCaseDialog(),
                  ),
                ),
                const SizedBox(width: 8),
                _QuickActionPill(
                  icon: Icons.event_available_rounded,
                  label: 'Schedule Hearing',
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => const ScheduleHearingDialog(),
                  ),
                ),
                const SizedBox(width: 8),
                _QuickActionPill(
                  icon: Icons.person_add_rounded,
                  label: 'Add Client',
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => const AddClientDialog(),
                  ),
                ),
                const SizedBox(width: 8),
                _QuickActionPill(
                  icon: Icons.note_add_rounded,
                  label: 'Log C.A',
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => const LogCCDialog(),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ─── Today's Hearings ───────────────────────────────
        if (todayHearings.isNotEmpty) ...[
          Padding(
            padding: CfSpacing.pageHorizontal,
            child: CfSectionHeader(
              title: "Today's Hearings",
              icon: Icons.gavel_rounded,
              trailing: '${todayHearings.length}',
              onSeeAll: () => context.go('/hearings'),
            ),
          ),
          ...todayHearings.take(3).map((hearing) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: _HearingCard(hearing: hearing),
          )),
          const SizedBox(height: 12),
        ],

        // ─── KPI Grid ───────────────────────────────────────
        Padding(
          padding: CfSpacing.pageHorizontal,
          child: CfSectionHeader(
            title: 'Practice Overview',
            icon: Icons.insights_rounded,
          ),
        ),
        Padding(
          padding: CfSpacing.pageHorizontal,
          child: Row(
            children: [
              Expanded(
                child: CfStatTile(
                  icon: Icons.calendar_month_rounded,
                  iconColor: CfColors.info,
                  value: '${stats['upcomingHearingsCount'] ?? 0}',
                  label: 'Upcoming Hearings',
                  onTap: () => context.go('/hearings'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CfStatTile(
                  icon: Icons.people_rounded,
                  iconColor: CfColors.success,
                  value: '${stats['clientsCount'] ?? 0}',
                  label: 'Total Clients',
                  onTap: () => context.go('/clients'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: CfSpacing.pageHorizontal,
          child: Row(
            children: [
              Expanded(
                child: CfStatTile(
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFF14B8A6),
                  value: '${stats['disposedCasesCount'] ?? 0}',
                  label: 'Disposed',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CfStatTile(
                  icon: Icons.cancel_rounded,
                  iconColor: const Color(0xFF64748B),
                  value: '${stats['dismissedCasesCount'] ?? 0}',
                  label: 'Dismissed',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ─── Daily Board ────────────────────────────────────
        Padding(
          padding: CfSpacing.pageHorizontal,
          child: DailyBoardWidget(),
        ),

        const SizedBox(height: 24),

        // ─── Court Diary ────────────────────────────────────
        Padding(
          padding: CfSpacing.pageHorizontal,
          child: DashboardCourtDiary(),
        ),

        const SizedBox(height: 24),

        // ─── Tasks ──────────────────────────────────────────
        Padding(
          padding: CfSpacing.pageHorizontal,
          child: TaskWidget(),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

// ═══════════════════════════════════════════════════════════════
// DESKTOP DASHBOARD
// ═══════════════════════════════════════════════════════════════

class _DesktopDashboard extends ConsumerWidget {
  final Map<String, dynamic> stats;
  final String userName;
  final AsyncValue<UserProfile> profileAsync;

  const _DesktopDashboard({
    required this.stats,
    required this.userName,
    required this.profileAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CfColors.of(context);
    final todayHearings = stats['todayHearings'] as List<Hearing>? ?? [];

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Dashboard',
                style: CfTypography.displayMd.copyWith(color: colors.textPrimary),
              ),
              const Spacer(),
              Text(
                DateFormat('EEEE, d MMMM y').format(DateTime.now()),
                style: CfTypography.bodyMd.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // KPI Row
          Row(
            children: [
              Expanded(
                child: CfStatTile(
                  icon: Icons.folder_open_rounded,
                  iconColor: CfColors.brand,
                  value: '${stats['activeCasesCount'] ?? 0}',
                  label: 'Active Cases',
                  onTap: () => context.go('/cases'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CfStatTile(
                  icon: Icons.gavel_rounded,
                  iconColor: CfColors.warning,
                  value: '${todayHearings.length}',
                  label: "Today's Hearings",
                  onTap: () => context.go('/hearings'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CfStatTile(
                  icon: Icons.calendar_month_rounded,
                  iconColor: CfColors.info,
                  value: '${stats['upcomingHearingsCount'] ?? 0}',
                  label: 'Upcoming Hearings',
                  onTap: () => context.go('/hearings'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CfStatTile(
                  icon: Icons.people_rounded,
                  iconColor: CfColors.success,
                  value: '${stats['clientsCount'] ?? 0}',
                  label: 'Total Clients',
                  onTap: () => context.go('/clients'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Two-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DailyBoardWidget(),
                    const SizedBox(height: 32),
                    TaskWidget(),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 1,
                child: Column(children: [DashboardCourtDiary()]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════

/// Hero stat inside the greeting card
class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _HeroStat({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: CfTypography.statSm.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: CfTypography.captionSm.copyWith(
            color: Colors.white.withValues(alpha: 0.60),
          ),
        ),
      ],
    );
  }
}

/// Quick action pill button
class _QuickActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: CfSpacing.borderRadiusFull,
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: CfColors.brand),
            const SizedBox(width: 6),
            Text(
              label,
              style: CfTypography.labelMd.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Today's hearing card
class _HearingCard extends StatelessWidget {
  final Hearing hearing;

  const _HearingCard({required this.hearing});

  @override
  Widget build(BuildContext context) {
    final colors = CfColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (hearing.caseId != null) {
          context.push('/cases/${hearing.caseId}');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: CfSpacing.borderRadiusLg,
          border: Border.all(color: colors.border, width: 1),
          boxShadow: CfDecorations.shadowSm(isDark),
        ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: CfColors.warning,
                borderRadius: CfSpacing.borderRadiusFull,
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hearing.caseTitle ?? 'Untitled Case',
                    style: CfTypography.headingSm.copyWith(
                      color: colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: colors.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hearing.courtName ?? 'Court',
                          style: CfTypography.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Time badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: CfColors.warning.withValues(alpha: 0.10),
                borderRadius: CfSpacing.borderRadiusFull,
              ),
              child: Text(
                hearing.hearingDate != null
                    ? DateFormat('h:mm a').format(hearing.hearingDate!)
                    : 'Today',
                style: CfTypography.labelMd.copyWith(
                  color: CfColors.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile completion nudge banner
class _ProfileNudge extends ConsumerWidget {
  final UserProfile profile;
  const _ProfileNudge({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = CfColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CfColors.brandSubtle,
          borderRadius: CfSpacing.borderRadiusLg,
          border: Border.all(
            color: CfColors.brand.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: CfColors.brand.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: CfColors.brand,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete Your Profile',
                    style: CfTypography.labelLg.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Add a photo to stand out',
                    style: CfTypography.captionSm.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: CfColors.brand,
              borderRadius: CfSpacing.borderRadiusSm,
              child: InkWell(
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 512,
                    maxHeight: 512,
                    imageQuality: 75,
                  );
                  if (picked == null) return;
                  final bytes = await picked.readAsBytes();
                  try {
                    await SupabaseService.updateProfilePhoto(profile.id, bytes);
                    ref.invalidate(userProfileProvider);
                  } catch (_) {}
                },
                borderRadius: CfSpacing.borderRadiusSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Text(
                    'Add',
                    style: CfTypography.labelMd.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
