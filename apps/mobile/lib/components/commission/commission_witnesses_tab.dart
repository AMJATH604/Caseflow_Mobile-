import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/commission_models.dart';
import '../../theme/app_theme.dart';

/// Displays the witnesses list for a commission.
///
/// Shows witness cards with photo/avatar, ID info, statement preview,
/// audio playback tags, signature indicators, and delete actions.
class CommissionWitnessesTab extends StatelessWidget {
  final List<CommissionWitness> witnesses;
  final bool isDark;
  final String? currentlyPlayingId;
  final VoidCallback onRecordWitness;
  final ValueChanged<CommissionWitness> onPlayAudio;
  final ValueChanged<CommissionWitness> onDeleteWitness;

  const CommissionWitnessesTab({
    super.key,
    required this.witnesses,
    required this.isDark,
    required this.currentlyPlayingId,
    required this.onRecordWitness,
    required this.onPlayAudio,
    required this.onDeleteWitness,
  });

  @override
  Widget build(BuildContext context) {
    if (witnesses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            SizedBox(height: 12.h),
            Text(
              'No witnesses recorded',
              style: GoogleFonts.inter(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: onRecordWitness,
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Record Witness'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(16.r),
      itemCount: witnesses.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return _addWitnessCard();
        }
        final w = witnesses[i - 1];
        return _witnessCard(w);
      },
    );
  }

  Widget _addWitnessCard() => Padding(
    padding: EdgeInsets.only(bottom: 12.h),
    child: Material(
      color: AppTheme.warning.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onRecordWitness,
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Row(
            children: [
              Icon(Icons.person_add, color: AppTheme.warning),
              SizedBox(width: 12.w),
              Text(
                'Record New Witness',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _witnessCard(CommissionWitness w) => Container(
    margin: EdgeInsets.only(bottom: 10.h),
    padding: EdgeInsets.all(14.r),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      borderRadius: BorderRadius.circular(14.r),
      border: Border.all(
        color: isDark ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo
        ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child:
              w.photoUrl != null
                  ? Image.network(
                    w.photoUrl!,
                    width: 56.w,
                    height: 56.h,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _witnessAvatar(w),
                  )
                  : _witnessAvatar(w),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                w.witnessName,
                style: GoogleFonts.outfit(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                '${w.idLabel}${w.idNumber != null ? ': ${w.idNumber}' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 11.sp,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              if (w.statementText != null) ...[
                SizedBox(height: 6.h),
                Text(
                  w.statementText!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.4.h,
                  ),
                ),
              ],
              SizedBox(height: 4.h),
              Row(
                children: [
                  if (w.audioUrl != null) ...[
                    GestureDetector(
                      onTap: () => onPlayAudio(w),
                      child: _witnessTag(
                        currentlyPlayingId == w.id
                            ? Icons.stop
                            : Icons.play_arrow,
                        currentlyPlayingId == w.id
                            ? 'Playing...'
                            : 'Original Voice',
                        currentlyPlayingId == w.id
                            ? AppTheme.error
                            : AppTheme.accentViolet,
                      ),
                    ),
                  ],
                  if (w.signatureUrl != null)
                    _witnessTag(Icons.draw, 'Signed', AppTheme.success),
                  Spacer(),
                  Text(
                    w.locationText,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.sp,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.delete_outline,
            size: 16,
            color: AppTheme.error.withValues(alpha: 0.5),
          ),
          onPressed: () => onDeleteWitness(w),
        ),
      ],
    ),
  );

  Widget _witnessAvatar(CommissionWitness w) => Container(
    width: 56.w,
    height: 56.h,
    decoration: BoxDecoration(
      color: AppTheme.warning.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12.r),
    ),
    child: Center(
      child: Text(
        w.witnessName.isNotEmpty ? w.witnessName[0].toUpperCase() : '?',
        style: GoogleFonts.outfit(
          fontSize: 22.sp,
          fontWeight: FontWeight.w700,
          color: AppTheme.warning,
        ),
      ),
    ),
  );

  Widget _witnessTag(IconData icon, String label, Color color) => Container(
    margin: EdgeInsets.only(right: 6.w),
    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6.r),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        SizedBox(width: 3.w),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9.sp,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}
