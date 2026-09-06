import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import '../../models/models.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LegalTemplatesScreen extends StatefulWidget {
  const LegalTemplatesScreen({super.key});

  @override
  State<LegalTemplatesScreen> createState() => _LegalTemplatesScreenState();
}

class _LegalTemplatesScreenState extends State<LegalTemplatesScreen>
    with TickerProviderStateMixin {
  List<LegalTemplate> _templates = [];
  String? _selectedCategory;
  List<LegalTemplate> _filteredTemplates = [];
  List<LegalTemplate> _globalSearchResults = [];
  bool _isLoading = true;
  bool _isSearchingGlobal = false;
  bool _showGlobalSearch = false;
  final TextEditingController _globalSearchController = TextEditingController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Category Color palette matching Bare Act style
  static const List<List<Color>> _categoryGradients = [
    [Color(0xFF1E293B), Color(0xFF334155)], // Slate
    [Color(0xFF1A1A2E), Color(0xFF16213E)], // Deep Blue/Navy
    [Color(0xFF0F172A), Color(0xFF1E293B)], // Dark Navy
    [Color(0xFF312E81), Color(0xFF4338CA)], // Indigo
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
    _fetchTemplates();
  }

  @override
  void dispose() {
    _globalSearchController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchTemplates() async {
    try {
      final templates = await SupabaseService.fetchLegalTemplates();
      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterByCategory(String? category) {
    setState(() {
      _selectedCategory = category;
      if (category == null) {
        _filteredTemplates = _templates;
      } else {
        _filteredTemplates =
            _templates.where((t) => t.category == category).toList();
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
      final results = await SupabaseService.searchLegalTemplates(query);
      if (mounted) {
        setState(() {
          _globalSearchResults = results;
          _isSearchingGlobal = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearchingGlobal = false);
    }
  }

  Future<void> _openFile(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open file')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16.h),
              Text(
                'Syncing Template Library...',
                style: TextStyle(color: Colors.grey, fontSize: 14.sp),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedCategory != null) {
      return _buildCategoryTemplatesView();
    }

    return _showGlobalSearch
        ? _buildGlobalSearchView()
        : _buildCategorySelector();
  }

  Widget _buildCategorySelector() {
    final categories = _templates.map((t) => t.category).toSet().toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeroHeader()),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 4.w,
                      height: 20.h,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Template Categories',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            categories.isEmpty
                ? SliverToBoxAdapter(child: _buildEmptyState())
                : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildCategoryCard(categories[index], index),
                      childCount: categories.length,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      margin: EdgeInsets.all(16.r),
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Template Library',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Professional Drafting Resources',
                      style: TextStyle(color: Colors.white70, fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          GestureDetector(
            onTap: () => setState(() => _showGlobalSearch = true),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Search templates by name...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14.sp,
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

  Widget _buildCategoryCard(String category, int index) {
    final gradient = _categoryGradients[index % _categoryGradients.length];
    final count = _templates.where((t) => t.category == category).length;

    return GestureDetector(
      onTap: () => _filterByCategory(category),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.folder_shared_rounded,
                color: AppTheme.primary,
                size: 28,
              ),
              Spacer(),
              Text(
                category,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$count templates',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTemplatesView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _selectedCategory!.toUpperCase(),
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => _filterByCategory(null),
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16.r),
        itemCount: _filteredTemplates.length,
        itemBuilder:
            (context, index) => _buildTemplateCard(_filteredTemplates[index]),
      ),
    );
  }

  Widget _buildGlobalSearchView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
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
        title: Text(
          'Search Templates',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17.sp),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.r),
            color: const Color(0xFF1E293B),
            child: TextField(
              controller: _globalSearchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Keyword search...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                contentPadding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              onChanged: _globalSearch,
            ),
          ),
          Expanded(
            child:
                _isSearchingGlobal
                    ? const Center(child: CircularProgressIndicator())
                    : _globalSearchResults.isEmpty
                    ? const Center(child: Text('No templates found'))
                    : ListView.builder(
                      padding: EdgeInsets.all(16.r),
                      itemCount: _globalSearchResults.length,
                      itemBuilder:
                          (context, index) =>
                              _buildTemplateCard(_globalSearchResults[index]),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(LegalTemplate template) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.insert_drive_file_outlined,
                  color: Colors.blueGrey,
                  size: 20,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    template.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.sp,
                    ),
                  ),
                ),
              ],
            ),
            if (template.description != null) ...[
              SizedBox(height: 6.h),
              Text(
                template.description!,
                style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
              ),
            ],
            SizedBox(height: 16.h),
            Row(
              children: [
                if (template.pdfUrl != null)
                  _fileButton(
                    'PDF',
                    Icons.picture_as_pdf,
                    Colors.red[700]!,
                    () => _openFile(template.pdfUrl),
                  ),
                SizedBox(width: 8.w),
                if (template.docxUrl != null)
                  _fileButton(
                    'WORD',
                    Icons.description,
                    Colors.blue[800]!,
                    () => _openFile(template.docxUrl),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60.h),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[300]),
            SizedBox(height: 12.h),
            Text(
              'No templates found in library.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
