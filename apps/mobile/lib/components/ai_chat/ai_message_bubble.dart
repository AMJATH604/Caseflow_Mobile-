import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/gemini_service.dart';
import 'ai_genui_cards.dart';
import 'ai_palette.dart';

/// One turn of the conversation.
///
/// Set the way ChatGPT sets it: your message is a soft rounded bubble on the
/// right; the answer runs the full width with no bubble, avatar or label —
/// a legal answer is paragraphs, headings and citations, and it reads best
/// as a page. Copy and Share sit quietly under a finished answer.
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

  AiPalette get _c => AiPalette(isDark);

  @override
  Widget build(BuildContext context) =>
      isUser ? _buildUserTurn(context) : _buildAssistantTurn(context);

  Widget _buildUserTurn(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h, left: 48.w),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 11.h),
          decoration: BoxDecoration(
            color: _c.surface,
            borderRadius: BorderRadius.circular(22.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.hasImage && message.imagePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: Image.file(
                    File(message.imagePath!),
                    width: 200.w,
                    height: 150.h,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 200.w,
                      height: 60.h,
                      color: _c.surfaceHigh,
                      child: Icon(Icons.broken_image_outlined, color: _c.muted),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
              ],
              SelectableText(
                message.text,
                style: GoogleFonts.inter(
                  fontSize: 15.sp,
                  height: 1.5,
                  color: _c.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssistantTurn(BuildContext context) {
    final streaming = message.isLoading && message.text.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isLoading && message.text.isEmpty)
            const _ThinkingPulse()
          else ...[
            AiGenUiContent(text: message.text, isDark: isDark),
            if (streaming) ...[
              SizedBox(height: 6.h),
              const _ThinkingPulse(compact: true),
            ],
            if (!message.isLoading) ...[
              if (message.hasSources) ...[
                SizedBox(height: 14.h),
                _buildSources(context),
              ],
              SizedBox(height: 8.h),
              _buildActions(context),
            ],
          ],
        ],
      ),
    );
  }

  // ─── Actions under a finished answer ───────────────────────

  Widget _buildActions(BuildContext context) {
    Widget action(IconData icon, String tooltip, VoidCallback onTap) =>
        IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.all(6.r),
          constraints: const BoxConstraints(),
          icon: Icon(icon, size: 17, color: _c.faint),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        action(Icons.content_copy_rounded, 'Copy', () {
          Clipboard.setData(ClipboardData(text: message.text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(milliseconds: 1200),
            ),
          );
        }),
        SizedBox(width: 4.w),
        action(Icons.ios_share_rounded, 'Share', () {
          Share.share(message.text);
        }),
      ],
    );
  }

  // ─── Sources ───────────────────────────────────────────────

  /// The legal sources the answer was grounded in, as numbered pills.
  Widget _buildSources(BuildContext context) {
    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Sources',
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: _c.muted,
          ),
        ),
        for (final entry in message.ragSources.asMap().entries)
          _sourcePill(context, entry.key + 1, entry.value),
      ],
    );
  }

  Widget _sourcePill(BuildContext context, int n, Map<String, dynamic> source) {
    final ref = source['ref'] as String? ?? 'Source';
    return InkWell(
      onTap: () => _showSourceDetail(context, ref, source),
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.fromLTRB(4.w, 4.h, 10.w, 4.h),
        decoration: BoxDecoration(
          color: _c.surface,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18.r,
              height: 18.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _c.cite.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$n',
                style: GoogleFonts.inter(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: _c.cite,
                ),
              ),
            ),
            SizedBox(width: 6.w),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 180.w),
              child: Text(
                ref,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: _c.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSourceDetail(
    BuildContext context,
    String ref,
    Map<String, dynamic> source,
  ) {
    final metadata = source['metadata'] as Map<String, dynamic>? ?? {};
    final actTitle = metadata['act_title'] as String? ?? '';
    final sectionNumber = metadata['section_number'] as String? ?? '';
    final sectionTitle = metadata['section_title'] as String? ?? '';
    final similarity = source['similarity'] as num?;

    showModalBottomSheet(
      context: context,
      backgroundColor: _c.bg,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ref,
                style: GoogleFonts.inter(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: _c.ink,
                ),
              ),
              if (actTitle.isNotEmpty) ...[
                SizedBox(height: 6.h),
                Text(
                  actTitle,
                  style: GoogleFonts.inter(fontSize: 13.sp, color: _c.muted),
                ),
              ],
              if (sectionTitle.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  'Section $sectionNumber: $sectionTitle',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: _c.ink,
                  ),
                ),
              ],
              SizedBox(height: 14.h),
              Text(
                'Matched from the CaseFlow legal library and used to ground '
                'this answer'
                '${similarity != null ? ' (${(similarity * 100).round()}% match)' : ''}.',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  height: 1.5,
                  color: _c.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The breathing dot ChatGPT shows while it thinks: one circle, gently
/// pulsing, for as long as the wait lasts.
class _ThinkingPulse extends StatefulWidget {
  final bool compact;
  const _ThinkingPulse({this.compact = false});

  @override
  State<_ThinkingPulse> createState() => _ThinkingPulseState();
}

class _ThinkingPulseState extends State<_ThinkingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AiPalette(Theme.of(context).brightness == Brightness.dark);
    final size = widget.compact ? 9.0 : 13.0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.compact ? 0 : 6.h),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = Curves.easeInOut.transform(_ctrl.value);
          return Semantics(
            label: 'CaseFlow AI is thinking',
            child: Transform.scale(
              scale: 0.75 + 0.35 * t,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: c.ink.withValues(alpha: 0.55 + 0.45 * t),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
