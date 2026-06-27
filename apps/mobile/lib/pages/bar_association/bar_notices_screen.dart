import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/bar_association_models.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';

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
      case 'election': return _C.violet;
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
            fontSize: 20,
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
              const SizedBox(height: 12),
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
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildChip('all', 'All', null),
                _buildChip('urgent', '🔴 Urgent', _C.danger),
                _buildChip('general', '📌 General', _C.primary),
                _buildChip('election', '🗳️ Election', _C.violet),
                _buildChip('event', '📅 Event', _C.info),
                _buildChip('holiday', '🏖️ Holiday', _C.accent),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _C.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.campaign_rounded,
                            size: 36,
                            color: _C.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notices yet',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _C.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Pinned Section
                      if (pinned.isNotEmpty) ...[
                        _buildSectionHeader('📌 Pinned', pinned.length),
                        ...pinned.map(_buildNoticeCard),
                        const SizedBox(height: 16),
                      ],
                      // All / Unpinned
                      if (unpinned.isNotEmpty) ...[
                        if (pinned.isNotEmpty)
                          _buildSectionHeader('All Notices', unpinned.length),
                        ...unpinned.map(_buildNoticeCard),
                      ],
                      const SizedBox(height: 32),
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
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
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
          borderRadius: BorderRadius.circular(10),
        ),
        showCheckmark: false,
        onSelected: (_) => setState(() => _selectedCategory = key),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 11,
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
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(16),
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
              width: 4,
              height: 72,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Unread dot
                        if (!notice.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
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
                              fontSize: 14,
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            notice.categoryLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: _C.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeAgo,
                          style: GoogleFonts.inter(
                            fontSize: 11,
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
              padding: const EdgeInsets.only(right: 12),
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _C.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Category + Date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notice.categoryLabel,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(notice.publishedAt),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _C.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                notice.title,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _C.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              // Body
              Text(
                notice.body,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: _C.textSecondary,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 24),
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
