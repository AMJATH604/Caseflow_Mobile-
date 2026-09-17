import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../../services/gemini_service.dart';
import 'ai_genui_cards.dart';

/// A single AI or user message bubble with avatar, content, and action chips.
class AiMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isUser;
  final bool isDark;

  const AiMessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Assistant replies run the full width of the column with no bubble,
    // border or shadow — the way ChatGPT and Claude set them. A legal answer
    // is several paragraphs with headings and citations, and a chat bubble
    // squeezed it into a narrow column that then had to wrap every line.
    // The user's turn stays a bubble, so the two are still easy to tell
    // apart at a glance.
    return isUser ? _buildUserTurn(context) : _buildAssistantTurn(context);
  }

  Widget _buildUserTurn(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 18.h, left: 40.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
                bottomLeft: Radius.circular(16.r),
                bottomRight: Radius.circular(4.r),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: message.imagePath != null
                        ? Image.file(
                            File(message.imagePath!),
                            width: 200.w,
                            height: 150.h,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 200.w,
                              height: 60.h,
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.broken_image),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  SizedBox(height: 8.h),
                ],
                SelectableText(
                  message.text,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    height: 1.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantTurn(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 22.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAiAvatar(),
              SizedBox(width: 9.w),
              Text(
                'CaseFlow AI',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          if (message.isLoading)
            _buildTypingIndicator()
          else ...[
            _buildMessageContent(context),
            if (message.hasSources) ...[
              SizedBox(height: 12.h),
              _buildSourceChips(context),
            ],
            SizedBox(height: 10.h),
            _buildCopyChip(context),
          ],
        ],
      ),
    );
  }

  Widget _buildAiAvatar() {
    return Container(
      width: 32.w,
      height: 32.h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF22D3EE)],
        ),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: const Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  // The user's own avatar is gone: their turn is right-aligned in a tinted
  // bubble, which already says whose it is without spending a row on it.

  Widget _buildMessageContent(BuildContext context) {
    if (isUser) {
      return SelectableText(
        message.text,
        style: GoogleFonts.inter(
          fontSize: 14.sp,
          height: 1.6.h,
          color: Colors.white,
        ),
      );
    }

    // Parse Gen UI tags: <genui-([a-z0-9\-]+)([^>]*)\/>
    return AiGenUiContent(
      text: message.text,
      isDark: isDark,
    );
  }

  Widget _buildCopyChip(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: message.text));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Copied to clipboard'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                duration: const Duration(milliseconds: 1500),
              ),
            );
          },
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF232330) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.copy_rounded,
                  size: 13,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
                SizedBox(width: 5.w),
                Text(
                  'Copy',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Perplexity-style source citation chips — shows numbered legal sources
  /// that were used to ground the AI's answer.
  Widget _buildSourceChips(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Icon(
              Icons.library_books_rounded,
              size: 12,
              color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
            ),
            SizedBox(width: 5.w),
            Text(
              'Sources',
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        // Source chips in a wrap
        Wrap(
          spacing: 6.w,
          runSpacing: 6.h,
          children: message.ragSources.asMap().entries.map((entry) {
            final idx = entry.key;
            final source = entry.value;
            final ref = source['ref'] as String? ?? 'Source';
            final type = source['type'] as String? ?? 'bare_act';
            final similarity = source['similarity'] as num? ?? 0;

            // Icon based on source type
            IconData icon;
            Color chipColor;
            switch (type) {
              case 'template':
                icon = Icons.description_rounded;
                chipColor = const Color(0xFF059669);
                break;
              case 'dictionary':
                icon = Icons.menu_book_rounded;
                chipColor = const Color(0xFFD97706);
                break;
              default: // bare_act
                icon = Icons.gavel_rounded;
                chipColor = const Color(0xFF6366F1);
            }

            return InkWell(
              onTap: () => _showSourceDetail(context, ref, source),
              borderRadius: BorderRadius.circular(8.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isDark
                      ? chipColor.withValues(alpha: 0.15)
                      : chipColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: chipColor.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Numbered badge
                    Container(
                      width: 16.w,
                      height: 16.h,
                      decoration: BoxDecoration(
                        color: chipColor,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${idx + 1}',
                        style: GoogleFonts.inter(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Icon(icon, size: 11, color: chipColor),
                    SizedBox(width: 4.w),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 160.w),
                      child: Text(
                        ref,
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? chipColor.withValues(alpha: 0.9)
                              : chipColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '${(similarity * 100).round()}%',
                      style: GoogleFonts.inter(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Show source detail in a bottom sheet when a citation chip is tapped.
  void _showSourceDetail(
    BuildContext context,
    String ref,
    Map<String, dynamic> source,
  ) {
    final metadata = source['metadata'] as Map<String, dynamic>? ?? {};
    final actTitle = metadata['act_title'] as String? ?? '';
    final sectionNumber = metadata['section_number'] as String? ?? '';
    final sectionTitle = metadata['section_title'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3D3D50) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              // Title
              Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.gavel_rounded,
                          size: 18,
                          color: const Color(0xFF6366F1),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            ref,
                            style: GoogleFonts.inter(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (actTitle.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        actTitle,
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                    if (sectionTitle.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'Section $sectionNumber: $sectionTitle',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? const Color(0xFF2D2D3F) : const Color(0xFFE2E8F0),
              ),
              // This would show the full source content retrieved from RAG
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16.r),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: SelectableText(
                      'Source content retrieved from the CaseFlow legal knowledge base.\n\nThis section was matched with the AI query and used to ground the response in actual Indian law.',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        height: 1.7,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        SizedBox(width: 4.w),
        _buildDot(1),
        SizedBox(width: 4.w),
        _buildDot(2),
        SizedBox(width: 8.w),
        Text(
          'Thinking...',
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            color: const Color(0xFF94A3B8),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8.w,
          height: 8.h,
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.4 + (value * 0.6)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
