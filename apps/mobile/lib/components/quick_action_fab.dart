import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import 'dialogs/schedule_hearing_dialog.dart';
import 'dialogs/new_case_dialog.dart';
import 'dialogs/add_client_dialog.dart';
import 'dialogs/log_cc_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuickActionFAB extends ConsumerStatefulWidget {
  const QuickActionFAB({super.key});

  @override
  ConsumerState<QuickActionFAB> createState() => _QuickActionFABState();
}

class _QuickActionFABState extends ConsumerState<QuickActionFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isExpanded) ...[
          _buildActionItem(
            label: 'New Case',
            icon: Icons.work,
            color: Colors.blue,
            onPressed: () {
              _toggle();
              showDialog(
                context: context,
                builder: (context) => const NewCaseDialog(),
              );
            },
          ),
          SizedBox(height: 16.h),
          _buildActionItem(
            label: 'New Client',
            icon: Icons.person_add,
            color: Colors.green,
            onPressed: () {
              _toggle();
              showDialog(
                context: context,
                builder: (context) => const AddClientDialog(),
              );
            },
          ),
          SizedBox(height: 16.h),
          _buildActionItem(
            label: 'New Hearing',
            icon: Icons.calendar_today,
            color: Colors.amber,
            onPressed: () {
              _toggle();
              showDialog(
                context: context,
                builder: (context) => const ScheduleHearingDialog(),
              );
            },
          ),
          SizedBox(height: 16.h),
          _buildActionItem(
            label: 'Log C.A',
            icon: Icons.note_add,
            color: Colors.deepOrange,
            onPressed: () {
              _toggle();
              showDialog(
                context: context,
                builder: (context) => const LogCCDialog(),
              );
            },
          ),
          SizedBox(height: 16.h),
        ],
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: _isExpanded ? Colors.grey : AppTheme.accent,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * math.pi / 4,
                child: const Icon(Icons.add, size: 28, color: Colors.white),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        FloatingActionButton.small(
          onPressed: onPressed,
          backgroundColor: color,
          heroTag: label,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ],
    );
  }
}
