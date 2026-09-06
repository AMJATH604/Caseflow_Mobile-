import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Animated typing indicator with three bouncing dots.
class ChatTypingIndicator extends StatefulWidget {
  final Color dotColor;

  const ChatTypingIndicator({
    super.key,
    this.dotColor = const Color(0xFF94A3B8),
  });

  @override
  State<ChatTypingIndicator> createState() => _ChatTypingIndicatorState();
}

class _ChatTypingIndicatorState extends State<ChatTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) => _buildDot(index)),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final offset = (_controller.value * 3 - index).clamp(0.0, 1.0);
        final bounce = (offset < 0.5)
            ? offset * 2
            : 2 - offset * 2;
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 2.w),
          child: Transform.translate(
            offset: Offset(0, -4 * bounce),
            child: Container(
              width: 6.w,
              height: 6.h,
              decoration: BoxDecoration(
                color: widget.dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}
