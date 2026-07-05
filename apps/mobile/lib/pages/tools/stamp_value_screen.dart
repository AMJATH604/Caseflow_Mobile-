import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StampValueScreen extends ConsumerStatefulWidget {
  const StampValueScreen({super.key});

  @override
  ConsumerState<StampValueScreen> createState() => _StampValueScreenState();
}

class _StampValueScreenState extends ConsumerState<StampValueScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _allStamps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStamps();
  }

  Future<void> _loadStamps() async {
    try {
      final stamps = await SupabaseService.fetchStampValues();
      if (mounted) {
        setState(() {
          _allStamps = stamps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load stamps: $e')));
      }
    }
  }

  static const List<String> _categories = [
    'All',
    'Civil',
    'Criminal',
    'Documents',
    'Appeals',
  ];

  static const Map<String, Color> _categoryColors = {
    'Civil': Color(0xFF3B82F6),
    'Criminal': Color(0xFFEF4444),
    'Documents': Color(0xFF10B981),
    'Appeals': Color(0xFF8B5CF6),
  };

  static const Map<String, IconData> _iconMap = {
    'event_busy': Icons.event_busy,
    'edit_document': Icons.edit_document,
    'description': Icons.description,
    'shield': Icons.shield,
    'reply_all': Icons.reply_all,
    'find_replace': Icons.find_replace,
    'restore': Icons.restore,
    'pause_circle': Icons.pause_circle,
    'swap_horiz': Icons.swap_horiz,
    'gavel': Icons.gavel,
    'play_arrow': Icons.play_arrow,
    'rate_review': Icons.rate_review,
    'assignment': Icons.assignment,
    'lock_open': Icons.lock_open,
    'security': Icons.security,
    'cancel': Icons.cancel,
    'report': Icons.report,
    'access_time': Icons.access_time,
    'folder_special': Icons.folder_special,
    'person_pin': Icons.person_pin,
    'content_copy': Icons.content_copy,
    'bolt': Icons.bolt,
    'verified': Icons.verified,
    'receipt_long': Icons.receipt_long,
    'fact_check': Icons.fact_check,
    'account_balance': Icons.account_balance,
    'approval': Icons.approval,
    'file_copy': Icons.file_copy,
    'balance': Icons.balance,
    'upload': Icons.upload,
    'copyright': Icons.copyright,
  };

  List<Map<String, dynamic>> get _filteredData {
    return _allStamps.where((item) {
      final matchesCategory =
          _selectedCategory == 'All' || item['category'] == _selectedCategory;
      final matchesSearch =
          _searchQuery.isEmpty ||
          item['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredData;

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search petition type...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]
                      : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16.r),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 14.h),
              suffixIcon:
                  _isLoading
                      ? const Padding(
                        padding: EdgeInsets.all(12.0.r),
                        child: SizedBox(
                          width: 14.w,
                          height: 14.h,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : null,
            ),
          ),
        ),

        // Category Chips
        SizedBox(
          height: 40.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;
              final color = _categoryColors[cat] ?? AppTheme.accent;

              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: FilterChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.sp,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  backgroundColor: color.withValues(alpha: 0.1),
                  selectedColor: color,
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.r),
                    side: BorderSide(color: color.withValues(alpha: 0.3)),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 8.h),

        // Results Count & Refresh
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            children: [
              Text(
                '${filtered.length} items',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                onPressed: _loadStamps,
                color: Colors.grey[400],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              SizedBox(width: 8.w),
              Text(
                'Tamil Nadu Courts',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),

        // Stamp Value List
        Expanded(
          child:
              _isLoading && _allStamps.isEmpty
                  ? _buildSkeletonList()
                  : filtered.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'No petitions found',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16.sp,
                          ),
                        ),
                      ],
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _loadStamps,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final color =
                            _categoryColors[item['category']] ??
                            AppTheme.accent;
                        final iconKey = item['icon_name'] ?? 'description';
                        final icon = _iconMap[iconKey] ?? Icons.description;

                        return Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[800]!
                                      : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 42.w,
                              height: 42.h,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            title: Text(
                              item['name'],
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                              ),
                            ),
                            subtitle: Text(
                              item['category'],
                              style: TextStyle(
                                color: color,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    color.withValues(alpha: 0.15),
                                    color.withValues(alpha: 0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10.r),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                item['value'],
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: 8,
      itemBuilder:
          (context, index) => Container(
            height: 70.h,
            margin: EdgeInsets.only(bottom: 8.h),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.grey[100],
              borderRadius: BorderRadius.circular(14.r),
            ),
          ),
    );
  }
}
