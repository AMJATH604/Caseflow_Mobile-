import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/caveat_models.dart';
import '../services/providers.dart';

import '../theme/app_theme.dart';
import 'dialogs/caveat_form_sheet.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Caveat register.
///
/// The screen used to show a bare expiry date and assume the reader knew what
/// a caveat does. It does two things now that it did not: it says what the
/// thing is in one line, and it leads with **days left** rather than a date,
/// because a caveat is a countdown — it dies at 90 days under §148A CPC and
/// the only remedy is to file again.
class CaveatsScreen extends ConsumerStatefulWidget {
  const CaveatsScreen({super.key});

  @override
  ConsumerState<CaveatsScreen> createState() => _CaveatsScreenState();
}

enum _CaveatFilter { all, urgent, active, expired }

class _CaveatsScreenState extends ConsumerState<CaveatsScreen> {
  _CaveatFilter _filter = _CaveatFilter.all;
  bool _explainerOpen = false;

  /// A caveat runs 90 days from filing — the window the ring draws down.
  static const int _validityDays = 90;

  /// Inside 15 days the advocate needs to act, not just be aware.
  static const int _urgentWithinDays = 15;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _surface => _isDark ? const Color(0xFF121824) : Colors.white;
  Color get _sunken =>
      _isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC);
  Color get _border => _isDark ? Colors.white12 : const Color(0xFFE2E8F0);
  Color get _ink => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _muted => _isDark ? Colors.white60 : const Color(0xFF64748B);

  /// Red once it is a this-week problem, amber inside the month, green
  /// beyond, grey once it has lapsed.
  Color _urgencyColor(Caveat c) {
    if (c.isExpired) return _muted;
    if (c.daysRemaining <= 7) return AppTheme.error;
    if (c.daysRemaining <= 30) return AppTheme.warning;
    return AppTheme.success;
  }

  bool _isUrgent(Caveat c) =>
      !c.isExpired && c.daysRemaining <= _urgentWithinDays;

  List<Caveat> _apply(List<Caveat> all) {
    final list = switch (_filter) {
      _CaveatFilter.all => [...all],
      _CaveatFilter.urgent => all.where(_isUrgent).toList(),
      _CaveatFilter.active => all.where((c) => !c.isExpired).toList(),
      _CaveatFilter.expired => all.where((c) => c.isExpired).toList(),
    };
    // Soonest first, lapsed at the bottom: the list is a queue of work.
    list.sort((a, b) {
      if (a.isExpired != b.isExpired) return a.isExpired ? 1 : -1;
      return a.daysRemaining.compareTo(b.daysRemaining);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final asyncCaveats = ref.watch(caveatsProvider);

    return Scaffold(
      backgroundColor: _sunken,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(caveatsProvider),
          color: AppTheme.accent,
          child: asyncCaveats.when(
            data: (caveats) => _buildBody(caveats),
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
            error: (e, _) => _buildError(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCaveatForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('File Caveat'),
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBody(List<Caveat> caveats) {
    final filtered = _apply(caveats);
    final urgentCount = caveats.where(_isUrgent).length;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(caveats, urgentCount)),
        SliverToBoxAdapter(child: _buildFilters(caveats)),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(caveats.isEmpty),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 96.h),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildCaveatCard(filtered[i]),
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }

  // ─── HEADER + EXPLAINER ─────────────────────────────────

  Widget _buildHeader(List<Caveat> caveats, int urgentCount) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, size: 22.sp, color: AppTheme.accent),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Caveat Tracker',
                  style: GoogleFonts.outfit(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          // The one line that was missing. A caveat is not self-explanatory,
          // and the screen previously assumed it was.
          Text(
            'A caveat tells a court to hear you before it passes any order '
            'against you. It lasts 90 days, then it must be filed again.',
            style: GoogleFonts.inter(
              fontSize: 12.5.sp,
              height: 1.5,
              color: _muted,
            ),
          ),
          if (urgentCount > 0) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(9.r),
                border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    size: 16.sp,
                    color: AppTheme.error,
                  ),
                  SizedBox(width: 9.w),
                  Expanded(
                    child: Text(
                      urgentCount == 1
                          ? '1 caveat lapses within 15 days — re-file it.'
                          : '$urgentCount caveats lapse within 15 days — '
                              're-file them.',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 10.h),
          _buildExplainer(),
        ],
      ),
    );
  }

  Widget _buildExplainer() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _explainerOpen = !_explainerOpen),
            borderRadius: BorderRadius.circular(10.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    size: 15.sp,
                    color: _muted,
                  ),
                  SizedBox(width: 9.w),
                  Expanded(
                    child: Text(
                      'How does a caveat work?',
                      style: GoogleFonts.inter(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                  Icon(
                    _explainerOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18.sp,
                    color: _muted,
                  ),
                ],
              ),
            ),
          ),
          if (_explainerOpen)
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in const [
                    [
                      'Why file one',
                      'Your opponent may move the court without telling you. '
                          'A caveat forces the court to notify you first, so '
                          'no order is passed behind your back.',
                    ],
                    [
                      'How long it lasts',
                      'Ninety days from the filing date, under §148A CPC. '
                          'After that it lapses automatically — the court '
                          'sends no reminder.',
                    ],
                    [
                      'What this screen does',
                      'Counts the days down for each caveat and warns you at '
                          '30, 15, 7 and 3 days before it lapses, so you can '
                          're-file in time.',
                    ],
                  ])
                    Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line[0],
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            line[1],
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              height: 1.5,
                              color: _muted,
                            ),
                          ),
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

  // ─── FILTERS ────────────────────────────────────────────

  Widget _buildFilters(List<Caveat> all) {
    final counts = {
      _CaveatFilter.all: all.length,
      _CaveatFilter.urgent: all.where(_isUrgent).length,
      _CaveatFilter.active: all.where((c) => !c.isExpired).length,
      _CaveatFilter.expired: all.where((c) => c.isExpired).length,
    };
    const labels = {
      _CaveatFilter.all: 'All',
      _CaveatFilter.urgent: 'Lapsing soon',
      _CaveatFilter.active: 'Active',
      _CaveatFilter.expired: 'Lapsed',
    };

    return SizedBox(
      height: 62.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 10.h),
        children: [
          for (final f in _CaveatFilter.values) ...[
            _buildFilterChip(labels[f]!, counts[f]!, f),
            SizedBox(width: 8.w),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, _CaveatFilter value) {
    final selected = _filter == value;
    final isUrgent = value == _CaveatFilter.urgent && count > 0;
    final tint = isUrgent ? AppTheme.error : AppTheme.accent;

    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? tint.withValues(alpha: 0.08) : _surface,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: selected ? tint : _border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? tint : _muted,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: selected
                    ? tint.withValues(alpha: 0.15)
                    : (_isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.robotoMono(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: selected ? tint : _muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CARD ───────────────────────────────────────────────

  Widget _buildCaveatCard(Caveat caveat) {
    final color = _urgencyColor(caveat);
    final expired = caveat.isExpired;
    final needsRefile = expired || _isUrgent(caveat);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: needsRefile ? color.withValues(alpha: 0.4) : _border,
          width: needsRefile ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCaveatForm(context, caveat: caveat),
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDayRing(caveat, color),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            caveat.courtName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                              height: 1.25,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          // Who this protects, against whom.
                          Text(
                            '${caveat.caveatorName}  vs  ${caveat.opponentName}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12.5.sp,
                              color: _muted,
                              height: 1.35,
                            ),
                          ),
                          if (caveat.caveatNumber != null &&
                              caveat.caveatNumber!.isNotEmpty) ...[
                            SizedBox(height: 5.h),
                            Text(
                              caveat.caveatNumber!,
                              style: GoogleFonts.robotoMono(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: _muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 11.w,
                    vertical: 9.h,
                  ),
                  decoration: BoxDecoration(
                    color: _sunken,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      _buildDateBit('Filed', caveat.filingDate),
                      Container(
                        width: 1,
                        height: 22.h,
                        margin: EdgeInsets.symmetric(horizontal: 12.w),
                        color: _border,
                      ),
                      _buildDateBit(
                        expired ? 'Lapsed' : 'Lapses',
                        caveat.expiryDate,
                        color: expired ? null : color,
                      ),
                    ],
                  ),
                ),
                if (needsRefile) ...[
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showCaveatForm(
                        context,
                        refileFrom: caveat,
                      ),
                      icon: Icon(Icons.restart_alt_rounded, size: 16.sp),
                      label: Text(
                        expired ? 'File again' : 'Re-file now',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: color,
                        side: BorderSide(color: color.withValues(alpha: 0.5)),
                        padding: EdgeInsets.symmetric(vertical: 9.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Days left as the headline, with the 90-day window draining around it.
  /// The date alone never said how urgent it was.
  Widget _buildDayRing(Caveat caveat, Color color) {
    final days = caveat.daysRemaining;
    final expired = caveat.isExpired;
    final progress = expired
        ? 1.0
        : (1 - (days / _validityDays)).clamp(0.0, 1.0);

    return SizedBox(
      width: 58.w,
      height: 58.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 58.w,
            height: 58.w,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              backgroundColor: color.withValues(alpha: 0.13),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                expired ? '—' : '$days',
                style: GoogleFonts.outfit(
                  fontSize: expired ? 16.sp : 19.sp,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.05,
                ),
              ),
              Text(
                expired ? 'lapsed' : (days == 1 ? 'day' : 'days'),
                style: GoogleFonts.inter(
                  fontSize: 8.5.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateBit(String label, DateTime date, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
          DateFormat('dd MMM yyyy').format(date),
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: color ?? _ink,
          ),
        ),
      ],
    );
  }

  // ─── EMPTY / ERROR ──────────────────────────────────────

  Widget _buildEmptyState(bool noneAtAll) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 40.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            noneAtAll ? Icons.gavel_rounded : Icons.filter_alt_off_rounded,
            size: 42.sp,
            color: _muted,
          ),
          SizedBox(height: 14.h),
          Text(
            noneAtAll ? 'No caveats on file' : 'Nothing in this filter',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            noneAtAll
                ? 'File a caveat when you expect the other side to move the '
                    'court, and you will be heard before any order is passed.'
                : 'Try a different filter to see the rest of your caveats.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12.5.sp,
              height: 1.5,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 40.sp),
          SizedBox(height: 12.h),
          Text(
            'Could not load your caveats.',
            style: GoogleFonts.inter(fontSize: 13.sp, color: _ink),
          ),
          TextButton(
            onPressed: () => ref.invalidate(caveatsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showCaveatForm(
    BuildContext context, {
    Caveat? caveat,
    Caveat? refileFrom,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          CaveatFormSheet(caveat: caveat, refileFrom: refileFrom),
    );
  }
}
