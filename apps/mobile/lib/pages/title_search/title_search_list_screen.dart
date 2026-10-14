import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/title_search_models.dart';
import '../../services/providers.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'title_search_detail_screen.dart';
import 'new_title_search_sheet.dart';

class TitleSearchListScreen extends ConsumerStatefulWidget {
  const TitleSearchListScreen({super.key});

  @override
  ConsumerState<TitleSearchListScreen> createState() => _TitleSearchListScreenState();
}

class _TitleSearchListScreenState extends ConsumerState<TitleSearchListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final searchesAsync = ref.watch(titleSearchesProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Title Chain Inconsistency Detector',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: AppTheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(titleSearchesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewSearchSheet(context),
        backgroundColor: const Color(0xFF0D9488),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'New Title Search',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Banner / Explainer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF0FDFA),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF0D9488), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Property Due-Diligence',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: const Color(0xFF115E59),
                        ),
                      ),
                      Text(
                        'Cross-references 30-yr Sale Deeds, EC, Patta & Legal Heir Certs across 18 legal checks.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: const Color(0xFF134E4A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search Filter Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by Survey No., Village or Party...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Search List
          Expanded(
            child: searchesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Error loading title searches: $err', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(titleSearchesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (searches) {
                final filtered = searches.where((s) {
                  if (_searchQuery.isEmpty) return true;
                  return s.surveyNumber.toLowerCase().contains(_searchQuery) ||
                      s.village.toLowerCase().contains(_searchQuery) ||
                      s.district.toLowerCase().contains(_searchQuery) ||
                      (s.proposedSeller?.toLowerCase().contains(_searchQuery) ?? false) ||
                      (s.proposedBuyer?.toLowerCase().contains(_searchQuery) ?? false);
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) => _buildSearchCard(ctx, filtered[idx]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(BuildContext context, TitleSearch search) {
    Color scoreColor = Colors.grey;
    if (search.healthScore != null) {
      if (search.healthScore! >= 80) scoreColor = const Color(0xFF10B981);
      else if (search.healthScore! >= 60) scoreColor = const Color(0xFFF59E0B);
      else scoreColor = const Color(0xFFEF4444);
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TitleSearchDetailScreen(searchId: search.id),
            ),
          ).then((_) => ref.invalidate(titleSearchesProvider));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          search.displayName,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${search.village}, ${search.taluk}, ${search.district}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (search.healthScore != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: scoreColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: scoreColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${search.healthScore}%',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: scoreColor,
                            ),
                          ),
                          Text(
                            'Health',
                            style: GoogleFonts.inter(fontSize: 9, color: scoreColor),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (search.extent != null)
                    _badge(
                      Icons.square_foot_rounded,
                      '${search.extent} ${search.extentUnit}',
                    ),
                  if (search.proposedSeller != null) ...[
                    const SizedBox(width: 8),
                    _badge(
                      Icons.person_outline_rounded,
                      'Seller: ${search.proposedSeller}',
                    ),
                  ],
                  const Spacer(),
                  if (search.criticalCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            '${search.criticalCount} Red Flags',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (search.status == 'completed')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Clean Chain',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.holiday_village_rounded,
                size: 48,
                color: Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Title Searches Yet',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload a Sale Deed, EC, and Patta to automatically verify the 30-year ownership history.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openNewSearchSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Start Title Due-Diligence',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openNewSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NewTitleSearchSheet(),
    ).then((_) => ref.invalidate(titleSearchesProvider));
  }
}
