import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';

class LogCCDialog extends ConsumerStatefulWidget {
  const LogCCDialog({super.key});

  @override
  ConsumerState<LogCCDialog> createState() => _LogCCDialogState();
}

class _LogCCDialogState extends ConsumerState<LogCCDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCaseId;
  final _caNumberController = TextEditingController();
  DateTime _boxDropDate = DateTime.now();
  String _status = "box_drop";
  bool _isSaving = false;

  @override
  void dispose() {
    _caNumberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedCaseId == null) return;

    setState(() => _isSaving = true);
    try {
      await SupabaseService.createCertifiedCopy({
        'case_id': _selectedCaseId,
        'ca_number': _caNumberController.text.trim(),
        'box_drop_date': DateFormat('yyyy-MM-dd').format(_boxDropDate),
        'status': _status,
      });
      ref.invalidate(certifiedCopiesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(casesProvider);
    const themeColor = AppTheme.info;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Premium Header ───
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    themeColor.withValues(alpha: 0.12),
                    AppTheme.accent.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.description_rounded,
                      color: themeColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "New CC Application",
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Log a certified copy tracking entry",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Form Body ───
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Case Selector
                      Text(
                        "SELECT CASE",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[400],
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      casesAsync.when(
                        data:
                            (cases) => DropdownButtonFormField<String>(
                              value: _selectedCaseId,
                              style: GoogleFonts.inter(
                                color: AppTheme.primary,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: "Choose a case...",
                                prefixIcon: const Icon(
                                  Icons.folder_shared_outlined,
                                  color: AppTheme.accent,
                                ),
                                filled: true,
                                fillColor: AppTheme.background.withValues(
                                  alpha: 0.5,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: AppTheme.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: AppTheme.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: AppTheme.accent,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              items:
                                  cases
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c.id,
                                          child: Text(
                                            c.caseTitle.isEmpty
                                                ? (c.caseNumber ??
                                                    "Case #${c.id.substring(0, 4)}")
                                                : c.caseTitle,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  (val) =>
                                      setState(() => _selectedCaseId = val),
                              validator:
                                  (v) =>
                                      v == null ? "Please select a case" : null,
                            ),
                        loading: () => const LinearProgressIndicator(),
                        error:
                            (e, s) => Text(
                              "Error loading cases: $e",
                              style: const TextStyle(color: AppTheme.error),
                            ),
                      ),
                      const SizedBox(height: 20),

                      // CA Number
                      Text(
                        "CA NUMBER",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[400],
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _caNumberController,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: "e.g. CA/123/2026 (Optional)",
                          prefixIcon: const Icon(
                            Icons.numbers_rounded,
                            color: AppTheme.accent,
                          ),
                          filled: true,
                          fillColor: AppTheme.background.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppTheme.accent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Box Drop Date
                      Text(
                        "APPLICATION DATE",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[400],
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _boxDropDate,
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null)
                            setState(() => _boxDropDate = picked);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.background.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                color: AppTheme.accent,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('dd MMMM yyyy').format(_boxDropDate),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.edit_calendar_rounded,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Initial Status
                      Text(
                        "INITIAL STATUS",
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[400],
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _status,
                        style: GoogleFonts.inter(
                          color: AppTheme.primary,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.track_changes_rounded,
                            color: AppTheme.accent,
                          ),
                          filled: true,
                          fillColor: AppTheme.background.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppTheme.accent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: "box_drop",
                            child: Text("📦  Box Dropped"),
                          ),
                          DropdownMenuItem(
                            value: "memo_filed",
                            child: Text("📋  Memo Filed"),
                          ),
                          DropdownMenuItem(
                            value: "ready",
                            child: Text("✅  Ready for Collection"),
                          ),
                          DropdownMenuItem(
                            value: "collected",
                            child: Text("🤝  Collected"),
                          ),
                        ],
                        onChanged: (val) => setState(() => _status = val!),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Actions ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: AppTheme.border),
                      ),
                      child: Text(
                        "Cancel",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child:
                          _isSaving
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Text(
                                "Log Application",
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
