import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'english_dictionary_data.dart';

class EnglishDictionary extends StatefulWidget {
  const EnglishDictionary({super.key});

  @override
  State<EnglishDictionary> createState() => _EnglishDictionaryState();
}

class _EnglishDictionaryState extends State<EnglishDictionary> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<EnglishWord> _filteredWords = [];
  int? _expandedIndex;
  String _selectedLetter = '';

  @override
  void initState() {
    super.initState();
    _filteredWords = List.from(englishDictionaryData);
    _filteredWords.sort((a, b) => a.word.compareTo(b.word));
  }

  void _applyFilters() {
    String query = _searchCtrl.text.toLowerCase();
    setState(() {
      _expandedIndex = null;
      _filteredWords =
          englishDictionaryData.where((w) {
            bool matchesQuery =
                query.isEmpty ||
                w.word.toLowerCase().contains(query) ||
                w.definition.toLowerCase().contains(query);
            bool matchesLetter =
                _selectedLetter.isEmpty ||
                w.word.toUpperCase().startsWith(_selectedLetter);
            return matchesQuery && matchesLetter;
          }).toList();
      _filteredWords.sort((a, b) => a.word.compareTo(b.word));
    });
  }

  void _copyWord(EnglishWord w) {
    String text = '${w.word} (${w.partOfSpeech})\n${w.definition}';
    if (w.example.isNotEmpty) text += '\n\nExample: ${w.example}';
    if (w.synonyms.isNotEmpty) text += '\nSynonyms: ${w.synonyms.join(', ')}';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${w.word}" copied!'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _applyFilters(),
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search English words...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon:
                    _searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
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
                        : Colors.black.withValues(alpha: 0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Alphabet Filter
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 27,
              itemBuilder: (context, index) {
                String letter =
                    index == 0 ? '' : String.fromCharCode(64 + index);
                bool isSelected = _selectedLetter == letter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(
                      index == 0 ? 'All' : letter,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color:
                            isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedLetter = letter;
                        _applyFilters();
                      });
                    },
                    selectedColor: AppTheme.accent,
                    backgroundColor:
                        isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filteredWords.length} words found',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Words List
          Expanded(
            child:
                _filteredWords.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No words match your search',
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: _filteredWords.length,
                      itemBuilder: (context, index) {
                        final w = _filteredWords[index];
                        bool isExpanded = _expandedIndex == index;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF1E1E2E) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isExpanded
                                      ? AppTheme.accent.withValues(alpha: 0.3)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : AppTheme.borderLight),
                              width: 1,
                            ),
                            boxShadow:
                                isExpanded
                                    ? [
                                      BoxShadow(
                                        color: AppTheme.accent.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              key: PageStorageKey(w.word),
                              initiallyExpanded: isExpanded,
                              onExpansionChanged: (expanded) {
                                setState(
                                  () =>
                                      _expandedIndex = expanded ? index : null,
                                );
                              },
                              title: Text(
                                w.word,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1E293B),
                                ),
                              ),
                              subtitle: Text(
                                w.partOfSpeech,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.accent.withValues(alpha: 0.8),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                onPressed: () => _copyWord(w),
                                visualDensity: VisualDensity.compact,
                                color: isDark ? Colors.white38 : Colors.black26,
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Divider(height: 1),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Definition',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                          color:
                                              isDark
                                                  ? Colors.white38
                                                  : Colors.black38,
                                          textStyle: const TextStyle(
                                            textBaseline:
                                                TextBaseline.alphabetic,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        w.definition,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          height: 1.4,
                                          color:
                                              isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF334155),
                                        ),
                                      ),
                                      if (w.example.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          'In Context',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                            color:
                                                isDark
                                                    ? Colors.white38
                                                    : Colors.black38,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color:
                                                isDark
                                                    ? Colors.white.withValues(
                                                      alpha: 0.03,
                                                    )
                                                    : Colors.blueGrey
                                                        .withValues(
                                                          alpha: 0.05,
                                                        ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border(
                                              left: BorderSide(
                                                color: AppTheme.accent,
                                                width: 3,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            w.example,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontStyle: FontStyle.italic,
                                              color:
                                                  isDark
                                                      ? Colors.white60
                                                      : Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (w.synonyms.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          'Synonyms',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                            color:
                                                isDark
                                                    ? Colors.white38
                                                    : Colors.black38,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children:
                                              w.synonyms
                                                  .map(
                                                    (s) => Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.accent
                                                            .withValues(
                                                              alpha: 0.05,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        s,
                                                        style:
                                                            GoogleFonts.inter(
                                                              fontSize: 11,
                                                              color:
                                                                  AppTheme
                                                                      .accent,
                                                            ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
