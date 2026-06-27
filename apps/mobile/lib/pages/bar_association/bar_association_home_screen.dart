import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/bar_association_models.dart';
import '../../services/providers.dart';
import '../../services/repositories/bar_association_repository.dart';
import '../../theme/app_theme.dart';

// ── Premium Color Palette ────────────────────────────────
class _BarColors {
  static const primary = Color(0xFF4F46E5);       // Indigo-600
  static const primaryLight = Color(0xFF818CF8);   // Indigo-400
  static const primaryDark = Color(0xFF3730A3);    // Indigo-800
  static const accent = Color(0xFFF59E0B);         // Amber-500
  static const success = Color(0xFF10B981);        // Emerald-500
  static const warning = Color(0xFFF97316);        // Orange-500
  static const danger = Color(0xFFEF4444);         // Red-500
  static const surface = Color(0xFFF8FAFC);        // Slate-50
  static const card = Colors.white;
  static const textPrimary = Color(0xFF0F172A);    // Slate-900
  static const textSecondary = Color(0xFF64748B);  // Slate-500
  static const textMuted = Color(0xFF94A3B8);      // Slate-400
  static const border = Color(0xFFE2E8F0);         // Slate-200
  static const gradient1 = Color(0xFF4F46E5);
  static const gradient2 = Color(0xFF7C3AED);
  static const gradient3 = Color(0xFFEC4899);
}

class BarAssociationHomeScreen extends ConsumerStatefulWidget {
  const BarAssociationHomeScreen({super.key});

  @override
  ConsumerState<BarAssociationHomeScreen> createState() =>
      _BarAssociationHomeScreenState();
}

class _BarAssociationHomeScreenState
    extends ConsumerState<BarAssociationHomeScreen>
    with SingleTickerProviderStateMixin {
  final _inviteCodeController = TextEditingController();
  bool _joining = false;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final associationsAsync = ref.watch(barAssociationsProvider);

    return Scaffold(
      backgroundColor: _BarColors.surface,
      body: associationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _BarColors.primary),
        ),
        error: (e, _) => _buildEmptyState(context),
        data: (associations) {
          if (associations.isEmpty) {
            return _buildEmptyState(context);
          }
          final selectedId = ref.watch(selectedBarAssociationIdProvider);
          final assoc = selectedId != null
              ? associations.firstWhere(
                  (a) => a.id == selectedId,
                  orElse: () => associations.first,
                )
              : associations.first;
          return _buildAssociationHome(context, assoc, associations);
        },
      ),
    );
  }

  // ── Empty State (Premium) ─────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_BarColors.gradient1, _BarColors.gradient2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: _BarColors.primary.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Join Your Bar Association',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _BarColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Connect with your local bar to receive\nnotices, pay fees, and participate in elections.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: _BarColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _showJoinSheet(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _BarColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.vpn_key_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Enter Invite Code',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main Association Home ─────────────────────────────
  Widget _buildAssociationHome(
    BuildContext context,
    BarAssociation assoc,
    List<BarAssociation> allAssociations,
  ) {
    final membershipAsync = ref.watch(barMembershipProvider(assoc.id));
    final noticesAsync = ref.watch(barNoticesProvider(assoc.id));
    final electionAsync = ref.watch(barElectionProvider(assoc.id));
    final eventsAsync = ref.watch(barEventsProvider(assoc.id));

    return RefreshIndicator(
      color: _BarColors.primary,
      onRefresh: () async {
        ref.invalidate(barAssociationsProvider);
        ref.invalidate(barMembershipProvider(assoc.id));
        ref.invalidate(barNoticesProvider(assoc.id));
        ref.invalidate(barElectionProvider(assoc.id));
        ref.invalidate(barEventsProvider(assoc.id));
      },
      child: CustomScrollView(
        slivers: [
          // ── Gradient App Bar ──
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: _BarColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _BarColors.gradient1,
                      _BarColors.gradient2,
                      _BarColors.gradient3,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: assoc.logoUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.network(
                                        assoc.logoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.account_balance_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.account_balance_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    assoc.name,
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${assoc.court} • ${assoc.district}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Stats Row
                        Row(
                          children: [
                            _buildStatChip(
                              Icons.people_rounded,
                              '${assoc.memberCount ?? 0} Members',
                            ),
                            const SizedBox(width: 10),
                            _buildStatChip(
                              Icons.calendar_today_rounded,
                              'Est. ${assoc.createdAt.year}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: Colors.white),
                tooltip: 'Join Another Association',
                onPressed: () => _showJoinSheet(context),
              ),
            ],
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Multi-association switcher
                if (allAssociations.length > 1) ...[
                  _buildAssociationSwitcher(allAssociations, assoc),
                  const SizedBox(height: 16),
                ],

                // Membership + Fee
                membershipAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (member) {
                    if (member == null) return const SizedBox.shrink();

                    // Check if member is suspended
                    if (member.status == 'suspended') {
                      return _buildSuspendedBanner();
                    }

                    return Column(
                      children: [
                        _buildMembershipCard(assoc, member),
                        const SizedBox(height: 12),
                        _buildFeeCard(assoc, member),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

                // Election Banner
                electionAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (election) {
                    if (election == null || !election.isVotingOpen) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: [
                        _buildElectionBanner(election),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),

                // Quick Actions
                _buildQuickActions(context),
                const SizedBox(height: 20),

                // Notices
                noticesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (notices) {
                    if (notices.isEmpty) return const SizedBox.shrink();
                    return _buildNoticesSection(notices.take(3).toList());
                  },
                ),
                const SizedBox(height: 16),

                // Events
                eventsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (events) {
                    final upcoming = events
                        .where((e) => e.eventDate.isAfter(
                              DateTime.now().subtract(const Duration(days: 1)),
                            ))
                        .take(3)
                        .toList();
                    if (upcoming.isEmpty) return const SizedBox.shrink();
                    return _buildEventsSection(upcoming);
                  },
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat Chip (header) ────────────────────────────────
  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Suspended Banner ──────────────────────────────────
  Widget _buildSuspendedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _BarColors.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _BarColors.danger.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _BarColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.block_rounded,
              color: _BarColors.danger,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membership Suspended',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _BarColors.danger,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your membership has been suspended. Please contact your bar association secretary.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _BarColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Association Switcher ──────────────────────────────
  Widget _buildAssociationSwitcher(
    List<BarAssociation> associations,
    BarAssociation current,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _BarColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _BarColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current.id,
          isExpanded: true,
          icon: const Icon(Icons.swap_horiz_rounded,
              color: _BarColors.primary),
          items: associations.map((a) {
            return DropdownMenuItem(
              value: a.id,
              child: Text(
                a.name,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
          onChanged: (id) {
            ref.read(selectedBarAssociationIdProvider.notifier).state = id;
          },
        ),
      ),
    );
  }

  // ── Membership Card (Premium) ─────────────────────────
  Widget _buildMembershipCard(BarAssociation assoc, BarMember member) {
    return GestureDetector(
      onTap: () => context.push('/bar-membership?assocId=${assoc.id}'),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MEMBERSHIP CARD',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _BarColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _BarColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'VALID ${DateTime.now().year}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _BarColors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              member.name,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildCardDetail(
                  'Enrollment',
                  member.enrollmentNumber ?? 'N/A',
                ),
                const SizedBox(width: 24),
                _buildCardDetail('Type', member.membershipTypeLabel),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  assoc.name,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.4),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  // ── Fee Card ──────────────────────────────────────────
  Widget _buildFeeCard(BarAssociation assoc, BarMember member) {
    final isPaid = member.isFeePaidForCurrentYear;
    final currentYear = DateTime.now().year;

    return Container(
      decoration: BoxDecoration(
        color: _BarColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _BarColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPaid
                  ? _BarColors.success.withValues(alpha: 0.1)
                  : _BarColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPaid
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              color: isPaid ? _BarColors.success : _BarColors.warning,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPaid ? 'Fee Paid ✅' : 'Fee Due',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _BarColors.textPrimary,
                  ),
                ),
                Text(
                  isPaid
                      ? 'Paid for $currentYear-${currentYear + 1}'
                      : '₹${assoc.annualFee.toStringAsFixed(0)} due for $currentYear-${currentYear + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _BarColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isPaid)
            TextButton(
              onPressed: () => context.push('/bar-fees?assocId=${assoc.id}'),
              style: TextButton.styleFrom(
                backgroundColor: _BarColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Pay Now',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Election Banner (Pulsing) ─────────────────────────
  Widget _buildElectionBanner(BarElection election) {
    return GestureDetector(
      onTap: () => context.push(
        '/bar-elections?assocId=${election.associationId}',
      ),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [
                  Color(0xFF7C3AED),
                  Color(0xFFDB2777),
                  Color(0xFF7C3AED),
                ],
                stops: [
                  0.0,
                  _shimmerController.value,
                  1.0,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.how_to_vote_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VOTE NOW',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        election.title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ends ${DateFormat('dd MMM yyyy').format(election.votingEnd)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Quick Actions (Redesigned) ────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    final assocs = ref.watch(barAssociationsProvider).valueOrNull ?? [];
    final assocId = assocs.isNotEmpty ? assocs.first.id : '';

    final actions = [
      _QuickAction(
        icon: Icons.campaign_rounded,
        label: 'Notices',
        gradient: const [Color(0xFFEF4444), Color(0xFFF97316)],
        route: '/bar-notices?assocId=$assocId',
      ),
      _QuickAction(
        icon: Icons.receipt_long_rounded,
        label: 'Fees',
        gradient: const [Color(0xFF10B981), Color(0xFF059669)],
        route: '/bar-fees?assocId=$assocId',
      ),
      _QuickAction(
        icon: Icons.how_to_vote_rounded,
        label: 'Elections',
        gradient: const [Color(0xFF7C3AED), Color(0xFF4F46E5)],
        route: '/bar-elections?assocId=$assocId',
      ),
      _QuickAction(
        icon: Icons.event_rounded,
        label: 'Events',
        gradient: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
        route: '/bar-events?assocId=$assocId',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _BarColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: actions.map((action) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: action != actions.last ? 10 : 0,
                ),
                child: GestureDetector(
                  onTap: () => context.push(action.route),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: _BarColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _BarColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: action.gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            action.icon,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          action.label,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _BarColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Notices Section (Redesigned) ──────────────────────
  Widget _buildNoticesSection(List<BarNotice> notices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Latest Notices',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _BarColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                final assocs =
                    ref.read(barAssociationsProvider).valueOrNull ?? [];
                if (assocs.isNotEmpty) {
                  context.push('/bar-notices?assocId=${assocs.first.id}');
                }
              },
              child: Text(
                'View All →',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _BarColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...notices.map((notice) => _buildNoticeCard(notice)),
      ],
    );
  }

  Widget _buildNoticeCard(BarNotice notice) {
    final categoryColors = {
      'general': _BarColors.primary,
      'urgent': _BarColors.danger,
      'election': const Color(0xFF7C3AED),
      'event': const Color(0xFF0EA5E9),
      'holiday': _BarColors.accent,
    };
    final color = categoryColors[notice.category] ?? _BarColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _BarColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _BarColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!notice.isRead)
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                  color: _BarColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (notice.isPinned)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.push_pin_rounded,
                                  size: 13,
                                  color: _BarColors.accent,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                notice.title,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: notice.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: _BarColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy').format(notice.publishedAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _BarColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      notice.category,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Events Section (Timeline Style) ──────────────────
  Widget _buildEventsSection(List<BarEvent> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Events',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: _BarColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...events.asMap().entries.map((entry) {
          final event = entry.value;
          final isLast = entry.key == events.length - 1;
          return _buildEventItem(event, isLast);
        }),
      ],
    );
  }

  Widget _buildEventItem(BarEvent event, bool isLast) {
    final categoryColors = {
      'meeting': const Color(0xFF2563EB),
      'holiday': _BarColors.danger,
      'lecture': _BarColors.success,
      'sports': _BarColors.accent,
      'annual': const Color(0xFF7C3AED),
    };
    final color = categoryColors[event.category] ?? _BarColors.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: _BarColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Event card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _BarColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _BarColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        DateFormat('dd MMM').format(event.eventDate),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      if (event.startTime != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          event.startTime!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _BarColors.textMuted,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          event.categoryLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _BarColors.textPrimary,
                    ),
                  ),
                  if (event.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: _BarColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          event.location!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _BarColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Join Sheet ────────────────────────────────────────
  void _showJoinSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_BarColors.gradient1, _BarColors.gradient2],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Join Bar Association',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _BarColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-character invite code from\nyour Bar Association Secretary.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _BarColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _inviteCodeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  UpperCaseTextFormatter(),
                ],
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                  color: _BarColors.primary,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '• • • • • •',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 10,
                    color: const Color(0xFFCBD5E1),
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: _BarColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _joining
                      ? null
                      : () async {
                          final code = _inviteCodeController.text.trim();
                          if (code.length != 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a 6-character invite code',
                                ),
                              ),
                            );
                            return;
                          }
                          setSheetState(() => _joining = true);
                          try {
                            await BarAssociationRepository.joinAssociation(
                              code,
                            );
                            ref.invalidate(barAssociationsProvider);
                            ref.invalidate(userProfileProvider);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '✅ Successfully joined the Bar Association!',
                                ),
                                backgroundColor: _BarColors.success,
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('❌ $e')),
                            );
                          } finally {
                            if (mounted) {
                              setSheetState(() => _joining = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _BarColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _joining
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Join Association',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper Classes ──────────────────────────────────────

class _QuickAction {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final String route;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.route,
  });
}

/// Formatter to auto-uppercase the invite code input.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
