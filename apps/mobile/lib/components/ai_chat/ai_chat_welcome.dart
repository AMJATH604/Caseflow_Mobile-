import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/gemini_service.dart';

/// Welcome hero view shown when the AI chat history is empty.
/// Displays branding, capabilities hint, and tappable suggestion cards.
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.r),
      child: Column(
        children: [
          SizedBox(height: 24.h),
          // Hero icon
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF22D3EE),
                  Color(0xFF34D399),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 36,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'CaseFlow AI',
            style: GoogleFonts.outfit(
              fontSize: 28.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your expert Indian legal assistant.\nAsk questions or share images of legal documents.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.5.h,
            ),
          ),
          SizedBox(height: 16.h),
          // Image analysis hint
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.image_search_rounded,
                  size: 18,
                  color: Color(0xFF6366F1),
                ),
                SizedBox(width: 8.w),
                Text(
                  '📸 Send photos of court orders, FIRs, or legal docs!',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 32.h),
          Text(
            'TRY ASKING',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 16.h),
          ...GeminiService.suggestedPrompts.map(
            (prompt) => _SuggestionCard(
              prompt: prompt,
              isDark: isDark,
              onTap: () => onSendPrompt(prompt['prompt']!),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single suggestion card with icon, title, and prompt text.
class _SuggestionCard extends StatelessWidget {
  final Map<String, String> prompt;
  final bool isDark;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.prompt,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161620) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isDark ? const Color(0xFF232330) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Text(prompt['icon']!, style: TextStyle(fontSize: 22.sp)),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prompt['title']!,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      prompt['prompt']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
