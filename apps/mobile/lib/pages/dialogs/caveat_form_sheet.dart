import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/caveat_models.dart';
import '../../services/caveat_service.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CaveatFormSheet extends ConsumerStatefulWidget {
  final Caveat? caveat;

  const CaveatFormSheet({super.key, this.caveat});

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
    _courtNameController = TextEditingController(
      text: widget.caveat?.courtName ?? '',
    );
    _caseTypeController = TextEditingController(
      text: widget.caveat?.caseType ?? '',
    );
    _caveatorNameController = TextEditingController(
      text: widget.caveat?.caveatorName ?? '',
    );
    _opponentNameController = TextEditingController(
      text: widget.caveat?.opponentName ?? '',
    );
    _subjectMatterController = TextEditingController(
      text: widget.caveat?.subjectMatter ?? '',
    );
    _caveatNumberController = TextEditingController(
      text: widget.caveat?.caveatNumber ?? '',
    );
    _notesController = TextEditingController(text: widget.caveat?.notes ?? '');

    if (widget.caveat != null) {
      _filingDate = widget.caveat!.filingDate;
    }
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.caveat == null ? 'File New Caveat' : 'Edit Caveat',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
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

                  const SizedBox(height: 16),
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

                  const SizedBox(height: 16),
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

                  const SizedBox(height: 16),
                  _buildSectionLabel('Timeline', isDark),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Filing Date',
                            style: GoogleFonts.inter(
                              fontSize: 14,
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
                              borderRadius: BorderRadius.circular(8),
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
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Auto-Expiry Date',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color:
                                        isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Strictly 90 days from filing',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
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
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildSectionLabel('Additional Notes', isDark),
                  _buildTextField(
                    label: 'Notes',
                    controller: _notesController,
                    isDark: isDark,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
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
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
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
                            fontSize: 16,
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
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
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        maxLines: maxLines,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.white10 : AppTheme.borderLight,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark ? Colors.white10 : AppTheme.borderLight,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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
