import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../theme/cf_colors.dart';
import '../theme/cf_spacing.dart';
import '../theme/cf_typography.dart';
import '../theme/cf_decorations.dart';
import '../services/legal_news_service.dart';
import '../components/error_state_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ─── Providers ─────────────────────────────────────────
final legalNewsProvider = FutureProvider.family<List<LegalNewsArticle>, String>(
  (ref, category) async {
    return LegalNewsService.fetchArticles(
      category: category == 'all' ? null : category,
    );
  },
);

final legalNewsBookmarksProvider = FutureProvider<List<LegalNewsArticle>>((
  ref,
) async {
  return LegalNewsService.fetchBookmarks();
});

// ─── Main Screen ───────────────────────────────────────
class LegalPulseScreen extends ConsumerStatefulWidget {
  const LegalPulseScreen({super.key});

  @override
  ConsumerState<LegalPulseScreen> createState() => _LegalPulseScreenState();
}

class _LegalPulseScreenState extends ConsumerState<LegalPulseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRefreshing = false;

  static const _categories = [
    {'id': 'all', 'label': 'All', 'icon': Icons.dashboard_rounded},
    {'id': 'top_stories', 'label': 'Top Stories', 'icon': Icons.star_rounded},
    {
      'id': 'supreme_court',
      'label': 'Supreme Court',
      'icon': Icons.account_balance_rounded,
    },
    {'id': 'high_court', 'label': 'High Courts', 'icon': Icons.gavel_rounded},
    {'id': 'news', 'label': 'News', 'icon': Icons.newspaper_rounded},
    {'id': 'columns', 'label': 'Columns', 'icon': Icons.article_rounded},
    {'id': 'bookmarks', 'label': 'Saved', 'icon': Icons.bookmark_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshNews() async {
    setState(() => _isRefreshing = true);
    try {
      await LegalNewsService.triggerFetch();
      // Invalidate all category providers
      for (final cat in _categories) {
        if (cat['id'] != 'bookmarks') {
          ref.invalidate(legalNewsProvider(cat['id'] as String));
        }
      }
      ref.invalidate(legalNewsBookmarksProvider);
    } catch (_) {}
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CfColors.of(context).background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCategoryTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children:
                    _categories.map((cat) {
                      if (cat['id'] == 'bookmarks') {
                        return _BookmarksTab(ref: ref);
                      }
                      return _NewsFeedTab(
                        category: cat['id'] as String,
                        ref: ref,
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFEF4444), Color(0xFFF87171)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: const Icon(
              Icons.newspaper_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Legal Pulse',
                  style: GoogleFonts.outfit(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Live legal news from across India',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          Material(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12.r),
            child: InkWell(
              onTap: _isRefreshing ? null : _refreshNews,
              borderRadius: BorderRadius.circular(12.r),
              child: Padding(
                padding: EdgeInsets.all(10.r),
                child:
                    _isRefreshing
                        ? SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      height: 40.h,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        indicator: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(20.r),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
        labelPadding: EdgeInsets.symmetric(horizontal: 6.w),
        tabs:
            _categories.map((cat) {
              return Tab(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat['icon'] as IconData, size: 14),
                      SizedBox(width: 6.w),
                      Text(cat['label'] as String),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

// ─── News Feed Tab ─────────────────────────────────────
class _NewsFeedTab extends StatelessWidget {
  final String category;
  final WidgetRef ref;

  const _NewsFeedTab({required this.category, required this.ref});

  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(legalNewsProvider(category));

    return articlesAsync.when(
      data: (articles) {
        if (articles.isEmpty) {
          return _buildEmptyState();
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(legalNewsProvider(category)),
          color: const Color(0xFFDC2626),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              // First article gets a hero card treatment
              if (index == 0) {
                return _HeroNewsCard(article: article, ref: ref);
              }
              return _NewsCard(article: article, ref: ref);
            },
          ),
        );
      },
      loading: () => _buildLoadingShimmer(),
      error:
          (err, _) => ErrorStateWidget(
            error: err,
            onRetry: () => ref.invalidate(legalNewsProvider(category)),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.newspaper_rounded,
              size: 48,
              color: const Color(0xFFDC2626).withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'No articles yet',
            style: GoogleFonts.outfit(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Pull down to refresh and fetch latest news',
            style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: EdgeInsets.all(16.r),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 16.h),
          height: index == 0 ? 220 : 120,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20.r),
          ),
        );
      },
    );
  }
}

// ─── Bookmarks Tab ─────────────────────────────────────
class _BookmarksTab extends StatelessWidget {
  final WidgetRef ref;

  const _BookmarksTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(legalNewsBookmarksProvider);

    return bookmarksAsync.when(
      data: (articles) {
        if (articles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24.r),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bookmark_border_rounded,
                    size: 48,
                    color: AppTheme.accent.withValues(alpha: 0.4),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'No saved articles',
                  style: GoogleFonts.outfit(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Tap the bookmark icon on any article to save it',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
          itemCount: articles.length,
          itemBuilder:
              (context, index) => _NewsCard(article: articles[index], ref: ref),
        );
      },
      loading:
          () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
      error:
          (err, _) => ErrorStateWidget(
            error: err,
            onRetry: () => ref.invalidate(legalNewsBookmarksProvider),
          ),
    );
  }
}

// ─── Hero News Card (first article) ────────────────────
class _HeroNewsCard extends StatelessWidget {
  final LegalNewsArticle article;
  final WidgetRef ref;

  const _HeroNewsCard({required this.article, required this.ref});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openArticle(article.link),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            if (article.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24.r),
                ),
                child: Image.network(
                  article.imageUrl!,
                  height: 180.h,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) => Container(
                        height: 120.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFDC2626).withValues(alpha: 0.1),
                              const Color(0xFFEF4444).withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24.r),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.newspaper_rounded,
                            size: 40,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                ),
              ),

            Padding(
              padding: EdgeInsets.all(20.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + Time
                  Row(
                    children: [
                      _CategoryChip(category: article.category),
                      const Spacer(),
                      _TimeAgo(date: article.publishedAt),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Title
                  Text(
                    article.title,
                    style: GoogleFonts.outfit(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                      height: 1.3.h,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 10.h),

                  // Summary
                  if (article.summary != null && article.summary!.isNotEmpty)
                    Text(
                      article.summary!,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        color: Colors.grey[600],
                        height: 1.5.h,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  SizedBox(height: 14.h),

                  // Actions row
                  Row(
                    children: [
                      _ReadMoreButton(),
                      Spacer(),
                      _BookmarkButton(article: article, ref: ref),
                      SizedBox(width: 8.w),
                      _ShareButton(article: article),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Standard News Card ────────────────────────────────
class _NewsCard extends StatelessWidget {
  final LegalNewsArticle article;
  final WidgetRef ref;

  const _NewsCard({required this.article, required this.ref});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openArticle(article.link),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child:
                  article.imageUrl != null
                      ? Image.network(
                        article.imageUrl!,
                        width: 80.w,
                        height: 80.h,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) =>
                                _PlaceholderThumb(category: article.category),
                      )
                      : _PlaceholderThumb(category: article.category),
            ),
            SizedBox(width: 14.w),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryChip(category: article.category, small: true),
                      const Spacer(),
                      _TimeAgo(date: article.publishedAt, small: true),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    article.title,
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      height: 1.3.h,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 12,
                        color: Colors.grey[400],
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Read on LiveLaw',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      _BookmarkButton(article: article, ref: ref, small: true),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Widgets ────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String category;
  final bool small;

  const _CategoryChip({required this.category, this.small = false});

  @override
  Widget build(BuildContext context) {
    final info = _getCategoryInfo(category);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: small ? 10 : 12, color: info.color),
          SizedBox(width: small ? 3 : 4),
          Text(
            info.label,
            style: GoogleFonts.inter(
              fontSize: small ? 9 : 10,
              fontWeight: FontWeight.w800,
              color: info.color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeAgo extends StatelessWidget {
  final DateTime? date;
  final bool small;

  const _TimeAgo({this.date, this.small = false});

  @override
  Widget build(BuildContext context) {
    final text = date != null ? _formatTimeAgo(date!) : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time_rounded,
          size: small ? 10 : 12,
          color: Colors.grey[400],
        ),
        SizedBox(width: small ? 3 : 4),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: small ? 9 : 10,
            color: Colors.grey[400],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ReadMoreButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Read Full Article',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFDC2626),
            ),
          ),
          SizedBox(width: 4.w),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 14,
            color: Color(0xFFDC2626),
          ),
        ],
      ),
    );
  }
}

class _BookmarkButton extends StatefulWidget {
  final LegalNewsArticle article;
  final WidgetRef ref;
  final bool small;

  const _BookmarkButton({
    required this.article,
    required this.ref,
    this.small = false,
  });

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton> {
  bool _isBookmarked = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _toggleBookmark,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.all(widget.small ? 4 : 8),
        child:
            _isLoading
                ? SizedBox(
                  width: widget.small ? 14 : 18,
                  height: widget.small ? 14 : 18,
                  child: const CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppTheme.accent,
                  ),
                )
                : Icon(
                  _isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: widget.small ? 18 : 22,
                  color: _isBookmarked ? AppTheme.accent : Colors.grey[400],
                ),
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    setState(() => _isLoading = true);
    try {
      if (_isBookmarked) {
        await LegalNewsService.removeBookmark(widget.article.id);
      } else {
        await LegalNewsService.addBookmark(widget.article.id);
      }
      setState(() => _isBookmarked = !_isBookmarked);
      widget.ref.invalidate(legalNewsBookmarksProvider);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }
}

class _ShareButton extends StatelessWidget {
  final LegalNewsArticle article;

  const _ShareButton({required this.article});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Simple share via clipboard
        _openArticle(article.link);
      },
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.all(8.r),
        child: Icon(Icons.share_rounded, size: 18, color: Colors.grey[400]),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  final String category;

  const _PlaceholderThumb({required this.category});

  @override
  Widget build(BuildContext context) {
    final info = _getCategoryInfo(category);
    return Container(
      width: 80.w,
      height: 80.h,
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: Icon(
          info.icon,
          size: 28,
          color: info.color.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────

void _openArticle(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

String _formatTimeAgo(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  } else if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  } else if (diff.inDays < 7) {
    return '${diff.inDays}d ago';
  } else {
    return DateFormat('dd MMM').format(date);
  }
}

class _CategoryInfo {
  final String label;
  final Color color;
  final IconData icon;

  const _CategoryInfo(this.label, this.color, this.icon);
}

_CategoryInfo _getCategoryInfo(String category) {
  switch (category) {
    case 'supreme_court':
      return const _CategoryInfo(
        'Supreme Court',
        Color(0xFFDC2626),
        Icons.account_balance_rounded,
      );
    case 'high_court':
      return const _CategoryInfo(
        'High Court',
        Color(0xFF7C3AED),
        Icons.gavel_rounded,
      );
    case 'top_stories':
      return const _CategoryInfo(
        'Top Story',
        Color(0xFFF59E0B),
        Icons.star_rounded,
      );
    case 'news':
      return const _CategoryInfo(
        'News',
        Color(0xFF2563EB),
        Icons.newspaper_rounded,
      );
    case 'columns':
      return const _CategoryInfo(
        'Column',
        Color(0xFF059669),
        Icons.article_rounded,
      );
    case 'tribunals':
      return const _CategoryInfo(
        'Tribunal',
        Color(0xFFEC4899),
        Icons.policy_rounded,
      );
    default:
      return const _CategoryInfo(
        'Legal News',
        Color(0xFF6B7280),
        Icons.newspaper_rounded,
      );
  }
}
