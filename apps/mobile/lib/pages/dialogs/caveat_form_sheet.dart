import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/caveat_models.dart';
import '../../services/caveat_service.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CaveatFormSheet extends ConsumerStatefulWidget {
  /// The caveat being edited. Null when filing a new one.
  final Caveat? caveat;

  /// A lapsed caveat to copy the court and parties from, filing it afresh
  /// from today. A caveat dies at 90 days and the only remedy is to file
  /// again — re-typing the same court and party names each quarter is the
  /// part advocates actually skip.
  final Caveat? refileFrom;

  const CaveatFormSheet({super.key, this.caveat, this.refileFrom});

  @override
  ConsumerState<CaveatFormSheet> createState() => _CaveatFormSheetState();
}

class _CaveatFormSheetState extends ConsumerState<CaveatFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _courtNameController;
  late TextEditingController _caseTypeController;
  late TextEditingController _caveatorNameController;
  late TextEditingController _opponentNameController;
  late TextEditingController _subjectMatterController;
  late TextEditingController _caveatNumberController;
  late TextEditingController _notesController;

  DateTime _filingDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Editing uses the caveat's own values; a re-file copies everything
    // except the dates and the caveat number, which the court issues anew.
    final source = widget.caveat ?? widget.refileFrom;

    _courtNameController = TextEditingController(text: source?.courtName ?? '');
    _caseTypeController = TextEditingController(text: source?.caseType ?? '');
    _caveatorNameController = TextEditingController(
      text: source?.caveatorName ?? '',
    );
    _opponentNameController = TextEditingController(
      text: source?.opponentName ?? '',
    );
    _subjectMatterController = TextEditingController(
      text: source?.subjectMatter ?? '',
    );
    _caveatNumberController = TextEditingController(
      text: widget.caveat?.caveatNumber ?? '',
    );
    _notesController = TextEditingController(text: source?.notes ?? '');

    if (widget.caveat != null) {
      _filingDate = widget.caveat!.filingDate;
    }
    // A re-file keeps today's date — that is the whole point of re-filing.
  }

  @override
  void dispose() {
    _courtNameController.dispose();
    _caseTypeController.dispose();
    _caveatorNameController.dispose();
    _opponentNameController.dispose();
    _subjectMatterController.dispose();
    _caveatNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.caveat == null) {
        // Create new
        await CaveatService.createCaveat(
          courtName: _courtNameController.text.trim(),
          caseType:
              _caseTypeController.text.trim().isNotEmpty
                  ? _caseTypeController.text.trim()
                  : null,
          caveatorName: _caveatorNameController.text.trim(),
          opponentName: _opponentNameController.text.trim(),
          subjectMatter:
              _subjectMatterController.text.trim().isNotEmpty
                  ? _subjectMatterController.text.trim()
                  : null,
          caveatNumber:
              _caveatNumberController.text.trim().isNotEmpty
                  ? _caveatNumberController.text.trim()
                  : null,
          filingDate: _filingDate,
          notes:
              _notesController.text.trim().isNotEmpty
                  ? _notesController.text.trim()
                  : null,
        );
      } else {
        // Update existing
        await CaveatService.updateCaveat(widget.caveat!.id, {
          'court_name': _courtNameController.text.trim(),
          'case_type':
              _caseTypeController.text.trim().isNotEmpty
                  ? _caseTypeController.text.trim()
                  : null,
          'caveator_name': _caveatorNameController.text.trim(),
          'opponent_name': _opponentNameController.text.trim(),
          'subject_matter':
              _subjectMatterController.text.trim().isNotEmpty
                  ? _subjectMatterController.text.trim()
                  : null,
          'caveat_number':
              _caveatNumberController.text.trim().isNotEmpty
                  ? _caveatNumberController.text.trim()
                  : null,
          'filing_date': _filingDate.toIso8601String().split('T')[0],
          'notes':
              _notesController.text.trim().isNotEmpty
                  ? _notesController.text.trim()
                  : null,
        });
      }

      ref.invalidate(caveatsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.caveat == null
                  ? 'Caveat filed successfully'
                  : 'Caveat updated successfully',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expiryDate = _filingDate.add(const Duration(days: 90));

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          SizedBox(height: 12.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20.r),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.caveat == null ? 'File New Caveat' : 'Edit Caveat',
                  style: GoogleFonts.outfit(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                children: [
                  _buildSectionLabel('Court Details', isDark),
                  _buildTextField(
                    label: 'Court Name *',
                    controller: _courtNameController,
                    isDark: isDark,
                    validator:
                        (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  _buildTextField(
                    label: 'Caveat Number (If available)',
                    controller: _caveatNumberController,
                    isDark: isDark,
                  ),

                  SizedBox(height: 16.h),
                  _buildSectionLabel('Parties', isDark),
                  _buildTextField(
                    label: 'Caveator Name (Your Client) *',
                    controller: _caveatorNameController,
                    isDark: isDark,
                    validator:
                        (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  _buildTextField(
                    label: 'Opponent/Anticipated Petitioner *',
                    controller: _opponentNameController,
                    isDark: isDark,
                    validator:
                        (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),

                  SizedBox(height: 16.h),
                  _buildSectionLabel('Case Information', isDark),
                  _buildTextField(
                    label: 'Anticipated Case Type (e.g. OS, WP)',
                    controller: _caseTypeController,
                    isDark: isDark,
                  ),
                  _buildTextField(
                    label: 'Subject Matter / Property Details',
                    controller: _subjectMatterController,
                    isDark: isDark,
                    maxLines: 2,
                  ),

                  SizedBox(height: 16.h),
                  _buildSectionLabel('Timeline', isDark),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    padding: EdgeInsets.all(16.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Filing Date',
                            style: GoogleFonts.inter(
                              fontSize: 14.sp,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? Colors.white10
                                      : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              DateFormat('dd MMM yyyy').format(_filingDate),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _filingDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setState(() => _filingDate = date);
                            }
                          },
                        ),
                        Divider(height: 24.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto-Expiry Date',
                                  style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Strictly 90 days from filing',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: AppTheme.warning,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              DateFormat('dd MMM yyyy').format(expiryDate),
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.error,
                                fontSize: 16.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),
                  _buildSectionLabel('Additional Notes', isDark),
                  _buildTextField(
                    label: 'Notes',
                    controller: _notesController,
                    isDark: isDark,
                    maxLines: 3,
                  ),
                  SizedBox(height: 80.h),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white10 : AppTheme.borderLight,
                ),
              ),
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child:
                    _isLoading
                        ? SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          widget.caveat == null
                              ? 'Save Caveat Record'
                              : 'Update Caveat',
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFCBD5E1) : Colors.black54,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        style: GoogleFonts.inter(
          fontSize: 14.sp,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            fontSize: 13.sp,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(
              color: isDark ? Colors.white10 : AppTheme.borderLight,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(
              color: isDark ? Colors.white10 : AppTheme.borderLight,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: const BorderSide(color: AppTheme.accent),
          ),
          filled: true,
          fillColor:
              isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.02),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
