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
import '../services/analytics_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Track dashboard view
    AnalyticsService.logScreenView('Dashboard');
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
    final todayHearings = stats['todayHearings'] as List<Hearing>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Header Card (Navy → Deep Indigo Gradient)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
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
              borderRadius: BorderRadius.circular(28),
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
                            "Hello, $userName 👋",
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, d MMMM y').format(DateTime.now()),
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mini profile badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "ONLINE",
                            style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF10B981), letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Compact stats inside header
                Row(
                  children: [
                    _buildHeaderStat("${stats['activeCasesCount'] ?? 0}", "Active", const Color(0xFF818CF8)),
                    const SizedBox(width: 8),
                    _buildHeaderStat("${todayHearings.length}", "Today", const Color(0xFFFBBF24)),
                    const SizedBox(width: 8),
                    _buildHeaderStat("${stats['clientsCount'] ?? 0}", "Clients", const Color(0xFF34D399)),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ─── Hero KPI Cards (2x2 Grid) ────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: KpiCard(
                      title: "Active Cases",
                      value: "${stats['activeCasesCount'] ?? 0}",
                      icon: Icons.folder_open_rounded,
                      accentColor: const Color(0xFF6366F1),
                      onTap: () => context.go('/cases'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KpiCard(
                      title: "Today's Hearings",
                      value: "${todayHearings.length}",
                      icon: Icons.gavel_rounded,
                      accentColor: const Color(0xFFF59E0B),
                      showPulse: true,
                      onTap: () => context.go('/hearings'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: KpiCard(
                      title: "Upcoming Hearings",
                      value: "${stats['upcomingHearingsCount'] ?? 0}",
                      icon: Icons.calendar_month_rounded,
                      accentColor: const Color(0xFF0EA5E9),
                      onTap: () => context.go('/hearings'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KpiCard(
                      title: "Total Clients",
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
              StatChip(
                label: "Disposed",
                value: stats['disposedCasesCount'] ?? 0,
                color: const Color(0xFF14B8A6),
                icon: Icons.done_all_rounded,
              ),
              const SizedBox(width: 8),
              StatChip(
                label: "Closed",
                value: stats['dismissedCasesCount'] ?? 0,
                color: const Color(0xFF64748B),
                icon: Icons.close_rounded,
              ),
              const SizedBox(width: 8),
              StatChip(
                label: "E-Filings",
                value: stats['filingsCount'] ?? 0,
                color: const Color(0xFF3B82F6),
                icon: Icons.file_present_rounded,
              ),
              const SizedBox(width: 8),
              StatChip(
                label: "Pending ₹",
                value: stats['pendingPaymentsCount'] ?? 0,
                color: const Color(0xFFF97316),
                icon: Icons.account_balance_wallet_rounded,
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DailyBoardWidget(),
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
    final todayHearings = stats['todayHearings'] as List<Hearing>? ?? [];

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
            SizedBox(width: 280, child: KpiCard(title: "Active Cases", value: "${stats['activeCasesCount']}", icon: Icons.folder_open_rounded, accentColor: const Color(0xFF6366F1), onTap: () => context.go('/cases'))),
            SizedBox(width: 280, child: KpiCard(title: "Today's Hearings", value: "${todayHearings.length}", icon: Icons.gavel_rounded, accentColor: const Color(0xFFF59E0B), showPulse: true, onTap: () => context.go('/hearings'))),
            SizedBox(width: 280, child: KpiCard(title: "Upcoming Hearings", value: "${stats['upcomingHearingsCount']}", icon: Icons.calendar_month_rounded, accentColor: const Color(0xFF0EA5E9), onTap: () => context.go('/hearings'))),
            SizedBox(width: 280, child: KpiCard(title: "Total Clients", value: "${stats['clientsCount']}", icon: Icons.people_rounded, accentColor: const Color(0xFF10B981), onTap: () => context.go('/clients'))),
          ],
        ),
        const SizedBox(height: 20),
        // Secondary stats row
        Row(
          children: [
            StatChip(label: "Disposed", value: stats['disposedCasesCount'] ?? 0, color: const Color(0xFF14B8A6), icon: Icons.done_all_rounded),
            const SizedBox(width: 10),
            StatChip(label: "Closed", value: stats['dismissedCasesCount'] ?? 0, color: const Color(0xFF64748B), icon: Icons.close_rounded),
            const SizedBox(width: 10),
            StatChip(label: "E-Filings", value: stats['filingsCount'] ?? 0, color: const Color(0xFF3B82F6), icon: Icons.file_present_rounded),
            const SizedBox(width: 10),
            StatChip(label: "Pending ₹", value: stats['pendingPaymentsCount'] ?? 0, color: const Color(0xFFF97316), icon: Icons.account_balance_wallet_rounded),
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

  Widget _buildHeaderStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
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
