import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BareActsLibraryScreen extends StatefulWidget {
  const BareActsLibraryScreen({super.key});

  @override
  State<BareActsLibraryScreen> createState() => _BareActsLibraryScreenState();
}

class _BareActsLibraryScreenState extends State<BareActsLibraryScreen>
    with TickerProviderStateMixin {
  // ─── Design Tokens ───────────────────────────────────────────
  static const _bgColor = Color(0xFFF8FAFC);
  static const _cardColor = Color(0xFFFFFFFF);
  static const _borderColor = Color(0xFFE2E8F0);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF475569);
  static const _textMuted = Color(0xFF94A3B8);
  static const _readerBg = Color(0xFFF8FAFC);

  static const List<String> _categories = [
    'All',
    'Criminal',
    'Civil',
    'Constitutional',
    'Family',
    'Commercial',
    'Property',
    'Motor Vehicle',
    'Special',
  ];

  static const Map<String, Color> _domainColors = {
    'Criminal': Color(0xFFDC2626),
    'Civil': Color(0xFF2563EB),
    'Constitutional': Color(0xFFD97706),
    'Family': Color(0xFFDB2777),
    'Commercial': Color(0xFF059669),
    'Property': Color(0xFF7C3AED),
    'Motor Vehicle': Color(0xFFEA580C),
    'Special': Color(0xFF475569),
  };

  static const Map<String, IconData> _domainIcons = {
    'Criminal': Icons.gavel_rounded,
    'Civil': Icons.balance_rounded,
    'Constitutional': Icons.account_balance_rounded,
    'Family': Icons.family_restroom_rounded,
    'Commercial': Icons.business_center_rounded,
    'Property': Icons.home_work_rounded,
    'Motor Vehicle': Icons.directions_car_rounded,
    'Special': Icons.policy_rounded,
  };

  // ─── State ───────────────────────────────────────────────────
  List<dynamic> _acts = [];
  Map<String, dynamic>? _selectedAct;
  List<dynamic> _sections = [];
  List<dynamic> _filteredSections = [];
  List<dynamic> _globalSearchResults = [];
  bool _isLoading = true;
  bool _isLoadingSections = false;
  bool _isSearchingGlobal = false;
  bool _showSearchOverlay = false;
  String _selectedCategory = 'All';
  String? _selectedSearchActId;
  final Set<int> _expandedSections = {};

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _globalSearchController =
      TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late AnimationController _overlayController;
  late AnimationController _shimmerController;

  // ─── Lifecycle ───────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _searchController.addListener(_filterSections);
    _fetchActs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _globalSearchController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _staggerController.dispose();
    _overlayController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // ─── Data Methods ────────────────────────────────────────────
  Future<void> _fetchActs() async {
    try {
      final acts = await SupabaseService.fetchBareActs();
      if (mounted) {
        setState(() {
          _acts = acts;
          _isLoading = false;
        });
        _shimmerController.stop();
        _fadeController.forward();
        _staggerController.forward();
      }
    } catch (e) {
      debugPrint('Error fetching acts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _shimmerController.stop();
      }
    }
  }

  Future<void> _selectAct(Map<String, dynamic> act) async {
    setState(() {
      _selectedAct = act;
      _isLoadingSections = true;
      _sections = [];
      _filteredSections = [];
      _expandedSections.clear();
      _searchController.clear();
    });

    try {
      final sections = await SupabaseService.fetchSections(act['id']);
      if (mounted) {
        setState(() {
          _sections = sections;
          _filteredSections = sections;
          _isLoadingSections = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching sections: $e');
      if (mounted) setState(() => _isLoadingSections = false);
    }
  }

  void _filterSections() {
    final query = _searchController.text.toLowerCase().trim();
    final cleanQuery = query
        .replaceAll(
          RegExp(
            r'^(art\w*|sec\w*|article|section)\s*\.?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    setState(() {
      if (query.isEmpty) {
        _filteredSections = _sections;
      } else {
        _filteredSections = _sections.where((section) {
          final sectionNo =
              section['section_number']?.toString().toLowerCase() ?? '';
          final title =
              section['section_title']?.toString().toLowerCase() ?? '';
          final text =
              section['section_text']?.toString().toLowerCase() ?? '';

          bool matchesClean = false;
          if (cleanQuery.isNotEmpty && cleanQuery != query) {
            matchesClean = sectionNo.contains(cleanQuery);
          }

          return sectionNo.contains(query) ||
              title.contains(query) ||
              text.contains(query) ||
              matchesClean;
        }).toList();
      }
    });
  }

  Future<void> _globalSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _globalSearchResults = [];
        _isSearchingGlobal = false;
      });
      return;
    }

    setState(() => _isSearchingGlobal = true);

    try {
      final results = await SupabaseService.searchBareActs(
        query,
        actId: _selectedSearchActId,
      );
      if (mounted) {
        setState(() {
          _globalSearchResults = results;
          _isSearchingGlobal = false;
        });
      }
    } catch (e) {
      debugPrint('Global search error: $e');
      if (mounted) setState(() => _isSearchingGlobal = false);
    }
  }

  Future<void> _openPdf() async {
    if (_selectedAct?['pdf_url'] == null) return;
    final url = Uri.parse(_selectedAct!['pdf_url']);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open PDF')),
        );
      }
    }
  }

  void _openSearchOverlay() {
    setState(() => _showSearchOverlay = true);
    _overlayController.forward();
  }

  void _closeSearchOverlay() {
    _overlayController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showSearchOverlay = false;
          _globalSearchController.clear();
          _globalSearchResults = [];
          _selectedSearchActId = null;
        });
      }
    });
  }

  void _toggleSection(int index) {
    setState(() {
      if (_expandedSections.contains(index)) {
        _expandedSections.remove(index);
      } else {
        _expandedSections.add(index);
      }
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10.w),
              Text('$label copied to clipboard'),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          margin: EdgeInsets.all(16.r),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ─── Category Helpers ────────────────────────────────────────
  String _getCategoryForAct(dynamic act) {
    final title = (act['title'] ?? '').toString().toLowerCase();
    final shortTitle = (act['short_title'] ?? '').toString().toLowerCase();
    final combined = '$title $shortTitle';

    if (combined.contains('constitution')) {
      return 'Constitutional';
    }
    if (combined.contains('penal') ||
        combined.contains('ipc') ||
        combined.contains('bns') ||
        combined.contains('bnss') ||
        combined.contains('crpc') ||
        combined.contains('criminal') ||
        combined.contains('evidence') ||
        combined.contains('bsa')) {
      return 'Criminal';
    }
    if (combined.contains('cpc') ||
        combined.contains('civil procedure') ||
        combined.contains('limitation') ||
        combined.contains('specific relief')) {
      return 'Civil';
    }
    if (combined.contains('hindu') ||
        combined.contains('muslim') ||
        combined.contains('marriage') ||
        combined.contains('divorce') ||
        combined.contains('adoption') ||
        combined.contains('guardian') ||
        combined.contains('mohammedan') ||
        combined.contains('succession') ||
        combined.contains('dvc') ||
        combined.contains('domestic violence')) {
      return 'Family';
    }
    if (combined.contains('negotiable') ||
        combined.contains('contract') ||
        combined.contains('partnership') ||
        combined.contains('company') ||
        combined.contains('insolvency') ||
        combined.contains('arbitration') ||
        combined.contains('commercial')) {
      return 'Commercial';
    }
    if (combined.contains('property') ||
        combined.contains('registration') ||
        combined.contains('stamp') ||
        combined.contains('transfer') ||
        combined.contains('partition')) {
      return 'Property';
    }
    if (combined.contains('motor') || combined.contains('vehicle')) {
      return 'Motor Vehicle';
    }
    return 'Special';
  }

  Color _getDomainColor(String category) =>
      _domainColors[category] ?? const Color(0xFF475569);

  IconData _getDomainIcon(String category) =>
      _domainIcons[category] ?? Icons.policy_rounded;

  List<dynamic> get _filteredActs {
    if (_selectedCategory == 'All') return _acts;
    return _acts
        .where((act) => _getCategoryForAct(act) == _selectedCategory)
        .toList();
  }

  String _getSectionLabel(Map<String, dynamic>? act) {
    final short = (act?['short_title'] ?? '').toString().toLowerCase();
    if (short.contains('constitution')) return 'Article';
    return 'Section';
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingState();
    if (_selectedAct != null) return _buildReaderView();
    return _buildLibraryHome();
  }

  // ─── Loading State (Shimmer Skeleton) ────────────────────────
  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: _bgColor,
      body: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, _) {
          return CustomScrollView(
            physics: const NeverScrollableScrollPhysics(),
            slivers: [
              // Shimmer Hero
              SliverToBoxAdapter(
                child: Container(
                  margin: EdgeInsets.all(16.r),
                  height: 180.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24.r),
                    gradient: LinearGradient(
                      begin: Alignment(
                        -1.0 + 2.0 * _shimmerController.value,
                        0,
                      ),
                      end: Alignment(
                        2.0 * _shimmerController.value,
                        0,
                      ),
                      colors: const [
                        Color(0xFFE2E8F0),
                        Color(0xFFF1F5F9),
                        Color(0xFFE2E8F0),
                      ],
                    ),
                  ),
                ),
              ),
              // Shimmer Category Bar
              SliverToBoxAdapter(
                child: Container(
                  height: 40.h,
                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Row(
                    children: List.generate(
                      4,
                      (i) => Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: _buildShimmerBox(width: 80.w, height: 36.h, radius: 20),
                      ),
                    ),
                  ),
                ),
              ),
              // Shimmer Grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildShimmerCard(),
                    childCount: 6,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShimmerBox({
    double width = double.infinity,
    double height = 16,
    double radius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + 2.0 * _shimmerController.value, 0),
          end: Alignment(2.0 * _shimmerController.value, 0),
          colors: const [
            Color(0xFFE2E8F0),
            Color(0xFFF1F5F9),
            Color(0xFFE2E8F0),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: _borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accent stripe shimmer
            Container(
              height: 4.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(
                    -1.0 + 2.0 * _shimmerController.value,
                    0,
                  ),
                  end: Alignment(2.0 * _shimmerController.value, 0),
                  colors: const [
                    Color(0xFFE2E8F0),
                    Color(0xFFF1F5F9),
                    Color(0xFFE2E8F0),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShimmerBox(width: 44.w, height: 44.h, radius: 12),
                  SizedBox(height: 16.h),
                  _buildShimmerBox(width: 60.w, height: 20.h, radius: 6),
                  SizedBox(height: 8.h),
                  _buildShimmerBox(height: 12.h, radius: 4),
                  SizedBox(height: 6.h),
                  _buildShimmerBox(width: 80.w, height: 12.h, radius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LIBRARY HOME — Premium Bookshelf Grid
  // ═══════════════════════════════════════════════════════════════
  Widget _buildLibraryHome() {
    final acts = _filteredActs;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // Main Content
          FadeTransition(
            opacity: CurvedAnimation(
              parent: _fadeController,
              curve: Curves.easeOut,
            ),
            child: CustomScrollView(
              slivers: [
                // ── Hero Header ──
                SliverToBoxAdapter(child: _buildHeroHeader()),

                // ── Category Filter Bar ──
                SliverToBoxAdapter(child: _buildCategoryBar()),

                // ── Stats Row ──
                SliverToBoxAdapter(child: _buildStatsRow(acts)),

                // ── Section Title ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 4.w,
                          height: 20.h,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.accent, AppTheme.accentViolet],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          _selectedCategory == 'All'
                              ? 'All Statutes'
                              : '$_selectedCategory Law',
                          style: const TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${acts.length} ${acts.length == 1 ? 'act' : 'acts'}',
                          style: const TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Acts Grid ──
                acts.isEmpty
                    ? SliverToBoxAdapter(child: _buildEmptyState())
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.78,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _buildBookCard(acts[index], index),
                            childCount: acts.length,
                          ),
                        ),
                      ),
              ],
            ),
          ),

          // Search Overlay
          if (_showSearchOverlay) _buildSearchOverlay(),
        ],
      ),
    );
  }

  // ─── Hero Header ─────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: Stack(
          children: [
            // Base Gradient
            Container(
              height: 190.h,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF312E81),
                    Color(0xFF1E1B4B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // Gradient Orb — Top Right (Purple)
            Positioned(
              right: -40,
              top: -30,
              child: Container(
                width: 180.w,
                height: 180.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7C3AED).withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Gradient Orb — Bottom Left (Blue)
            Positioned(
              left: -30,
              bottom: -40,
              child: Container(
                width: 150.w,
                height: 150.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2563EB).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Gradient Orb — Center (Amber glow)
            Positioned(
              left: 60.w,
              top: 20.h,
              child: Container(
                width: 100.w,
                height: 100.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Container(
              height: 190.h,
              padding: EdgeInsets.all(24.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_stories_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Legal Library',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              'Browse & Search Indian Statutes',
                              style: TextStyle(
                                color: Color(0xAAFFFFFF),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Glassmorphism Search Bar
                  GestureDetector(
                    onTap: _openSearchOverlay,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.r),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                color: Colors.white.withValues(alpha: 0.65),
                                size: 20,
                              ),
                              SizedBox(width: 12.w),
                              Text(
                                'Search across all acts...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  '⌘K',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  // ─── Category Filter Bar ─────────────────────────────────────
  Widget _buildCategoryBar() {
    return Container(
      height: 48.h,
      margin: EdgeInsets.only(top: 4.h, bottom: 4.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;
          final color = cat == 'All'
              ? AppTheme.accent
              : _getDomainColor(cat);

          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: isSelected ? color : _borderColor,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? color : _textMuted,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.sp,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Stats Row ───────────────────────────────────────────────
  Widget _buildStatsRow(List<dynamic> acts) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Row(
        children: [
          _buildStatPill(
            Icons.auto_stories_rounded,
            '${_acts.length}',
            'Statutes',
            AppTheme.accent,
          ),
          SizedBox(width: 8.w),
          _buildStatPill(
            Icons.category_rounded,
            '${_domainColors.length}',
            'Domains',
            AppTheme.accentViolet,
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          SizedBox(width: 6.w),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.sp,
              color: _textPrimary,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Book Card (Premium) ─────────────────────────────────────
  Widget _buildBookCard(dynamic act, int index) {
    final category = _getCategoryForAct(act);
    final domainColor = _getDomainColor(category);
    final domainIcon = _getDomainIcon(category);
    final hasPdf =
        act['pdf_url'] != null && act['pdf_url'].toString().isNotEmpty;
    final shortTitle = act['short_title'] ?? '';
    final title = act['title'] ?? 'Untitled';

    // Stagger animation
    final startDelay = (index * 0.06).clamp(0.0, 0.6);
    final endDelay = (startDelay + 0.4).clamp(0.0, 1.0);

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: Interval(startDelay, endDelay, curve: Curves.easeOutCubic),
      ),
    );

    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: Interval(startDelay, endDelay, curve: Curves.easeOut),
      ),
    );

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: GestureDetector(
          onTap: () => _selectAct(Map<String, dynamic>.from(act)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: domainColor.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Accent Stripe
                    Container(
                      height: 4.h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            domainColor,
                            domainColor.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),

                    // Card Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon + Badge Row
                            Row(
                              children: [
                                // Domain Icon
                                Container(
                                  padding: EdgeInsets.all(10.r),
                                  decoration: BoxDecoration(
                                    color: domainColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color:
                                          domainColor.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Icon(
                                    domainIcon,
                                    color: domainColor,
                                    size: 20,
                                  ),
                                ),
                                const Spacer(),
                                if (hasPdf)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626)
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.picture_as_pdf_rounded,
                                          color: Color(0xFFDC2626),
                                          size: 12,
                                        ),
                                        SizedBox(width: 3.w),
                                        Text(
                                          'PDF',
                                          style: TextStyle(
                                            color: Color(0xFFDC2626),
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            const Spacer(),

                            // Short Title (large, bold)
                            if (shortTitle.isNotEmpty)
                              Text(
                                shortTitle,
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            SizedBox(height: 4.h),

                            // Full Title
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 11.sp,
                                height: 1.4.h,
                                fontWeight: FontWeight.w400,
                              ),
                            ),

                            SizedBox(height: 10.h),

                            // Bottom: Category + Arrow
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: domainColor.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      color: domainColor,
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: domainColor.withValues(alpha: 0.5),
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
          ),
        ),
      ),
    );
  }

  // ─── Empty State ─────────────────────────────────────────────
  Widget _buildEmptyState() {
    final isFiltered = _selectedCategory != 'All';
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60.h, horizontal: 32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(28.r),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered
                    ? Icons.filter_list_rounded
                    : Icons.auto_stories_outlined,
                size: 48,
                color: AppTheme.accent.withValues(alpha: 0.35),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              isFiltered ? 'No Statutes in Category' : 'No Statutes Yet',
              style: const TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              isFiltered
                  ? 'Try selecting a different category above'
                  : 'Upload bare acts from the admin dashboard',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textMuted, fontSize: 13.sp),
            ),
            if (isFiltered) ...[
              SizedBox(height: 20.h),
              TextButton(
                onPressed: () => setState(() => _selectedCategory = 'All'),
                child: const Text(
                  'Show All Statutes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // READER VIEW — Premium Section Reader
  // ═══════════════════════════════════════════════════════════════
  Widget _buildReaderView() {
    String? currentChapter;
    final hasPdf = _selectedAct!['pdf_url'] != null &&
        _selectedAct!['pdf_url'].toString().isNotEmpty;
    final hasSections = _sections.isNotEmpty;
    final sectionLabel = _getSectionLabel(_selectedAct);
    final category = _getCategoryForAct(_selectedAct);
    final domainColor = _getDomainColor(category);

    return Scaffold(
      backgroundColor: _readerBg,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Collapsible AppBar ──
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                ),
              ),
              onPressed: () => setState(() {
                _selectedAct = null;
                _staggerController.reset();
                _staggerController.forward();
              }),
            ),
            actions: [
              if (hasPdf)
                Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: TextButton.icon(
                    onPressed: _openPdf,
                    icon: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: const Text(
                      'Open PDF',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.sp,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    // Subtle orb
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Container(
                        width: 120.w,
                        height: 120.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              domainColor.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(56, 0, 16, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: domainColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: TextStyle(
                                color: domainColor,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          // Short title
                          Text(
                            _selectedAct!['short_title'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          // Full title
                          Text(
                            _selectedAct!['title'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w400,
                              height: 1.4.h,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              titlePadding: EdgeInsets.zero,
              title: const SizedBox.shrink(),
            ),
          ),

          // ── Search Bar ──
          if (hasSections)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    fontSize: 14.sp,
                    color: _textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Search ${sectionLabel.toLowerCase()}s or keywords...',
                    hintStyle: const TextStyle(
                      color: _textMuted,
                      fontSize: 14.sp,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _textMuted,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              size: 18,
                              color: _textMuted,
                            ),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: _cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.r),
                      borderSide: const BorderSide(color: _borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.r),
                      borderSide: const BorderSide(color: _borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.r),
                      borderSide: BorderSide(
                        color: domainColor,
                        width: 1.5.w,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                ),
              ),
            ),

          // ── Section count indicator ──
          if (hasSections)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '${_filteredSections.length} ${sectionLabel.toLowerCase()}${_filteredSections.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_searchController.text.isNotEmpty) ...[
                      SizedBox(width: 6.w),
                      Container(
                        width: 4.w,
                        height: 4.h,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _textMuted,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'filtered',
                        style: TextStyle(
                          color: domainColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // ── Content Area ──
          if (_isLoadingSections)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 32.w,
                      height: 32.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppTheme.accent,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Loading sections...',
                      style: TextStyle(color: _textMuted, fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
            )
          else if (!hasSections && hasPdf)
            _buildPdfOnlyState()
          else if (!hasSections && !hasPdf)
            _buildComingSoonState()
          else
            // Sections List
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final section = _filteredSections[index];
                  final chapterNo = section['chapter_number'];
                  final chapterTitle = section['chapter_title'];

                  bool showChapterHeader = false;
                  if (_searchController.text.isEmpty &&
                      currentChapter != chapterNo) {
                    showChapterHeader = true;
                    currentChapter = chapterNo;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showChapterHeader &&
                          chapterNo != null &&
                          chapterNo.toString().isNotEmpty) ...[
                        if (index > 0) SizedBox(height: 24.h),
                        _buildChapterDivider(
                          chapterNo.toString(),
                          chapterTitle?.toString(),
                          domainColor,
                        ),
                        SizedBox(height: 14.h),
                      ],
                      _buildSectionCard(
                        section,
                        index,
                        sectionLabel,
                        domainColor,
                      ),
                    ],
                  );
                }, childCount: _filteredSections.length),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Chapter Divider ─────────────────────────────────────────
  Widget _buildChapterDivider(
    String chapterNo,
    String? chapterTitle,
    Color domainColor,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 36.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [domainColor, domainColor.withValues(alpha: 0.4)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHAPTER $chapterNo',
                  style: TextStyle(
                    color: domainColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.sp,
                    letterSpacing: 2.0,
                  ),
                ),
                if (chapterTitle != null && chapterTitle.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 5.h),
                    child: Text(
                      chapterTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.sp,
                        height: 1.3.h,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Card ────────────────────────────────────────────
  Widget _buildSectionCard(
    dynamic section,
    int index,
    String sectionLabel,
    Color domainColor,
  ) {
    final isExpanded = _expandedSections.contains(index);
    final sectionNumber = section['section_number'] ?? '—';
    final sectionTitle = section['section_title'] ?? '';
    final sectionText = section['section_text'] ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: GestureDetector(
        onTap: () => _toggleSection(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isExpanded
                  ? domainColor.withValues(alpha: 0.25)
                  : _borderColor,
              width: isExpanded ? 1.5 : 1.0,
            ),
            boxShadow: isExpanded
                ? [
                    BoxShadow(
                      color: domainColor.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section number badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: domainColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: domainColor.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        '$sectionLabel $sectionNumber',
                        style: TextStyle(
                          color: domainColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    // Section title
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 2.h),
                        child: Text(
                          sectionTitle,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.sp,
                            height: 1.4.h,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // Expand indicator
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: isExpanded ? domainColor : _textMuted,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),

              // Expanded content
              AnimatedCrossFade(
                firstChild: SizedBox(width: double.infinity, height: 0.h),
                secondChild: _buildExpandedSectionContent(
                  sectionText,
                  sectionLabel,
                  sectionNumber.toString(),
                  sectionTitle,
                  domainColor,
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
                firstCurve: Curves.easeInOut,
                secondCurve: Curves.easeInOut,
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedSectionContent(
    String text,
    String sectionLabel,
    String sectionNumber,
    String sectionTitle,
    Color domainColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Divider
        Container(
          margin: EdgeInsets.symmetric(horizontal: 14.w),
          height: 1.h,
          color: _borderColor,
        ),

        // Text content
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(18.r),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: _borderColor.withValues(alpha: 0.5)),
            ),
            child: SelectableText(
              text,
              style: const TextStyle(
                fontSize: 14.sp,
                height: 1.85.h,
                color: _textSecondary,
                letterSpacing: 0.15,
              ),
            ),
          ),
        ),

        // Action bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Row(
            children: [
              // Copy section text
              _buildActionButton(
                Icons.copy_rounded,
                'Copy Text',
                () => _copyToClipboard(
                  text,
                  '$sectionLabel $sectionNumber',
                ),
                domainColor,
              ),
              SizedBox(width: 8.w),
              // Copy full reference
              _buildActionButton(
                Icons.format_quote_rounded,
                'Copy Ref',
                () => _copyToClipboard(
                  '$sectionLabel $sectionNumber — $sectionTitle\n\n$text',
                  'Reference',
                ),
                domainColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onTap,
    Color color,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(width: 5.w),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PDF Only State ──────────────────────────────────────────
  Widget _buildPdfOnlyState() {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 48,
                  color: Color(0xFFDC2626),
                ),
              ),
              SizedBox(height: 24.h),
              const Text(
                'PDF Available',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              const Text(
                'This statute is available as a PDF.\nSection-wise search will be available\nwhen sections are uploaded.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textMuted,
                  height: 1.6.h,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 28.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openPdf,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(
                    'Open Full PDF',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.sp),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Coming Soon State ───────────────────────────────────────
  Widget _buildComingSoonState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hourglass_empty_rounded,
                size: 48,
                color: AppTheme.accent.withValues(alpha: 0.4),
              ),
            ),
            SizedBox(height: 20.h),
            const Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            const Text(
              'Sections for this act will be uploaded soon.',
              style: TextStyle(color: _textMuted, fontSize: 13.sp),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SEARCH OVERLAY — Command Palette (⌘K)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSearchOverlay() {
    return AnimatedBuilder(
      animation: _overlayController,
      builder: (context, _) {
        if (_overlayController.value == 0 && !_showSearchOverlay) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            // Backdrop blur
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSearchOverlay,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 12 * _overlayController.value,
                    sigmaY: 12 * _overlayController.value,
                  ),
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: 0.35 * _overlayController.value,
                    ),
                  ),
                ),
              ),
            ),

            // Search Panel
            SafeArea(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _overlayController,
                  curve: Curves.easeOut,
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.03),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _overlayController,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Search Card
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(24.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Search Input
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 6, 8, 0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search_rounded,
                                    color: _textMuted,
                                    size: 22,
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: TextField(
                                      controller: _globalSearchController,
                                      autofocus: true,
                                      style: const TextStyle(
                                        color: _textPrimary,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Search sections, titles, keywords...',
                                        hintStyle: TextStyle(
                                          color: _textMuted,
                                          fontSize: 15.sp,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            EdgeInsets.symmetric(vertical: 14.h),
                                      ),
                                      onChanged: (value) {
                                        setState(() {});
                                        if (value.length >= 2) {
                                          _globalSearch(value);
                                        } else {
                                          setState(
                                            () => _globalSearchResults = [],
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  if (_globalSearchController.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        color: _textMuted,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _globalSearchController.clear();
                                        setState(
                                          () => _globalSearchResults = [],
                                        );
                                      },
                                    ),
                                  IconButton(
                                    icon: Container(
                                      padding: EdgeInsets.all(4.r),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: _textSecondary,
                                        size: 18,
                                      ),
                                    ),
                                    onPressed: _closeSearchOverlay,
                                  ),
                                ],
                              ),
                            ),

                            // Divider
                            const Divider(color: _borderColor, height: 1.h),

                            // Filter Chips
                            Container(
                              height: 52.h,
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                children: [
                                  _buildSearchFilterChip(null, 'All Acts'),
                                  ..._acts.map(
                                    (act) => _buildSearchFilterChip(
                                      act['id'],
                                      act['short_title'] ?? act['title'],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Results
                      Expanded(
                        child: _isSearchingGlobal
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 48.h),
                                  child: SizedBox(
                                    width: 28.w,
                                    height: 28.h,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                ),
                              )
                            : _globalSearchResults.isEmpty
                                ? _buildSearchEmptyState()
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      24,
                                    ),
                                    itemCount: _globalSearchResults.length,
                                    itemBuilder: (context, index) {
                                      final result =
                                          _globalSearchResults[index];
                                      final actInfo = result['bare_acts'];
                                      return _buildSearchResultCard(
                                        result,
                                        actInfo,
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: 48.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _globalSearchController.text.isEmpty
                  ? Icons.manage_search_rounded
                  : Icons.search_off_rounded,
              size: 52,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            SizedBox(height: 16.h),
            Text(
              _globalSearchController.text.isEmpty
                  ? 'Search for any section or keyword'
                  : 'No results found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_globalSearchController.text.isEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                'Try "Art 14", "Section 302", or "right to life"',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12.sp,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Search Result Card ──────────────────────────────────────
  Widget _buildSearchResultCard(dynamic result, dynamic actInfo) {
    final actShortTitle = actInfo?['short_title'] ?? 'Unknown Act';
    final sectionLabel = _getSectionLabel(actInfo);
    final sectionNumber = result['section_number'] ?? '—';
    final sectionTitle = result['section_title'] ?? '';
    final sectionText = result['section_text'] ?? '';

    String category = 'Special';
    if (actInfo != null) {
      category = _getCategoryForAct(actInfo);
    }
    final domainColor = _getDomainColor(category);

    return GestureDetector(
      onTap: () async {
        if (actInfo == null) return;
        _closeSearchOverlay();
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) {
          await _selectAct(Map<String, dynamic>.from(actInfo));
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Act Badge Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: domainColor.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                ),
                border: Border(
                  bottom: BorderSide(color: _borderColor.withValues(alpha: 0.5)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getDomainIcon(category),
                    color: domainColor,
                    size: 14,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    actShortTitle,
                    style: TextStyle(
                      color: domainColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.sp,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: domainColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      '$sectionLabel $sectionNumber',
                      style: TextStyle(
                        color: domainColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Section Content
            Padding(
              padding: EdgeInsets.all(14.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sectionTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp,
                      color: _textPrimary,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    sectionText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 13.sp,
                      height: 1.5.h,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Text(
                        'Tap to view full act',
                        style: TextStyle(
                          color: domainColor.withValues(alpha: 0.6),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 12,
                        color: domainColor.withValues(alpha: 0.6),
                      ),
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

  // ─── Search Filter Chip ──────────────────────────────────────
  Widget _buildSearchFilterChip(String? id, String label) {
    final isSelected = _selectedSearchActId == id;
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedSearchActId = id);
          if (_globalSearchController.text.isNotEmpty) {
            _globalSearch(_globalSearchController.text);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isSelected ? AppTheme.accent : _borderColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : _textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12.sp,
            ),
          ),
        ),
      ),
    );
  }
}
