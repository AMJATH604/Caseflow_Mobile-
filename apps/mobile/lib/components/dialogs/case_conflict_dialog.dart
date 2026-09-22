import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/case_conflict.dart';
import '../../theme/app_theme.dart';

/// Shown when a case being saved clashes with one already on file.
///
/// Returns `true` only when the user chooses to save anyway, which is offered
/// for a title match and never for a number match — the database rejects that
/// one regardless of what the dialog says.
Future<bool> showCaseConflictDialog(
  BuildContext context,
  List<CaseConflict> conflicts, {
  void Function(String caseId)? onOpenExisting,
}) async {
  if (conflicts.isEmpty) return true;

  final blocking = conflicts.where((c) => c.isBlocking).toList();
  final isBlocked = blocking.isNotEmpty;
  final shown = isBlocked ? blocking : conflicts;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final accent = isBlocked ? AppTheme.error : AppTheme.warning;
      final ink = isDark ? Colors.white : const Color(0xFF0F172A);
      final muted = isDark ? Colors.white70 : const Color(0xFF64748B);

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        titlePadding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 0),
        contentPadding: EdgeInsets.fromLTRB(22.w, 14.h, 22.w, 0),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9.r),
              ),
              child: Icon(
                isBlocked
                    ? Icons.block_rounded
                    : Icons.warning_amber_rounded,
                color: accent,
                size: 19.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                isBlocked ? 'This case already exists' : 'Similar case found',
                style: GoogleFonts.outfit(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBlocked
                  ? 'A case with this number is already on file in the same '
                      'court. The same case cannot be added twice.'
                  : 'A case with this name already exists. Case names are '
                      'often similar, so this may still be a different '
                      'matter — check before you continue.',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                height: 1.5,
                color: muted,
              ),
            ),
            SizedBox(height: 16.h),
            for (final c in shown)
              Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.all(13.r),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(9.r),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.caseNumber != null && c.caseNumber!.isNotEmpty) ...[
                      Text(
                        c.caseNumber!,
                        style: GoogleFonts.robotoMono(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      SizedBox(height: 3.h),
                    ],
                    Text(
                      c.caseTitle,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: ink,
                        height: 1.35,
                      ),
                    ),
                    if (c.courtName != null && c.courtName!.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_rounded,
                            size: 12.sp,
                            color: muted,
                          ),
                          SizedBox(width: 5.w),
                          Expanded(
                            child: Text(
                              c.courtName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5.sp,
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
        actionsPadding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 12.h),
        actions: [
          if (isBlocked && onOpenExisting != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
                onOpenExisting(shown.first.id);
              },
              child: Text('Open existing', style: TextStyle(fontSize: 13.sp)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isBlocked ? 'Close' : 'Cancel',
              style: TextStyle(fontSize: 13.sp, color: muted),
            ),
          ),
          // Only ever offered for a soft conflict.
          if (!isBlocked)
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text('Save anyway', style: TextStyle(fontSize: 13.sp)),
            ),
        ],
      );
    },
  );

  return result ?? false;
}
