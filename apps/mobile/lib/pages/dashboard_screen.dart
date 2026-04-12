import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../components/task_widget.dart';
import '../components/kpi_card.dart';
import '../components/dialogs/schedule_hearing_dialog.dart';
import '../components/dialogs/new_case_dialog.dart';
import '../components/dialogs/add_client_dialog.dart';
import '../components/dialogs/log_cc_dialog.dart';
import '../components/dashboard_court_diary.dart';
import '../components/daily_board_widget.dart';
import '../components/error_state_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final statsAsync = ref.watch(dashboardStatsProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.valueOrNull;
    final firstName = profile?.fullName?.split(' ').first;
    final userName = firstName != null && firstName.isNotEmpty 
        ? "Advocate $firstName" 
        : "Advocate";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          physics: const AlwaysScrollableScrollPhysics(),
          child: statsAsync.when(
            data: (stats) => isMobile 
              ? _buildMobileDashboard(context, ref, stats, userName, profileAsync) 
              : _buildDesktopDashboard(context, ref, stats, userName, profileAsync),
            loading: () => _buildLoadingState(),
            error: (err, stack) => ErrorStateWidget(
              error: err,
              onRetry: () => ref.invalidate(dashboardStatsProvider),
            ),
          ),
        ),
      ),
    );
  }

  // ─── MOBILE DASHBOARD ────────────────────────────────

  Widget _buildMobileDashboard(BuildContext context, WidgetRef ref, Map<String, dynamic> stats, String userName, AsyncValue<UserProfile> profileAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Header Card (Teal to Green Gradient)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.glassGradient,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, $userName 👋",
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1E293B),
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  DateFormat('EEEE, d MMMM y').format(DateTime.now()),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Column(
                  children: [
                    Row(
                      children: [
                        _buildInCardStat("Active", stats['activeCasesCount'] ?? 0),
                        const SizedBox(width: 8),
                        _buildInCardStat("Hearings", stats['upcomingHearingsCount'] ?? 0),
                        const SizedBox(width: 8),
                        _buildInCardStat("Filings", stats['filingsCount'] ?? 0),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildInCardStat("Clients", stats['clientsCount'] ?? 0),
                        const SizedBox(width: 8),
                        _buildInCardStat("Disposed", stats['disposedCasesCount'] ?? 0),
                        const SizedBox(width: 8),
                        _buildInCardStat("Closed", stats['dismissedCasesCount'] ?? 0),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),



        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DailyBoardWidget(),
              const SizedBox(height: 32),
              const SizedBox(height: 32),
              Text(
                "Jump To",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFeatureCard(context, Icons.business_center_rounded, "Cases", const Color(0xFF6366F1), () { context.go('/cases'); }),
                  _buildFeatureCard(context, Icons.people_alt_rounded, "Clients", const Color(0xFF10B981), () { context.go('/clients'); }),
                  _buildFeatureCard(context, Icons.gavel_rounded, "Hearings", const Color(0xFFF59E0B), () { context.go('/hearings'); }),
                  _buildFeatureCard(context, Icons.credit_card_rounded, "Payments", const Color(0xFF0EA5E9), () { context.go('/payments'); }),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                "Quick Actions",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF94A3B8),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildActionButton(context, Icons.add_rounded, "New Case", const Color(0xFF3B82F6), () {
                    showDialog(context: context, builder: (context) => const NewCaseDialog());
                  }),
                  _buildActionButton(context, Icons.person_add_rounded, "New Client", const Color(0xFF4ADE80), () {
                    showDialog(context: context, builder: (context) => const AddClientDialog());
                  }),
                  _buildActionButton(context, Icons.event_available_rounded, "New Hearing", const Color(0xFFF59E0B), () {
                    showDialog(context: context, builder: (context) => const ScheduleHearingDialog());
                  }),
                  _buildActionButton(context, Icons.note_add_rounded, "Log C.A", Colors.deepOrange, () {
                    showDialog(context: context, builder: (context) => const LogCCDialog());
                  }),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildActionButton(context, Icons.mail_rounded, "Invitations", Colors.purple, () {
                    context.push('/collaborator-invitations');
                  }),
                ],
              ),
              const SizedBox(height: 32),
              const DashboardCourtDiary(),
              const SizedBox(height: 24),
              const TaskWidget(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  // ─── DESKTOP DASHBOARD ───────────────────────────────

  Widget _buildDesktopDashboard(BuildContext context, WidgetRef ref, Map<String, dynamic> stats, String userName, AsyncValue<UserProfile> profileAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Dashboard",
              style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            profileAsync.when(
              data: (profile) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: AppTheme.cardDecoration(color: AppTheme.surfaceLight),
                child: Text(
                  "BETA UNLOCKED",
                  style: GoogleFonts.inter(
                    fontSize: 11,
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
        const SizedBox(height: 32),

        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            SizedBox(width: 280, child: KpiCard(title: "Active Cases", value: "${stats['activeCasesCount']}", icon: Icons.folder_rounded, accentColor: AppTheme.accent)),
            SizedBox(width: 280, child: KpiCard(title: "Upcoming Hearings", value: "${stats['upcomingHearingsCount']}", icon: Icons.calendar_month_rounded, accentColor: AppTheme.accentViolet)),
            SizedBox(width: 280, child: KpiCard(title: "Digital Files", value: "${stats['filingsCount']}", icon: Icons.file_present_rounded, accentColor: const Color(0xFF10B981))),
            SizedBox(width: 280, child: KpiCard(title: "Total Clients", value: "${stats['clientsCount']}", icon: Icons.groups_rounded, accentColor: Colors.blueAccent)),
            SizedBox(width: 280, child: KpiCard(title: "Disposed Cases", value: "${stats['disposedCasesCount']}", icon: Icons.done_all_rounded, accentColor: Colors.teal)),
            SizedBox(width: 280, child: KpiCard(title: "Dismissed/Closed", value: "${stats['dismissedCasesCount']}", icon: Icons.close_rounded, accentColor: Colors.redAccent)),
          ],
        ),
        const SizedBox(height: 40),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2, 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DailyBoardWidget(),
                  const SizedBox(height: 32),
                  const TaskWidget(),
                ],
              ),
            ),
            const SizedBox(width: 32),
            const Expanded(
              flex: 1,
              child: Column(
                children: [
                  DashboardCourtDiary(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── HELPERS ─────────────────────────────────────────

  Widget _buildInCardStat(String label, int value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(
              "$value",
              style: GoogleFonts.outfit(
                color: const Color(0xFF1E293B),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, IconData icon, String label, Color accentColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accentColor, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(icon, color: const Color(0xFF1E293B), size: 24),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: Padding(
      padding: EdgeInsets.symmetric(vertical: 200),
      child: CircularProgressIndicator(color: AppTheme.accent),
    ));
  }
}
