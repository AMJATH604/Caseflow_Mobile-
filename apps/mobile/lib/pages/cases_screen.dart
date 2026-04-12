import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/providers.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../components/error_state_widget.dart';
import '../theme/app_theme.dart';

class CasesScreen extends ConsumerStatefulWidget {
  const CasesScreen({super.key});

  @override
  ConsumerState<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends ConsumerState<CasesScreen> {
  String _searchQuery = "";
  String _statusFilter = "all";

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(casesProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          const SizedBox(height: 16),
          _buildSearchAndFilters(isMobile, casesAsync.value ?? []),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              "CLIENT REGISTRY",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black38,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: casesAsync.when(
              data: (cases) => _buildCasesList(isMobile, cases),
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
              error: (err, stack) => ErrorStateWidget(
                error: err,
                onRetry: () => ref.invalidate(casesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Case Archive",
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "CENTRALIZED LEGAL DATABASE",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black38, 
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isMobile, List<CaseModel> cases) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 52,
            decoration: AppTheme.cardDecoration(
              isDark: Theme.of(context).brightness == Brightness.dark,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.surfaceLight
                  : Colors.black.withValues(alpha: 0.03),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: GoogleFonts.inter(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: "Search by title or ID...",
                hintStyle: GoogleFonts.inter(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFCBD5E1)
                        : Colors.black38,
                    fontWeight: FontWeight.w500),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFCBD5E1)
                        : Colors.black38),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ["all", "active", "closed", "pending"].map((s) {
                final isActive = _statusFilter == s;
                final count = s == "all"
                    ? cases.length
                    : cases
                        .where((c) =>
                            c.status.name.toLowerCase() == s.toLowerCase())
                        .length;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _statusFilter = s),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.accent
                            : (Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.secondary
                                : Colors.black.withValues(alpha: 0.03)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isActive
                                ? Colors.transparent
                                : (Theme.of(context).dividerTheme.color ??
                                    Colors.grey)),
                      ),
                      child: Text(
                        "${s.toUpperCase()} ${s == 'all' ? '' : '($count)'}",
                        style: GoogleFonts.inter(
                          color:
                              isActive ? Colors.white : const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCasesList(bool isMobile, List<CaseModel> cases) {
    final filtered = cases.where((c) {
      final matchesSearch = c.caseTitle.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (c.caseNumber ?? "").toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == "all" || c.status.name.toLowerCase() == _statusFilter.toLowerCase();
      return matchesSearch && matchesStatus;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF1F1F2E)),
            const SizedBox(height: 16),
            Text(
              "ARCHIVE EMPTY",
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12, color: const Color(0xFF4B5563), letterSpacing: 1),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final c = filtered[index];
        final statColor = _caseColor(c.status.name);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: AppTheme.cardDecoration(isDark: Theme.of(context).brightness == Brightness.dark),
          child: InkWell(
            onTap: () => context.push('/cases/${c.id}'),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: statColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statColor.withValues(alpha: 0.1)),
                    ),
                    child: Center(
                      child: Icon(Icons.file_copy_rounded, color: statColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text(
                            c.caseTitle,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                (c.caseNumber ?? 'NO ID').toUpperCase(),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black38, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(width: 8),
                              Container(width: 3, height: 3, decoration: BoxDecoration(color: Theme.of(context).dividerTheme.color, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.clientName ?? (c.firmId != null ? "Firm Shared Case" : "Private Entity"),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFCBD5E1) : Colors.black38, fontWeight: FontWeight.w600),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.error),
                    onPressed: () async {
                      final confirmed = await _confirmDeleteCase(c.caseTitle);
                      if (confirmed == true) {
                        await _deleteCase(c.id);
                      }
                    },
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF1F1F2E)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _caseColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return AppTheme.success;
      case 'closed': return AppTheme.error;
      case 'pending': return AppTheme.warning;
      default: return AppTheme.accent;
    }
  }

  Future<bool?> _confirmDeleteCase(String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.secondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Case?"),
        content: Text("Are you sure you want to permanently delete \"$title\" and all related records?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCase(String id) async {
    try {
      await SupabaseService.deleteCase(id);
      ref.invalidate(casesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Case records removed")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }
}
