import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// One parsed block of an AI reply.
///
/// The model answers in Markdown and the app used to print it through a plain
/// SelectableText, so a cited section arrived on screen as literal
/// `**Section 138**` and a list as a column of hyphens. That — more than any
/// colour choice — is what made the assistant look unfinished.
///
/// Parsed rather than pulled from a package: `flutter_markdown` is
/// discontinued, and the subset a legal answer actually uses is small enough
/// to own and to test.
enum MdBlockType { paragraph, heading, bullet, numbered, code, quote, rule }

class MdBlock {
  final MdBlockType type;
  final String text;

  /// 1-3 for headings; the item number for an ordered list item.
  final int level;

  const MdBlock(this.type, this.text, {this.level = 0});

  @override
  bool operator ==(Object other) =>
      other is MdBlock &&
      other.type == type &&
      other.text == text &&
      other.level == level;

  @override
  int get hashCode => Object.hash(type, text, level);

  @override
  String toString() => 'MdBlock($type, "$text", level: $level)';
}

/// Splits Markdown into blocks. Deliberately line-based: the model emits one
/// construct per line, and a full CommonMark parser would be far more than
/// this needs.
List<MdBlock> parseMarkdownBlocks(String source) {
  final blocks = <MdBlock>[];
  final lines = source.replaceAll('\r\n', '\n').split('\n');

  final paragraph = <String>[];
  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(MdBlock(MdBlockType.paragraph, paragraph.join(' ').trim()));
    paragraph.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    // Fenced code runs to the closing fence, or to the end if the model was
    // cut off mid-block — an unterminated fence must not swallow nothing.
    if (trimmed.startsWith('```')) {
      flushParagraph();
      final buffer = <String>[];
      i++;
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        buffer.add(lines[i]);
        i++;
      }
      i++; // step past the closing fence
      blocks.add(MdBlock(MdBlockType.code, buffer.join('\n')));
      continue;
    }

    if (trimmed.isEmpty) {
      flushParagraph();
      i++;
      continue;
    }

    if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
      flushParagraph();
      blocks.add(const MdBlock(MdBlockType.rule, ''));
      i++;
      continue;
    }

    final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      flushParagraph();
      blocks.add(MdBlock(
        MdBlockType.heading,
        heading.group(2)!.trim(),
        level: heading.group(1)!.length,
      ));
      i++;
      continue;
    }

    final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
    if (bullet != null) {
      flushParagraph();
      blocks.add(MdBlock(MdBlockType.bullet, bullet.group(1)!.trim()));
      i++;
      continue;
    }

    final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
    if (numbered != null) {
      flushParagraph();
      blocks.add(MdBlock(
        MdBlockType.numbered,
        numbered.group(2)!.trim(),
        level: int.parse(numbered.group(1)!),
      ));
      i++;
      continue;
    }

    final quote = RegExp(r'^>\s?(.*)$').firstMatch(trimmed);
    if (quote != null) {
      flushParagraph();
      blocks.add(MdBlock(MdBlockType.quote, quote.group(1)!.trim()));
      i++;
      continue;
    }

    paragraph.add(trimmed);
    i++;
  }
  flushParagraph();
  return blocks;
}

/// Renders a Markdown subset: headings, bullets, numbered lists, quotes,
/// rules, fenced code, and inline bold / italic / code.
class MarkdownBody extends StatelessWidget {
  final String text;
  final bool isDark;

  /// Base body size; headings scale from it.
  final double? fontSize;

  const MarkdownBody({
    super.key,
    required this.text,
    required this.isDark,
    this.fontSize,
  });

  Color get _ink => isDark ? const Color(0xFFE6EAF2) : const Color(0xFF1E293B);
  Color get _strong => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _muted => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _codeBg =>
      isDark ? const Color(0xFF0B1220) : const Color(0xFFF1F5F9);
  Color get _line => isDark ? Colors.white12 : const Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdownBlocks(text);
    final base = fontSize ?? 14.sp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == blocks.length - 1 ? 0 : _gapAfter(blocks[i]),
            ),
            child: _renderBlock(context, blocks[i], base),
          ),
      ],
    );
  }

  double _gapAfter(MdBlock b) => switch (b.type) {
        MdBlockType.heading => 7.h,
        MdBlockType.bullet || MdBlockType.numbered => 5.h,
        MdBlockType.rule => 12.h,
        _ => 10.h,
      };

  Widget _renderBlock(BuildContext context, MdBlock block, double base) {
    switch (block.type) {
      case MdBlockType.rule:
        return Divider(height: 1, thickness: 1, color: _line);

      case MdBlockType.heading:
        final size = switch (block.level) {
          1 => base + 4,
          2 => base + 2,
          _ => base + 1,
        };
        return SelectableText.rich(
          _inline(
            block.text,
            GoogleFonts.outfit(
              fontSize: size,
              fontWeight: FontWeight.w700,
              color: _strong,
              height: 1.35,
            ),
          ),
        );

      case MdBlockType.code:
        return _buildCodeBlock(context, block.text, base);

      case MdBlockType.quote:
        return Container(
          padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: _muted.withValues(alpha: 0.5), width: 3),
            ),
          ),
          child: SelectableText.rich(
            _inline(
              block.text,
              GoogleFonts.inter(
                fontSize: base,
                height: 1.6,
                color: _muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );

      case MdBlockType.bullet:
      case MdBlockType.numbered:
        final marker = block.type == MdBlockType.bullet
            ? '•'
            : '${block.level}.';
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: block.type == MdBlockType.bullet ? 18.w : 24.w,
              child: Text(
                marker,
                style: GoogleFonts.inter(
                  fontSize: base,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ),
            Expanded(
              child: SelectableText.rich(
                _inline(
                  block.text,
                  GoogleFonts.inter(
                    fontSize: base,
                    height: 1.6,
                    color: _ink,
                  ),
                ),
              ),
            ),
          ],
        );

      case MdBlockType.paragraph:
        return SelectableText.rich(
          _inline(
            block.text,
            GoogleFonts.inter(fontSize: base, height: 1.6, color: _ink),
          ),
        );
    }
  }

  Widget _buildCodeBlock(BuildContext context, String code, double base) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _codeBg,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Copy',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.all(6.r),
              constraints: const BoxConstraints(),
              icon: Icon(Icons.copy_rounded, size: 14.sp, color: _muted),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(milliseconds: 1200),
                  ),
                );
              },
            ),
          ),
          // Code may legitimately run wide; it scrolls rather than wrapping.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
            child: SelectableText(
              code,
              style: GoogleFonts.robotoMono(
                fontSize: base - 1.5,
                height: 1.55,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Inline `**bold**`, `*italic*`, `_italic_` and `` `code` ``.
  ///
  /// One pass over the string, so a bold run containing code does not need
  /// nesting rules the model never produces anyway.
  TextSpan _inline(String source, TextStyle base) {
    final pattern = RegExp(
      r'(\*\*.+?\*\*)|(`[^`]+?`)|(\*[^*\n]+?\*)|(_[^_\n]+?_)',
      dotAll: true,
    );

    final spans = <TextSpan>[];
    var last = 0;

    for (final m in pattern.allMatches(source)) {
      if (m.start > last) {
        spans.add(TextSpan(text: source.substring(last, m.start)));
      }
      final token = m.group(0)!;
      if (token.startsWith('**')) {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: TextStyle(fontWeight: FontWeight.w700, color: _strong),
        ));
      } else if (token.startsWith('`')) {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: GoogleFonts.robotoMono(
            fontSize: base.fontSize! - 1,
            backgroundColor: _codeBg,
            color: _strong,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      }
      last = m.end;
    }
    if (last < source.length) {
      spans.add(TextSpan(text: source.substring(last)));
    }

    return TextSpan(style: base, children: spans);
  }
}
