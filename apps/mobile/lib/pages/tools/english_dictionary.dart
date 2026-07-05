import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'english_dictionary_data.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
    final String query = _searchCtrl.text.toLowerCase();
    setState(() {
      _expandedIndex = null;
      _filteredWords =
          englishDictionaryData.where((w) {
            final bool matchesQuery =
                query.isEmpty ||
                w.word.toLowerCase().contains(query) ||
                w.definition.toLowerCase().contains(query);
            final bool matchesLetter =
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
              style: GoogleFonts.inter(fontSize: 14.sp),
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
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 0.h),
              ),
            ),
          ),

          // Alphabet Filter
          Container(
            height: 40.h,
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 27,
              itemBuilder: (context, index) {
                final String letter =
                    index == 0 ? '' : String.fromCharCode(64 + index);
                final bool isSelected = _selectedLetter == letter;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: ChoiceChip(
                    label: Text(
                      index == 0 ? 'All' : letter,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
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
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 8.h),

          // Results count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Text(
                  '${_filteredWords.length} words found',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 8.h),

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
                          SizedBox(height: 16.h),
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
                        final bool isExpanded = _expandedIndex == index;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(bottom: 8.h),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF1E1E2E) : Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color:
                                  isExpanded
                                      ? AppTheme.accent.withValues(alpha: 0.3)
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : AppTheme.borderLight),
                              width: 1.w,
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
                                  fontSize: 16.sp,
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
                                  fontSize: 12.sp,
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
                                      const Divider(height: 1.h),
                                      SizedBox(height: 12.h),
                                      Text(
                                        'Definition',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.sp,
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
                                      SizedBox(height: 4.h),
                                      Text(
                                        w.definition,
                                        style: GoogleFonts.inter(
                                          fontSize: 14.sp,
                                          height: 1.4.h,
                                          color:
                                              isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF334155),
                                        ),
                                      ),
                                      if (w.example.isNotEmpty) ...[
                                        SizedBox(height: 12.h),
                                        Text(
                                          'In Context',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                            color:
                                                isDark
                                                    ? Colors.white38
                                                    : Colors.black38,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Container(
                                          padding: EdgeInsets.all(10.r),
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
                                            border: const Border(
                                              left: BorderSide(
                                                color: AppTheme.accent,
                                                width: 3.w,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            w.example,
                                            style: GoogleFonts.inter(
                                              fontSize: 13.sp,
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
                                        SizedBox(height: 12.h),
                                        Text(
                                          'Synonyms',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                            color:
                                                isDark
                                                    ? Colors.white38
                                                    : Colors.black38,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
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
                                                              fontSize: 11.sp,
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
