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

class BarAssociationHomeScreen extends ConsumerStatefulWidget {
  const BarAssociationHomeScreen({super.key});

  @override
  ConsumerState<BarAssociationHomeScreen> createState() =>
      _BarAssociationHomeScreenState();
}

class _BarAssociationHomeScreenState
    extends ConsumerState<BarAssociationHomeScreen> {
  bool _showJoinDialog = false;
  final _inviteCodeController = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final associationsAsync = ref.watch(barAssociationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'My Bar Association',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Join Association',
            onPressed: () => _showJoinSheet(context),
          ),
        ],
      ),
      body: associationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildEmptyState(context),
        data: (associations) {
          if (associations.isEmpty) {
            return _buildEmptyState(context);
          }
          // Use first association or selected one
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF0891B2).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                size: 48,
                color: Color(0xFF0891B2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Not a member yet',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join your local Bar Association to receive\nnotices, pay fees, and vote in elections.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _showJoinSheet(context),
                icon: const Icon(Icons.qr_code_rounded),
                label: Text(
                  'Enter Invite Code',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0891B2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      onRefresh: () async {
        ref.invalidate(barAssociationsProvider);
        ref.invalidate(barMembershipProvider(assoc.id));
        ref.invalidate(barNoticesProvider(assoc.id));
        ref.invalidate(barElectionProvider(assoc.id));
        ref.invalidate(barEventsProvider(assoc.id));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Multi-association switcher ──
          if (allAssociations.length > 1) ...[
            _buildAssociationSwitcher(allAssociations, assoc),
            const SizedBox(height: 16),
          ],

          // ── Header Card ──
          _buildHeaderCard(assoc),
          const SizedBox(height: 16),

          // ── Membership Card Preview ──
          membershipAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (member) {
              if (member == null) return const SizedBox.shrink();
              return Column(
                children: [
                  _buildMembershipCardPreview(assoc, member),
                  const SizedBox(height: 16),
                  _buildFeeStatusCard(assoc, member),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),

          // ── Election Banner ──
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

          // ── Quick Actions Grid ──
          _buildQuickActions(context),
          const SizedBox(height: 16),

          // ── Latest Notices ──
          noticesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (notices) {
              if (notices.isEmpty) return const SizedBox.shrink();
              return _buildLatestNotices(notices.take(3).toList());
            },
          ),
          const SizedBox(height: 16),

          // ── Upcoming Events ──
          eventsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (events) {
              final upcoming = events
                  .where(
                    (e) => e.eventDate.isAfter(
                      DateTime.now().subtract(const Duration(days: 1)),
                    ),
                  )
                  .take(3)
                  .toList();
              if (upcoming.isEmpty) return const SizedBox.shrink();
              return _buildUpcomingEvents(upcoming);
            },
          ),
          const SizedBox(height: 32),
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
      decoration: AppTheme.cardDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current.id,
          isExpanded: true,
          icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0891B2)),
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

  // ── Header Card ───────────────────────────────────────
  Widget _buildHeaderCard(BarAssociation assoc) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.glassGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: assoc.logoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          assoc.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.account_balance_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.account_balance_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assoc.name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${assoc.court} • ${assoc.district}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${assoc.memberCount ?? 0} Active Members',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Membership Card Preview ───────────────────────────
  Widget _buildMembershipCardPreview(BarAssociation assoc, BarMember member) {
    return GestureDetector(
      onTap: () => context.push('/bar-membership?assocId=${assoc.id}'),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF334155)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
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
                color: const Color(0xFF0891B2).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.badge_rounded,
                color: Color(0xFF22D3EE),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Enrl: ${member.enrollmentNumber ?? 'N/A'} • ${member.membershipTypeLabel}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'VALID ${DateTime.now().year}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Fee Status Card ───────────────────────────────────
  Widget _buildFeeStatusCard(BarAssociation assoc, BarMember member) {
    final isPaid = member.isFeePaidForCurrentYear;
    final currentYear = DateTime.now().year;

    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isPaid
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPaid
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPaid ? 'Fee Paid ✅' : 'Fee Due',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPaid
                      ? 'Paid until $currentYear-${currentYear + 1}'
                      : '₹${assoc.annualFee.toStringAsFixed(0)} due for $currentYear-${currentYear + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (!isPaid)
            TextButton(
              onPressed: () => context.push('/bar-fees?assocId=${assoc.id}'),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF0891B2),
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

  // ── Election Banner ───────────────────────────────────
  Widget _buildElectionBanner(BarElection election) {
    return GestureDetector(
      onTap: () => context.push(
        '/bar-elections?assocId=${election.associationId}',
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Text('🗳️', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vote Now — ${election.title}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Voting closes ${DateFormat('dd/MM/yyyy').format(election.votingEnd)}',
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
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Actions Grid ────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    final assocs = ref.watch(barAssociationsProvider).valueOrNull ?? [];
    final assocId = assocs.isNotEmpty ? assocs.first.id : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildActionTile(
              icon: Icons.campaign_rounded,
              label: 'Notices',
              color: const Color(0xFFEF4444),
              onTap: () => context.push('/bar-notices?assocId=$assocId'),
            ),
            const SizedBox(width: 12),
            _buildActionTile(
              icon: Icons.receipt_long_rounded,
              label: 'Fees',
              color: const Color(0xFF10B981),
              onTap: () => context.push('/bar-fees?assocId=$assocId'),
            ),
            const SizedBox(width: 12),
            _buildActionTile(
              icon: Icons.how_to_vote_rounded,
              label: 'Elections',
              color: const Color(0xFF7C3AED),
              onTap: () => context.push('/bar-elections?assocId=$assocId'),
            ),
            const SizedBox(width: 12),
            _buildActionTile(
              icon: Icons.event_rounded,
              label: 'Events',
              color: const Color(0xFF0891B2),
              onTap: () => context.push('/bar-events?assocId=$assocId'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: AppTheme.cardDecoration(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Latest Notices ────────────────────────────────────
  Widget _buildLatestNotices(List<BarNotice> notices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Latest Notices',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
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
                'View All',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0891B2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...notices.map((notice) => _buildNoticeItem(notice)),
      ],
    );
  }

  Widget _buildNoticeItem(BarNotice notice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: notice.isPinned
                ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                : const Color(0xFF6366F1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            notice.isPinned ? Icons.push_pin_rounded : Icons.article_rounded,
            color: notice.isPinned
                ? const Color(0xFFF59E0B)
                : const Color(0xFF6366F1),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            if (!notice.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Text(
                notice.title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight:
                      notice.isRead ? FontWeight.w500 : FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          DateFormat('dd/MM/yyyy').format(notice.publishedAt),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF94A3B8),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            notice.categoryLabel,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  // ── Upcoming Events ───────────────────────────────────
  Widget _buildUpcomingEvents(List<BarEvent> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Events',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ...events.map((event) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: AppTheme.cardDecoration(),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF0891B2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('dd').format(event.eventDate),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0891B2),
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(event.eventDate),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0891B2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    if (event.location != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '📍 ${event.location}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.categoryLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
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
              const SizedBox(height: 20),
              Text(
                'Join Bar Association',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-character invite code provided by\nyour Bar Association Secretary.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
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
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'TNTKSI',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 8,
                    color: const Color(0xFFCBD5E1),
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF0891B2),
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
                height: 52,
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
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '✅ Successfully joined the Bar Association!',
                                  ),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('❌ $e')),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setSheetState(() => _joining = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0891B2),
                    foregroundColor: Colors.white,
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
                            fontWeight: FontWeight.w600,
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
