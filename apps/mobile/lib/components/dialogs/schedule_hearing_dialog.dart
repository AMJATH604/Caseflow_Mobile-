import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/providers.dart';

import '../../theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ScheduleHearingDialog extends ConsumerStatefulWidget {
  const ScheduleHearingDialog({super.key});

  @override
  ConsumerState<ScheduleHearingDialog> createState() =>
      _ScheduleHearingDialogState();
}

class _ScheduleHearingDialogState extends ConsumerState<ScheduleHearingDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCaseId;
  DateTime? _hearingDate = DateTime.now();
  final _purposeController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _selectedCaseId == null ||
        _hearingDate == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await SupabaseService.createHearing({
        'case_id': _selectedCaseId,
        'hearing_date': DateFormat('yyyy-MM-dd').format(_hearingDate!),
        'stage': _purposeController.text,
        'notes': _notesController.text,
      });

      ref.invalidate(hearingsProvider);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(casesProvider);

    return AlertDialog(
      title: const Text(
        'Schedule New Hearing',
        style: TextStyle(
          fontFamily: 'Playfair Display',
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              casesAsync.when(
                data:
                    (cases) => DropdownButtonFormField<String>(
                      initialValue: _selectedCaseId,
                      decoration: const InputDecoration(
                        labelText: 'Select Case',
                      ),
                      items:
                          cases
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    c.caseTitle.isEmpty
                                        ? (c.caseNumber ?? 'Unknown Case')
                                        : c.caseTitle,
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (val) => setState(() => _selectedCaseId = val),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('Error loading cases: $e'),
              ),
              SizedBox(height: 16.h),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _hearingDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _hearingDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Hearing Date'),
                  child: Text(DateFormat('dd MMM yyyy').format(_hearingDate!)),
                ),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(labelText: 'Purpose / Stage'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child:
              _isSaving
                  ? SizedBox(
                    height: 20.h,
                    width: 20.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text('Schedule'),
        ),
      ],
    );
  }
}
