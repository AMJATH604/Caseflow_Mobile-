import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/providers.dart';

import '../theme/app_theme.dart';

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
        ref.invalidate(hearingsProvider);
        ref.invalidate(casesProvider);
        ref.invalidate(dashboardStatsProvider);

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
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.forward, color: AppTheme.accent),
              const SizedBox(width: 12),
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
          const SizedBox(height: 8),
          const Text(
            'Record what happened today and set the next date.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes for Today (Optional)',
              hintText: 'e.g., Petitioner absent, cost ₹500 imposed...',
            ),
          ),
          const SizedBox(height: 20),
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
                const SizedBox(width: 16),
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
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                    : const Text('Update Diary'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
