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
import '../../theme/app_theme.dart';

/// MyBar — the advocate's view of their bar association.
///
/// Rebuilt around what an advocate needs to know, in the order they need it:
/// whether their membership is about to lapse, whether the bar is sitting
/// today, and what has been published. The previous screen opened with a
/// violet-to-pink gradient hero and gave membership status a small badge,
/// which is the wrong way round — a lapsed membership is why a welfare claim
/// gets refused, so it belongs at the top.
///
/// Restrained on purpose: one accent, flat surfaces, colour reserved for
/// status. When every tile carried its own gradient, nothing could stand out
/// at the moment something was actually wrong.
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

  // ─── Palette ────────────────────────────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0A0E15) : const Color(0xFFF7F8FA);
  Color get _card => _isDark ? const Color(0xFF141A24) : Colors.white;
  Color get _line => _isDark ? Colors.white10 : const Color(0xFFE6E9EF);
  Color get _ink => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _muted => _isDark ? Colors.white60 : const Color(0xFF6B7684);
  Color get _sunken => _isDark
      ? Colors.white.withValues(alpha: 0.03)
      : const Color(0xFFF7F8FA);

  @override
  Widget build(BuildContext context) {
    final associationsAsync = ref.watch(barAssociationsProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: associationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
        error: (_, __) => _buildNotJoined(),
        data: (associations) {
          if (associations.isEmpty) return _buildNotJoined();
          final selectedId = ref.watch(selectedBarAssociationIdProvider);
          final assoc = selectedId != null
              ? associations.firstWhere(
                  (a) => a.id == selectedId,
                  orElse: () => associations.first,
                )
              : associations.first;
          return _buildHome(assoc);
        },
      ),
    );
  }

  // ─── NOT A MEMBER YET ───────────────────────────────────

  Widget _buildNotJoined() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(28.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68.w,
                height: 68.w,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  size: 32.sp,
                  color: AppTheme.accent,
                ),
              ),
              SizedBox(height: 22.h),
              Text(
                'Join your bar association',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 21.sp,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Notices, fee receipts, your membership card and welfare '
                'status — in one place.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5.sp,
                  height: 1.55,
                  color: _muted,
                ),
              ),
              SizedBox(height: 26.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton.icon(
                  onPressed: () => _showJoinSheet(context),
                  icon: Icon(Icons.vpn_key_rounded, size: 18.sp),
                  label: Text(
                    'Enter association code',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5.sp,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
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

  // ─── MEMBER HOME ────────────────────────────────────────

  Widget _buildHome(BarAssociation assoc) {
    // Holds a filtered realtime channel while this screen is up, so anything
    // published in BarDesk arrives without a pull to refresh.
    ref.watch(barRealtimeProvider(assoc.id));

    final membershipAsync = ref.watch(barMembershipProvider(assoc.id));
    final condolencesAsync = ref.watch(barCondolencesProvider(assoc.id));
    final noticesAsync = ref.watch(barNoticesProvider(assoc.id));
    final eventsAsync = ref.watch(barEventsProvider(assoc.id));

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppTheme.accent,
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
            SliverToBoxAdapter(child: _buildHeader(assoc)),

            // The membership card leads. Everything else is secondary to
            // whether this advocate is still on the roll.
            SliverToBoxAdapter(
              child: membershipAsync.when(
                loading: () => _buildCardSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
                data: (m) => m == null
                    ? const SizedBox.shrink()
                    : _buildMembershipCard(m),
              ),
            ),

            // A death decides whether an advocate sets out for court, so it
            // sits above the notices rather than inside them.
            SliverToBoxAdapter(
              child: condolencesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) {
                  final recent = list
                      .where((c) =>
                          DateTime.now().difference(c.dateOfDeath).inDays <= 7)
                      .toList();
                  if (recent.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 4.h),
                    child: Column(
                      children: [
                        for (final c in recent) _buildCondolenceCard(c),
                      ],
                    ),
                  );
                },
              ),
            ),

            SliverToBoxAdapter(child: _buildQuickActions(assoc.id)),

            SliverToBoxAdapter(
              child: noticesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (notices) => notices.isEmpty
                    ? const SizedBox.shrink()
                    : _buildNotices(assoc.id, notices.take(3).toList()),
              ),
            ),

            SliverToBoxAdapter(
              child: eventsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (events) {
                  final upcoming = events
                      .where((e) => e.eventDate.isAfter(
                          DateTime.now().subtract(const Duration(days: 1))))
                      .take(2)
                      .toList();
                  return upcoming.isEmpty
                      ? const SizedBox.shrink()
                      : _buildEvents(assoc.id, upcoming);
                },
              ),
            ),

            SliverToBoxAdapter(child: SizedBox(height: 90.h)),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ─────────────────────────────────────────────

  Widget _buildHeader(BarAssociation assoc) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11.r),
            ),
            child: Icon(
              Icons.account_balance_rounded,
              size: 19.sp,
              color: AppTheme.accent,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  assoc.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${assoc.district} · ${assoc.court}',
                  style: GoogleFonts.inter(fontSize: 11.5.sp, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── MEMBERSHIP CARD ────────────────────────────────────

  Widget _buildMembershipCard(BarMember m) {
    final days = m.daysUntilExpiry;
    final lapsed = m.hasLapsed;
    final soon = m.isLapsingSoon;

    final tone = lapsed
        ? AppTheme.error
        : soon
            ? AppTheme.warning
            : AppTheme.success;

    final statusLine = days == null
        ? 'Renewal date not recorded'
        : lapsed
            ? 'Lapsed ${days.abs()} ${days.abs() == 1 ? "day" : "days"} ago'
            : 'Valid for $days ${days == 1 ? "day" : "days"}';

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: lapsed || soon ? tone.withValues(alpha: 0.45) : _line,
            width: lapsed || soon ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16.r),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          [
                            if (m.enrollmentNumber != null &&
                                m.enrollmentNumber!.isNotEmpty)
                              m.enrollmentNumber!,
                            m.isClerk ? 'Clerk' : m.membershipTypeLabel,
                          ].join('  ·  '),
                          style: GoogleFonts.robotoMono(
                            fontSize: 11.5.sp,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusPill(
                    lapsed ? 'LAPSED' : (soon ? 'RENEW' : 'ACTIVE'),
                    tone,
                  ),
                ],
              ),
            ),

            Container(height: 1, color: _line),

            Padding(
              padding: EdgeInsets.all(14.r),
              child: Row(
                children: [
                  Icon(
                    lapsed
                        ? Icons.error_outline_rounded
                        : Icons.event_available_rounded,
                    size: 15.sp,
                    color: tone,
                  ),
                  SizedBox(width: 9.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusLine,
                          style: GoogleFonts.inter(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: lapsed || soon ? tone : _ink,
                          ),
                        ),
                        if (m.membershipExpiresOn != null) ...[
                          SizedBox(height: 2.h),
                          Text(
                            'Expires ${DateFormat('dd MMM yyyy').format(m.membershipExpiresOn!)}',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: _muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Why a lapse matters, stated once rather than assumed known.
            if (lapsed || soon)
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(14.w, 11.h, 14.w, 13.h),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(15.r),
                  ),
                ),
                child: Text(
                  lapsed
                      ? 'While your membership is lapsed, a welfare fund claim '
                          'can be refused. Contact your association to renew.'
                      : 'Renew before it lapses — a lapsed membership can cost '
                          'your family the welfare fund benefit.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5.sp,
                    height: 1.45,
                    color: tone,
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
                child: Row(
                  children: [
                    Expanded(
                      child: _miniFact(
                        'Welfare fund',
                        m.welfareFundLabel,
                        m.welfareFundStatus == 'arrears'
                            ? AppTheme.warning
                            : null,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _miniFact(
                        'ID card',
                        m.hasValidIdCard ? 'Valid' : 'Not issued',
                        m.hasValidIdCard ? null : _muted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniFact(String label, String value, Color? tone) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: _sunken,
        borderRadius: BorderRadius.circular(9.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: _muted,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: tone ?? _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, Color tone) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9.sp,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: tone,
        ),
      ),
    );
  }

  Widget _buildCardSkeleton() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
      child: Container(
        height: 132.h,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _line),
        ),
      ),
    );
  }

  // ─── CONDOLENCE ─────────────────────────────────────────

  Widget _buildCondolenceCard(BarCondolence c) {
    final meta = [
      if (c.enrolmentNumber != null && c.enrolmentNumber!.isNotEmpty)
        c.enrolmentNumber!,
      if (c.age != null) 'Aged ${c.age}',
      DateFormat('dd MMM yyyy').format(c.dateOfDeath),
    ].join('  ·  ');

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(15.r),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_florist_rounded, size: 14.sp, color: _muted),
              SizedBox(width: 7.w),
              Text(
                'CONDOLENCE',
                style: GoogleFonts.inter(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: _muted,
                ),
              ),
              const Spacer(),
              if (c.noWorkResolution) _statusPill('NO WORK', AppTheme.error),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            c.deceasedName,
            style: GoogleFonts.outfit(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          SizedBox(height: 3.h),
          Text(meta, style: GoogleFonts.inter(fontSize: 11.5.sp, color: _muted)),
          if (c.message != null && c.message!.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Text(
              c.message!,
              style: GoogleFonts.inter(
                fontSize: 12.5.sp,
                height: 1.5,
                color: _muted,
              ),
            ),
          ],
          if (c.meetingAt != null) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: _sunken,
                borderRadius: BorderRadius.circular(9.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.groups_rounded, size: 13.sp, color: _muted),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Meeting ${DateFormat('dd MMM, h:mm a').format(c.meetingAt!)}',
                      style: GoogleFonts.inter(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (c.meetingVenue != null && c.meetingVenue!.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                c.meetingVenue!,
                style: GoogleFonts.inter(fontSize: 11.sp, color: _muted),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ─── QUICK ACTIONS ──────────────────────────────────────

  Widget _buildQuickActions(String assocId) {
    final actions = <(IconData, String, String)>[
      (Icons.campaign_rounded, 'Notices', '/bar-notices?assocId=$assocId'),
      (Icons.receipt_long_rounded, 'Fees', '/bar-fees?assocId=$assocId'),
      (Icons.badge_rounded, 'My card', '/bar-membership?assocId=$assocId'),
      (Icons.event_rounded, 'Events', '/bar-events?assocId=$assocId'),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => context.push(actions[i].$3),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: _line),
                  ),
                  child: Column(
                    children: [
                      Icon(actions[i].$1, size: 19.sp, color: AppTheme.accent),
                      SizedBox(height: 7.h),
                      Text(
                        actions[i].$2,
                        style: GoogleFonts.inter(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                          color: _ink,
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
      ),
    );
  }

  // ─── NOTICES ────────────────────────────────────────────

  Widget _buildNotices(String assocId, List<BarNotice> notices) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Notices',
            () => context.push('/bar-notices?assocId=$assocId'),
          ),
          SizedBox(height: 10.h),
          Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: _line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < notices.length; i++) ...[
                  Padding(
                    padding: EdgeInsets.all(14.r),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6.w,
                          height: 6.w,
                          margin: EdgeInsets.only(top: 5.h),
                          decoration: BoxDecoration(
                            color: notices[i].category == 'urgent'
                                ? AppTheme.error
                                : AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 11.w),
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
                                  color: _ink,
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
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < notices.length - 1)
                    Container(height: 1, color: _line),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── EVENTS ─────────────────────────────────────────────

  Widget _buildEvents(String assocId, List<BarEvent> events) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            'Upcoming',
            () => context.push('/bar-events?assocId=$assocId'),
          ),
          SizedBox(height: 10.h),
          for (final e in events)
            Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(13.r),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42.w,
                    padding: EdgeInsets.symmetric(vertical: 7.h),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9.r),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('dd').format(e.eventDate),
                          style: GoogleFonts.outfit(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accent,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(e.eventDate).toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
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
                            color: _ink,
                          ),
                        ),
                        if (e.location != null && e.location!.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            e.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              color: _muted,
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
      ),
    );
  }

  Widget _sectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            'See all',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppTheme.accent,
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
              color: _card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
            ),
            padding: EdgeInsets.fromLTRB(22.w, 12.h, 22.w, 26.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: _line,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 22.h),
                Text(
                  'Join your association',
                  style: GoogleFonts.outfit(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                SizedBox(height: 7.h),
                Text(
                  'Enter the code your association shared, and your enrolment '
                  'number so it can match you to its roll.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5.sp,
                    height: 1.5,
                    color: _muted,
                  ),
                ),
                SizedBox(height: 22.h),
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
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 8,
                    color: AppTheme.accent,
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
                    color: _ink,
                  ),
                  decoration:
                      _fieldDecoration('Enrolment no. e.g. MS/1234/2015'),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Your association must have added you to its roll first. '
                  'If it has not, ask the secretary.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10.5.sp,
                    height: 1.45,
                    color: _muted,
                  ),
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed:
                        _joining ? null : () => _submitJoin(ctx, setSheetState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: _joining
                        ? SizedBox(
                            width: 19.w,
                            height: 19.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Join',
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
        color: _muted,
      ),
      filled: true,
      fillColor: _sunken,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: _line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
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
      _snack(
        context,
        'Joined. Your membership is now verified.',
        tone: AppTheme.success,
      );
    } catch (e) {
      if (!ctx.mounted) return;
      // The server's own message is the useful one — "you are not on this
      // association's roll" tells the advocate exactly what to do next.
      _snack(
        ctx,
        e.toString().replaceAll('Exception: ', ''),
        tone: AppTheme.error,
      );
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
