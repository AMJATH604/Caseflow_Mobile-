import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../components/task_widget.dart';
import '../components/kpi_card.dart';
import '../components/profile_avatar.dart';
import '../components/dialogs/schedule_hearing_dialog.dart';
import '../components/dialogs/new_case_dialog.dart';
import '../components/dialogs/add_client_dialog.dart';
import '../components/dialogs/log_cc_dialog.dart';
import '../components/dashboard_court_diary.dart';
import '../components/daily_board_widget.dart';
import '../components/error_state_widget.dart';
import '../services/analytics_service.dart';
import 'citizen_home_screen.dart';
import '../utils/responsive.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Track dashboard view
    AnalyticsService.logScreenView('Dashboard');

    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;

    // If the profile is loading for the first time (no cached value), show loading
    if (profileAsync.isLoading && !profileAsync.hasValue) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    // If logged in user is a citizen, show the Citizen Home Screen directly
    if (profile != null && profile.isCitizen) {
      return const CitizenHomeScreen();
    }

    final isMobile = MediaQuery.of(context).size.width < 768;
    final statsAsync = ref.watch(dashboardStatsProvider);
    final firstName = profile?.fullName?.split(' ').first;
    final userName =
        firstName != null && firstName.isNotEmpty
            ? 'Advocate $firstName'
            : 'Advocate';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: isMobile
          ? _buildChatFab(context)
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          // Increment global refresh trigger — this causes ALL providers to re-compute
          ref.read(dataRefreshProvider.notifier).state++;
          // Also invalidate profile since it's not in the global trigger
          ref.invalidate(userProfileProvider);
          await ref.read(dashboardStatsProvider.future);
        },
        color: AppTheme.accent,
        child: SingleChildScrollView(
          key: const PageStorageKey('dashboard_scroll_view'),
          physics: const AlwaysScrollableScrollPhysics(),
          child: statsAsync.when(
            skipLoadingOnRefresh: true,
            data:
                (stats) =>
                    isMobile
                        ? _buildMobileDashboard(
                          context,
                          ref,
                          stats,
                          userName,
                          profileAsync,
                        )
                        : _buildDesktopDashboard(
                          context,
                          ref,
                          stats,
                          userName,
                          profileAsync,
                        ),
            loading: () => _buildLoadingState(),
            error:
                (err, stack) => ErrorStateWidget(
                  error: err,
                  onRetry: () => ref.invalidate(dashboardStatsProvider),
                ),
          ),
        ),
      ),
    );
  }

  // ─── MOBILE DASHBOARD ────────────────────────────────

  Widget _buildMobileDashboard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> stats,
    String userName,
    AsyncValue<UserProfile> profileAsync,
  ) {
    final todayHearings = stats['todayHearings'] as List<Hearing>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Header Card (Navy → Deep Indigo Gradient)
        Padding(
          padding: EdgeInsets.all(16.0.r),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F172A), // Navy
                  Color(0xFF1E3A5F), // Deep Blue
                  Color(0xFF312E81), // Deep Indigo
                ],
                stops: [0.0, 0.5, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF312E81).withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
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
                            'Hello, $userName 👋',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            DateFormat('EEEE, d MMMM y').format(DateTime.now()),
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mini profile badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6.w,
                            height: 6.h,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'ONLINE',
                            style: GoogleFonts.inter(
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF10B981),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),
        ),

        // ─── Profile Completion Nudge ────────────────────
        if (profileAsync.valueOrNull != null && profileAsync.valueOrNull!.avatarUrl == null)
          _buildProfileNudgeBanner(context, ref, profileAsync.valueOrNull!),

        // ─── Hero KPI Cards (2x2 Grid) ────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: KpiCard(
                      title: 'Active Cases',
                      value: "${stats['activeCasesCount'] ?? 0}",
                      icon: Icons.folder_open_rounded,
                      accentColor: const Color(0xFF6366F1),
                      onTap: () => context.go('/cases'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: KpiCard(
                      title: "Today's Hearings",
                      value: '${todayHearings.length}',
                      icon: Icons.gavel_rounded,
                      accentColor: const Color(0xFFF59E0B),
                      showPulse: true,
                      onTap: () => context.go('/hearings'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: KpiCard(
                      title: 'Upcoming Hearings',
                      value: "${stats['upcomingHearingsCount'] ?? 0}",
                      icon: Icons.calendar_month_rounded,
                      accentColor: const Color(0xFF0EA5E9),
                      onTap: () => context.go('/hearings'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: KpiCard(
                      title: 'Total Clients',
                      value: "${stats['clientsCount'] ?? 0}",
                      icon: Icons.people_rounded,
                      accentColor: const Color(0xFF10B981),
                      onTap: () => context.go('/clients'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ─── Secondary Stats Row ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: StatChip(
                  label: 'Disposed',
                  value: stats['disposedCasesCount'] ?? 0,
                  color: const Color(0xFF14B8A6),
                  icon: Icons.done_all_rounded,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: StatChip(
                  label: 'Dismissed',
                  value: stats['dismissedCasesCount'] ?? 0,
                  color: const Color(0xFF64748B),
                  icon: Icons.cancel_rounded,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go('/payments'),
                  child: StatChip(
                    label: 'Payments',
                    value: stats['pendingPaymentsCount'] ?? 0,
                    color: const Color(0xFFF97316),
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DailyBoardWidget(),
              SizedBox(height: 32.h),
              Text(
                'Jump To',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFeatureCard(
                    context,
                    Icons.business_center_rounded,
                    'Cases',
                    const Color(0xFF6366F1),
                    () {
                      context.go('/cases');
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    Icons.people_alt_rounded,
                    'Clients',
                    const Color(0xFF10B981),
                    () {
                      context.go('/clients');
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    Icons.gavel_rounded,
                    'Hearings',
                    const Color(0xFFF59E0B),
                    () {
                      context.go('/hearings');
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    Icons.credit_card_rounded,
                    'Payments',
                    const Color(0xFF0EA5E9),
                    () {
                      context.go('/payments');
                    },
                  ),
                ],
              ),
              SizedBox(height: 32.h),
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildActionButton(
                    context,
                    Icons.add_rounded,
                    'New Case',
                    const Color(0xFF3B82F6),
                    () {
                      showDialog(
                        context: context,
                        builder: (context) => const NewCaseDialog(),
                      );
                    },
                  ),
                  _buildActionButton(
                    context,
                    Icons.person_add_rounded,
                    'New Client',
                    const Color(0xFF4ADE80),
                    () {
                      showDialog(
                        context: context,
                        builder: (context) => const AddClientDialog(),
                      );
                    },
                  ),
                  _buildActionButton(
                    context,
                    Icons.event_available_rounded,
                    'New Hearing',
                    const Color(0xFFF59E0B),
                    () {
                      showDialog(
                        context: context,
                        builder: (context) => const ScheduleHearingDialog(),
                      );
                    },
                  ),
                  _buildActionButton(
                    context,
                    Icons.note_add_rounded,
                    'Log C.A',
                    Colors.deepOrange,
                    () {
                      showDialog(
                        context: context,
                        builder: (context) => const LogCCDialog(),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildActionButton(
                    context,
                    Icons.mail_rounded,
                    'Invitations',
                    Colors.purple,
                    () {
                      context.push('/collaborator-invitations');
                    },
                  ),
                ],
              ),
              SizedBox(height: 32.h),
              DashboardCourtDiary(),
              SizedBox(height: 24.h),
              TaskWidget(),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ],
    );
  }

  // ─── PROFILE NUDGE BANNER ──────────────────────────────

  Widget _buildProfileNudgeBanner(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0F4FF), Color(0xFFEDE9FE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: const Color(0xFF2563EB).withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFF2563EB),
                size: 22,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete Your Profile',
                    style: GoogleFonts.outfit(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Add a photo to stand out in the directory',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Material(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(10.r),
              child: InkWell(
                onTap: () => _showDashboardPhotoPicker(context, ref, profile),
                borderRadius: BorderRadius.circular(10.r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Text(
                    'Add Photo',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDashboardPhotoPicker(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Add Profile Photo',
              style: GoogleFonts.outfit(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: _buildDashboardPhotoOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFF2563EB),
                    onTap: () {
                      Navigator.pop(ctx);
                      _uploadDashboardPhoto(
                        context,
                        ref,
                        profile,
                        ImageSource.camera,
                      );
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildDashboardPhotoOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF059669),
                    onTap: () {
                      Navigator.pop(ctx);
                      _uploadDashboardPhoto(
                        context,
                        ref,
                        profile,
                        ImageSource.gallery,
                      );
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardPhotoOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 6.h),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDashboardPhoto(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      // Show uploading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16.w,
                  height: 16.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'Uploading photo...',
                  style: GoogleFonts.inter(fontSize: 13.sp),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2563EB),
            duration: const Duration(seconds: 10),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }

      await SupabaseService.updateProfilePhoto(profile.id, bytes);

      // Refresh profile to hide the nudge banner
      ref.invalidate(userProfileProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 10.w),
                Text(
                  'Profile photo updated!',
                  style: GoogleFonts.inter(fontSize: 13.sp),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 10.w),
                Text(
                  'Failed to upload photo. Try again.',
                  style: GoogleFonts.inter(fontSize: 13.sp),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    }
  }
  // ─── CHAT FAB ─────────────────────────────────────────

  Widget _buildChatFab(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () => context.push('/chat-hub'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        heroTag: 'chat_fab',
        child: const Icon(
          Icons.chat_bubble_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  // ─── DESKTOP DASHBOARD ───────────────────────────────

  Widget _buildDesktopDashboard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> stats,
    String userName,
    AsyncValue<UserProfile> profileAsync,
  ) {
    final todayHearings = stats['todayHearings'] as List<Hearing>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Dashboard',
              style: Theme.of(
                context,
              ).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            profileAsync.when(
              data:
                  (profile) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: AppTheme.cardDecoration(
                      color: AppTheme.surfaceLight,
                    ),
                    child: Text(
                      'BETA UNLOCKED',
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accent,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
        SizedBox(height: 32.h),

        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            SizedBox(
              width: 280.w,
              child: KpiCard(
                title: 'Active Cases',
                value: "${stats['activeCasesCount']}",
                icon: Icons.folder_open_rounded,
                accentColor: const Color(0xFF6366F1),
                onTap: () => context.go('/cases'),
              ),
            ),
            SizedBox(
              width: 280.w,
              child: KpiCard(
                title: "Today's Hearings",
                value: '${todayHearings.length}',
                icon: Icons.gavel_rounded,
                accentColor: const Color(0xFFF59E0B),
                showPulse: true,
                onTap: () => context.go('/hearings'),
              ),
            ),
            SizedBox(
              width: 280.w,
              child: KpiCard(
                title: 'Upcoming Hearings',
                value: "${stats['upcomingHearingsCount']}",
                icon: Icons.calendar_month_rounded,
                accentColor: const Color(0xFF0EA5E9),
                onTap: () => context.go('/hearings'),
              ),
            ),
            SizedBox(
              width: 280.w,
              child: KpiCard(
                title: 'Total Clients',
                value: "${stats['clientsCount']}",
                icon: Icons.people_rounded,
                accentColor: const Color(0xFF10B981),
                onTap: () => context.go('/clients'),
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),
        // Secondary stats row
        Row(
          children: [
            Expanded(
              child: StatChip(
                label: 'Disposed',
                value: stats['disposedCasesCount'] ?? 0,
                color: const Color(0xFF14B8A6),
                icon: Icons.done_all_rounded,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: StatChip(
                label: 'Dismissed',
                value: stats['dismissedCasesCount'] ?? 0,
                color: const Color(0xFF64748B),
                icon: Icons.cancel_rounded,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: GestureDetector(
                onTap: () => context.go('/payments'),
                child: StatChip(
                  label: 'Payments',
                  value: stats['pendingPaymentsCount'] ?? 0,
                  color: const Color(0xFFF97316),
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 40.h),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DailyBoardWidget(),
                  SizedBox(height: 32.h),
                  TaskWidget(),
                ],
              ),
            ),
            SizedBox(width: 32.w),
            Expanded(
              flex: 1,
              child: Column(children: [DashboardCourtDiary()]),
            ),
          ],
        ),
      ],
    );
  }

  // ─── HELPERS ─────────────────────────────────────────

  // _buildHeaderStat removed — stats now shown only in KPI cards

  Widget _buildFeatureCard(
    BuildContext context,
    IconData icon,
    String label,
    Color accentColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accentColor, size: 26),
            SizedBox(height: 8.h),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF1E293B), size: 24),
          ),
          if (label.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 200.h),
        child: CircularProgressIndicator(color: AppTheme.accent),
      ),
    );
  }
}
