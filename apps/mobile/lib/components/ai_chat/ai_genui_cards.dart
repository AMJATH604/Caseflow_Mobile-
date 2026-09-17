import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'markdown_body.dart';

/// Renders AI message text with embedded Gen UI cards (case, payment, calculators, section).
/// Parses `<genui-TYPE attr="val" />` tags from the AI response and renders
/// the matching interactive card widget inline with surrounding text.
class AiGenUiContent extends StatelessWidget {
  final String text;
  final bool isDark;

  const AiGenUiContent({
    super.key,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final regex = RegExp(r'<genui-([a-z0-9\-]+)\s*([^>]*)\/>');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      // Through the Markdown renderer: the model answers in Markdown, and a
      // plain SelectableText printed **Section 138** with the asterisks
      // showing.
      return MarkdownBody(text: text, isDark: isDark);
    }

    final children = <Widget>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final textBefore = text.substring(lastEnd, match.start).trim();
        if (textBefore.isNotEmpty) {
          // Same Markdown treatment as a reply with no cards in it.
          children.add(MarkdownBody(text: textBefore, isDark: isDark));
          children.add(SizedBox(height: 12.h));
        }
      }

      final tagType = match.group(1);
      final attrString = match.group(2) ?? '';
      final attrs = _parseAttributes(attrString);

      switch (tagType) {
        case 'case':
          children.add(_GenUiCaseCard(attrs: attrs, isDark: isDark));
          break;
        case 'payment':
          children.add(_GenUiPaymentCard(attrs: attrs, isDark: isDark));
          break;
        case 'calculators':
          children.add(_GenUiCalculatorsCard(isDark: isDark));
          break;
        case 'section':
          children.add(_GenUiSectionCard(attrs: attrs, isDark: isDark));
          break;
        default:
          children.add(
            Text(
              '[Unknown Gen UI Widget: $tagType]',
              style: const TextStyle(color: Colors.red),
            ),
          );
      }

      children.add(SizedBox(height: 12.h));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final textAfter = text.substring(lastEnd).trim();
      if (textAfter.isNotEmpty) {
        children.add(MarkdownBody(text: textAfter, isDark: isDark));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Map<String, String> _parseAttributes(String attrString) {
    final Map<String, String> attrs = {};
    final regex = RegExp(r'([a-zA-Z0-9_]+)="([^"]*)"');
    for (final match in regex.allMatches(attrString)) {
      attrs[match.group(1)!] = match.group(2)!;
    }
    return attrs;
  }
}

// ─── Case Card ─────────────────────────────────────────────

class _GenUiCaseCard extends StatelessWidget {
  final Map<String, String> attrs;
  final bool isDark;

  const _GenUiCaseCard({required this.attrs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final title = attrs['title'] ?? 'Unknown Case';
    final cnr = attrs['cnr'] ?? 'N/A';
    final court = attrs['court'] ?? 'Unknown Court';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161620) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  size: 16,
                  color: Color(0xFF3B82F6),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'CNR: $cnr',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Court: $court',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (cnr != 'N/A') {
                  context.go('/track-case?text=$cnr');
                }
              },
              icon: const Icon(Icons.search_rounded, size: 14),
              label: const Text('Track this Case'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Payment Card ──────────────────────────────────────────

class _GenUiPaymentCard extends StatelessWidget {
  final Map<String, String> attrs;
  final bool isDark;

  const _GenUiPaymentCard({required this.attrs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final title = attrs['caseTitle'] ?? 'Payment';
    final paid = attrs['paid'] ?? '0';
    final balance = attrs['balance'] ?? '0';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161620) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: const Icon(
                  Icons.currency_rupee_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paid',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    '₹$paid',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Balance',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  Text(
                    '₹$balance',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Calculators Card ──────────────────────────────────────

class _GenUiCalculatorsCard extends StatelessWidget {
  final bool isDark;

  const _GenUiCalculatorsCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161620) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular Calculators',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _calcChip(context, 'Court Fee', Icons.account_balance_rounded, 'court-fee'),
              _calcChip(context, 'Limitation', Icons.timer_rounded, 'limitation'),
              _calcChip(context, 'Maintenance', Icons.family_restroom_rounded, 'maintenance_calculator'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calcChip(
    BuildContext context,
    String label,
    IconData icon,
    String toolId,
  ) {
    return InkWell(
      onTap: () => context.go('/citizen-tools?tool=$toolId'),
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF6366F1)),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Card ──────────────────────────────────────────

class _GenUiSectionCard extends StatelessWidget {
  final Map<String, String> attrs;
  final bool isDark;

  const _GenUiSectionCard({required this.attrs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final act = attrs['act'] ?? 'Bare Act';
    final section = attrs['section'] ?? '';
    final title = attrs['title'] ?? '';
    final content = attrs['content'] ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(12.r),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  size: 14,
                  color: Color(0xFFD4AF37),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '$act - Section $section',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 8.h),
                ],
                Text(
                  content,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    height: 1.5.h,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
