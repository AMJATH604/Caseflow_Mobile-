import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Chat input bar with text field, attachment button, camera button, mic/send toggle.
///
/// Also shows a recording UI when [isRecording] is true.
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final bool isUploading;
  final bool isRecording;
  final int recordDuration;

  // Callbacks
  final VoidCallback? onSend;
  final VoidCallback? onAttach;
  final VoidCallback? onCamera;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;
  final VoidCallback? onCancelRecording;
  final ValueChanged<String>? onTextChanged;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isDark,
    this.isUploading = false,
    this.isRecording = false,
    this.recordDuration = 0,
    this.onSend,
    this.onAttach,
    this.onCamera,
    this.onStartRecording,
    this.onStopRecording,
    this.onCancelRecording,
    this.onTextChanged,
  });

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (isRecording) {
      return _buildRecordingBar(context);
    }
    return _buildNormalBar(context);
  }

  Widget _buildRecordingBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8.w,
        right: 8.w,
        top: 8.h,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? 8
            : MediaQuery.of(context).padding.bottom + 8,
      ),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.fiber_manual_record,
                    color: Color(0xFFEF4444),
                    size: 16,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    _formatDuration(recordDuration),
                    style: GoogleFonts.inter(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Recording voice...',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFEF4444),
              size: 26,
            ),
            onPressed: onCancelRecording,
          ),
          SizedBox(width: 8.w),
          Container(
            width: 48.w,
            height: 48.h,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, size: 22, color: Colors.white),
              onPressed: onStopRecording,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalBar(BuildContext context) {
    final showMic = controller.text.trim().isEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 8.w,
        right: 8.w,
        top: 8.h,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? 8
            : MediaQuery.of(context).padding.bottom + 8,
      ),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.attach_file_rounded,
                      size: 22,
                      color: const Color(0xFF4F46E5),
                    ),
                    onPressed: isUploading ? null : onAttach,
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLines: 4,
                      minLines: 1,
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      textInputAction: TextInputAction.newline,
                      onChanged: onTextChanged,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.inter(
                          color: isDark ? Colors.white38 : Colors.grey[500],
                          fontSize: 15.sp,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_rounded,
                      size: 22,
                      color: const Color(0xFF4F46E5),
                    ),
                    onPressed: isUploading ? null : onCamera,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            width: 48.w,
            height: 48.h,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                showMic ? Icons.mic_rounded : Icons.send_rounded,
                size: 20,
                color: Colors.white,
              ),
              onPressed: showMic ? onStartRecording : onSend,
            ),
          ),
        ],
      ),
    );
  }
}
