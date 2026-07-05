import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ResetWorkspaceDialog extends StatefulWidget {
  const ResetWorkspaceDialog({super.key});

  @override
  State<ResetWorkspaceDialog> createState() => _ResetWorkspaceDialogState();
}

class _ResetWorkspaceDialogState extends State<ResetWorkspaceDialog> {
  final TextEditingController _confirmController = TextEditingController();
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _handleReset(WidgetRef ref) async {
    if (_confirmController.text.trim().toUpperCase() != 'RESET') {
      setState(() {
        _errorMessage = 'Please type RESET to confirm';
      });
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.resetUserWorkspace();

      // Invalidate all data providers to refresh UI
      ref.invalidate(casesProvider);
      ref.invalidate(clientsProvider);
      ref.invalidate(hearingsProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(userProfileProvider);

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workspace reset successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _errorMessage = 'Reset failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: EdgeInsets.all(32.r),
        child: Consumer(
          builder: (context, ref, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.error,
                    size: 32,
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Reset Workspace?',
                  style: GoogleFonts.outfit(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'This action will permanently delete all your Cases, Clients, Hearings, and Documents. This cannot be undone.',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                    height: 1.5.h,
                  ),
                ),
                SizedBox(height: 24.h),
                Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Type RESET to confirm:',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _confirmController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'RESET',
                          hintStyle: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                          border: InputBorder.none,
                          errorText: _errorMessage,
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                        onChanged: (val) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed:
                            _isDeleting ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isDeleting ? null : () => _handleReset(ref),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child:
                            _isDeleting
                                ? SizedBox(
                                  height: 20.h,
                                  width: 20.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(
                                  'Delete All',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }
}
