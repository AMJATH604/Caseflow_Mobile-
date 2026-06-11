import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import 'legal_dictionary_data.dart';

class LegalDictionary extends StatefulWidget {
  const LegalDictionary({super.key});

  @override
  State<LegalDictionary> createState() => _LegalDictionaryState();
}

class _LegalDictionaryState extends State<LegalDictionary> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedLetter = '';
  List<LegalTerm> _filteredTerms = [];
  int? _expandedIndex;

  final List<String> _categories = [
    'All',
    'Latin',
    'Legal English',
    'Criminal',
    'Evidence',
    'Property',
    'Constitutional',
    'Family',
    'Contract',
    'Corporate',
    'Taxation',
    'Cyber',
    'Environmental',
    'Labour',
    'Consumer',
    'Administrative',
    'International',
  ];

  @override
  void initState() {
    super.initState();
    _filteredTerms = List.from(legalTermsData);
    _filteredTerms.sort((a, b) => a.term.compareTo(b.term));
  }

  void _applyFilters() {
    final String query = _searchCtrl.text.toLowerCase();
    setState(() {
      _expandedIndex = null;
      _filteredTerms =
          legalTermsData.where((t) {
            final bool matchesQuery =
                query.isEmpty ||
                t.term.toLowerCase().contains(query) ||
                t.meaning.toLowerCase().contains(query);
            final bool matchesCategory =
                _selectedCategory == 'All' || t.category == _selectedCategory;
            final bool matchesLetter =
                _selectedLetter.isEmpty ||
                t.term.toUpperCase().startsWith(_selectedLetter);
            return matchesQuery && matchesCategory && matchesLetter;
          }).toList();
      _filteredTerms.sort((a, b) => a.term.compareTo(b.term));
    });
  }

  void _copyTerm(LegalTerm t) {
    String text = '${t.term}\n${t.meaning}';
    if (t.usage.isNotEmpty) text += '\n\nUsage: ${t.usage}';
    if (t.section.isNotEmpty) text += '\nRef: ${t.section}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${t.term}" copied!'),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => _applyFilters(),
            decoration: InputDecoration(
              hintText: 'Search terms, e.g. "habeas corpus", "injunction"...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchCtrl.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applyFilters();
                        },
                      )
                      : null,
              filled: true,
              fillColor:
                  isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        // Category chips
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final bool selected = _selectedCategory == _categories[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      _categories[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : null,
                      ),
                    ),
                    selected: selected,
                    selectedColor: AppTheme.accent,
                    onSelected: (_) {
                      setState(() => _selectedCategory = _categories[i]);
                      _applyFilters();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),
        ),

        // A-Z quick index
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _letterChip('', 'All'),
                ...List.generate(
                  26,
                  (i) => _letterChip(
                    String.fromCharCode(65 + i),
                    String.fromCharCode(65 + i),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                '${_filteredTerms.length} terms',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              const Spacer(),
              Text(
                'Tap a term to expand',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
        ),

        // Terms list
        Expanded(
          child:
              _filteredTerms.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No terms found',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: _filteredTerms.length,
                    itemBuilder:
                        (ctx, i) =>
                            _buildTermCard(_filteredTerms[i], i, isDark),
                  ),
        ),
      ],
    );
  }

  Widget _letterChip(String letter, String label) {
    final bool selected = _selectedLetter == letter;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLetter = letter);
        _applyFilters();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildTermCard(LegalTerm term, int index, bool isDark) {
    final bool expanded = _expandedIndex == index;
    final Color catColor = _getCategoryColor(term.category);

    return GestureDetector(
      onTap: () => setState(() => _expandedIndex = expanded ? null : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              expanded
                  ? (isDark
                      ? catColor.withValues(alpha: 0.08)
                      : catColor.withValues(alpha: 0.04))
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                expanded
                    ? catColor.withValues(alpha: 0.3)
                    : (isDark ? Colors.white10 : Colors.grey[200]!),
          ),
          boxShadow:
              expanded
                  ? [
                    BoxShadow(
                      color: catColor.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    term.category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: catColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    term.term,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: Colors.grey[400],
                ),
              ],
            ),

            // Brief meaning (always visible)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                term.meaning,
                maxLines: expanded ? 10 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ),

            // Expanded content
            if (expanded) ...[
              if (term.usage.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usage in Court:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: catColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        term.usage,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (term.section.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.bookmark_outline, size: 14, color: catColor),
                    const SizedBox(width: 4),
                    Text(
                      'Ref: ${term.section}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: catColor,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _copyTerm(term),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Latin':
        return Colors.deepPurple;
      case 'Legal English':
        return Colors.blue;
      case 'Criminal':
        return Colors.red;
      case 'Evidence':
        return Colors.teal;
      case 'Property':
        return Colors.orange;
      case 'Constitutional':
        return Colors.green;
      case 'Family':
        return Colors.pink;
      case 'Contract':
        return Colors.indigo;
      case 'Corporate':
        return Colors.blueGrey;
      case 'Taxation':
        return Colors.amber.shade800;
      case 'Cyber':
        return Colors.cyan;
      case 'Environmental':
        return Colors.lightGreen;
      case 'Labour':
        return Colors.brown;
      case 'Consumer':
        return Colors.deepOrange;
      case 'Administrative':
        return Colors.purple;
      case 'International':
        return Colors.blue.shade800;
      default:
        return AppTheme.accent;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
}
