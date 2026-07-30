import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/strategy_models.dart';
import '../services/repositories/strategy_repository.dart';
import '../theme/app_theme.dart';

/// Bottom sheet dialog to create a new strategy task.
///
/// Requires [caseId] to associate the task.
/// Optionally accepts [firmMembers] for the assignee dropdown
/// and [hearings] for linking to a hearing.
class StrategyCreateDialog extends StatefulWidget {
  final String caseId;
  final List<Map<String, dynamic>> firmMembers;
  final List<Map<String, dynamic>> hearings;

  const StrategyCreateDialog({
    super.key,
    required this.caseId,
    this.firmMembers = const [],
    this.hearings = const [],
  });

  /// Show the dialog as a modal bottom sheet.
  static Future<StrategyTask?> show(
    BuildContext context, {
    required String caseId,
    List<Map<String, dynamic>> firmMembers = const [],
    List<Map<String, dynamic>> hearings = const [],
  }) {
    return showModalBottomSheet<StrategyTask>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StrategyCreateDialog(
        caseId: caseId,
        firmMembers: firmMembers,
        hearings: hearings,
      ),
    );
  }

  @override
  State<StrategyCreateDialog> createState() => _StrategyCreateDialogState();
}

class _StrategyCreateDialogState extends State<StrategyCreateDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  String? _assignedTo;
  DateTime? _dueDate;
  String? _linkedHearingId;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final task = await StrategyRepository.createTask({
        'case_id': widget.caseId,
        'title': title,
        'description': _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        'priority': _priority.name,
        'assigned_to': _assignedTo,
        'due_date': _dueDate?.toIso8601String().split('T').first,
        'linked_hearing_id': _linkedHearingId,
      });
      if (mounted) Navigator.pop(context, task);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Header
              Text(
                'New Task',
                style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 16.h),

              // Title
              _buildLabel('Title'),
              SizedBox(height: 6.h),
              TextField(
                controller: _titleController,
                style: GoogleFonts.inter(fontSize: 14.sp),
                decoration: _inputDecoration('e.g. Draft bail application'),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
              ),
              SizedBox(height: 14.h),

              // Description
              _buildLabel('Description (optional)'),
              SizedBox(height: 6.h),
              TextField(
                controller: _descController,
                style: GoogleFonts.inter(fontSize: 13.sp),
                decoration: _inputDecoration('Add details...'),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              SizedBox(height: 14.h),

              // Priority
              _buildLabel('Priority'),
              SizedBox(height: 6.h),
              Row(
                children: TaskPriority.values.map((p) {
                  final selected = p == _priority;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = p),
                      child: Container(
                        margin: EdgeInsets.only(
                          right: p != TaskPriority.urgent ? 6.w : 0,
                        ),
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        decoration: BoxDecoration(
                          color: selected
                              ? _priorityColor(p).withValues(alpha: 0.12)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: selected
                                ? _priorityColor(p)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${p.emoji} ${p.label}',
                            style: GoogleFonts.inter(
                              fontSize: 11.sp,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected
                                  ? _priorityColor(p)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 14.h),

              // Assignee
              if (widget.firmMembers.isNotEmpty) ...[
                _buildLabel('Assign to'),
                SizedBox(height: 6.h),
                DropdownButtonFormField<String?>(
                  value: _assignedTo,
                  decoration: _inputDecoration('Select team member'),
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: const Color(0xFF1E293B),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ...widget.firmMembers
                        .where((m) => m['id'] != null)
                        .map(
                          (m) => DropdownMenuItem<String?>(
                            value: m['id'].toString(),
                            child: Text(m['full_name']?.toString() ?? 'Member'),
                          ),
                        ),
                  ],
                  onChanged: (v) => setState(() => _assignedTo = v),
                ),
                SizedBox(height: 14.h),
              ],

              // Due Date
              _buildLabel('Due date'),
              SizedBox(height: 6.h),
              GestureDetector(
                onTap: _pickDueDate,
                child: Container(
                  width: double.infinity,
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16.sp,
                        color: const Color(0xFF64748B),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        _dueDate != null
                            ? DateFormat('dd MMM yyyy').format(_dueDate!)
                            : 'Select due date',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          color: _dueDate != null
                              ? const Color(0xFF1E293B)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      if (_dueDate != null) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _dueDate = null),
                          child: Icon(
                            Icons.close,
                            size: 16.sp,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 18.w,
                              height: 18.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Create Task ✓',
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF475569),
        letterSpacing: 0.3,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        fontSize: 13.sp,
        color: const Color(0xFF94A3B8),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.r),
        borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
      ),
      contentPadding:
          EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
    );
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
      case TaskPriority.urgent:
        return AppTheme.error;
      case TaskPriority.high:
        return AppTheme.warning;
      case TaskPriority.medium:
        return const Color(0xFFFBBF24);
      case TaskPriority.low:
        return AppTheme.success;
    }
  }
}
