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
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onPlayVoice?.call(attachmentUrl),
            child: Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: isMe
                    ? Colors.white24
                    : const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                showPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isMe ? Colors.white : const Color(0xFF4F46E5),
                size: 24,
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
                    trackHeight: 3,
                    activeTrackColor:
                        isMe ? Colors.white : const Color(0xFF4F46E5),
                    inactiveTrackColor:
                        isMe ? Colors.white30 : Colors.grey[300],
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    thumbColor:
                        isMe ? Colors.white : const Color(0xFF4F46E5),
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
                          fontSize: 10.sp,
                          color: isMe ? Colors.white70 : Colors.black45,
                        ),
                      ),
                      const Icon(
                        Icons.mic_rounded,
                        size: 14,
                        color: Color(0xFF10B981),
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
