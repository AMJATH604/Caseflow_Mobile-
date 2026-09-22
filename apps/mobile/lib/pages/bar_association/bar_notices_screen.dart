import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/bar_association_models.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Premium Color Palette
class _C {
  static const primary = Color(0xFF4F46E5);
  static const danger = Color(0xFFEF4444);
  static const accent = Color(0xFFF59E0B);
  static const info = Color(0xFF0EA5E9);
  static const violet = Color(0xFF7C3AED);
  static const surface = Color(0xFFF8FAFC);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
}

class BarNoticesScreen extends ConsumerStatefulWidget {
  final String associationId;
  const BarNoticesScreen({super.key, required this.associationId});

  @override
  ConsumerState<BarNoticesScreen> createState() => _BarNoticesScreenState();
}

class _BarNoticesScreenState extends ConsumerState<BarNoticesScreen> {
  String _selectedCategory = 'all';

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'urgent': return _C.danger;
      case 'event': return _C.info;
      case 'holiday': return _C.accent;
      default: return _C.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(barNoticesProvider(widget.associationId));

    return Scaffold(
      backgroundColor: _C.surface,
      appBar: AppBar(
        title: Text(
          'Notices',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 20.sp,
            color: _C.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _C.textPrimary),
      ),
      body: noticesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _C.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: _C.danger.withValues(alpha: 0.5)),
              SizedBox(height: 12.h),
              Text('Failed to load notices', style: GoogleFonts.inter(color: _C.textMuted)),
            ],
          ),
        ),
        data: (notices) => _buildContent(notices),
      ),
    );
  }

  Widget _buildContent(List<BarNotice> allNotices) {
    final filtered = _selectedCategory == 'all'
        ? allNotices
        : allNotices.where((n) => n.category == _selectedCategory).toList();

    final pinned = filtered.where((n) => n.isPinned).toList();
    final unpinned = filtered.where((n) => !n.isPinned).toList();

    return RefreshIndicator(
      color: _C.primary,
      onRefresh: () async {
        ref.invalidate(barNoticesProvider(widget.associationId));
      },
      child: Column(
        children: [
          // Category Filter Chips
          Container(
            height: 48.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildChip('all', 'All', null),
                _buildChip('urgent', '🔴 Urgent', _C.danger),
                _buildChip('general', '📌 General', _C.primary),
                _buildChip('event', '📅 Event', _C.info),
                _buildChip('holiday', '🏖️ Holiday', _C.accent),
              ],
            ),
          ),
          SizedBox(height: 8.h),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80.w,
                          height: 80.h,
                          decoration: BoxDecoration(
                            color: _C.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                          child: Icon(
                            Icons.campaign_rounded,
                            size: 36,
                            color: _C.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'No notices yet',
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: _C.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    children: [
                      // Pinned Section
                      if (pinned.isNotEmpty) ...[
                        _buildSectionHeader('📌 Pinned', pinned.length),
                        ...pinned.map(_buildNoticeCard),
                        SizedBox(height: 16.h),
                      ],
                      // All / Unpinned
                      if (unpinned.isNotEmpty) ...[
                        if (pinned.isNotEmpty)
                          _buildSectionHeader('All Notices', unpinned.length),
                        ...unpinned.map(_buildNoticeCard),
                      ],
                      SizedBox(height: 32.h),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String key, String label, Color? color) {
    final isSelected = _selectedCategory == key;
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : _C.textSecondary,
          ),
        ),
        selectedColor: color ?? _C.primary,
        backgroundColor: _C.card,
        side: BorderSide(
          color: isSelected ? (color ?? _C.primary) : _C.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        showCheckmark: false,
        onSelected: (_) => setState(() => _selectedCategory = key),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h, top: 4.h),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: _C.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(BarNotice notice) {
    final color = _categoryColor(notice.category);
    final timeAgo = _formatTimeAgo(notice.publishedAt);

    return GestureDetector(
      onTap: () => _showNoticeDetail(notice),
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Color strip
            Container(
              width: 4.w,
              height: 72.h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  bottomLeft: Radius.circular(16.r),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Unread dot
                        if (!notice.isRead)
                          Container(
                            width: 8.w,
                            height: 8.h,
                            margin: EdgeInsets.only(right: 8.w),
                            decoration: BoxDecoration(
                              color: _C.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _C.primary.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: Text(
                            notice.title,
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              fontWeight: notice.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: _C.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                          child: Text(
                            notice.categoryLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: _C.textMuted,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          timeAgo,
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: _C.textMuted,
                          ),
                        ),
                        if (notice.isPinned) ...[
                          const Spacer(),
                          Icon(
                            Icons.push_pin_rounded,
                            size: 13,
                            color: _C.accent,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 12.w),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _C.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoticeDetail(BarNotice notice) {
    final color = _categoryColor(notice.category);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.r),
              topRight: Radius.circular(24.r),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.all(24.r),
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: _C.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),

              // Category + Date
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      notice.categoryLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  Spacer(),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(notice.publishedAt),
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: _C.textMuted,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),

              // Title
              Text(
                notice.title,
                style: GoogleFonts.inter(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                  height: 1.3.h,
                ),
              ),
              SizedBox(height: 20.h),

              // Body
              Text(
                notice.body,
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  color: _C.textSecondary,
                  height: 1.8.h,
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(date);
  }
}
