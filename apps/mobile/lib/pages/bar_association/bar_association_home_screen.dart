import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/bar_association_models.dart';
import '../../services/bar_realtime_service.dart';
import '../../services/providers.dart';
import '../../services/repositories/bar_association_repository.dart';

// ── Palette ──────────────────────────────────────────────
// The original three-stop indigo → violet → pink ran the full rainbow and
// fought everything under it. Kept as a gradient — it is what gives the
// screen its character — but pulled into one family so the hero reads as
// depth rather than as decoration.
class _C {
  static const indigo = Color(0xFF4338CA);
  static const violet = Color(0xFF6D28D9);
  static const plum = Color(0xFF8B2FA8);

  static const ink = Color(0xFF0B1220);
  static const inkSoft = Color(0xFF5A6474);
  static const inkFaint = Color(0xFF94A0B0);

  static const surface = Color(0xFFF6F7FA);
  static const card = Colors.white;
  static const line = Color(0xFFE6E9F0);

  static const good = Color(0xFF0E9F6E);
  static const warn = Color(0xFFB4690E);
  static const bad = Color(0xFFD03434);

  // The membership card's own ground — near-black slate, so it reads as a
  // card you carry rather than another panel on the page.
  static const cardTop = Color(0xFF111827);
  static const cardMid = Color(0xFF1E2537);
  static const cardBot = Color(0xFF2B3345);
}

/// MyBar — the advocate's view of their bar association.
class BarAssociationHomeScreen extends ConsumerStatefulWidget {
  const BarAssociationHomeScreen({super.key});

  @override
  ConsumerState<BarAssociationHomeScreen> createState() =>
      _BarAssociationHomeScreenState();
}

class _BarAssociationHomeScreenState
    extends ConsumerState<BarAssociationHomeScreen> {
  final _inviteCodeController = TextEditingController();
  // The code alone proves nothing — every member of the bar has it. The
  // enrolment number identifies which entry on the roll is yours.
  final _enrolmentController = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _enrolmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final associationsAsync = ref.watch(barAssociationsProvider);

    return Scaffold(
      backgroundColor: _C.surface,
      body: associationsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _C.indigo)),
        error: (_, __) => _buildEmptyState(),
        data: (associations) {
          if (associations.isEmpty) return _buildEmptyState();
          final selectedId = ref.watch(selectedBarAssociationIdProvider);
          final assoc = selectedId != null
              ? associations.firstWhere(
                  (a) => a.id == selectedId,
                  orElse: () => associations.first,
                )
              : associations.first;
          return _buildHome(assoc, associations);
        },
      ),
    );
  }

  // ─── NOT A MEMBER ───────────────────────────────────────

  Widget _buildEmptyState() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(32.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 104.w,
                height: 104.w,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.indigo, _C.violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30.r),
                  boxShadow: [
                    BoxShadow(
                      color: _C.violet.withValues(alpha: 0.32),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  size: 44.sp,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 30.h),
              Text(
                'Join your bar association',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 23.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: _C.ink,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Notices, fee receipts, your membership card and\n'
                'welfare status — all in one place.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5.sp,
                  height: 1.6,
                  color: _C.inkSoft,
                ),
              ),
              SizedBox(height: 34.h),
              SizedBox(
                width: double.infinity,
                height: 54.h,
                child: ElevatedButton.icon(
                  onPressed: () => _showJoinSheet(context),
                  icon: Icon(Icons.vpn_key_rounded, size: 19.sp),
                  label: Text(
                    'Enter association code',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.sp,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.indigo,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.r),
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

  // ─── HOME ───────────────────────────────────────────────

  Widget _buildHome(BarAssociation assoc, List<BarAssociation> all) {
    // Holds a filtered realtime channel while this screen is up, so anything
    // published in BarDesk arrives without a pull to refresh.
    ref.watch(barRealtimeProvider(assoc.id));

    final membershipAsync = ref.watch(barMembershipProvider(assoc.id));
    final condolencesAsync = ref.watch(barCondolencesProvider(assoc.id));
    final noticesAsync = ref.watch(barNoticesProvider(assoc.id));
    final eventsAsync = ref.watch(barEventsProvider(assoc.id));

    return RefreshIndicator(
      color: _C.indigo,
      onRefresh: () async {
        ref.invalidate(barAssociationsProvider);
        ref.invalidate(barMembershipProvider(assoc.id));
        ref.invalidate(barNoticesProvider(assoc.id));
        ref.invalidate(barCondolencesProvider(assoc.id));
        ref.invalidate(barEventsProvider(assoc.id));
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildHero(assoc),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (all.length > 1) ...[
                    _buildSwitcher(all, assoc),
                    SizedBox(height: 16.h),
                  ],

                  membershipAsync.when(
                    loading: () => _cardSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (m) {
                      if (m == null) return const SizedBox.shrink();
                      return Column(
                        children: [
                          _buildMembershipCard(assoc, m),
                          SizedBox(height: 12.h),
                          _buildFeeCard(assoc, m),
                          SizedBox(height: 18.h),
                        ],
                      );
                    },
                  ),

                  // A death decides whether an advocate sets out for court,
                  // so it sits above the notices rather than inside them.
                  condolencesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) {
                      final recent = list
                          .where((c) =>
                              DateTime.now().difference(c.dateOfDeath).inDays <=
                              7)
                          .toList();
                      if (recent.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          for (final c in recent) _buildCondolence(c),
                          SizedBox(height: 6.h),
                        ],
                      );
                    },
                  ),

                  _buildQuickActions(assoc.id),
                  SizedBox(height: 22.h),

                  noticesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (n) => n.isEmpty
                        ? const SizedBox.shrink()
                        : _buildNotices(assoc.id, n.take(3).toList()),
                  ),

                  eventsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (e) {
                      final upcoming = e
                          .where((x) => x.eventDate.isAfter(DateTime.now()
                              .subtract(const Duration(days: 1))))
                          .take(3)
                          .toList();
                      return upcoming.isEmpty
                          ? const SizedBox.shrink()
                          : _buildEvents(assoc.id, upcoming);
                    },
                  ),

                  SizedBox(height: 90.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HERO ───────────────────────────────────────────────

  Widget _buildHero(BarAssociation assoc) {
    return SliverAppBar(
      expandedHeight: 188.h,
      pinned: true,
      elevation: 0,
      backgroundColor: _C.indigo,
      automaticallyImplyLeading: false,
      // Shown only once the hero has collapsed, so the name is never lost.
      title: Text(
        assoc.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.outfit(
          fontSize: 15.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_C.indigo, _C.violet, _C.plum],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Two soft highlights give the gradient somewhere to catch the
              // light, so it reads as a surface instead of a flat wash.
              Positioned(
                top: -50.h,
                right: -30.w,
                child: _glow(150.w, Colors.white.withValues(alpha: 0.13)),
              ),
              Positioned(
                bottom: -60.h,
                left: -40.w,
                child: _glow(170.w, Colors.black.withValues(alpha: 0.10)),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 18.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 50.w,
                            height: 50.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(15.r),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.24),
                              ),
                            ),
                            child: assoc.logoUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(15.r),
                                    child: Image.network(
                                      assoc.logoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.account_balance_rounded,
                                        color: Colors.white,
                                        size: 24.sp,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.account_balance_rounded,
                                    color: Colors.white,
                                    size: 24.sp,
                                  ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  assoc.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 19.sp,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    letterSpacing: -0.3,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  '${assoc.court}  ·  ${assoc.district}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5.sp,
                                    color: Colors.white.withValues(alpha: 0.78),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          _heroChip(
                            Icons.people_rounded,
                            '${assoc.memberCount ?? 0} members',
                          ),
                          SizedBox(width: 9.w),
                          _heroChip(
                            Icons.calendar_today_rounded,
                            'Est. ${assoc.createdAt.year}',
                          ),
                        ],
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

  Widget _glow(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _heroChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(9.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: Colors.white),
          SizedBox(width: 6.w),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ─── MEMBERSHIP CARD ────────────────────────────────────

  Widget _buildMembershipCard(BarAssociation assoc, BarMember m) {
    final days = m.daysUntilExpiry;
    final lapsed = m.hasLapsed;
    final soon = m.isLapsingSoon;
    final tone = lapsed ? _C.bad : (soon ? _C.warn : _C.good);
    final badge = lapsed
        ? 'LAPSED'
        : soon
            ? 'RENEW SOON'
            : 'ACTIVE';

    return GestureDetector(
      onTap: () => context.push('/bar-membership?assocId=${assoc.id}'),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_C.cardTop, _C.cardMid, _C.cardBot],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: _C.cardTop.withValues(alpha: 0.32),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -40.h,
              right: -30.w,
              child: _glow(130.w, Colors.white.withValues(alpha: 0.05)),
            ),
            Padding(
              padding: EdgeInsets.all(20.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MEMBERSHIP CARD',
                        style: GoogleFonts.inter(
                          fontSize: 9.5.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 9.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: tone.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8.r),
                          border:
                              Border.all(color: tone.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.inter(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: lapsed
                                ? const Color(0xFFFF8A80)
                                : soon
                                    ? const Color(0xFFFFCC80)
                                    : const Color(0xFF6EE7B7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 22.h),
                  Text(
                    m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Row(
                    children: [
                      Expanded(
                        child: _cardDetail(
                          'ENROLMENT',
                          m.enrollmentNumber ?? '—',
                        ),
                      ),
                      Expanded(
                        child: _cardDetail(
                          'TYPE',
                          m.isClerk ? 'Clerk' : m.membershipTypeLabel,
                        ),
                      ),
                      Expanded(
                        child: _cardDetail(
                          lapsed ? 'LAPSED' : 'VALID TILL',
                          m.membershipExpiresOn != null
                              ? DateFormat('MMM yyyy')
                                  .format(m.membershipExpiresOn!)
                              : '—',
                        ),
                      ),
                    ],
                  ),

                  // The countdown, and why it matters. A lapsed membership is
                  // why a welfare claim gets refused, and that is not
                  // something to leave as assumed knowledge.
                  if (days != null && (lapsed || soon)) ...[
                    SizedBox(height: 18.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 13.w,
                        vertical: 11.h,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11.r),
                        border: Border.all(color: tone.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            lapsed
                                ? Icons.error_outline_rounded
                                : Icons.schedule_rounded,
                            size: 15.sp,
                            color: lapsed
                                ? const Color(0xFFFF8A80)
                                : const Color(0xFFFFCC80),
                          ),
                          SizedBox(width: 9.w),
                          Expanded(
                            child: Text(
                              lapsed
                                  ? 'Lapsed ${days.abs()} days ago — a welfare '
                                      'claim can be refused while it is lapsed.'
                                  : '$days days left — renew before it lapses, '
                                      'or a welfare claim can be refused.',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 8.5.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.robotoMono(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _cardSkeleton() => Container(
        height: 176.h,
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: _C.line),
        ),
      );

  // ─── FEE CARD ───────────────────────────────────────────

  Widget _buildFeeCard(BarAssociation assoc, BarMember m) {
    final paid = m.isFeePaidForCurrentYear;
    final year = DateTime.now().year;
    final tone = paid ? _C.good : _C.warn;

    return GestureDetector(
      onTap: () => context.push('/bar-fees?assocId=${assoc.id}'),
      child: Container(
        padding: EdgeInsets.all(15.r),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: paid ? _C.line : tone.withValues(alpha: 0.32),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13.r),
              ),
              child: Icon(
                paid
                    ? Icons.verified_rounded
                    : Icons.account_balance_wallet_rounded,
                color: tone,
                size: 21.sp,
              ),
            ),
            SizedBox(width: 13.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paid ? 'Fees paid for $year' : 'Fees due for $year',
                    style: GoogleFonts.inter(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      color: _C.ink,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '₹${assoc.annualFee.toStringAsFixed(0)} annual subscription',
                    style: GoogleFonts.inter(
                      fontSize: 11.5.sp,
                      color: _C.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (!paid)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 13.w,
                  vertical: 8.h,
                ),
                decoration: BoxDecoration(
                  color: _C.indigo,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  'Pay',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded, color: _C.inkFaint, size: 20.sp),
          ],
        ),
      ),
    );
  }

  // ─── CONDOLENCE ─────────────────────────────────────────

  Widget _buildCondolence(BarCondolence c) {
    final meta = [
      if (c.enrolmentNumber != null && c.enrolmentNumber!.isNotEmpty)
        c.enrolmentNumber!,
      if (c.age != null) 'Aged ${c.age}',
      DateFormat('dd MMM yyyy').format(c.dateOfDeath),
    ].join('  ·  ');

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_florist_rounded, size: 14.sp, color: _C.inkFaint),
              SizedBox(width: 7.w),
              Text(
                'CONDOLENCE',
                style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: _C.inkFaint,
                ),
              ),
              const Spacer(),
              if (c.noWorkResolution)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 3.h,
                  ),
                  decoration: BoxDecoration(
                    color: _C.bad.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6.r),
                    border: Border.all(color: _C.bad.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'NO WORK',
                    style: GoogleFonts.inter(
                      fontSize: 8.5.sp,
                      fontWeight: FontWeight.w800,
                      color: _C.bad,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            c.deceasedName,
            style: GoogleFonts.outfit(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: _C.ink,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            meta,
            style: GoogleFonts.inter(fontSize: 11.5.sp, color: _C.inkSoft),
          ),
          if (c.message != null && c.message!.isNotEmpty) ...[
            SizedBox(height: 11.h),
            Text(
              c.message!,
              style: GoogleFonts.inter(
                fontSize: 12.5.sp,
                height: 1.55,
                color: _C.inkSoft,
              ),
            ),
          ],
          if (c.meetingAt != null) ...[
            SizedBox(height: 13.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.groups_rounded, size: 14.sp, color: _C.indigo),
                  SizedBox(width: 9.w),
                  Expanded(
                    child: Text(
                      'Meeting ${DateFormat('dd MMM, h:mm a').format(c.meetingAt!)}'
                      '${c.meetingVenue != null && c.meetingVenue!.isNotEmpty ? '  ·  ${c.meetingVenue}' : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: _C.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── SWITCHER ───────────────────────────────────────────

  Widget _buildSwitcher(List<BarAssociation> all, BarAssociation current) {
    return SizedBox(
      height: 36.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: all.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (_, i) {
          final a = all[i];
          final selected = a.id == current.id;
          return GestureDetector(
            onTap: () => ref
                .read(selectedBarAssociationIdProvider.notifier)
                .state = a.id,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _C.indigo : _C.card,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: selected ? _C.indigo : _C.line),
              ),
              child: Text(
                a.district,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _C.inkSoft,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── QUICK ACTIONS ──────────────────────────────────────

  Widget _buildQuickActions(String assocId) {
    final actions = <(IconData, String, List<Color>, String)>[
      (
        Icons.campaign_rounded,
        'Notices',
        [const Color(0xFFEF4444), const Color(0xFFF97316)],
        '/bar-notices?assocId=$assocId',
      ),
      (
        Icons.receipt_long_rounded,
        'Fees',
        [const Color(0xFF059669), const Color(0xFF10B981)],
        '/bar-fees?assocId=$assocId',
      ),
      (
        Icons.badge_rounded,
        'My card',
        [_C.indigo, _C.violet],
        '/bar-membership?assocId=$assocId',
      ),
      (
        Icons.event_rounded,
        'Events',
        [const Color(0xFF0284C7), const Color(0xFF0EA5E9)],
        '/bar-events?assocId=$assocId',
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => context.push(actions[i].$4),
              child: Container(
                height: 86.h,
                decoration: BoxDecoration(
                  color: _C.card,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: _C.line),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38.w,
                      height: 38.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: actions[i].$3,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: actions[i].$3.first.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(actions[i].$1, size: 18.sp, color: Colors.white),
                    ),
                    SizedBox(height: 9.h),
                    Text(
                      actions[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
                        color: _C.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (i < actions.length - 1) SizedBox(width: 9.w),
        ],
      ],
    );
  }

  // ─── NOTICES ────────────────────────────────────────────

  Widget _buildNotices(String assocId, List<BarNotice> notices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Notices',
          () => context.push('/bar-notices?assocId=$assocId'),
        ),
        SizedBox(height: 11.h),
        Container(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: _C.line),
          ),
          child: Column(
            children: [
              for (var i = 0; i < notices.length; i++) ...[
                Padding(
                  padding: EdgeInsets.all(15.r),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34.w,
                        height: 34.w,
                        decoration: BoxDecoration(
                          color: (notices[i].category == 'urgent'
                                  ? _C.bad
                                  : _C.indigo)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          notices[i].category == 'urgent'
                              ? Icons.priority_high_rounded
                              : Icons.campaign_rounded,
                          size: 16.sp,
                          color: notices[i].category == 'urgent'
                              ? _C.bad
                              : _C.indigo,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notices[i].title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                color: _C.ink,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              notices[i].publishedAt != null
                                  ? DateFormat('dd MMM')
                                      .format(notices[i].publishedAt!)
                                  : 'Unpublished',
                              style: GoogleFonts.inter(
                                fontSize: 10.5.sp,
                                color: _C.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < notices.length - 1)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15.w),
                    child: Container(height: 1, color: _C.line),
                  ),
              ],
            ],
          ),
        ),
        SizedBox(height: 22.h),
      ],
    );
  }

  // ─── EVENTS ─────────────────────────────────────────────

  Widget _buildEvents(String assocId, List<BarEvent> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Upcoming',
          () => context.push('/bar-events?assocId=$assocId'),
        ),
        SizedBox(height: 11.h),
        for (final e in events)
          Container(
            margin: EdgeInsets.only(bottom: 9.h),
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(15.r),
              border: Border.all(color: _C.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 46.w,
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _C.indigo.withValues(alpha: 0.12),
                        _C.violet.withValues(alpha: 0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('dd').format(e.eventDate),
                        style: GoogleFonts.outfit(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: _C.indigo,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(e.eventDate).toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 8.5.sp,
                          fontWeight: FontWeight.w700,
                          color: _C.indigo,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 13.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w600,
                          color: _C.ink,
                        ),
                      ),
                      if (e.location != null && e.location!.isNotEmpty) ...[
                        SizedBox(height: 3.h),
                        Text(
                          e.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: _C.inkSoft,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _sectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: _C.ink,
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            'See all',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: _C.indigo,
            ),
          ),
        ),
      ],
    );
  }

  // ─── JOIN SHEET ─────────────────────────────────────────

  void _showJoinSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
            ),
            padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 28.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: _C.line,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 24.h),
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_C.indigo, _C.violet],
                    ),
                    borderRadius: BorderRadius.circular(17.r),
                  ),
                  child: Icon(
                    Icons.vpn_key_rounded,
                    color: Colors.white,
                    size: 24.sp,
                  ),
                ),
                SizedBox(height: 18.h),
                Text(
                  'Join your association',
                  style: GoogleFonts.outfit(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: _C.ink,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Enter the code your association shared, and your enrolment '
                  'number so it can match you to its roll.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5.sp,
                    height: 1.55,
                    color: _C.inkSoft,
                  ),
                ),
                SizedBox(height: 24.h),
                TextField(
                  controller: _inviteCodeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    UpperCaseTextFormatter(),
                  ],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.robotoMono(
                    fontSize: 25.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 9,
                    color: _C.indigo,
                  ),
                  decoration: _fieldDecoration('••••••', counter: ''),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _enrolmentController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: _C.ink,
                  ),
                  decoration:
                      _fieldDecoration('Enrolment no. e.g. MS/1234/2015'),
                ),
                SizedBox(height: 11.h),
                Text(
                  'Your association must have added you to its roll first. '
                  'If it has not, ask the secretary.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10.5.sp,
                    height: 1.45,
                    color: _C.inkFaint,
                  ),
                ),
                SizedBox(height: 22.h),
                SizedBox(
                  width: double.infinity,
                  height: 54.h,
                  child: ElevatedButton(
                    onPressed:
                        _joining ? null : () => _submitJoin(ctx, setSheetState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.indigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.r),
                      ),
                    ),
                    child: _joining
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Join association',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.sp,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, {String? counter}) {
    return InputDecoration(
      hintText: hint,
      counterText: counter,
      hintStyle: GoogleFonts.inter(
        fontSize: 13.sp,
        fontWeight: FontWeight.w400,
        color: _C.inkFaint,
      ),
      filled: true,
      fillColor: _C.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: _C.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: _C.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: const BorderSide(color: _C.indigo, width: 1.8),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 17.h),
    );
  }

  Future<void> _submitJoin(BuildContext ctx, StateSetter setSheetState) async {
    final code = _inviteCodeController.text.trim();
    final enrolment = _enrolmentController.text.trim();

    if (code.length != 6) {
      _snack(ctx, 'Enter the 6-character association code');
      return;
    }
    if (enrolment.isEmpty) {
      _snack(ctx, 'Enter your enrolment number so the roll can be matched');
      return;
    }

    setSheetState(() => _joining = true);
    try {
      await BarAssociationRepository.claimMembership(code, enrolment);
      ref.invalidate(barAssociationsProvider);
      ref.invalidate(userProfileProvider);
      if (ctx.mounted) Navigator.pop(ctx);
      if (!mounted) return;
      _snack(context, 'Joined. Your membership is now verified.', tone: _C.good);
    } catch (e) {
      if (!ctx.mounted) return;
      // The server's own message is the useful one — "you are not on this
      // association's roll" tells the advocate exactly what to do next.
      _snack(ctx, e.toString().replaceAll('Exception: ', ''), tone: _C.bad);
    } finally {
      if (ctx.mounted) setSheetState(() => _joining = false);
    }
  }

  void _snack(BuildContext ctx, String message, {Color? tone}) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: tone,
        behavior: SnackBarBehavior.floating,
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
