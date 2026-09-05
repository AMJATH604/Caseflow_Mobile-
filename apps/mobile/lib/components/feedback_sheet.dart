import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

/// Ultra-stable, cross-device feedback bottom sheet.
/// Compatible with all Android OEMs (Xiaomi, Samsung, Oppo, Vivo, OnePlus, Realme).
class FeedbackSheet extends StatefulWidget {
  final String? currentScreen;

  const FeedbackSheet({super.key, this.currentScreen});

  /// Show the feedback sheet from anywhere in the app
  static void show(BuildContext context, {String? screenName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FeedbackSheet(currentScreen: screenName),
    );
  }

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descFocusNode = FocusNode();

  String _feedbackType = 'general';
  String _severity = 'medium';
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  String? _errorMessage;

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

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _titleFocusNode.dispose();
    _descFocusNode.dispose();
    super.dispose();
  }

  String _getDeviceInfo() {
    try {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (_) {
      return 'Android Device';
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      setState(() => _errorMessage = 'Please fill in both title and description.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final user = SupabaseService.client.auth.currentUser;
      String userName = 'Advocate';
      String? userEmail = user?.email;

      if (user != null && user.id.isNotEmpty) {
        try {
          final profile = await SupabaseService.client
              .from('profiles')
              .select('full_name')
              .eq('id', user.id)
              .maybeSingle();
          if (profile != null && profile['full_name'] != null) {
            userName = profile['full_name'].toString();
          }
        } catch (_) {
          // Graceful fallback to email prefix if profile query fails
          userName = user.email?.split('@').first ?? 'Advocate';
        }
      }

      await SupabaseService.client.from('user_feedback').insert({
        'user_id': user?.id,
        'user_name': userName,
        'user_email': userEmail,
        'feedback_type': _feedbackType,
        'severity': _severity,
        'title': title,
        'description': desc,
        'screen_name': widget.currentScreen ?? 'Settings',
        'app_version': '2.0.0',
        'device_info': _getDeviceInfo(),
      });

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isSubmitted = true;
        });

        // Auto-close after showing success state
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to submit: ${e.toString().replaceAll("Exception: ", "")}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 25,
                offset: const Offset(0, -6),
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
      ),
    );
  }

  Widget _buildSuccessView(bool isDark) {
    return Padding(
      padding: EdgeInsets.all(32.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              size: 56,
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            'Thank You! 🎉',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your feedback has been sent to our development team.\nWe appreciate your help in perfecting CaseFlow.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: isDark ? Colors.white70 : Colors.grey[600],
              height: 1.4,
            ),
          ),
          SizedBox(height: 24.h),
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
          // Drag handle
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 12.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 16.w, 0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
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
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Help us improve CaseFlow',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isDark ? Colors.white60 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white54 : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Type Selector
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
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _feedbackType = t['key'] as String),
                        borderRadius: BorderRadius.circular(10.r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.12)
                                : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: isSelected ? color : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                t['icon'] as IconData,
                                size: 16,
                                color: isSelected ? color : Colors.grey[500],
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                t['label'] as String,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark ? Colors.white : color)
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          SizedBox(height: 14.h),

          // Severity Selector (for bugs/crashes/UI)
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
                            duration: const Duration(milliseconds: 180),
                            margin: EdgeInsets.only(right: s['key'] != 'critical' ? 6.w : 0),
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.12)
                                  : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: isSelected ? color : Colors.transparent,
                                width: 1.5,
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
                  SizedBox(height: 14.h),
                ],
              ),
            ),

          // Title TextField
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('TITLE', isDark),
                SizedBox(height: 6.h),
                _buildTextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  hint: 'Short summary of the issue or idea',
                  isDark: isDark,
                  maxLines: 1,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),
          ),

          SizedBox(height: 14.h),

          // Description TextField
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('DESCRIPTION', isDark),
                SizedBox(height: 6.h),
                _buildTextField(
                  controller: _descController,
                  focusNode: _descFocusNode,
                  hint: 'What happened? What did you expect? Any steps to reproduce...',
                  isDark: isDark,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            SizedBox(height: 10.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 12.sp, color: const Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          SizedBox(height: 10.h),

          // Auto-captured info pill
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Container(
              padding: EdgeInsets.all(10.r),
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
                  Icon(Icons.info_outline_rounded, size: 15, color: Colors.blue[400]),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Your device info, app version & user name will be attached automatically.',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: isDark ? Colors.lightBlueAccent : Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 18.h),

          // Submit Button
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
            child: SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 16),
                          SizedBox(width: 8.w),
                          Text(
                            'Submit Feedback',
                            style: TextStyle(
                              fontSize: 14.sp,
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
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white60 : Colors.grey[600],
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.done,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: TextStyle(
        fontSize: 13.sp,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.sp,
          color: Colors.grey[400],
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(
            color: AppTheme.accent,
            width: 1.5,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      ),
    );
  }
}
