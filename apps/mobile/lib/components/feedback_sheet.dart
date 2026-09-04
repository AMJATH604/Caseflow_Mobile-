import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

/// Premium feedback bottom sheet for collecting user feedback during beta testing.
/// Auto-captures device info, app version, and user context.
class FeedbackSheet extends StatefulWidget {
  final String? currentScreen;

  const FeedbackSheet({super.key, this.currentScreen});

  /// Show the feedback sheet from anywhere in the app
  static void show(BuildContext context, {String? screenName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => FeedbackSheet(currentScreen: screenName),
    );
  }

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _feedbackType = 'general';
  String _severity = 'medium';
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  final _types = [
    {'key': 'bug', 'label': 'Bug Report', 'icon': Icons.bug_report_rounded, 'color': const Color(0xFFEF4444)},
    {'key': 'feature', 'label': 'Feature Request', 'icon': Icons.lightbulb_rounded, 'color': const Color(0xFFF59E0B)},
    {'key': 'ui_issue', 'label': 'UI/UX Issue', 'icon': Icons.design_services_rounded, 'color': const Color(0xFF8B5CF6)},
    {'key': 'crash', 'label': 'App Crash', 'icon': Icons.error_rounded, 'color': const Color(0xFFDC2626)},
    {'key': 'general', 'label': 'General', 'icon': Icons.chat_rounded, 'color': const Color(0xFF3B82F6)},
  ];

  final _severities = [
    {'key': 'low', 'label': 'Low', 'color': const Color(0xFF10B981)},
    {'key': 'medium', 'label': 'Medium', 'color': const Color(0xFFF59E0B)},
    {'key': 'high', 'label': 'High', 'color': const Color(0xFFEF4444)},
    {'key': 'critical', 'label': 'Critical', 'color': const Color(0xFFDC2626)},
  ];

  String _getDeviceInfo() {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'Unknown';
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty ||
        _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both title and description')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = SupabaseService.client.auth.currentUser;
      final profile = await SupabaseService.client
          .from('profiles')
          .select('full_name')
          .eq('id', user?.id ?? '')
          .maybeSingle();

      await SupabaseService.client.from('user_feedback').insert({
        'user_id': user?.id,
        'user_name': profile?['full_name'] ?? 'Unknown',
        'user_email': user?.email,
        'feedback_type': _feedbackType,
        'severity': _severity,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'screen_name': widget.currentScreen ?? 'Settings',
        'app_version': '2.0.0',
        'device_info': _getDeviceInfo(),
      });

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSubmitted = true;
        });

        // Auto-close after showing success
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: _isSubmitted
              ? _buildSuccessView(isDark)
              : _buildFormView(isDark),
        ),
      ),
    );
  }

  Widget _buildSuccessView(bool isDark) {
    return Padding(
      padding: EdgeInsets.all(40.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: Color(0xFF10B981),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Thank You!',
            style: GoogleFonts.outfit(
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your feedback has been submitted successfully.\nWe will review it and get back to you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
          SizedBox(height: 30.h),
        ],
      ),
    );
  }

  Widget _buildFormView(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accent.withValues(alpha: 0.15),
                          const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: const Icon(
                      Icons.feedback_rounded,
                      color: AppTheme.accent,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send Feedback',
                          style: GoogleFonts.outfit(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Help us improve CaseFlow',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),

            // Feedback Type Selector
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('FEEDBACK TYPE', isDark),
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: _types.map((t) {
                      final isSelected = _feedbackType == t['key'];
                      final color = t['color'] as Color;
                      return GestureDetector(
                        onTap: () => setState(() => _feedbackType = t['key'] as String),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.12)
                                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[50]),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: isSelected
                                  ? color.withValues(alpha: 0.5)
                                  : (isDark ? Colors.white10 : Colors.grey[200]!),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(t['icon'] as IconData, size: 16, color: isSelected ? color : Colors.grey[400]),
                              SizedBox(width: 6.w),
                              Text(
                                t['label'] as String,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? color : (isDark ? Colors.white70 : Colors.grey[600]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Severity (only for bugs/crashes)
            if (_feedbackType == 'bug' || _feedbackType == 'crash' || _feedbackType == 'ui_issue')
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('SEVERITY', isDark),
                    SizedBox(height: 8.h),
                    Row(
                      children: _severities.map((s) {
                        final isSelected = _severity == s['key'];
                        final color = s['color'] as Color;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _severity = s['key'] as String),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(right: s['key'] != 'critical' ? 8.w : 0),
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withValues(alpha: 0.12)
                                    : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[50]),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: isSelected ? color.withValues(alpha: 0.5) : Colors.transparent,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  s['label'] as String,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? color : Colors.grey[500],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),

            // Title
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('TITLE', isDark),
                  SizedBox(height: 8.h),
                  _buildTextField(
                    controller: _titleController,
                    hint: 'Brief summary of your feedback',
                    isDark: isDark,
                    maxLines: 1,
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Description
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('DESCRIPTION', isDark),
                  SizedBox(height: 8.h),
                  _buildTextField(
                    controller: _descController,
                    hint: 'Describe in detail what happened, what you expected, or what you would like to see...',
                    isDark: isDark,
                    maxLines: 4,
                  ),
                ],
              ),
            ),

            SizedBox(height: 8.h),

            // Auto-captured info banner
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withValues(alpha: 0.06)
                      : const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue[400]),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Device info, app version & your account will be auto-attached for faster debugging.',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.blue[600],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20.h),

            // Submit Button
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
              child: SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 8.w),
                            Text(
                              'Submit Feedback',
                              style: GoogleFonts.inter(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: maxLines > 1 ? TextInputType.multiline : TextInputType.text,
      textInputAction: maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      style: TextStyle(
        fontSize: 14.sp,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13.sp,
          color: Colors.grey[400],
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(
            color: AppTheme.accent,
            width: 1.5,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      ),
    );
  }
}
