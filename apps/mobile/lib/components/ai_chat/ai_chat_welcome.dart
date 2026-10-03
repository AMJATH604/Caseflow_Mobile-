import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/gemini_service.dart';
import 'ai_palette.dart';

/// The empty conversation: one calm question in the middle, and a row of
/// starting points just above where you type — as ChatGPT opens a new chat.
class AiChatWelcome extends StatelessWidget {
  final bool isDark;
  final void Function(String prompt) onSendPrompt;

  const AiChatWelcome({
    super.key,
    required this.isDark,
    required this.onSendPrompt,
  });

  @override
  Widget build(BuildContext context) {
    final c = AiPalette(isDark);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44.r,
                    height: 44.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.border),
                    ),
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      size: 22,
                      color: c.ink,
                    ),
                  ),
                  SizedBox(height: 18.h),
                  Text(
                    'How can I help with your case today?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 24.sp,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: c.ink,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Ask about Indian law, or attach an order, FIR or deed.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      height: 1.45,
                      color: c.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: 78.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            itemCount: GeminiService.suggestedPrompts.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (context, i) {
              final p = GeminiService.suggestedPrompts[i];
              return _SuggestionCard(
                title: p['title']!,
                prompt: p['prompt']!,
                palette: c,
                onTap: () => onSendPrompt(p['prompt']!),
              );
            },
          ),
        ),
        SizedBox(height: 8.h),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final String title;
  final String prompt;
  final AiPalette palette;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.title,
    required this.prompt,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: 210.w,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: palette.ink,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                prompt,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  height: 1.35,
                  color: palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
