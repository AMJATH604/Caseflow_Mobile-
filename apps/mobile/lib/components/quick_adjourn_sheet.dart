import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/paginated_providers.dart';

import '../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QuickAdjournSheet extends ConsumerStatefulWidget {
  final Hearing hearing;
  final VoidCallback? onSuccess;

  const QuickAdjournSheet({super.key, required this.hearing, this.onSuccess});

  @override
  ConsumerState<QuickAdjournSheet> createState() => _QuickAdjournSheetState();
}

class _QuickAdjournSheetState extends ConsumerState<QuickAdjournSheet> {
  final _notesController = TextEditingController();
  CaseStage _selectedStage = CaseStage.filing;
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.hearing.notes ?? '';
    _selectedStage = CaseStage.fromString(widget.hearing.stage ?? 'filing');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final bool isFinal =
        _selectedStage == CaseStage.disposed ||
        _selectedStage == CaseStage.dismissed;

    if (!isFinal && _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a next hearing date.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final newHearing =
          await SupabaseService.adjournHearing(widget.hearing.id, {
            'current_notes': _notesController.text,
            'next_date':
                _selectedDate?.toIso8601String().split('T')[0] ??
                DateTime.now().toIso8601String().split('T')[0],
            'next_stage': _selectedStage.label,
            'case_id': widget.hearing.caseId,
          });

      if (newHearing != null) {}

      if (mounted) {
        // Only what adjourning touches, Case Dossier included — see
        // refreshAfterHearingChange. The global bump reloaded everything.
        refreshAfterHearingChange(ref, widget.hearing.caseId);

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFinal
                  ? 'Case ${_selectedStage.label} Successfully'
                  : 'Case Adjourned and Diary Updated',
            ),
          ),
        );
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20.w,
        right: 20.w,
        top: 20.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.forward, color: AppTheme.accent),
              SizedBox(width: 12.w),
              Text(
                'Quick Adjourn',
                style: AppTheme.lightTheme.textTheme.displaySmall,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          const Text(
            'Record what happened today and set the next date.',
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 24.h),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes for Today (Optional)',
              hintText: 'e.g., Petitioner absent, cost ₹500 imposed...',
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<CaseStage>(
                  initialValue: _selectedStage,
                  decoration: const InputDecoration(labelText: 'Next Stage'),
                  items:
                      CaseStage.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.label),
                            ),
                          )
                          .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedStage = val;
                        // Clear selected date if it's a final stage
                        if (_selectedStage == CaseStage.disposed ||
                            _selectedStage == CaseStage.dismissed) {
                          _selectedDate = null;
                        }
                      });
                    }
                  },
                ),
              ),
              if (_selectedStage != CaseStage.disposed &&
                  _selectedStage != CaseStage.dismissed) ...[
                SizedBox(width: 16.w),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 7),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 5),
                        ),
                      );
                      if (date != null) setState(() => _selectedDate = date);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Next Hearing Date',
                        prefixIcon: Icon(Icons.calendar_month, size: 20),
                      ),
                      child: Text(
                        _selectedDate == null
                            ? 'Select Date'
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 32.h),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child:
                _isLoading
                    ? SizedBox(
                      height: 20.h,
                      width: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                    : const Text('Update Diary'),
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }
}
