import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';

class BareActsLibraryScreen extends StatefulWidget {
  const BareActsLibraryScreen({super.key});

  @override
  State<BareActsLibraryScreen> createState() => _BareActsLibraryScreenState();
}

class _BareActsLibraryScreenState extends State<BareActsLibraryScreen>
    with TickerProviderStateMixin {
  List<dynamic> _acts = [];
  Map<String, dynamic>? _selectedAct;
  List<dynamic> _sections = [];
  List<dynamic> _filteredSections = [];
  List<dynamic> _globalSearchResults = [];
  bool _isLoading = true;
  bool _isLoadingSections = false;
  bool _isSearchingGlobal = false;
  bool _showGlobalSearch = false;
  String? _selectedSearchActId;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _globalSearchController = TextEditingController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();

  // Color palette for act cards
  static const List<List<Color>> _cardGradients = [
    [Color(0xFF1A237E), Color(0xFF3949AB)], // Deep Blue
    [Color(0xFF880E4F), Color(0xFFAD1457)], // Deep Pink
    [Color(0xFF004D40), Color(0xFF00695C)], // Teal
    [Color(0xFFE65100), Color(0xFFF57C00)], // Deep Orange
    [Color(0xFF4A148C), Color(0xFF7B1FA2)], // Purple
    [Color(0xFF1B5E20), Color(0xFF2E7D32)], // Green
    [Color(0xFFBF360C), Color(0xFFE64A19)], // Red Orange
    [Color(0xFF0D47A1), Color(0xFF1976D2)], // Blue
  ];

  static const List<IconData> _actIcons = [
    Icons.gavel_rounded,
    Icons.balance_rounded,
    Icons.policy_rounded,
    Icons.menu_book_rounded,
    Icons.account_balance_rounded,
    Icons.shield_rounded,
    Icons.description_rounded,
    Icons.library_books_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fetchActs();
    _searchController.addListener(_filterSections);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _globalSearchController.dispose();
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchActs() async {
    try {
      final acts = await SupabaseService.fetchBareActs();
      if (mounted) {
        setState(() {
          _acts = acts;
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      debugPrint("Error fetching acts: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectAct(Map<String, dynamic> act) async {
    setState(() {
      _selectedAct = act;
      _isLoadingSections = true;
      _sections = [];
      _filteredSections = [];
      _searchController.clear();
      _showGlobalSearch = false;
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
      debugPrint("Error fetching sections: $e");
      if (mounted) setState(() => _isLoadingSections = false);
    }
  }

  void _filterSections() {
    final query = _searchController.text.toLowerCase().trim();
    // Normalize query by removing common prefixes to match section/article numbers
    final cleanQuery =
        query
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
        _filteredSections =
            _sections.where((section) {
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
      debugPrint("Global search error: $e");
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Could not open PDF")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text(
                "Loading Legal Library...",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedAct != null) {
      return _buildSectionsView();
    }

    return _showGlobalSearch ? _buildGlobalSearchView() : _buildActSelector();
  }

  // ─── Act Selector Grid ──────────────────────────────────────
  Widget _buildActSelector() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // Hero Header
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A1A2E).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.library_books_rounded,
                            color: Color(0xFF1E293B),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Legal Library",
                                style: TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Browse & Search Indian Statutes",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Global Search Button
                    GestureDetector(
                      onTap: () => setState(() => _showGlobalSearch = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Search across all acts...",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 14,
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

            // Stats Row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    _buildStatChip(
                      Icons.book_rounded,
                      "${_acts.length}",
                      "Statutes",
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(Icons.article_rounded, "—", "Sections"),
                  ],
                ),
              ),
            ),

            // Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Available Statutes",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Acts Grid
            _acts.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyState())
                : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildActCard(_acts[index], index),
                      childCount: _acts.length,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActCard(dynamic act, int index) {
    final gradient = _cardGradients[index % _cardGradients.length];
    final icon = _actIcons[index % _actIcons.length];
    final hasPdf =
        act['pdf_url'] != null && act['pdf_url'].toString().isNotEmpty;
    final shortTitle = act['short_title'] ?? '';
    final title = act['title'] ?? 'Untitled';

    return GestureDetector(
      onTap: () => _selectAct(act),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background Pattern
            Positioned(
              right: -15,
              bottom: -15,
              child: Icon(
                icon,
                size: 80,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon + Badge Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: const Color(0xFF1E293B),
                          size: 22,
                        ),
                      ),
                      if (hasPdf)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Color(0xFF1E293B),
                                size: 12,
                              ),
                              SizedBox(width: 3),
                              Text(
                                "PDF",
                                style: TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const Spacer(),

                  // Short Title
                  if (shortTitle.isNotEmpty)
                    Text(
                      shortTitle,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  const SizedBox(height: 4),

                  // Full Title
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Bottom Indicator
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 12,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.library_books_outlined,
                size: 48,
                color: AppTheme.primary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "No Statutes Yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Upload bare acts from the admin dashboard",
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Global Search View ─────────────────────────────────────
  Widget _buildGlobalSearchView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed:
              () => setState(() {
                _showGlobalSearch = false;
                _globalSearchResults = [];
                _globalSearchController.clear();
              }),
        ),
        title: const Text(
          "Search All Acts",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          // Search Input & Filters
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
            child: Column(
              children: [
                TextField(
                  controller: _globalSearchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "Search sections, titles, or keywords...",
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    suffixIcon:
                        _globalSearchController.text.isNotEmpty
                            ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 20,
                              ),
                              onPressed: () {
                                _globalSearchController.clear();
                                setState(() => _globalSearchResults = []);
                              },
                            )
                            : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (value) {
                    if (value.length >= 2) {
                      _globalSearch(value);
                    } else {
                      setState(() => _globalSearchResults = []);
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Act Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(null, "All Acts"),
                      ..._acts.map(
                        (act) => _buildFilterChip(
                          act['id'],
                          act['short_title'] ?? act['title'],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // Results
          Expanded(
            child:
                _isSearchingGlobal
                    ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                    : _globalSearchResults.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 56,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _globalSearchController.text.isEmpty
                                ? "Search for any section or keyword"
                                : "No results found",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _globalSearchResults.length,
                      itemBuilder: (context, index) {
                        final result = _globalSearchResults[index];
                        final actInfo = result['bare_acts'];
                        return _buildSearchResultCard(result, actInfo);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(dynamic result, dynamic actInfo) {
    return GestureDetector(
      onTap: () async {
        if (actInfo == null) return;

        // 1. Exit search
        setState(() {
          _showGlobalSearch = false;
          _globalSearchController.clear();
          _globalSearchResults = [];
        });

        // 2. Load the specific act
        await _selectAct(actInfo);

        // 3. Optional: Scroll to the specific section if needed
        // (Since we don't have exact index before fetch, we just open the act)
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Act Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.book_rounded, color: Colors.amber, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    actInfo?['short_title'] ?? 'Unknown Act',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${(actInfo?['short_title']?.toString().toLowerCase().contains('constitution') ?? false) ? 'Art' : 'Sec'} ${result['section_number'] ?? '—'}",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Section Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result['section_title'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result['section_text'] ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      height: 1.5,
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

  // ─── Sections View ──────────────────────────────────────────
  Widget _buildSectionsView() {
    String? currentChapter;
    final hasPdf =
        _selectedAct!['pdf_url'] != null &&
        _selectedAct!['pdf_url'].toString().isNotEmpty;
    final hasSections = _sections.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          // Collapsible AppBar
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A2E),
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _selectedAct = null),
            ),
            actions: [
              if (hasPdf)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    onPressed: _openPdf,
                    icon: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFF1E293B),
                      size: 18,
                    ),
                    label: const Text(
                      "PDF",
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedAct!['short_title'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedAct!['title'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              title: const SizedBox.shrink(),
            ),
          ),

          // Search Bar (only if sections exist)
          if (hasSections)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search sections or keywords...",
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    suffixIcon:
                        _searchController.text.isNotEmpty
                            ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                size: 18,
                                color: Colors.grey[400],
                              ),
                              onPressed: () => _searchController.clear(),
                            )
                            : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

          // Content Area
          if (_isLoadingSections)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
            )
          else if (!hasSections && hasPdf)
            // PDF-only act — no sections uploaded yet
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 48,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "PDF Available",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "This statute is available as a PDF.\nSection-wise search will be available when sections are uploaded.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _openPdf,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text(
                            "Open Full PDF",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A1A2E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (!hasSections && !hasPdf)
            // No sections AND no PDF
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.hourglass_empty_rounded,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Coming Soon",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Sections for this act will be uploaded soon.",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          else
            // Sections List
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                        if (index > 0) const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "CHAPTER $chapterNo",
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                    if (chapterTitle != null &&
                                        chapterTitle.toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          chapterTitle.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Section Card
                      _buildSectionCard(section),
                    ],
                  );
                }, childCount: _filteredSections.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(dynamic section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF334155)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  "${(_selectedAct?['short_title']?.toString().toLowerCase().contains('constitution') ?? false) ? 'Article' : 'Section'} ${section['section_number'] ?? '—'}",
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section['section_title'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: SelectableText(
                section['section_text'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: Color(0xFF334155),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String? id, String label) {
    final isSelected = _selectedSearchActId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        selectedColor: AppTheme.primary,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppTheme.primary : Colors.white24,
          ),
        ),
        onSelected: (selected) {
          setState(() => _selectedSearchActId = id);
          if (_globalSearchController.text.isNotEmpty) {
            _globalSearch(_globalSearchController.text);
          }
        },
      ),
    );
  }
}
