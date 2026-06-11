import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/caveat_models.dart';
import '../services/providers.dart';

import '../theme/app_theme.dart';
import 'dialogs/caveat_form_sheet.dart';

class CaveatsScreen extends ConsumerStatefulWidget {
  const CaveatsScreen({super.key});

  @override
  ConsumerState<CaveatsScreen> createState() => _CaveatsScreenState();
}

class _CaveatsScreenState extends ConsumerState<CaveatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _filters = ['Active', 'Expiring Soon', 'Expired'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Caveat> _filter(List<Caveat> all, int tabIndex) {
    if (tabIndex == 2) {
      return all.where((c) => c.isExpired).toList();
    } else if (tabIndex == 1) {
      return all.where((c) => !c.isExpired && c.daysRemaining <= 15).toList();
    } else {
      return all.where((c) => !c.isExpired).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncCaveats = ref.watch(caveatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark, asyncCaveats),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: (_) => setState(() {}),
              indicatorColor: AppTheme.accent,
              labelColor: AppTheme.accent,
              unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
              labelStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: _filters.map((f) => Tab(text: f)).toList(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: asyncCaveats.when(
                data: (caveats) {
                  return AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      final filteredList = _filter(
                        caveats,
                        _tabController.index,
                      );

                      if (filteredList.isEmpty) return _buildEmptyState(isDark);

                      return RefreshIndicator(
                        onRefresh: () async => ref.invalidate(caveatsProvider),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredList.length,
                          itemBuilder:
                              (context, index) =>
                                  _buildCaveatCard(isDark, filteredList[index]),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (e, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.error,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text('Failed to load caveats.'),
                          TextButton(
                            onPressed: () => ref.invalidate(caveatsProvider),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ],
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

  Widget _buildHeader(bool isDark, AsyncValue<List<Caveat>> asyncCaveats) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF97316),
            Color(0xFFEA580C),
          ], // Orange fiery gradient for caveats
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Caveat Tracker',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Track expirations & prevent ex-parte orders',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          asyncCaveats.when(
            data: (list) {
              final active = list.where((c) => !c.isExpired).length;
              final expiring =
                  list
                      .where((c) => !c.isExpired && c.daysRemaining <= 15)
                      .length;
              final expired = list.where((c) => c.isExpired).length;

              return Row(
                children: [
                  _statBadge('Active', '$active', Colors.white),
                  const SizedBox(width: 8),
                  if (expiring > 0)
                    _statBadge(
                      'Exp. Soon',
                      '$expiring',
                      const Color(0xFFFDE047),
                    ), // Yellow
                  if (expiring > 0) const SizedBox(width: 8),
                  _statBadge(
                    'Expired',
                    '$expired',
                    const Color(0xFFFCA5A5),
                  ), // Red tint
                ],
              );
            },
            loading: () => const SizedBox(height: 24),
            error: (_, __) => const SizedBox(height: 24),
          ),
        ],
      ),
    );
  }

  Widget _statBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 48,
              color: AppTheme.accent.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No caveats found',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to file a new caveat',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaveatCard(bool isDark, Caveat caveat) {
    final days = caveat.daysRemaining;
    final isExpired = caveat.isExpired;

    Color badgeColor;
    Color badgeText;
    String badgeLabel;

    if (isExpired) {
      badgeColor = AppTheme.error.withValues(alpha: 0.15);
      badgeText = AppTheme.error;
      badgeLabel = 'EXPIRED';
    } else if (days <= 7) {
      badgeColor = AppTheme.error;
      badgeText = Colors.white;
      badgeLabel = '$days DAYS LEFT';
    } else if (days <= 30) {
      badgeColor = AppTheme.warning;
      badgeText = const Color(0xFF1E293B);
      badgeLabel = '$days DAYS LEFT';
    } else {
      badgeColor = AppTheme.success.withValues(alpha: 0.15);
      badgeText = AppTheme.success;
      badgeLabel = '$days DAYS LEFT';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              days <= 7 && !isExpired
                  ? AppTheme.error.withValues(alpha: 0.5)
                  : (isDark ? const Color(0xFF2D2D3F) : AppTheme.borderLight),
          width: days <= 7 && !isExpired ? 1.5 : 1,
        ),
        boxShadow:
            days <= 7 && !isExpired
                ? [
                  BoxShadow(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCaveatForm(context, caveat: caveat),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        caveat.courtName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color:
                              isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeLabel,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: badgeText,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppTheme.accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Caveator: ',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                            TextSpan(
                              text: caveat.caveatorName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: AppTheme.error.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Opponent: ',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                            TextSpan(
                              text: caveat.opponentName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _dateChip(
                      'Filing',
                      caveat.filingDate,
                      isDark,
                      icon: Icons.calendar_today_outlined,
                    ),
                    const SizedBox(width: 8),
                    _dateChip(
                      'Expiry',
                      caveat.expiryDate,
                      isDark,
                      isCritical: days <= 15 && !isExpired,
                      icon: Icons.timer_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateChip(
    String label,
    DateTime date,
    bool isDark, {
    bool isCritical = false,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            isCritical
                ? AppTheme.error.withValues(alpha: 0.1)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color:
                isCritical
                    ? AppTheme.error
                    : (isDark ? Colors.white54 : Colors.black45),
          ),
          const SizedBox(width: 4),
          Text(
            '$label: ${DateFormat('dd MMM').format(date)}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isCritical ? FontWeight.w600 : FontWeight.w500,
              color:
                  isCritical
                      ? AppTheme.error
                      : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  void _showCaveatForm(BuildContext context, {Caveat? caveat}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CaveatFormSheet(caveat: caveat),
    );
  }
}
