import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Voice message bubble with play/pause button, seekable slider, and duration.
class ChatVoiceBubble extends StatelessWidget {
  final String attachmentUrl;
  final String messageText;
  final bool isMe;
  final bool isDark;

  /// Currently playing audio URL (to determine if this bubble is active).
  final String? playingUrl;
  final bool isPlaying;
  final double audioProgress;
  final String? audioDurationText;

  final void Function(String url)? onPlayVoice;
  final void Function(double value)? onSeek;

  const ChatVoiceBubble({
    super.key,
    required this.attachmentUrl,
    required this.messageText,
    required this.isMe,
    required this.isDark,
    this.playingUrl,
    this.isPlaying = false,
    this.audioProgress = 0.0,
    this.audioDurationText,
    this.onPlayVoice,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final isPlayingThis = playingUrl == attachmentUrl;
    final showPlaying = isPlayingThis && isPlaying;
    final progressValue = isPlayingThis ? audioProgress : 0.0;

    // Parse duration from message text if not actively playing
    String durationText = audioDurationText ?? '0:00';
    if (!isPlayingThis) {
      final reg = RegExp(r'\((\d+:\d+)\)');
      final match = reg.firstMatch(messageText);
      if (match != null) {
        durationText = match.group(1) ?? '0:00';
      }
    }

    return Container(
      width: 250.w,
      padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 4.w),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onPlayVoice?.call(attachmentUrl),
            child: Container(
              width: 42.w,
              height: 42.h,
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.accent
                    : (isDark ? AppTheme.accent : const Color(0xFF2563EB)),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                showPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24.sp,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: AppTheme.accent,
                    inactiveTrackColor: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : const Color(0xFFE2E8F0),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    thumbColor: AppTheme.accent,
                    overlayColor: AppTheme.accent.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: progressValue.clamp(0.0, 1.0),
                    onChanged: (val) => onSeek?.call(val),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        durationText,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      Icon(
                        Icons.mic_rounded,
                        size: 14.sp,
                        color: AppTheme.accent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
