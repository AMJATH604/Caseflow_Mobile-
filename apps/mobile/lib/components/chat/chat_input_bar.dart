import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Premium WhatsApp-style chat input bar.
///
/// Features:
/// - Emoji button on the left
/// - Expandable text field
/// - Attachment clip + Camera icons on the right inside the pill
/// - Floating teal send/mic button outside the pill
/// - Recording mode with red dot, timer, delete, and send
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

  // WhatsApp teal accent
  static const _teal = Color(0xFF00A884);
  static const _tealDark = Color(0xFF005C4B);

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (isRecording) return _buildRecordingBar(context);
    return _buildNormalBar(context);
  }

  Widget _buildRecordingBar(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5);

    return Container(
      padding: EdgeInsets.only(
        left: 6.w,
        right: 6.w,
        top: 6.h,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? 6
            : MediaQuery.of(context).padding.bottom + 6,
      ),
      color: bgColor,
      child: Row(
        children: [
          // Recording pill
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF202C33) : Colors.white,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Row(
                children: [
                  // Red pulsing dot
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.3, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    builder: (_, opacity, __) => Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: opacity),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    _formatDuration(recordDuration),
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [const FontFeature.tabularFigures()],
                      color: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Recording voice note...',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        color: const Color(0xFF8696A0),
                      ),
                    ),
                  ),
                  // Delete button
                  GestureDetector(
                    onTap: onCancelRecording,
                    child: Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_rounded,
                        color: const Color(0xFFEF4444),
                        size: 20.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 6.w),
          // Send voice button
          _buildActionButton(
            icon: Icons.send_rounded,
            onTap: onStopRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildNormalBar(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    final bgColor = isDark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5);
    final pillColor = isDark ? const Color(0xFF202C33) : Colors.white;
    final iconColor = isDark ? const Color(0xFF8696A0) : const Color(0xFF54656F);

    return Container(
      padding: EdgeInsets.only(
        left: 6.w,
        right: 6.w,
        top: 6.h,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? 6
            : MediaQuery.of(context).padding.bottom + 6,
      ),
      color: bgColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ─── Text field pill ──────────────────
          Expanded(
            child: Container(
              constraints: BoxConstraints(maxHeight: 120.h),
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Emoji button
                  Padding(
                    padding: EdgeInsets.only(left: 4.w, bottom: 4.h),
                    child: IconButton(
                      icon: Icon(
                        Icons.emoji_emotions_outlined,
                        size: 24.sp,
                        color: iconColor,
                      ),
                      onPressed: null, // Reserved for emoji picker
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: 36.w,
                        minHeight: 36.h,
                      ),
                    ),
                  ),

                  // Text field
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLines: 6,
                      minLines: 1,
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        color: isDark
                            ? const Color(0xFFE9EDEF)
                            : const Color(0xFF111B21),
                        height: 1.35,
                      ),
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: onTextChanged,
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFF8696A0),
                          fontSize: 16.sp,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10.h,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),

                  // Attachment clip
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: IconButton(
                      icon: Transform.rotate(
                        angle: 0.8,
                        child: Icon(
                          Icons.attach_file_rounded,
                          size: 22.sp,
                          color: iconColor,
                        ),
                      ),
                      onPressed: isUploading ? null : onAttach,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: 36.w,
                        minHeight: 36.h,
                      ),
                    ),
                  ),

                  // Camera (only when text is empty)
                  if (!hasText)
                    Padding(
                      padding: EdgeInsets.only(right: 4.w, bottom: 4.h),
                      child: IconButton(
                        icon: Icon(
                          Icons.camera_alt_rounded,
                          size: 22.sp,
                          color: iconColor,
                        ),
                        onPressed: isUploading ? null : onCamera,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 36.w,
                          minHeight: 36.h,
                        ),
                      ),
                    ),

                  if (hasText) SizedBox(width: 4.w),
                ],
              ),
            ),
          ),
          SizedBox(width: 6.w),

          // ─── Send / Mic floating button ──────
          _buildActionButton(
            icon: hasText ? Icons.send_rounded : Icons.mic_rounded,
            onTap: hasText ? onSend : onStartRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: GestureDetector(
        onTap: isUploading ? null : onTap,
        child: Container(
          width: 48.w,
          height: 48.w,
          decoration: BoxDecoration(
            color: isDark ? _tealDark : _teal,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isDark ? _tealDark : _teal).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: isUploading
              ? Center(
                  child: SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : Icon(
                  icon,
                  size: 22.sp,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }
}
