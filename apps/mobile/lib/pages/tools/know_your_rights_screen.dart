import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import 'know_your_rights_data.dart';

class KnowYourRightsScreen extends StatefulWidget {
  const KnowYourRightsScreen({super.key});

  @override
  State<KnowYourRightsScreen> createState() => _KnowYourRightsScreenState();
}

class _KnowYourRightsScreenState extends State<KnowYourRightsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryId = 'all';
  String? _expandedCardId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _shareCard(LaymanCard card) {
    final textToShare = '''
⚖️ KNOW YOUR RIGHTS — CASEFLOW ⚖️

📚 ${card.title.toUpperCase()}
📖 Law/Statute: ${card.sectionOrStatute}

💡 WHAT IS THE LAW?
${card.coreLaw}

🔍 WHEN DOES IT APPLY?
${card.whenItApplies}

🛡️ IMMEDIATE REMEDIES & ACTIONS:
${card.immediateRemedy}

📞 Emergency/Helplines:
${card.contactInfo}

CaseFlow Legal Encyclopedia — Empowering Every Indian with Law.
''';

    Clipboard.setData(ClipboardData(text: textToShare));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('Rights card copied to clipboard! Share it with others. 🔗'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter logic
    final filteredCards =
        KnowYourRightsData.cards.where((card) {
          final matchesCategory =
              _selectedCategoryId == 'all' ||
              card.categoryId == _selectedCategoryId;

          final query = _searchQuery.toLowerCase();
          final matchesSearch =
              card.title.toLowerCase().contains(query) ||
              card.sectionOrStatute.toLowerCase().contains(query) ||
              card.coreLaw.toLowerCase().contains(query) ||
              card.whenItApplies.toLowerCase().contains(query) ||
              card.immediateRemedy.toLowerCase().contains(query);

          return matchesCategory && matchesSearch;
        }).toList();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0F172A) : AppTheme.accent,
        foregroundColor: Colors.white,
        title: Text(
          'Know Your Rights',
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      backgroundColor:
                          isDark ? const Color(0xFF1E293B) : Colors.white,
                      title: Text(
                        'About Legal Encyclopedia',
                        style: GoogleFonts.playfairDisplay(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      content: Text(
                        'Our mission is to translate complex legal statutes into simple, bite-sized summaries that any Indian layman can easily read, understand, and use to protect their rights in everyday life.',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                          height: 1.5,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Got it',
                            style: TextStyle(color: Color(0xFFD4AF37)),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // ── Header Banner ──
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFF9A7B1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💡 Everyday Legal Hub',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'We explain complex statutes as if talking to a 10-year-old. Get remedies, helpline contacts, and share cards instantly.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Search Bar ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                            : null,
                    hintText: 'Search laws, rights, or remedies...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey[400],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // ── Horizontal Categories chips ──
          SliverToBoxAdapter(
            child: SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                itemCount: KnowYourRightsData.categories.length + 1,
                itemBuilder: (ctx, index) {
                  if (index == 0) {
                    final isSelected = _selectedCategoryId == 'all';
                    return _buildCategoryChip(
                      isSelected: isSelected,
                      title: 'All Guides',
                      icon: '⚖️',
                      gradient:
                          isSelected
                              ? [
                                const Color(0xFFD4AF37),
                                const Color(0xFFB5942B),
                              ]
                              : [Colors.grey[800]!, Colors.grey[700]!],
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = 'all';
                        });
                      },
                    );
                  }

                  final cat = KnowYourRightsData.categories[index - 1];
                  final isSelected = _selectedCategoryId == cat.id;
                  return _buildCategoryChip(
                    isSelected: isSelected,
                    title: cat.title,
                    icon: cat.icon,
                    gradient:
                        isSelected
                            ? cat.gradient
                            : [Colors.grey[800]!, Colors.grey[700]!],
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = cat.id;
                      });
                    },
                  );
                },
              ),
            ),
          ),

          // ── Empty State ──
          if (filteredCards.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.find_in_page_rounded,
                        size: 64,
                        color: isDark ? Colors.white30 : Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Guides Found',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try tweaking your search keywords or choosing a different category.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Layman Cards List ──
          if (filteredCards.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((ctx, index) {
                  final card = filteredCards[index];
                  final isExpanded = _expandedCardId == card.id;

                  return _buildLaymanCardWidget(card, isExpanded, isDark);
                }, childCount: filteredCards.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required bool isSelected,
    required String title,
    required String icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected ? LinearGradient(colors: gradient) : null,
              color:
                  isSelected
                      ? null
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color:
                    isSelected
                        ? Colors.transparent
                        : (isDark ? Colors.white10 : Colors.black12),
              ),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: gradient[0].withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color:
                        isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLaymanCardWidget(LaymanCard card, bool isExpanded, bool isDark) {
    // Get category gradient for accent matching
    final category = KnowYourRightsData.categories.firstWhere(
      (c) => c.id == card.categoryId,
      orElse:
          () => const RightsCategory(
            id: 'other',
            title: 'Other',
            icon: '⚖️',
            gradient: [Color(0xFFD4AF37), Color(0xFFB5942B)],
          ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isExpanded
                  ? category.gradient[0].withOpacity(0.3)
                  : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          width: isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isExpanded ? 0.08 : 0.02),
            blurRadius: isExpanded ? 12 : 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedCardId = expanded ? card.id : null;
            });
          },
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: category.gradient),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(category.icon, style: const TextStyle(fontSize: 18)),
            ),
          ),
          title: Text(
            card.title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            card.sectionOrStatute,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFD4AF37), // Gold accent
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 20,
                top: 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white10, height: 16),
                  const SizedBox(height: 8),

                  // ── Pillar 1: What is the Law? ──
                  _buildSubSection(
                    title: '💡 IN SIMPLE TERMS (THE LAW)',
                    content: card.coreLaw,
                    accentColor: const Color(0xFF2563EB), // Blue
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // ── Pillar 2: When it applies? ──
                  _buildSubSection(
                    title: '🔍 WHEN DOES IT APPLY?',
                    content: card.whenItApplies,
                    accentColor: const Color(0xFF10B981), // Teal/Green
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // ── Pillar 3: Immediate Remedy ──
                  _buildSubSection(
                    title: '🛡️ YOUR IMMEDIATE REMEDY',
                    content: card.immediateRemedy,
                    accentColor: const Color(0xFFF97316), // Orange
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // ── Helpline contact details ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF0F172A).withOpacity(0.4)
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isDark
                                ? Colors.white10
                                : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.support_agent_rounded,
                          size: 20,
                          color: Color(0xFFD4AF37),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Emergency Contacts & Helplines',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                card.contactInfo,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Bottom Action row ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _shareCard(card),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: Text(
                          'Copy & Share Card',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  Widget _buildSubSection({
    required String title,
    required String content,
    required Color accentColor,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accentColor,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                isDark
                    ? const Color(0xFF0F172A).withOpacity(0.3)
                    : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isDark
                      ? Colors.white.withOpacity(0.03)
                      : Colors.black.withOpacity(0.03),
            ),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color:
                  isDark
                      ? Colors.white.withOpacity(0.85)
                      : Colors.black.withOpacity(0.75),
            ),
          ),
        ),
      ],
    );
  }
}
