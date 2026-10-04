import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/providers.dart';
import '../services/repositories/profile_repository.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Shown in place of the whole app while an account waits out its 30-day
/// deletion grace period. The only choices are to keep the account or sign
/// out, so nothing new is created in an account that is about to go.
class AccountDeletionPendingScreen extends ConsumerStatefulWidget {
  final DateTime scheduledFor;

  const AccountDeletionPendingScreen({super.key, required this.scheduledFor});

  @override
  ConsumerState<AccountDeletionPendingScreen> createState() => _State();
}

class _State extends ConsumerState<AccountDeletionPendingScreen> {
  bool _busy = false;

  Future<void> _keep() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ProfileRepository.cancelAccountDeletion();
      ref.invalidate(userProfileProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account is safe — deletion cancelled.'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not cancel: $e'), backgroundColor: AppTheme.error));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = DateFormat('d MMMM yyyy').format(widget.scheduledFor.toLocal());
    final daysLeft = widget.scheduledFor.difference(DateTime.now()).inDays.clamp(0, 30);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B0F1A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  padding: EdgeInsets.all(18.r),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.hourglass_bottom_rounded, color: AppTheme.error, size: 36.sp),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'Your account is scheduled for deletion',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'It will be permanently deleted on $date — $daysLeft day${daysLeft == 1 ? '' : 's'} from now. '
                'Until then nothing is lost: keep your account and everything is exactly as you left it.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14.sp, height: 1.5, color: const Color(0xFF64748B)),
              ),
              const Spacer(),
              SizedBox(
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _busy ? null : _keep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Keep my account', style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w600)),
                ),
              ),
              SizedBox(height: 10.h),
              SizedBox(
                height: 52.h,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => SupabaseService.signOut(),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  ),
                  child: Text('Sign out', style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
