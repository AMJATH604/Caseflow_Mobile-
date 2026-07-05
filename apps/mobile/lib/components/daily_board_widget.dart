import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DailyBoardWidget extends ConsumerWidget {
  const DailyBoardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hearingsAsync = ref.watch(hearingsProvider);

    return hearingsAsync.when(
      data: (allHearings) {
        final today = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(today);

        final todayHearings =
            allHearings.where((h) {
              return DateFormat('yyyy-MM-dd').format(h.hearingDate) == todayStr;
            }).toList();

        if (todayHearings.isEmpty) {
          return _buildEmptyBoard(today);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 24.w),
              decoration: const BoxDecoration(
                color: AppTheme.secondary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                border: Border(
                  top: BorderSide(color: AppTheme.border),
                  left: BorderSide(color: AppTheme.border),
                  right: BorderSide(color: AppTheme.border),
                  bottom: BorderSide(color: AppTheme.border, width: 0.5.w),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_view_day_rounded,
                        color: AppTheme.accent,
                        size: 18,
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        "TODAY'S SCHEDULE",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF1E293B),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${todayHearings.length} HEARINGS',
                        style: GoogleFonts.inter(
                          color: AppTheme.accent,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ...todayHearings.asMap().entries.map((entry) {
              final index = entry.key;
              final h = entry.value;
              final color = _itemColor(index);
              final isLast = index == todayHearings.length - 1;

              return InkWell(
                onTap: () => context.push('/cases/${h.caseId}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      left: const BorderSide(color: AppTheme.border),
                      right: const BorderSide(color: AppTheme.border),
                      bottom: BorderSide(
                        color: AppTheme.border,
                        width: isLast ? 1 : 0.5,
                      ),
                    ),
                    borderRadius:
                        isLast
                            ? const BorderRadius.vertical(
                              bottom: Radius.circular(16.r),
                            )
                            : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3.w,
                        height: 32.h,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.caseTitle ?? 'Unknown Case',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF1E293B),
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              (h.purpose ?? h.stage ?? 'Hearing').toUpperCase(),
                              style: GoogleFonts.inter(
                                color: const Color(0xFF6B7280),
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF94A3B8),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyBoard(DateTime today) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 24.w),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_rounded,
            size: 32,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 16.h),
          Text(
            'NO HEARINGS TODAY',
            style: GoogleFonts.inter(
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w700,
              fontSize: 12.sp,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            DateFormat('EEEE, MMMM dd').format(today),
            style: GoogleFonts.inter(
              color: const Color(0xFF4B5563),
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _itemColor(int index) {
    const colors = [
      AppTheme.accent,
      AppTheme.accentViolet,
      Color(0xFF10B981),
      Color(0xFF3B82F6),
      Color(0xFFF59E0B),
    ];
    return colors[index % colors.length];
  }
}
