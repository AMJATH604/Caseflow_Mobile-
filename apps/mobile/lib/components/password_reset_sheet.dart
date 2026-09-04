import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';

/// Premium in-app password reset sheet.
/// Uses a 6-digit OTP code sent to the advocate's email instead of
/// an external web browser redirect link that often breaks on mobile.
class PasswordResetSheet extends StatefulWidget {
  final String? initialEmail;

  const PasswordResetSheet({super.key, this.initialEmail});

  static Future<void> show(BuildContext context, {String? initialEmail}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PasswordResetSheet(initialEmail: initialEmail),
    );
  }

  @override
  State<PasswordResetSheet> createState() => _PasswordResetSheetState();
}

class _PasswordResetSheetState extends State<PasswordResetSheet> {
  // 0 = Enter Email, 1 = Enter Code & New Password, 2 = Success
  int _step = 0;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  // Resend countdown timer
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      _emailController.text = widget.initialEmail!.trim();
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$').hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _step = 1;
        });
        _startResendTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          final err = e.toString().toLowerCase();
          if (err.contains('rate limit')) {
            _errorMessage = 'Too many requests. Please wait a minute and try again.';
          } else {
            _errorMessage = 'Failed to send reset code. Please verify your email.';
          }
        });
      }
    }
  }

  Future<void> _verifyAndResetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (code.length < 6 || code.length > 8) {
      setState(() => _errorMessage = 'Please enter the verification code (6 to 8 digits).');
      return;
    }

    if (newPassword.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters long.');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Verify the recovery OTP token
      final res = await SupabaseService.client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.recovery,
      );

      if (res.session == null && res.user == null) {
        throw Exception('Invalid verification code');
      }

      // 2. Set the new password
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _step = 2;
        });

        // Auto close after 2.5 seconds
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          final err = e.toString().toLowerCase();
          if (err.contains('invalid') || err.contains('token') || err.contains('otp')) {
            _errorMessage = 'Invalid or expired 6-digit code. Please check your email.';
          } else {
            _errorMessage = 'Failed to reset password: ${e.toString().replaceAll("Exception: ", "")}';
          }
        });
      }
    }
  }

  Future<void> _openSupportWhatsApp() async {
    final url = Uri.parse(
      'https://wa.me/919944646736?text=${Uri.encodeComponent("Hello CaseFlow Support, I am an advocate testing the app and need help recovering my account.")}',
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 20.h),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),

            if (_step == 2)
              _buildSuccessView(isDark)
            else if (_step == 1)
              _buildStep1Verify(isDark)
            else
              _buildStep0Email(isDark),

            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  // ─── Step 0: Enter Email ──────────────────────────────────────────
  Widget _buildStep0Email(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                color: Color(0xFF1E3A8A),
                size: 26,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reset Password',
                    style: GoogleFonts.outfit(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Receive a verification code in your email',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),

        Text(
          'Enter your registered email address. We will send you a verification code to set a new password directly in the app.',
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
            height: 1.4,
          ),
        ),
        SizedBox(height: 20.h),

        // Email TextField
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            labelText: 'Email Address',
            hintText: 'advocate@example.com',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          SizedBox(height: 12.h),
          _buildErrorBanner(),
        ],

        SizedBox(height: 24.h),

        // Send Code Button
        ElevatedButton(
          onPressed: _isLoading ? null : _sendCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 15.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
            elevation: 0,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  'Send Verification Code',
                  style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
        ),

        SizedBox(height: 18.h),

        // Forgot Email Support link
        Center(
          child: TextButton.icon(
            onPressed: _openSupportWhatsApp,
            icon: const Icon(Icons.help_outline_rounded, size: 16, color: Color(0xFF10B981)),
            label: Text(
              'Forgot your email ID? Contact Support',
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Step 1: Enter 6-digit Code & New Password ─────────────────────
  Widget _buildStep1Verify(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                color: Color(0xFF10B981),
                size: 26,
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter Reset Code',
                    style: GoogleFonts.outfit(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Sent to ${_emailController.text.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),

        // Verification code input (supports 6 to 8 digits)
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          textAlign: TextAlign.center,
          style: GoogleFonts.robotoMono(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 5,
            color: const Color(0xFF1E3A8A),
          ),
          decoration: InputDecoration(
            labelText: 'Verification Code (OTP)',
            hintText: '••••••••',
            hintStyle: GoogleFonts.robotoMono(
              letterSpacing: 5,
              color: Colors.grey.shade400,
            ),
            prefixIcon: const Icon(Icons.pin_rounded),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
            ),
          ),
        ),
        SizedBox(height: 14.h),

        // New Password
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            labelText: 'New Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
            ),
          ),
        ),
        SizedBox(height: 14.h),

        // Confirm Password
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            prefixIcon: const Icon(Icons.lock_clock_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.r),
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
            ),
          ),
        ),

        if (_errorMessage != null) ...[
          SizedBox(height: 12.h),
          _buildErrorBanner(),
        ],

        SizedBox(height: 20.h),

        // Submit Button
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyAndResetPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 15.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
            elevation: 0,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  'Update Password & Sign In',
                  style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
        ),

        SizedBox(height: 12.h),

        // Resend or Back
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => setState(() {
                _step = 0;
                _errorMessage = null;
              }),
              child: Text(
                '← Change Email',
                style: GoogleFonts.inter(fontSize: 12.sp, color: Colors.grey.shade600),
              ),
            ),
            TextButton(
              onPressed: _resendCountdown > 0 ? null : _sendCode,
              child: Text(
                _resendCountdown > 0 ? 'Resend in ${_resendCountdown}s' : 'Resend Code',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: _resendCountdown > 0 ? Colors.grey : const Color(0xFF1E3A8A),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Step 2: Success ──────────────────────────────────────────────
  Widget _buildSuccessView(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 54,
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            'Password Reset Complete! 🎉',
            style: GoogleFonts.outfit(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your password has been updated successfully.\nYou are now authenticated and ready to sign in.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}
